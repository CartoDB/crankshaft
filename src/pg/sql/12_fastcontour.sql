CREATE OR REPLACE FUNCTION CDB_contour2(
    IN geomin geometry[],
    IN colin numeric[],
    IN classmethod integer,
    IN steps integer
    )
-- RETURNS geometry  AS $$
RETURNS TABLE(cartodb_id bigint, the_geom geometry, break numeric)   AS $$
DECLARE
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
        a as (SELECT unnest(geomin) AS e),
        b as (SELECT ST_DelaunayTriangles(ST_Collect(a.e)) AS t FROM a),
        c as (SELECT (ST_Dump(t)).geom AS v FROM b)

    SELECT array_agg(v) INTO gs FROM c;

    -- RAISE NOTICE 'TIN size: %',array_length(gs,1);

   i:= 0;

    -- ======================================================================================

    -- loop in the TIN
    FOREACH g IN ARRAY gs
    LOOP
        -- retrieve the value and bucket of each vertex
        SELECT
            array_agg(a.v),array_agg(b.c), array_agg(b.bk)
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
                unnest(geomin, colin, bucketin) as t(geo, c, bk)
            WHERE ST_Equals(geo, a.v)
            LIMIT 1
        ) as b;

        -- continue when there is no contour line crossing the current cell
        CONTINUE WHEN bu[1] = bu[2] and bu[1] = bu[3];

        -- we have contour lines in this cell, let's find their intersections with triangle sides
        interp12 := array_fill(null::geometry, ARRAY[steps]);
        interp23 := array_fill(null::geometry, ARRAY[steps]);
        interp31 := array_fill(null::geometry, ARRAY[steps]);

        IF bu[1] <> bu[2] THEN
            SELECT
                array_agg(b.point) INTO interp12
            FROM
            (
                SELECT
                    (t.x-vv[1])/(vv[2]-vv[1]) as p
                FROM unnest(breaks) as t(x)
            ) AS a
            LEFT JOIN LATERAL
            (
                SELECT
                    ST_LineInterpolatePoint(ST_MakeLine(vertex[1], vertex[2]), a.p)
                    as point
                WHERE a.p BETWEEN 0 AND 1
            ) AS b
            ON 1=1;
        END IF;

        IF bu[2] <> bu[3] THEN
            SELECT
                array_agg(b.point) INTO interp23
            FROM
            (
                SELECT
                    (t.x-vv[2])/(vv[3]-vv[2]) as p
                FROM unnest(breaks) as t(x)
            ) AS a
            LEFT JOIN LATERAL
            (
                SELECT
                    ST_LineInterpolatePoint(ST_MakeLine(vertex[2], vertex[3]), a.p)
                    as point
                WHERE a.p BETWEEN 0 AND 1
            ) AS b
            ON 1=1;
        END IF;

        IF bu[3] <> bu[1] THEN
            SELECT
                array_agg(b.point) INTO interp31
            FROM
            (
                SELECT
                    (t.x-vv[3])/(vv[1]-vv[3]) as p
                FROM unnest(breaks) as t(x)
            ) AS a
            LEFT JOIN LATERAL
            (
                SELECT
                    ST_LineInterpolatePoint(ST_MakeLine(vertex[3], vertex[1]), a.p)
                    as point
                WHERE a.p BETWEEN 0 AND 1
            ) AS b
            ON 1=1;
        END IF;

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


        -- concat the segments and breaks
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

    raise notice 'NOTICE: % - %', array_length(running_merge,1),array_length(breaks,1);

    -- return some stuff
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
    geo as the_geom,
    br as break
    from b;


END;
$$ language plpgsql IMMUTABLE;













CREATE OR REPLACE FUNCTION unnest_2d_1d(anyarray)
  RETURNS SETOF anyarray AS
$func$
SELECT array_agg($1[d1][d2])
FROM   generate_subscripts($1,1) d1
    ,  generate_subscripts($1,2) d2
GROUP  BY d1
ORDER  BY d1
$func$  LANGUAGE sql IMMUTABLE;































-- ============ test query ==========================================================================
-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================-- ============ test query ==========================================================================


with
a as(
  SELECT
  array_agg(the_geom) as  geomin,
  array_agg(temp::numeric) as colin
  FROM table_4804232032
  where temp is not null
  ),
b as(
  SELECT
      CDB_contour2(
        geomin,
        colin,
        2,
        7
      ) as the_geom
   from a
  )
  SELECT
  1 as cartodb_id,
  the_geom,
  st_transform(the_geom::geometry, 3857) as  the_geom_webmercator
  from b ;

-- ============ test query table ==========================================================================

with
a as(
  SELECT
  array_agg(the_geom)  as geomin,
  array_agg(temp::numeric) as   colin
  FROM table_4804232032
  where temp is not  null
  ),
b as(
  SELECT
     c.*
   from a, CDB_contour2(
        a.geomin,
        a.colin,
        0,
        7
      )  c
  )
  SELECT
  *,
  st_astext(the_geom) as text,
  st_transform(the_geom, 3857) as the_geom_webmercator
  from b
  where the_geom is not null;




