--DO NOT MODIFY THIS FILE, IT IS GENERATED AUTOMATICALLY FROM SOURCES
-- Complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION crankshaft" to load this file. \quit
-- Version number of the extension release
CREATE OR REPLACE FUNCTION cdb_crankshaft_version()
RETURNS text AS $$
  SELECT '0.6.0'::text;
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

-- Create aggregate if it did not exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT *
        FROM pg_catalog.pg_proc p
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'cdb_crankshaft'
            AND p.proname = 'cdb_pyagg'
            AND p.proisagg)
    THEN
        CREATE AGGREGATE CDB_PyAgg(NUMERIC[]) (
            SFUNC = CDB_PyAggS,
            STYPE = Numeric[],
            INITCOND = "{}"
        );
    END IF;
END
$$ LANGUAGE plpgsql;

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
CREATE OR REPLACE FUNCTION CDB_Gravity(
    IN target_query text,
    IN weight_column text,
    IN source_query text,
    IN pop_column text,
    IN target bigint,
    IN radius integer,
    IN minval numeric DEFAULT -10e307
    )
RETURNS TABLE(
    the_geom geometry,
    source_id bigint,
    target_id bigint,
    dist numeric,
    h numeric,
    hpop numeric)  AS $$
DECLARE
    t_id bigint[];
    t_geom geometry[];
    t_weight numeric[];
    s_id bigint[];
    s_geom geometry[];
    s_pop numeric[];
BEGIN
    EXECUTE 'WITH foo as('+target_query+') SELECT array_agg(cartodb_id), array_agg(the_geom), array_agg(' || weight_column || ') FROM foo' INTO t_id, t_geom, t_weight;
    EXECUTE 'WITH foo as('+source_query+') SELECT array_agg(cartodb_id), array_agg(the_geom), array_agg(' || pop_column || ') FROM foo' INTO s_id, s_geom, s_pop;
    RETURN QUERY
    SELECT g.* FROM t, s, CDB_Gravity(t_id, t_geom, t_weight, s_id, s_geom, s_pop, target, radius, minval) g;
END;
$$ language plpgsql;

CREATE OR REPLACE FUNCTION CDB_Gravity(
    IN t_id bigint[],
    IN t_geom geometry[],
    IN t_weight numeric[],
    IN s_id bigint[],
    IN s_geom geometry[],
    IN s_pop numeric[],
    IN target bigint,
    IN radius integer,
    IN minval numeric DEFAULT -10e307
    )
RETURNS TABLE(
    the_geom geometry,
    source_id bigint,
    target_id bigint,
    dist numeric,
    h numeric,
    hpop numeric)  AS $$
DECLARE
    t_type text;
    s_type text;
    t_center geometry[];
    s_center geometry[];
BEGIN
    t_type := GeometryType(t_geom[1]);
    s_type := GeometryType(s_geom[1]);
    IF t_type = 'POINT' THEN
        t_center := t_geom;
    ELSE
        WITH tmp as (SELECT unnest(t_geom) as g) SELECT array_agg(ST_Centroid(g)) INTO t_center FROM tmp;
    END IF;
    IF s_type = 'POINT' THEN
        s_center := s_geom;
    ELSE
        WITH tmp as (SELECT unnest(s_geom) as g) SELECT array_agg(ST_Centroid(g)) INTO s_center FROM tmp;
    END IF;
    RETURN QUERY
        with target0 as(
            SELECT unnest(t_center) as tc, unnest(t_weight) as tw, unnest(t_id) as td
        ),
        source0 as(
            SELECT unnest(s_center) as sc, unnest(s_id) as sd, unnest (s_geom) as sg, unnest(s_pop) as sp
        ),
        prev0 as(
            SELECT
                source0.sg,
                source0.sd as sourc_id,
                coalesce(source0.sp,0) as sp,
                target.td as targ_id,
                coalesce(target.tw,0) as tw,
                GREATEST(1.0,ST_Distance(geography(target.tc), geography(source0.sc)))::numeric as distance
            FROM source0
            CROSS JOIN LATERAL
                (
                SELECT
                    *
                FROM target0
                    WHERE tw > minval
                    AND ST_DWithin(geography(source0.sc), geography(tc), radius)
                ) AS target
        ),
        deno as(
            SELECT
                sourc_id,
                sum(tw/distance) as h_deno
            FROM
                prev0
            GROUP BY sourc_id
        )
        SELECT
            p.sg as the_geom,
            p.sourc_id as source_id,
            p.targ_id as target_id,
            case when p.distance > 1 then p.distance else 0.0 end as dist,
            100*(p.tw/p.distance)/d.h_deno as h,
            p.sp*(p.tw/p.distance)/d.h_deno as hpop
        FROM
            prev0 p,
            deno d
        WHERE
            p.targ_id = target AND
            p.sourc_id = d.sourc_id;
END;
$$ language plpgsql;
-- 0: nearest neighbor(s)
-- 1: barymetric
-- 2: IDW
-- 3: krigin ---> TO DO


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
    -- output :=  -999.999;

    -- nearest neighbors
    -- p1: limit the number of neighbors, 0-> closest one
    IF method = 0 THEN

        IF p1 = 0 THEN
            p1 := 1;
        END IF;

        WITH    a as (SELECT unnest(geomin) as g, unnest(colin) as v),
                b as (SELECT a.v as v FROM a ORDER BY point<->a.g LIMIT p1::integer)
        SELECT avg(b.v) INTO output FROM b;
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
        WITH a AS(SELECT unnest(geomin) as geo, unnest(colin) as c)
            SELECT c INTO va FROM a WHERE ST_Equals(geo, vertex[1]);
        WITH a AS(SELECT unnest(geomin) as geo, unnest(colin) as c)
            SELECT c INTO vb FROM a WHERE ST_Equals(geo, vertex[2]);
        WITH a AS(SELECT unnest(geomin) as geo, unnest(colin) as c)
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

    -- krigin
    ELSIF method = 3 THEN

    --  TO DO

    END IF;

    RETURN -777.777;

END;
$$
language plpgsql IMMUTABLE;
-- =============================================================================================
--
-- CDB_Voronoi
--
-- =============================================================================================
CREATE OR REPLACE FUNCTION CDB_voronoi(
    IN geomin geometry[],
    IN buffer numeric DEFAULT 0.5,
    IN tolerance numeric DEFAULT 1e-9
    )
RETURNS geometry  AS $$
DECLARE
    geomout geometry;
