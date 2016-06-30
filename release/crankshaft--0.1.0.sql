--DO NOT MODIFY THIS FILE, IT IS GENERATED AUTOMATICALLY FROM SOURCES
-- Complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION crankshaft" to load this file. \quit
-- Version number of the extension release
CREATE OR REPLACE FUNCTION cdb_crankshaft_version()
RETURNS text AS $$
  SELECT '0.1.0'::text;
$$ language 'sql' STABLE STRICT;

-- Internal identifier of the installed extension instence
-- e.g. 'dev' for current development version
CREATE OR REPLACE FUNCTION _cdb_crankshaft_internal_version()
RETURNS text AS $$
  SELECT installed_version FROM pg_available_extensions where name='crankshaft' and pg_available_extensions IS NOT NULL;
$$ language 'sql' STABLE STRICT;
-- Internal function.
-- Set the seeds of the RNGs (Random Number Generators)
-- used internally.
CREATE OR REPLACE FUNCTION
_cdb_random_seeds (seed_value INTEGER) RETURNS VOID
AS $$
  from crankshaft import random_seeds
  random_seeds.set_random_seeds(seed_value)
$$ LANGUAGE plpythonu;
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
-- Moran's I Global Measure (public-facing)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestGlobal(
      subquery TEXT,
      column_name TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (moran NUMERIC, significance NUMERIC)
