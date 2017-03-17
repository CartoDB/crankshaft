CREATE OR REPLACE FUNCTION CDB_contour2(
    IN geomin geometry[],
    IN colin numeric[],
    IN classmethod integer,
    IN steps integer,
    IN polygons integer DEFAULT 0
    )
-- RETURNS geometry  AS $$
RETURNS TABLE(cartodb_id bigint, the_geom geometry, break numeric)   AS $$
DECLARE
    geoplane geometry[];
    breaks numeric[];
    bucketin integer[];
    gs geometry[];
    g geometry;
    vertex geometry[];
    vv numeric[];
    bu integer[];
    inter numeric[];
    interp12 geometry[];
    interp23 geometry[];
    interp31 geometry[];
    segment geometry[];
    running_merge geometry[];
    cartodb_id bigint;
    the_geom geometry;
    break numeric;
    i integer;
BEGIN

    -- debug info
    raise notice 'Points: %', array_length(colin,1);

    -- translate to planar to avoid ST_LineInterpolatePoint errors for points far from equator
    WITH a AS(
        SELECT ST_transform(t.x, 3857) as gp FROM unnest(geomin) as t(x)
    )
    SELECT array_agg(gp) into geoplane FROM a;

    -- generate the breaks
    SELECT
        CASE
            classmethod
        WHEN 0 THEN
            cdb_crankshaft.CDB_EqualIntervalBins(colin, steps)
        WHEN 1 THEN
            cdb_crankshaft.CDB_HeadsTailsBins(colin, steps)
        WHEN 2 THEN
            cdb_crankshaft.CDB_JenksBins(colin, steps)
        ELSE
            cdb_crankshaft.CDB_QuantileBins(colin, steps)
        END
    INTO breaks;

    -- assign bucket to each point
    WITH
    a as(
        SELECT
            width_bucket(t.x, breaks) as bin
        FROM unnest(colin) as t(x)
    )
    SELECT array_agg(bin) INTO bucketin FROM a;

    -- generate the TIN
    WITH
        -- a as (SELECT ST_transform(x, 3857) as e FROM unnest(geomin) t(x)),
        a as (SELECT unnest(geomin) AS e),
        b as (SELECT ST_DelaunayTriangles(ST_Collect(a.e)) AS t FROM a),
        c as (SELECT (ST_Dump(t)).geom AS v FROM b)
    SELECT array_agg(v) INTO gs FROM c;

    RAISE NOTICE 'TIN size: %', array_length(gs,1);
    raise notice 'ratio: %', array_length(gs,1)::numeric /  array_length(colin,1)::numeric;

   i:= 0;

    -- ======================================================================================

    -- loop in the TIN
    FOREACH g IN ARRAY gs
    LOOP
        -- retrieve the value and bucket of each vertex
        SELECT
            -- array_agg(a.v),array_agg(b.c), array_agg(b.bk)
            array_agg(b.gp),array_agg(b.c), array_agg(b.bk)
            INTO vertex, vv, bu
        FROM
        (
            SELECT (ST_DumpPoints(g)).geom AS v limit 3
        ) as a
        CROSS JOIN LATERAL
        (
            SELECT
                t.*
            FROM
                unnest(geomin, colin, bucketin, geoplane) as t(geo, c, bk, gp)
            WHERE ST_Equals(geo, a.v)
            LIMIT 1
        ) as b;

        -- continue when there is no contour line crossing the current cell
        CONTINUE WHEN bu[1] = bu[2] and bu[1] = bu[3];


        -- we have contour lines in this cell, let's find their intersections with triangle sides

        interp12 := _get_cell_intersects(vertex, vv , bu, breaks, 1, 2);
        interp23 := _get_cell_intersects(vertex, vv , bu, breaks, 2, 3);
        interp31 := _get_cell_intersects(vertex, vv , bu, breaks, 3, 1);

        -- raise notice 'interp12 %', interp12;

        -- create segments crossing the cell per break
        WITH
        a as(
            SELECT
            t.*
            FROM
            unnest(breaks, interp12, interp23, interp31) as t(br, p12 , p23, p31)
        ),
        b as(
            SELECT
                case
                when
                    (p12 is not null and p23 is not null and ST_equals(p12, p23)=false) OR
                    (p23 is not null and p31 is not null and ST_equals(p23, p31)=false) OR
                    (p31 is not null and p12 is not null and ST_equals(p31, p12)=false)
                then ST_MakeLine(ARRAY[p12, p23, p31]::geometry[])
                else null::geometry end as segm,
                br
            FROM a
        )
        SELECT
            array_agg(b.segm) into segment
        FROM unnest(breaks) as c(x) left join b on b.br = c.x;


        -- sew the segments and assign breaks
        IF i = 0 THEN
            running_merge = segment;
            i := 1;
        ELSE
            WITH
            a AS(
                SELECT
                    ST_CollectionExtract(x, 2) as x,
                    y
                FROM unnest(running_merge,segment) as t(x,y)
            ),
            b AS(
                SELECT
                    ST_collect(x,y) as element
                FROM a
            )
            SELECT
                array_agg(element) into running_merge
            FROM b;

        END IF;

    -- loop end
    END LOOP;

    -- ====== ^^^ LOOP END ===========================================================================

    -- return some stuff
    IF polygons = 1 THEN
        RETURN QUERY
        with a as(
            SELECT
                br,
                ST_CollectionExtract(geo, 2) as geo
            FROM unnest(running_merge, breaks) as t(geo, br)
        ),
        b as(
            SELECT
                ST_LineMerge(geo) as v
            FROM a
        ),
        c as(
            SELECT
                ST_Polygonize(
                    ST_Node(
                        ST_LineMerge(
                            ST_Union(
                                v,
                                ST_ExteriorRing(
                                    ST_Convexhull(v)
                                )
                            )
                        )
                    )
                ) as g1
            FROM
                b
        ),
        d as(
            SELECT
            (st_dump(g1)).geom as geo
            FROM c
        )
        SELECT
        row_number() over() as cartodb_id,
        ST_Transform(geo, 4326) as the_geom,
        1::numeric as break
        from d
        WHERE ST_GeometryType(geo) = 'ST_Polygon';
    ELSE
        RETURN QUERY
        with a as(
            SELECT
                br,
                ST_CollectionExtract(geo, 2) as geo
            FROM unnest(running_merge, breaks) as t(geo, br)
        ),
        b as(
            SELECT
                ST_LineMerge(geo) as geo,
                br
            FROM a
        )
        SELECT
        row_number() over() as cartodb_id,
        ST_Transform(geo, 4326) as the_geom,
        br as break
        from b;
    END IF;