BEGIN
    -- we need to make the geometry calculations in (pseudo)meters!!!
    with a as (
        SELECT unnest(geomin) as g1
    ),
    b as(
        SELECT st_transform(g1, 3857) g2 from a
    )
    SELECT array_agg(g2) INTO geomin from b;

    WITH
    convexhull_1 as (
        SELECT
            ST_ConvexHull(ST_Collect(geomin)) as g,
            buffer * |/ (st_area(ST_ConvexHull(ST_Collect(geomin)))/PI()) as r
    ),
    clipper as(
        SELECT
            st_buffer(ST_MinimumBoundingCircle(a.g), buffer*a.r)  as g
        FROM convexhull_1 a
    ),
    env0 as (
        SELECT
            (st_dumppoints(st_expand(a.g, buffer*a.r))).geom as e
        FROM  convexhull_1 a
    ),
    env as (
        SELECT
            array_agg(env0.e) as e
        FROM  env0
    ),
    sample AS (
        SELECT
            ST_Collect(geomin || env.e) as geom
        FROM env
    ),
    convexhull as (
        SELECT
            ST_ConvexHull(ST_Collect(geomin)) as cg
    ),
    tin as (
        SELECT
            ST_Dump(ST_DelaunayTriangles(geom, tolerance, 0)) as gd
        FROM
            sample
    ),
    tin_polygons as (
        SELECT
            (gd).Path as id,
            (gd).Geom as pg,
            ST_Centroid(ST_MinimumBoundingCircle((gd).Geom, 180)) as ct
        FROM tin
    ),
    tin_lines as (
        SELECT
            id,
            ST_ExteriorRing(pg) as lg
        FROM tin_polygons
    ),
    tin_nodes as (
        SELECT
            id,
            ST_PointN(lg,1) p1,
            ST_PointN(lg,2) p2,
            ST_PointN(lg,3) p3
        FROM tin_lines
    ),
    tin_edges AS (
        SELECT
            p.id,
            UNNEST(ARRAY[
            ST_MakeLine(n.p1,n.p2) ,
            ST_MakeLine(n.p2,n.p3) ,
            ST_MakeLine(n.p3,n.p1)]) as Edge,
            ST_Force2D(cdb_crankshaft._Find_Circle(n.p1,n.p2,n.p3)) as ct,
            CASE WHEN st_distance(p.ct, ST_ExteriorRing(p.pg)) < tolerance THEN
                TRUE
            ELSE  FALSE END AS ctx,
            p.pg,
            ST_within(p.ct, convexhull.cg) as ctin
        FROM
            tin_polygons p,
            tin_nodes n,
            convexhull
        WHERE p.id = n.id
    ),
    voro_nodes as (
        SELECT
            CASE WHEN x.ctx = TRUE THEN
                ST_Centroid(x.edge)
            ELSE
                x.ct
            END as xct,
            CASE WHEN y.id is null THEN
                CASE WHEN x.ctin = TRUE THEN
                    ST_SetSRID(ST_MakePoint(
                        ST_X(x.ct) + ((ST_X(ST_Centroid(x.edge)) - ST_X(x.ct)) * (1+buffer)),
                        ST_Y(x.ct) + ((ST_Y(ST_Centroid(x.edge)) - ST_Y(x.ct)) * (1+buffer))
                    ), ST_SRID(x.ct))
                END
            ELSE
                y.ct
            END as yct
        FROM
            tin_edges x
        LEFT OUTER JOIN
            tin_edges y
        ON x.id <> y.id AND ST_Equals(x.edge, y.edge)
    ),
    voro_edges as(
        SELECT
            ST_LineMerge(ST_Collect(ST_MakeLine(xct, yct))) as v
        FROM
            voro_nodes
    ),
    voro_cells as(
        SELECT
            ST_Polygonize(
                ST_Node(
                    ST_LineMerge(
                        ST_Union(v, ST_ExteriorRing(
                            ST_Convexhull(v)
                            )
                        )
                    )
                )
            ) as g
        FROM
            voro_edges
    ),
    voro_set as(
        SELECT
        (st_dump(v.g)).geom as g
        FROM voro_cells v
    ),
    clipped_voro as(
        SELECT
            ST_intersection(c.g, v.g) as g
        FROM
            voro_set v,
            clipper c
        WHERE
            ST_GeometryType(v.g) = 'ST_Polygon'
    )
    SELECT
        st_collect(
            ST_Transform(
                ST_ConvexHull(g),
                4326
            )
        )
    INTO geomout
    FROM
        clipped_voro;
    RETURN geomout;
END;
$$ language plpgsql IMMUTABLE;

/** ----------------------------------------------------------------------------------------
  * @function   : FindCircle
  * @precis     : Function that determines if three points form a circle. If so a table containing
  *               centre and radius is returned. If not, a null table is returned.
  * @version    : 1.0.1
  * @param      : p_pt1        : First point in curve
  * @param      : p_pt2        : Second point in curve
  * @param      : p_pt3        : Third point in curve
  * @return     : geometry     : In which X,Y ordinates are the centre X, Y and the Z being the radius of found circle
  *                              or NULL if three points do not form a circle.
  * @history    : Simon Greener - Feb 2012 - Original coding.
  *               Rafa de la Torre - Aug 2016 - Small fix for type checking
  * @copyright  : Simon Greener @ 2012
  *               Licensed under a Creative Commons Attribution-Share Alike 2.5 Australia License. (http://creativecommons.org/licenses/by-sa/2.5/au/)
**/
CREATE OR REPLACE FUNCTION _Find_Circle(
    IN p_pt1 geometry,
    IN p_pt2 geometry,
    IN p_pt3 geometry)
  RETURNS geometry AS
$BODY$
DECLARE
   v_Centre geometry;
   v_radius NUMERIC;
   v_CX     NUMERIC;
   v_CY     NUMERIC;
   v_dA     NUMERIC;
   v_dB     NUMERIC;
   v_dC     NUMERIC;
   v_dD     NUMERIC;
   v_dE     NUMERIC;
   v_dF     NUMERIC;
   v_dG     NUMERIC;
