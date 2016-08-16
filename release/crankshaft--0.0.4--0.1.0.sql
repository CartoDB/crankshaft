--DO NOT MODIFY THIS FILE, IT IS GENERATED FROM SOURCES

-- Complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION crankshaft" to load this file. \quit

--------------------------------------------------------------------------------

-- Version number of the extension release
CREATE OR REPLACE FUNCTION cdb_crankshaft_version()
RETURNS text AS $$
  SELECT '0.1.0'::text;
$$ language 'sql' STABLE STRICT;

--------------------------------------------------------------------------------

-- PyAgg stuff
CREATE OR REPLACE FUNCTION
    CDB_PyAggS(current_state Numeric[], current_row Numeric[]) 
    returns NUMERIC[] as $$
    BEGIN
        if array_upper(current_state,1) is null  then
            RAISE NOTICE 'setting state %',array_upper(current_row,1);
            current_state[1] = array_upper(current_row,1);
        end if;
        return array_cat(current_state,current_row) ;
    END
    $$ LANGUAGE plpgsql;


CREATE AGGREGATE CDB_PyAgg(NUMERIC[])(
    SFUNC = CDB_PyAggS,
    STYPE = Numeric[],
    INITCOND = "{}" 
);

--------------------------------------------------------------------------------

-- Segmentation stuff
CREATE OR REPLACE FUNCTION
  CDB_CreateAndPredictSegment(
    target NUMERIC[],
    features NUMERIC[],
    target_features NUMERIC[],
    target_ids NUMERIC[],
    n_estimators INTEGER DEFAULT 1200,
    max_depth INTEGER DEFAULT 3,
    subsample DOUBLE PRECISION DEFAULT 0.5,
    learning_rate DOUBLE PRECISION DEFAULT 0.01,
    min_samples_leaf INTEGER DEFAULT 1)
RETURNS TABLE(cartodb_id NUMERIC, prediction NUMERIC, accuracy NUMERIC)
AS $$
    import numpy as np
    import plpy

    from crankshaft.segmentation import create_and_predict_segment_agg
    model_params = {'n_estimators': n_estimators,
                    'max_depth': max_depth,
                    'subsample': subsample,
                    'learning_rate': learning_rate,
                    'min_samples_leaf': min_samples_leaf}

    def unpack2D(data):
        dimension = data.pop(0)
        a = np.array(data, dtype=float)
        return a.reshape(len(a)/dimension, dimension)

    return create_and_predict_segment_agg(np.array(target, dtype=float),
            unpack2D(features),
            unpack2D(target_features),
            target_ids,
            model_params)

$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
  CDB_CreateAndPredictSegment (
      query TEXT,
      variable_name TEXT,
      target_table TEXT,
      n_estimators INTEGER DEFAULT 1200,
      max_depth INTEGER DEFAULT 3,
      subsample DOUBLE PRECISION DEFAULT 0.5,
      learning_rate DOUBLE PRECISION DEFAULT 0.01,
      min_samples_leaf INTEGER DEFAULT 1)
RETURNS TABLE (cartodb_id TEXT, prediction NUMERIC, accuracy NUMERIC)
AS $$
  from crankshaft.segmentation import create_and_predict_segment
  model_params = {'n_estimators': n_estimators, 'max_depth':max_depth, 'subsample' : subsample, 'learning_rate': learning_rate, 'min_samples_leaf' : min_samples_leaf}
  return create_and_predict_segment(query,variable_name,target_table, model_params)
$$ LANGUAGE plpythonu;

--------------------------------------------------------------------------------

-- Spatial interpolation

-- 0: nearest neighbor
-- 1: barymetric
-- 2: IDW

CREATE OR REPLACE FUNCTION CDB_SpatialInterpolation(
    IN query text,
    IN point geometry,
    IN method integer DEFAULT 1,
    IN p1 numeric DEFAULT 0,
    IN p2 numeric DEFAULT 0
    )
RETURNS numeric AS
$$
DECLARE
    gs geometry[];
    vs numeric[];
    output numeric;
BEGIN
    EXECUTE 'WITH a AS('||query||') SELECT array_agg(the_geom), array_agg(attrib) FROM a' INTO gs, vs;
    SELECT CDB_SpatialInterpolation(gs, vs, point, method, p1,p2) INTO output FROM a;

    RETURN output;
END;
$$
language plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION CDB_SpatialInterpolation(
    IN geomin geometry[],
    IN colin numeric[],
    IN point geometry,
    IN method integer DEFAULT 1,
    IN p1 numeric DEFAULT 0,
    IN p2 numeric DEFAULT 0
    )
RETURNS numeric AS
$$
DECLARE
    gs geometry[];
    vs numeric[];
    gs2 geometry[];
    vs2 numeric[];
    g geometry;
    vertex geometry[];
    sg numeric;
    sa numeric;
    sb numeric;
    sc numeric;
    va numeric;
    vb numeric;
    vc numeric;
    output numeric;