END;
$$ language plpgsql IMMUTABLE;



-- ========================= support function =========================

CREATE OR REPLACE FUNCTION _get_cell_intersects(
    IN vertex geometry[],
    IN vv numeric[],
    IN bu integer[],
    IN breaks numeric[],
    IN i1 integer,
    IN i2 integer
    )
RETURNS geometry[]  AS $$
DECLARE
    result geometry[];
BEGIN

    result := array_fill(null::geometry, ARRAY[array_length(breaks, 1)]);

    IF bu[i1] <> bu[i2] THEN

        SELECT
            array_agg(b.point) INTO result
        FROM
        (
            SELECT
                (t.x-vv[i1])/(vv[i2]-vv[i1]) as p
            FROM unnest(breaks) as t(x)
        ) AS a
        LEFT JOIN LATERAL
        (
            SELECT
                ST_LineInterpolatePoint(
                    ST_MakeLine(
                        vertex[i1],
                        vertex[i2]
                    ), a.p)
                as point
            WHERE a.p BETWEEN 0 AND 1
        ) AS b
        ON 1=1;
    END IF;

    return result;

END;
$$ language plpgsql IMMUTABLE;




-- ============ test query ==========================================================================
-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================


with
a0 as(
    select * from table_4804232032
    -- where cartodb_id % 2 = 0
),
a as(
  SELECT
  array_agg(the_geom)  as geomin,
  array_agg(temp::numeric) as   colin
  FROM a0
  where temp is not   null
  ),
b as(
  SELECT
     c.*
   from a, CDB_contour2(
        a.geomin,
        a.colin,
        3,
        7
      )  c
  )
  SELECT
  *,
  st_astext(the_geom) as text,
  st_transform(the_geom, 3857) as the_geom_webmercator
  from b
  where the_geom is not null;