BEGIN
   IF ( p_pt1 IS NULL OR p_pt2 IS NULL OR p_pt3 IS NULL ) THEN
      RAISE EXCEPTION 'All supplied points must be not null.';
      RETURN NULL;
   END IF;
   IF ( ST_GeometryType(p_pt1) <> 'ST_Point' OR
        ST_GeometryType(p_pt2) <> 'ST_Point' OR
        ST_GeometryType(p_pt3) <> 'ST_Point' ) THEN
      RAISE EXCEPTION 'All supplied geometries must be points.';
      RETURN NULL;
   END IF;
   v_dA := ST_X(p_pt2) - ST_X(p_pt1);
   v_dB := ST_Y(p_pt2) - ST_Y(p_pt1);
   v_dC := ST_X(p_pt3) - ST_X(p_pt1);
   v_dD := ST_Y(p_pt3) - ST_Y(p_pt1);
   v_dE := v_dA * (ST_X(p_pt1) + ST_X(p_pt2)) + v_dB * (ST_Y(p_pt1) + ST_Y(p_pt2));
   v_dF := v_dC * (ST_X(p_pt1) + ST_X(p_pt3)) + v_dD * (ST_Y(p_pt1) + ST_Y(p_pt3));
   v_dG := 2.0  * (v_dA * (ST_Y(p_pt3) - ST_Y(p_pt2)) - v_dB * (ST_X(p_pt3) - ST_X(p_pt2)));
   -- If v_dG is zero then the three points are collinear and no finite-radius
   -- circle through them exists.
   IF ( v_dG = 0 ) THEN
      RETURN NULL;
   ELSE
      v_CX := (v_dD * v_dE - v_dB * v_dF) / v_dG;
      v_CY := (v_dA * v_dF - v_dC * v_dE) / v_dG;
      v_Radius := SQRT(POWER(ST_X(p_pt1) - v_CX,2) + POWER(ST_Y(p_pt1) - v_CY,2) );
   END IF;
   RETURN ST_SetSRID(ST_MakePoint(v_CX, v_CY, v_radius),ST_Srid(p_pt1));
END;
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT;

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
  from crankshaft.clustering import Moran
  # TODO: use named parameters or a dictionary
  moran = Moran()
  return moran.global_stat(subquery, column_name, w_type,
                           num_ngbrs, permutations, geom_col, id_col)
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
  from crankshaft.clustering import Moran
  moran = Moran()
  # TODO: use named parameters or a dictionary
  return moran.local_stat(subquery, column_name, w_type,
                          num_ngbrs, permutations, geom_col, id_col)
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
  from crankshaft.clustering import Moran
  moran = Moran()
  # TODO: use named parameters or a dictionary
  return moran.global_rate_stat(subquery, numerator, denominator, w_type,
                                num_ngbrs, permutations, geom_col, id_col)
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
  from crankshaft.clustering import Moran
  moran = Moran()
  # TODO: use named parameters or a dictionary
  return moran.local_rate_stat(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col)
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
-- Spatial k-means clustering

CREATE OR REPLACE FUNCTION CDB_KMeans(query text, no_clusters integer, no_init integer default 20)
RETURNS table (cartodb_id integer, cluster_no integer) as $$

    from crankshaft.clustering import Kmeans
    kmeans = Kmeans()
    return kmeans.spatial(query, no_clusters, no_init)

$$ LANGUAGE plpythonu;


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

-- Create aggregate if it did not exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT *
        FROM pg_catalog.pg_proc p
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'cdb_crankshaft'
            AND p.proname = 'cdb_weightedmean'
            AND p.proisagg)
    THEN
        CREATE AGGREGATE CDB_WeightedMean(geometry(Point, 4326), NUMERIC) (
            SFUNC = CDB_WeightedMeanS,
            FINALFUNC = CDB_WeightedMeanF,
            STYPE = Numeric[],
            INITCOND = "{0.0,0.0,0.0}"
        );
    END IF;
END
$$ LANGUAGE plpgsql;
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

  from crankshaft.space_time_dynamics import Markov
  markov = Markov()

  ## TODO: use named parameters or a dictionary
  return markov.spatial_trend(subquery, time_cols, num_classes, w_type, num_ngbrs, permutations, geom_col, id_col)
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
-- Based on:
-- https://github.com/mapbox/polylabel/blob/master/index.js
-- https://sites.google.com/site/polesofinaccessibility/
-- Requires: https://github.com/CartoDB/cartodb-postgresql

-- Based on:
-- https://github.com/mapbox/polylabel/blob/master/index.js
-- https://sites.google.com/site/polesofinaccessibility/
-- Requires: https://github.com/CartoDB/cartodb-postgresql

CREATE OR REPLACE FUNCTION CDB_PIA(
    IN polygon geometry,
    IN tolerance numeric DEFAULT 1.0
    )
RETURNS geometry  AS $$
DECLARE
    env geometry[];
    cells geometry[];
    cell geometry;
    best_c geometry;
    best_d numeric;
    test_d numeric;
    test_mx numeric;
    test_h numeric;
    test_cells geometry[];
    width numeric;
    height numeric;
    h numeric;
    i integer;
    n integer;
    sqr numeric;
    p geometry;
BEGIN
    sqr := |/2;
    polygon := ST_Transform(polygon, 3857);

    -- grid #0 cell size
    height := ST_YMax(polygon) - ST_YMin(polygon);
    width := ST_XMax(polygon) - ST_XMin(polygon);
    h := 0.5*LEAST(height, width);

    -- grid #0
    with c1 as(
        SELECT cdb_crankshaft.CDB_RectangleGrid(polygon, h, h) as c
    )
    SELECT array_agg(c) INTO cells FROM c1;

    -- 1st guess: centroid
    best_d := cdb_crankshaft._Signed_Dist(polygon, ST_Centroid(Polygon));

    -- looping the loop
    n := array_length(cells,1);
    i := 1;
    LOOP

        EXIT WHEN i > n;

        cell := cells[i];
        i := i+1;

        -- cell side size, it's square
        test_h := ST_XMax(cell) - ST_XMin(cell) ;

        -- check distance
        test_d := cdb_crankshaft._Signed_Dist(polygon, ST_Centroid(cell));
        IF test_d > best_d THEN
            best_d := test_d;
            best_c := cells[i];
        END IF;

        -- longest distance within the cell
        test_mx := test_d + (test_h/2 * sqr);

        -- if the cell has no chance to contains the desired point, continue
        CONTINUE WHEN test_mx - best_d <= tolerance;

        -- resample the cell
        with c1 as(
            SELECT cdb_crankshaft.CDB_RectangleGrid(cell, test_h/2, test_h/2) as c
        )
        SELECT array_agg(c) INTO test_cells FROM c1;

        -- concat the new cells to the former array
        cells := cells || test_cells;

        -- prepare next iteration
        n := array_length(cells,1);

    END LOOP;

    RETURN ST_transform(ST_Centroid(best_c), 4326);

