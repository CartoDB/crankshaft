CREATE OR REPLACE FUNCTION CDB_Contour(
    IN geomin geometry[],
    IN colin numeric[],
    IN resolution integer,
    IN buffer numeric,
    IN intmethod integer,
    IN classmethod integer,
    IN steps integer
    )
RETURNS TABLE(
    the_geom geometry,
    bin integer,
    min_value numeric,
    max_value numeric,
    avg_value numeric
)  AS $$
DECLARE
    cell numeric;
    tin geometry[];
BEGIN
    -- calc the cell size in web mercator units
    WITH center as (
        SELECT ST_centroid(ST_Collect(geomin)) as c
    )
    SELECT
        round(resolution / cos(ST_y(c) * pi()/180))
        INTO cell
    FROM center;
    -- raise notice 'Resol: %', cell;

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
    grid as(
        SELECT
            ST_Transform(CDB_RectangleGrid(geom, cell, cell), 4326) as geom
        FROM envelope3857
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
                CDB_EqualIntervalBins(array_agg(val), steps)
            WHEN classmethod = 1 THEN
                CDB_HeadsTailsBins(array_agg(val), steps)
            WHEN classmethod = 2 THEN
                CDB_JenksBins(array_agg(val), steps)
            ELSE
                CDB_QuantileBins(array_agg(val), steps)
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
CREATE OR REPLACE FUNCTION cdb_crankshaft._interp_in_tin(
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