BEGIN
    output :=  -999.999;
    -- nearest
    IF method = 0 THEN

        WITH    a as (SELECT unnest(geomin) as g, unnest(colin) as v)
        SELECT a.v INTO output FROM a ORDER BY point<->a.g LIMIT 1;
        RETURN output;

    -- barymetric
    ELSIF method = 1 THEN
        WITH    a as (SELECT unnest(geomin) AS e),
                b as (SELECT ST_DelaunayTriangles(ST_Collect(a.e),0.001, 0) AS t FROM a),
                c as (SELECT (ST_Dump(t)).geom as v FROM b),
                d as (SELECT v FROM c WHERE ST_Within(point, v))
            SELECT v INTO g FROM d;
        IF g is null THEN
            -- out of the realm of the input data
            RETURN -888.888;
        END IF;
        -- vertex of the selected cell
        WITH a AS (SELECT (ST_DumpPoints(g)).geom AS v)
                SELECT array_agg(v) INTO vertex FROM a;

            -- retrieve the value of each vertex
        WITH a AS(SELECT unnest(vertex) as geo, unnest(colin) as c)
            SELECT c INTO va FROM a WHERE ST_Equals(geo, vertex[1]);
        WITH a AS(SELECT unnest(vertex) as geo, unnest(colin) as c)
            SELECT c INTO vb FROM a WHERE ST_Equals(geo, vertex[2]);
        WITH a AS(SELECT unnest(vertex) as geo, unnest(colin) as c)
                SELECT c INTO vc FROM a WHERE ST_Equals(geo, vertex[3]);

        SELECT ST_area(g), ST_area(ST_MakePolygon(ST_MakeLine(ARRAY[point, vertex[2], vertex[3], point]))), ST_area(ST_MakePolygon(ST_MakeLine(ARRAY[point, vertex[1], vertex[3], point]))), ST_area(ST_MakePolygon(ST_MakeLine(ARRAY[point,vertex[1],vertex[2], point]))) INTO sg, sa, sb, sc;

        output := (coalesce(sa,0) * coalesce(va,0) + coalesce(sb,0) * coalesce(vb,0) + coalesce(sc,0) * coalesce(vc,0)) / coalesce(sg);
        RETURN output;

    -- IDW
    -- p1: limit the number of neighbors, 0->no limit
    -- p2: order of distance decay, 0-> order 1
    ELSIF method = 2 THEN

        IF p2 = 0 THEN
            p2 := 1;
        END IF;

        WITH    a as (SELECT unnest(geomin) as g, unnest(colin) as v),
                b as (SELECT a.g, a.v FROM a ORDER BY point<->a.g)
        SELECT array_agg(b.g), array_agg(b.v) INTO gs, vs FROM b;
        IF p1::integer>0 THEN
            gs2:=gs;
            vs2:=vs;
            FOR i IN 1..p1
            LOOP
                gs2 := gs2 || gs[i];
                vs2 := vs2 || vs[i];
            END LOOP;
        ELSE
            gs2:=gs;
            vs2:=vs;
        END IF;

        WITH    a as (SELECT unnest(gs2) as g, unnest(vs2) as v),
                b as (
                    SELECT
                    (1/ST_distance(point, a.g)^p2::integer) as k,
                    (a.v/ST_distance(point, a.g)^p2::integer) as f
                    FROM a
                )
        SELECT sum(b.f)/sum(b.k) INTO output FROM b;
        RETURN output;

    END IF;

    RETURN -777.777;

END;
$$
language plpgsql IMMUTABLE;


--------------------------------------------------------------------------------

-- Spatial Markov

-- input table format:
-- id | geom | date_1 | date_2 | date_3
--  1 | Pt1  | 12.3   | 13.1   | 14.2
--  2 | Pt2  | 11.0   | 13.2   | 12.5
--  ...
-- Sample Function call:
-- SELECT CDB_SpatialMarkov('SELECT * FROM real_estate',
--                          Array['date_1', 'date_2', 'date_3'])

CREATE OR REPLACE FUNCTION
  CDB_SpatialMarkovTrend (
      subquery TEXT,
      time_cols TEXT[],
      num_classes INT DEFAULT 7,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
  	  permutations INT DEFAULT 99,
  	  geom_col TEXT DEFAULT 'the_geom',
  	  id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (trend NUMERIC, trend_up NUMERIC, trend_down NUMERIC, volatility NUMERIC, rowid INT)
AS $$

  from crankshaft.space_time_dynamics import spatial_markov_trend

  ## TODO: use named parameters or a dictionary
  return spatial_markov_trend(subquery, time_cols, num_classes, w_type, num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu;