END;
$$ language plpgsql IMMUTABLE;


-- signed distance point to polygon with holes
-- negative is the point is out the polygon
CREATE OR REPLACE FUNCTION _Signed_Dist(
    IN polygon geometry,
    IN point geometry
    )
RETURNS numeric  AS $$
DECLARE
    i integer;
    within integer;
    holes integer;
    dist numeric;
BEGIN
    dist := 1e999;
    SELECT LEAST(dist, ST_distance(point, ST_ExteriorRing(polygon))::numeric) INTO dist;
    SELECT CASE WHEN ST_Within(point,polygon) THEN 1 ELSE -1 END INTO within;
    SELECT ST_NumInteriorRings(polygon) INTO holes;
    IF holes > 0 THEN
        FOR i IN 1..holes
        LOOP
            SELECT LEAST(dist, ST_distance(point, ST_InteriorRingN(polygon, i))::numeric) INTO dist;
        END LOOP;
    END IF;
    dist := dist * within::numeric;
    RETURN dist;
END;
$$ language plpgsql IMMUTABLE;
--
-- Iterative densification of a set of points using Delaunay triangulation
-- the new points have as assigned value the average value of the 3 vertex (centroid)
--
-- @param geomin - array of geometries (points)
--
-- @param colin - array of numeric values in that points
--
-- @param iterations - integer, number of iterations
--
--
-- Returns: TABLE(geomout geometry, colout numeric)
--
--
CREATE OR REPLACE FUNCTION CDB_Densify(
    IN geomin geometry[],
    IN colin numeric[],
    IN iterations integer
    )
RETURNS TABLE(geomout geometry, colout numeric)  AS $$
DECLARE
    geotemp geometry[];
    coltemp numeric[];
    i integer;
    gs geometry[];
    g geometry;
    vertex geometry[];
    va numeric;
    vb numeric;
    vc numeric;
    center geometry;
    centerval numeric;
    tmp integer;
BEGIN
    geotemp := geomin;
    coltemp := colin;
    FOR i IN 1..iterations
    LOOP
        -- generate TIN
        WITH    a as (SELECT unnest(geotemp) AS e),
                b as (SELECT ST_DelaunayTriangles(ST_Collect(a.e),0.001, 0) AS t FROM a),
                c as (SELECT (ST_Dump(t)).geom AS v FROM b)
        SELECT array_agg(v) INTO gs FROM c;
        -- loop cells
        FOREACH g IN ARRAY gs
        LOOP
            -- append centroid
            SELECT ST_Centroid(g) INTO center;
            geotemp := array_append(geotemp, center);
            -- retrieve the value of each vertex
            WITH a AS (SELECT (ST_DumpPoints(g)).geom AS v)
            SELECT array_agg(v) INTO vertex FROM a;
            WITH a AS(SELECT unnest(geotemp) as geo, unnest(coltemp) as c)
            SELECT c INTO va FROM a WHERE ST_Equals(geo, vertex[1]);
            WITH a AS(SELECT unnest(geotemp) as geo, unnest(coltemp) as c)
            SELECT c INTO vb FROM a WHERE ST_Equals(geo, vertex[2]);
            WITH a AS(SELECT unnest(geotemp) as geo, unnest(coltemp) as c)
            SELECT c INTO vc FROM a WHERE ST_Equals(geo, vertex[3]);
            -- calc the value at the center
            centerval := (va + vb + vc) / 3;
            -- append the value
            coltemp := array_append(coltemp, centerval);
        END LOOP;
    END LOOP;
    RETURN QUERY SELECT unnest(geotemp ) as geomout, unnest(coltemp ) as colout;
END;
$$ language plpgsql IMMUTABLE;
CREATE OR REPLACE FUNCTION CDB_TINmap(
    IN geomin geometry[],
    IN colin numeric[],
    IN iterations integer
    )
RETURNS TABLE(geomout geometry, colout numeric)  AS $$
DECLARE
    p geometry[];
    vals numeric[];
    gs geometry[];
    g geometry;
    vertex geometry[];
    centerval numeric;
    va numeric;
    vb numeric;
    vc numeric;
    coltemp numeric[];
BEGIN
    SELECT array_agg(dens.geomout), array_agg(dens.colout) INTO p, vals FROM cdb_crankshaft.CDB_Densify(geomin, colin, iterations) dens;
    WITH    a as (SELECT unnest(p) AS e),
            b as (SELECT ST_DelaunayTriangles(ST_Collect(a.e),0.001, 0) AS t FROM a),
            c as (SELECT (ST_Dump(t)).geom AS v FROM b)
        SELECT array_agg(v) INTO gs FROM c;
    FOREACH g IN ARRAY gs
    LOOP
        -- retrieve the vertex of each triangle
        WITH a AS (SELECT (ST_DumpPoints(g)).geom AS v)
            SELECT array_agg(v) INTO vertex FROM a;
        -- retrieve the value of each vertex
        WITH a AS(SELECT unnest(p) as geo, unnest(vals) as c)
            SELECT c INTO va FROM a WHERE ST_Equals(geo, vertex[1]);
        WITH a AS(SELECT unnest(p) as geo, unnest(vals) as c)
            SELECT c INTO vb FROM a WHERE ST_Equals(geo, vertex[2]);
        WITH a AS(SELECT unnest(p) as geo, unnest(vals) as c)
            SELECT c INTO vc FROM a WHERE ST_Equals(geo, vertex[3]);
        -- calc the value at the center
        centerval := (va + vb + vc) / 3;
        -- append the value
        coltemp := array_append(coltemp, centerval);
    END LOOP;
    RETURN QUERY SELECT unnest(gs) as geomout, unnest(coltemp ) as colout;