AS $$
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran(subquery, column_name, w_type, num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu;

-- Moran's I Local (internal function)
CREATE OR REPLACE FUNCTION
  _CDB_AreasOfInterestLocal(
      subquery TEXT,
      column_name TEXT,
      w_type TEXT,
      num_ngbrs INT,
      permutations INT,
      geom_col TEXT,
      id_col TEXT)
RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran_local(subquery, column_name, w_type, num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu;

-- Moran's I Local (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestLocal(
    subquery TEXT,
    column_name TEXT,
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocal(subquery, column_name, w_type, num_ngbrs, permutations, geom_col, id_col);

$$ LANGUAGE SQL;

-- Moran's I only for HH and HL (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialHotspots(
    subquery TEXT,
    column_name TEXT,
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id')
    RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocal(subquery, column_name, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('HH', 'HL');

$$ LANGUAGE SQL;

-- Moran's I only for LL and LH (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialColdspots(
    subquery TEXT,
    attr TEXT,
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id')
    RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocal(subquery, attr, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('LL', 'LH');

$$ LANGUAGE SQL;

-- Moran's I only for LH and HL (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialOutliers(
    subquery TEXT,
    attr TEXT,
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id')
    RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocal(subquery, attr, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('HL', 'LH');

$$ LANGUAGE SQL;

-- Moran's I Global Rate (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestGlobalRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (moran FLOAT, significance FLOAT)
AS $$
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran_rate(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu;


-- Moran's I Local Rate (internal function)
CREATE OR REPLACE FUNCTION
  _CDB_AreasOfInterestLocalRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT,
      num_ngbrs INT,
      permutations INT,
      geom_col TEXT,
      id_col TEXT)
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$
  from crankshaft.clustering import moran_local_rate
  # TODO: use named parameters or a dictionary
  return moran_local_rate(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu;

-- Moran's I Local Rate (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestLocalRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocalRate(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col);

$$ LANGUAGE SQL;

-- Moran's I Local Rate only for HH and HL (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialHotspotsRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocalRate(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('HH', 'HL');

$$ LANGUAGE SQL;

-- Moran's I Local Rate only for LL and LH (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialColdspotsRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocalRate(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('LL', 'LH');

$$ LANGUAGE SQL;

-- Moran's I Local Rate only for LH and HL (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialOutliersRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocalRate(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('HL', 'LH');

$$ LANGUAGE SQL;
CREATE OR REPLACE FUNCTION  CDB_KMeans(query text, no_clusters integer,no_init integer default 20)
RETURNS table (cartodb_id integer, cluster_no integer) as $$
    
    from crankshaft.clustering import kmeans
    return kmeans(query,no_clusters,no_init)

$$ language plpythonu;


CREATE OR REPLACE FUNCTION CDB_WeightedMeanS(state Numeric[],the_geom GEOMETRY(Point, 4326), weight NUMERIC)
RETURNS Numeric[] AS 
$$
DECLARE 
    newX NUMERIC;
    newY NUMERIC;
    newW NUMERIC;
BEGIN
    IF weight IS NULL OR the_geom IS NULL THEN 
        newX = state[1];
        newY = state[2];
        newW = state[3];
    ELSE
        newX = state[1] + ST_X(the_geom)*weight;
        newY = state[2] + ST_Y(the_geom)*weight;
        newW = state[3] + weight;
    END IF;
    RETURN Array[newX,newY,newW];

END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CDB_WeightedMeanF(state Numeric[])
RETURNS GEOMETRY AS 
$$
BEGIN
    IF state[3] = 0 THEN 
        RETURN ST_SetSRID(ST_MakePoint(state[1],state[2]), 4326);
    ELSE 
        RETURN ST_SETSRID(ST_MakePoint(state[1]/state[3], state[2]/state[3]),4326);
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE AGGREGATE CDB_WeightedMean(geometry(Point, 4326), NUMERIC)(
    SFUNC = CDB_WeightedMeanS,
    FINALFUNC = CDB_WeightedMeanF,
    STYPE = Numeric[],
    INITCOND = "{0.0,0.0,0.0}" 
);
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

-- input table format: identical to above but in a predictable format
-- Sample function call:
-- SELECT cdb_spatial_markov('SELECT * FROM real_estate',
--                           'date_1')


-- CREATE OR REPLACE FUNCTION
--   cdb_spatial_markov (
--       subquery TEXT,
--       time_col_min text,
--       time_col_max text,
--       date_format text, -- '_YYYY_MM_DD'
--       num_time_per_bin INT DEFAULT 1,
--   	  permutations INT DEFAULT 99,
--   	  geom_column TEXT DEFAULT 'the_geom',
--   	  id_col TEXT DEFAULT 'cartodb_id',
--       w_type TEXT DEFAULT 'knn',
--       num_ngbrs int DEFAULT 5)
-- RETURNS TABLE (moran FLOAT, quads TEXT, significance FLOAT, ids INT)
-- AS $$
--   plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
--   from crankshaft.clustering import moran_local
--   # TODO: use named parameters or a dictionary
--   return spatial_markov(subquery, time_cols, permutations, geom_column, id_col, w_type, num_ngbrs)
-- $$ LANGUAGE plpythonu;
--
-- -- input table format:
-- -- id | geom | date  | measurement
-- --  1 | Pt1  | 12/3  | 13.2
-- --  2 | Pt2  | 11/5  | 11.3
-- --  3 | Pt1  | 11/13 | 12.9
-- --  4 | Pt3  | 12/19 | 10.1
-- -- ...
--
-- CREATE OR REPLACE FUNCTION
--   cdb_spatial_markov (
--       subquery TEXT,
--       time_col text,
--       num_time_per_bin INT DEFAULT 1,
--   	  permutations INT DEFAULT 99,
--   	  geom_column TEXT DEFAULT 'the_geom',
--   	  id_col TEXT DEFAULT 'cartodb_id',
--       w_type TEXT DEFAULT 'knn',
--       num_ngbrs int DEFAULT 5)
-- RETURNS TABLE (moran FLOAT, quads TEXT, significance FLOAT, ids INT)
-- AS $$
--   plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
--   from crankshaft.clustering import moran_local
--   # TODO: use named parameters or a dictionary
--   return spatial_markov(subquery, time_cols, permutations, geom_column, id_col, w_type, num_ngbrs)
-- $$ LANGUAGE plpythonu;
-- Function by Stuart Lynn for a simple interpolation of a value
-- from a polygon table over an arbitrary polygon
-- (weighted by the area proportion overlapped)
-- Aereal weighting is a very simple form of aereal interpolation.
--
-- Parameters:
--   * geom a Polygon geometry which defines the area where a value will be
--     estimated as the area-weighted sum of a given table/column
--   * target_table_name table name of the table that provides the values
--   * target_column column name of the column that provides the values
--   * schema_name optional parameter to defina the schema the target table
--     belongs to, which is necessary if its not in the search_path.
--     Note that target_table_name should never include the schema in it.
-- Return value:
--   Aereal-weighted interpolation of the column values over the geometry
CREATE OR REPLACE
FUNCTION cdb_overlap_sum(geom geometry, target_table_name text, target_column text, schema_name text DEFAULT NULL)
  RETURNS numeric AS
$$
DECLARE
	result numeric;
  qualified_name text;
BEGIN
  IF schema_name IS NULL THEN
    qualified_name := Format('%I', target_table_name);
  ELSE
    qualified_name := Format('%I.%s', schema_name, target_table_name);
  END IF;
  EXECUTE Format('
    SELECT sum(%I*ST_Area(St_Intersection($1, a.the_geom))/ST_Area(a.the_geom))
    FROM %s AS a
    WHERE $1 && a.the_geom
  ', target_column, qualified_name)
  USING geom
  INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql;
--
-- Creates N points randomly distributed arround the polygon
--
-- @param g - the geometry to be turned in to points
--
-- @param no_points - the number of points to generate
--
-- @params max_iter_per_point - the function generates points in the polygon's bounding box
-- and discards points which don't lie in the polygon. max_iter_per_point specifies how many
-- misses per point the funciton accepts before giving up.
--
-- Returns: Multipoint with the requested points
CREATE OR REPLACE FUNCTION cdb_dot_density(geom geometry , no_points Integer, max_iter_per_point Integer DEFAULT 1000)
RETURNS GEOMETRY AS $$
DECLARE
  extent GEOMETRY;
  test_point Geometry;
  width                NUMERIC;
  height               NUMERIC;
  x0                   NUMERIC;
  y0                   NUMERIC;
  xp                   NUMERIC;
  yp                   NUMERIC;
  no_left              INTEGER;
  remaining_iterations INTEGER;
  points               GEOMETRY[];
  bbox_line            GEOMETRY;
  intersection_line    GEOMETRY;
BEGIN
  extent  := ST_Envelope(geom);
  width   := ST_XMax(extent) - ST_XMIN(extent);
  height  := ST_YMax(extent) - ST_YMIN(extent);
  x0 	  := ST_XMin(extent);
  y0 	  := ST_YMin(extent);
  no_left := no_points;

  LOOP
    if(no_left=0) THEN
      EXIT;
    END IF;
    yp = y0 + height*random();
    bbox_line  = ST_MakeLine(
      ST_SetSRID(ST_MakePoint(yp, x0),4326),
      ST_SetSRID(ST_MakePoint(yp, x0+width),4326)
    );
    intersection_line = ST_Intersection(bbox_line,geom);
  	test_point = ST_LineInterpolatePoint(st_makeline(st_linemerge(intersection_line)),random());
	  points := points || test_point;
	  no_left = no_left - 1 ;
  END LOOP;
  RETURN ST_Collect(points);
END;
$$
LANGUAGE plpgsql VOLATILE;
-- Make sure by default there are no permissions for publicuser
-- NOTE: this happens at extension creation time, as part of an implicit transaction.
-- REVOKE ALL PRIVILEGES ON SCHEMA cdb_crankshaft FROM PUBLIC, publicuser CASCADE;

-- Grant permissions on the schema to publicuser (but just the schema)
GRANT USAGE ON SCHEMA cdb_crankshaft TO publicuser;

-- Revoke execute permissions on all functions in the schema by default
-- REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA cdb_crankshaft FROM PUBLIC, publicuser;