END;
$$ language plpgsql IMMUTABLE;
-- Getis-Ord's G
-- Hotspot/Coldspot Analysis tool
CREATE OR REPLACE FUNCTION
  CDB_GetisOrdsG(
      subquery TEXT,
      column_name TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 999,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (z_score NUMERIC, p_value NUMERIC, p_z_sim NUMERIC, rowid BIGINT)
AS $$
  from crankshaft.clustering import Getis
  getis = Getis()
  return getis.getis_ord(subquery, column_name, w_type, num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu;

-- TODO: make a version that accepts the values as arrays

-- Find outliers using a static threshold
--
CREATE OR REPLACE FUNCTION CDB_StaticOutlier(column_value numeric, threshold numeric)
RETURNS boolean
AS $$
BEGIN

  RETURN column_value > threshold;

END;
$$ LANGUAGE plpgsql;

-- Find outliers by a percentage above the threshold
-- TODO: add symmetric option? `is_symmetric boolean DEFAULT false`

CREATE OR REPLACE FUNCTION CDB_PercentOutlier(column_values numeric[], outlier_fraction numeric, ids int[])
RETURNS TABLE(is_outlier boolean, rowid int)
AS $$
DECLARE
  avg_val numeric;
  out_vals boolean[];
BEGIN

  SELECT avg(i) INTO avg_val
    FROM unnest(column_values) As x(i);

  IF avg_val = 0 THEN
    RAISE EXCEPTION 'Mean value is zero. Try another outlier method.';
  END IF;

  SELECT array_agg(
           outlier_fraction < i / avg_val) INTO out_vals
    FROM unnest(column_values) As x(i);

  RETURN QUERY
  SELECT unnest(out_vals) As is_outlier,
         unnest(ids) As rowid;

END;
$$ LANGUAGE plpgsql;

-- Find outliers above a given number of standard deviations from the mean

CREATE OR REPLACE FUNCTION CDB_StdDevOutlier(column_values numeric[], num_deviations numeric, ids int[], is_symmetric boolean DEFAULT true)
RETURNS TABLE(is_outlier boolean, rowid int)
AS $$
DECLARE
  stddev_val numeric;
  avg_val numeric;
  out_vals boolean[];
BEGIN

  SELECT stddev(i), avg(i) INTO stddev_val, avg_val
    FROM unnest(column_values) As x(i);

  IF stddev_val = 0 THEN
    RAISE EXCEPTION 'Standard deviation of input data is zero';
  END IF;

  IF is_symmetric THEN
    SELECT array_agg(
             abs(i - avg_val) / stddev_val > num_deviations) INTO out_vals
      FROM unnest(column_values) As x(i);
  ELSE
    SELECT array_agg(
             (i - avg_val) / stddev_val > num_deviations) INTO out_vals
      FROM unnest(column_values) As x(i);
  END IF;

  RETURN QUERY
  SELECT unnest(out_vals) As is_outlier,
         unnest(ids) As rowid;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION CDB_Contour(
    IN geomin geometry[],
    IN colin numeric[],
    IN buffer numeric,
    IN intmethod integer,
    IN classmethod integer,
    IN steps integer,
    IN max_time integer DEFAULT 60000
    )
RETURNS TABLE(
    the_geom geometry,
    bin integer,
    min_value numeric,
    max_value numeric,
    avg_value numeric
)  AS $$
DECLARE
    cell_count integer;
    tin geometry[];
    resolution integer;
BEGIN

    -- nasty trick to override issue #121
    IF max_time = 0 THEN
        max_time = -90;
    END IF;
    resolution := max_time;
    max_time := -1 * resolution;

    -- calc the optimal number of cells for the current dataset
    SELECT
    CASE intmethod
        WHEN 0 THEN round(3.7745903782 * max_time - 9.4399210051 * array_length(geomin,1) - 1350.8778213073)
        WHEN 1 THEN round(2.2855592156 * max_time - 87.285217133 * array_length(geomin,1) + 17255.7085601797)
        WHEN 2 THEN  round(0.9799471999 * max_time - 127.0334085369 * array_length(geomin,1) + 22707.9579721218)
        ELSE 10000
    END INTO cell_count;

    -- we don't have iterative barycentric interpolation in CDB_interpolation,
    --    and it's a costy function, so let's make a custom one here till
    --    we update the code
    -- tin := ARRAY[]::geometry[];
    IF intmethod=1 THEN
        WITH
            a as (SELECT unnest(geomin) AS e),
            b as (SELECT ST_DelaunayTriangles(ST_Collect(a.e),0.001, 0) AS t FROM a),
            c as (SELECT (ST_Dump(t)).geom as v FROM b)
        SELECT array_agg(v) INTO tin FROM c;
    END IF;
    -- Delaunay stuff performed just ONCE!!

    -- magic
    RETURN QUERY
    WITH
    convexhull as (
        SELECT
            ST_ConvexHull(ST_Collect(geomin)) as g,
            buffer * |/ st_area(ST_ConvexHull(ST_Collect(geomin)))/PI() as r
    ),
    envelope as (
        SELECT
            st_expand(a.g, a.r) as e
        FROM  convexhull a
    ),
    envelope3857 as(
        SELECT
            ST_Transform(e, 3857) as geom
        FROM envelope
    ),
    resolution as(
        SELECT
            CASE WHEN resolution <= 0  THEN
                round(|/ (
                 ST_area(geom) / abs(cell_count)
             ))
            ELSE
                resolution
            END AS cell
        FROM envelope3857
    ),
    grid as(
        SELECT
            ST_Transform(cdb_crankshaft.CDB_RectangleGrid(e.geom, r.cell, r.cell), 4326) as geom
        FROM envelope3857 e, resolution r
    ),
    interp as(
        SELECT
            geom,
            CASE
                WHEN intmethod=1 THEN cdb_crankshaft._interp_in_tin(geomin, colin, tin, ST_Centroid(geom))
                ELSE cdb_crankshaft.CDB_SpatialInterpolation(geomin, colin, ST_Centroid(geom), intmethod)
            END as val
        FROM grid
    ),
    classes as(
        SELECT CASE
            WHEN classmethod = 0 THEN
                cdb_crankshaft.CDB_EqualIntervalBins(array_agg(val), steps)
            WHEN classmethod = 1 THEN
                cdb_crankshaft.CDB_HeadsTailsBins(array_agg(val), steps)
            WHEN classmethod = 2 THEN
                cdb_crankshaft.CDB_JenksBins(array_agg(val), steps)
            ELSE
                cdb_crankshaft.CDB_QuantileBins(array_agg(val), steps)
            END as b
        FROM interp
        where val is not null
    ),
    classified as(
        SELECT
        i.*,
        width_bucket(i.val, c.b) as bucket
        FROM interp i left join classes c
        ON 1=1
    ),
    classified2 as(
        SELECT
            geom,
            val,
            CASE
                WHEN bucket = steps THEN bucket - 1
                ELSE bucket
            END as b
        FROM classified
    ),
    final as(
        SELECT
            st_union(geom) as the_geom,
            b as bin,
            min(val) as min_value,
            max(val) as max_value,
            avg(val) as avg_value
        FROM classified2
        GROUP BY bin
    )
    SELECT
        *
    FROM final
    where final.bin is not null
    ;
END;
$$ language plpgsql;



-- =====================================================================
-- Interp in grid, so we can use barycentric with a precalculated tin (NNI)
-- =====================================================================
CREATE OR REPLACE FUNCTION _interp_in_tin(
    IN geomin geometry[],
    IN colin numeric[],
    IN tin geometry[],
    IN point geometry
    )
RETURNS numeric AS
$$
DECLARE
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
    -- get the cell the point is within
    WITH
        a as (SELECT unnest(tin) as v),
        b as (SELECT v FROM a WHERE ST_Within(point, v))
    SELECT v INTO g FROM b;

    -- if we're out of the data realm,
    -- return null
    IF g is null THEN
        RETURN null;
    END IF;

    -- vertex of the selected cell
    WITH a AS (
        SELECT (ST_DumpPoints(g)).geom AS v
    )
    SELECT array_agg(v) INTO vertex FROM a;

    -- retrieve the value of each vertex
    WITH a AS(SELECT unnest(geomin) as geo, unnest(colin) as c)
        SELECT c INTO va FROM a WHERE ST_Equals(geo, vertex[1]);

    WITH a AS(SELECT unnest(geomin) as geo, unnest(colin) as c)
        SELECT c INTO vb FROM a WHERE ST_Equals(geo, vertex[2]);

    WITH a AS(SELECT unnest(geomin) as geo, unnest(colin) as c)
            SELECT c INTO vc FROM a WHERE ST_Equals(geo, vertex[3]);

    -- calc the areas
    SELECT
        ST_area(g),
        ST_area(ST_MakePolygon(ST_MakeLine(ARRAY[point, vertex[2], vertex[3], point]))),
        ST_area(ST_MakePolygon(ST_MakeLine(ARRAY[point, vertex[1], vertex[3], point]))),
        ST_area(ST_MakePolygon(ST_MakeLine(ARRAY[point,vertex[1],vertex[2], point]))) INTO sg, sa, sb, sc;

    output := (coalesce(sa,0) * coalesce(va,0) + coalesce(sb,0) * coalesce(vb,0) + coalesce(sc,0) * coalesce(vc,0)) / coalesce(sg,1);
    RETURN output;
END;
$$
language plpgsql;
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
CREATE OR REPLACE FUNCTION
CDB_GWR(subquery text, dep_var text, ind_vars text[],
        bw numeric default null, fixed boolean default False,
        kernel text default 'bisquare', geom_col text default 'the_geom',
        id_col text default 'cartodb_id')
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON,
              filtered_t_vals JSON, predicted numeric,
              residuals numeric, r_squared numeric, bandwidth numeric,
              rowid bigint)
AS $$

from crankshaft.regression import GWR

gwr = GWR()

return gwr.gwr(subquery, dep_var, ind_vars, bw, fixed, kernel, geom_col, id_col)

$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION
CDB_GWR_Predict(subquery text, dep_var text, ind_vars text[],
                bw numeric default null, fixed boolean default False,
                kernel text default 'bisquare',
                geom_col text default 'the_geom',
                id_col text default 'cartodb_id')
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON,
              r_squared numeric, predicted numeric, rowid bigint)
AS $$

from crankshaft.regression import GWR
gwr = GWR()

return gwr.gwr_predict(subquery, dep_var, ind_vars, bw, fixed, kernel, geom_col, id_col)

$$ LANGUAGE plpythonu;
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
--
-- Fill given extent with a rectangular coverage
--
-- @param ext Extent to fill. Only rectangles with center point falling
--            inside the extent (or at the lower or leftmost edge) will
--            be emitted. The returned hexagons will have the same SRID
--            as this extent.
--
-- @param width With of each rectangle
--
-- @param height Height of each rectangle
--
-- @param origin Optional origin to allow for exact tiling.
--               If omitted the origin will be 0,0.
--               The parameter is checked for having the same SRID
--               as the extent.
--
--
CREATE OR REPLACE FUNCTION CDB_RectangleGrid(ext GEOMETRY, width FLOAT8, height FLOAT8, origin GEOMETRY DEFAULT NULL)
RETURNS SETOF GEOMETRY
AS $$
DECLARE
  h GEOMETRY; -- rectangle cell
  hstep FLOAT8; -- horizontal step
  vstep FLOAT8; -- vertical step
  hw FLOAT8; -- half width
  hh FLOAT8; -- half height
  vstart FLOAT8;
  hstart FLOAT8;
  hend FLOAT8;
  vend FLOAT8;
  xoff FLOAT8;
  yoff FLOAT8;
  xgrd FLOAT8;
  ygrd FLOAT8;
  x FLOAT8;
  y FLOAT8;
  srid INTEGER;
BEGIN

  srid := ST_SRID(ext);

  xoff := 0;
  yoff := 0;

  IF origin IS NOT NULL THEN
    IF ST_SRID(origin) != srid THEN
      RAISE EXCEPTION 'SRID mismatch between extent (%) and origin (%)', srid, ST_SRID(origin);
    END IF;
    xoff := ST_X(origin);
    yoff := ST_Y(origin);
  END IF;

  --RAISE DEBUG 'X offset: %', xoff;
  --RAISE DEBUG 'Y offset: %', yoff;

  hw := width/2.0;
  hh := height/2.0;

  xgrd := hw;
  ygrd := hh;
  --RAISE DEBUG 'X grid size: %', xgrd;
  --RAISE DEBUG 'Y grid size: %', ygrd;

  hstep := width;
  vstep := height;

  -- Tweak horizontal start on hstep grid from origin
  hstart := xoff + ceil((ST_XMin(ext)-xoff)/hstep)*hstep;
  --RAISE DEBUG 'hstart: %', hstart;

  -- Tweak vertical start on vstep grid from origin
  vstart := yoff + ceil((ST_Ymin(ext)-yoff)/vstep)*vstep;
  --RAISE DEBUG 'vstart: %', vstart;

  hend := ST_XMax(ext);
  vend := ST_YMax(ext);

  --RAISE DEBUG 'hend: %', hend;
  --RAISE DEBUG 'vend: %', vend;

  x := hstart;
  WHILE x < hend LOOP -- over X
    y := vstart;
    h := ST_MakeEnvelope(x-hw, y-hh, x+hw, y+hh, srid);
    WHILE y < vend LOOP -- over Y
      RETURN NEXT h;
      h := ST_Translate(h, 0, vstep);
      y := yoff + round(((y + vstep)-yoff)/ygrd)*ygrd; -- round to grid
    END LOOP;
    x := xoff + round(((x + hstep)-xoff)/xgrd)*xgrd; -- round to grid
  END LOOP;

  RETURN;
END
$$ LANGUAGE 'plpgsql' IMMUTABLE;

--
-- Calculate the equal interval bins for a given column
--
-- @param in_array A numeric array of numbers to determine the best
--                   to determine the bin boundary
--
-- @param breaks The number of bins you want to find.
--
--
-- Returns: upper edges of bins
--
--

CREATE OR REPLACE FUNCTION CDB_EqualIntervalBins ( in_array NUMERIC[], breaks INT ) RETURNS NUMERIC[] as $$
DECLARE
    diff numeric;
    min_val numeric;
    max_val numeric;
    tmp_val numeric;
    i INT := 1;
    reply numeric[];
BEGIN
    SELECT min(e), max(e) INTO min_val, max_val FROM ( SELECT unnest(in_array) e ) x WHERE e IS NOT NULL;
    diff = (max_val - min_val) / breaks::numeric;
    LOOP
        IF i < breaks THEN
            tmp_val = min_val + i::numeric * diff;
            reply = array_append(reply, tmp_val);
            i := i+1;
        ELSE
            reply = array_append(reply, max_val);
            EXIT;
        END IF;
    END LOOP;
    RETURN reply;
END;
$$ language plpgsql IMMUTABLE;

--
-- Determine the Heads/Tails classifications from a numeric array
--
-- @param in_array A numeric array of numbers to determine the best
--            bins based on the Heads/Tails method.
--
-- @param breaks The number of bins you want to find.
--
--

CREATE OR REPLACE FUNCTION CDB_HeadsTailsBins ( in_array NUMERIC[], breaks INT) RETURNS NUMERIC[] as $$
DECLARE
    element_count INT4;
    arr_mean numeric;
    i INT := 2;
    reply numeric[];
BEGIN
    -- get the total size of our row
    element_count := array_upper(in_array, 1) - array_lower(in_array, 1);
    -- ensure the ordering of in_array
    SELECT array_agg(e) INTO in_array FROM (SELECT unnest(in_array) e ORDER BY e) x;
    -- stop if no rows
    IF element_count IS NULL THEN
        RETURN NULL;
    END IF;
    -- stop if our breaks are more than our input array size
    IF element_count < breaks THEN
        RETURN in_array;
    END IF;

    -- get our mean value
    SELECT avg(v) INTO arr_mean FROM (  SELECT unnest(in_array) as v ) x;

    reply = Array[arr_mean];
    -- slice our bread
    LOOP
        IF i > breaks THEN  EXIT;  END IF;
        SELECT avg(e) INTO arr_mean FROM ( SELECT unnest(in_array) e) x WHERE e > reply[i-1];
        IF arr_mean IS NOT NULL THEN
            reply = array_append(reply, arr_mean);
        END IF;
        i := i+1;
    END LOOP;
    RETURN reply;
END;
$$ language plpgsql IMMUTABLE;

--
-- Determine the Jenks classifications from a numeric array
--
-- @param in_array A numeric array of numbers to determine the best
--            bins based on the Jenks method.
--
-- @param breaks The number of bins you want to find.
--
-- @param iterations The number of different starting positions to test.
--
-- @param invert Optional wheter to return the top of each bin (default)
--               or the bottom. BOOLEAN, default=FALSE.
--
--


CREATE OR REPLACE FUNCTION CDB_JenksBins ( in_array NUMERIC[], breaks INT, iterations INT DEFAULT 5, invert BOOLEAN DEFAULT FALSE) RETURNS NUMERIC[] as $$
DECLARE
    element_count INT4;
    arr_mean NUMERIC;
    bot INT;
    top INT;
    tops INT[];
    classes INT[][];
    i INT := 1; j INT := 1;
    curr_result NUMERIC[];
    best_result NUMERIC[];
    seedtarget TEXT;
    quant NUMERIC[];
    shuffles INT;
BEGIN
    -- get the total size of our row
    element_count := array_length(in_array, 1); --array_upper(in_array, 1) - array_lower(in_array, 1);
    -- ensure the ordering of in_array
    SELECT array_agg(e) INTO in_array FROM (SELECT unnest(in_array) e ORDER BY e) x;
    -- stop if no rows
    IF element_count IS NULL THEN
        RETURN NULL;
    END IF;
    -- stop if our breaks are more than our input array size
    IF element_count < breaks THEN
        RETURN in_array;
    END IF;

    shuffles := LEAST(GREATEST(floor(2500000.0/(element_count::float*iterations::float)), 1), 750)::int;
    -- get our mean value
    SELECT avg(v) INTO arr_mean FROM (  SELECT unnest(in_array) as v ) x;

    -- assume best is actually Quantile
    SELECT cdb_crankshaft.CDB_QuantileBins(in_array, breaks) INTO quant;

    -- if data is very very large, just return quant and be done
    IF element_count > 5000000 THEN
        RETURN quant;
    END IF;

    -- change quant into bottom, top markers
    LOOP
        IF i = 1 THEN
            bot = 1;
        ELSE
            -- use last top to find this bot
            bot = top+1;
        END IF;
        IF i = breaks THEN
            top = element_count;
        ELSE
            SELECT count(*) INTO top FROM ( SELECT unnest(in_array) as v) x WHERE v <= quant[i];
        END IF;
        IF i = 1 THEN
            classes = ARRAY[ARRAY[bot,top]];
        ELSE
            classes = ARRAY_CAT(classes,ARRAY[bot,top]);
        END IF;
        IF i > breaks THEN EXIT; END IF;
        i = i+1;
    END LOOP;

    best_result = cdb_crankshaft.CDB_JenksBinsIteration( in_array, breaks, classes, invert, element_count, arr_mean, shuffles);

    --set the seed so we can ensure the same results
    SELECT setseed(0.4567) INTO seedtarget;
    --loop through random starting positions
    LOOP
        IF j > iterations-1 THEN  EXIT;  END IF;
        i = 1;
        tops = ARRAY[element_count];
        LOOP
            IF i = breaks THEN  EXIT;  END IF;
            SELECT array_agg(distinct e) INTO tops FROM (SELECT unnest(array_cat(tops, ARRAY[floor(random()*element_count::float)::int])) as e ORDER BY e) x WHERE e != 1;
            i = array_length(tops, 1);
        END LOOP;
        i = 1;
        LOOP
            IF i > breaks THEN  EXIT;  END IF;
            IF i = 1 THEN
                bot = 1;
            ELSE
                bot = top+1;
            END IF;
            top = tops[i];
            IF i = 1 THEN
                classes = ARRAY[ARRAY[bot,top]];
            ELSE
                classes = ARRAY_CAT(classes,ARRAY[bot,top]);
            END IF;
            i := i+1;
        END LOOP;
        curr_result = cdb_crankshaft.CDB_JenksBinsIteration( in_array, breaks, classes, invert, element_count, arr_mean, shuffles);

        IF curr_result[1] > best_result[1] THEN
            best_result = curr_result;
            j = j-1; -- if we found a better result, add one more search
        END IF;
        j = j+1;
    END LOOP;

    RETURN (best_result)[2:array_upper(best_result, 1)];
END;
$$ language plpgsql IMMUTABLE;



--
-- Perform a single iteration of the Jenks classification
--

CREATE OR REPLACE FUNCTION CDB_JenksBinsIteration ( in_array NUMERIC[], breaks INT, classes INT[][], invert BOOLEAN, element_count INT4, arr_mean NUMERIC, max_search INT DEFAULT 50) RETURNS NUMERIC[] as $$
DECLARE
    tmp_val numeric;
    new_classes int[][];
    tmp_class int[];
    i INT := 1;
    j INT := 1;
    side INT := 2;
    sdam numeric;
    gvf numeric := 0.0;
    new_gvf numeric;
    arr_gvf numeric[];
    class_avg numeric;
    class_max_i INT;
    class_min_i INT;
    class_max numeric;
    class_min numeric;
    reply numeric[];
BEGIN

    -- Calculate the sum of squared deviations from the array mean (SDAM).
    SELECT sum((arr_mean - e)^2) INTO sdam FROM (  SELECT unnest(in_array) as e ) x;
    --Identify the breaks for the lowest GVF
    LOOP
        i = 1;
        LOOP
            -- get our mean
            SELECT avg(e) INTO class_avg FROM ( SELECT unnest(in_array[classes[i][1]:classes[i][2]]) as e) x;
            -- find the deviation
            SELECT sum((class_avg-e)^2) INTO tmp_val FROM (   SELECT unnest(in_array[classes[i][1]:classes[i][2]]) as e  ) x;
            IF i = 1 THEN
                arr_gvf = ARRAY[tmp_val];
                -- init our min/max map for later
                class_max = arr_gvf[i];
                class_min = arr_gvf[i];
                class_min_i = 1;
                class_max_i = 1;
            ELSE
                arr_gvf = array_append(arr_gvf, tmp_val);
            END IF;
            i := i+1;
            IF i > breaks THEN EXIT; END IF;
        END LOOP;
        -- calculate our new GVF
        SELECT sdam-sum(e) INTO new_gvf FROM (  SELECT unnest(arr_gvf) as e  ) x;
        -- if no improvement was made, exit
        IF new_gvf < gvf THEN EXIT; END IF;
        gvf = new_gvf;
        IF j > max_search THEN EXIT; END IF;
        j = j+1;
        i = 1;
        LOOP
            --establish directionality (uppward through classes or downward)
            IF arr_gvf[i] < class_min THEN
                class_min = arr_gvf[i];
                class_min_i = i;
            END IF;
            IF arr_gvf[i] > class_max THEN
                class_max = arr_gvf[i];
                class_max_i = i;
            END IF;
            i := i+1;
            IF i > breaks THEN EXIT; END IF;
        END LOOP;
        IF class_max_i > class_min_i THEN
            class_min_i = class_max_i - 1;
        ELSE
            class_min_i = class_max_i + 1;
        END IF;
            --Move from higher class to a lower gid order
            IF class_max_i > class_min_i THEN
                classes[class_max_i][1] = classes[class_max_i][1] + 1;
                classes[class_min_i][2] = classes[class_min_i][2] + 1;
            ELSE -- Move from lower class UP into a higher class by gid
                classes[class_max_i][2] = classes[class_max_i][2] - 1;
                classes[class_min_i][1] = classes[class_min_i][1] - 1;
            END IF;
    END LOOP;

    i = 1;
    LOOP
        IF invert = TRUE THEN
            side = 1; --default returns bottom side of breaks, invert returns top side
        END IF;
        reply = array_append(reply, in_array[classes[i][side]]);
        i = i+1;
        IF i > breaks THEN  EXIT; END IF;
    END LOOP;

    RETURN array_prepend(gvf, reply);

END;
$$ language plpgsql IMMUTABLE;


--
-- Determine the Quantile classifications from a numeric array
--
-- @param in_array A numeric array of numbers to determine the best
--            bins based on the Quantile method.
--
-- @param breaks The number of bins you want to find.
--
--
CREATE OR REPLACE FUNCTION CDB_QuantileBins ( in_array NUMERIC[], breaks INT) RETURNS NUMERIC[] as $$
DECLARE
    element_count INT4;
    break_size numeric;
    tmp_val numeric;
    i INT := 1;
    reply numeric[];
BEGIN
    -- sort our values
    SELECT array_agg(e) INTO in_array FROM (SELECT unnest(in_array) e ORDER BY e ASC) x;
    -- get the total size of our data
    element_count := array_length(in_array, 1);
    break_size :=  element_count::numeric / breaks;
    -- slice our bread
    LOOP
        IF i < breaks THEN
            IF break_size * i % 1 > 0 THEN
                SELECT e INTO tmp_val FROM ( SELECT unnest(in_array) e LIMIT 1 OFFSET ceil(break_size * i) - 1) x;
            ELSE
                SELECT avg(e) INTO tmp_val FROM ( SELECT unnest(in_array) e LIMIT 2 OFFSET ceil(break_size * i) - 1 ) x;
            END IF;
        ELSIF i = breaks THEN
            -- select the last value
            SELECT max(e) INTO tmp_val FROM ( SELECT unnest(in_array) e ) x;
        ELSE
            EXIT;
        END IF;

        reply = array_append(reply, tmp_val);
        i := i+1;
    END LOOP;
    RETURN reply;
END;
$$ language plpgsql IMMUTABLE;
