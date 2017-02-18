CREATE OR REPLACE FUNCTION CDB_contour2(
    IN geomin geometry[],
    IN colin numeric[],
    IN classmethod integer,
    IN steps integer
    )
RETURNS geometry  AS $$
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
    geomout geometry;
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
    -- i:= 0;

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

        -- create segments crossing the cell per bucket
        WITH
        a as(
            SELECT
            unnest(interp12) as p12,
            unnest(interp23) as p23,
            unnest(interp31) as p31
        ),
        b as(
            SELECT
                ST_MakeLine(ARRAY[p12, p23, p31]::geometry[]) as segm
            FROM a
            WHERE
                (p12 is not null and p23 is not null and ST_equals(p12, p23)=false) OR
                (p23 is not null and p31 is not null and ST_equals(p23, p31)=false) OR
                (p31 is not null and p12 is not null and ST_equals(p31, p12)=false)
        )
        SELECT
            array_agg(segm) INTO segment
        FROM b;

        -- concat the segments and breaks
        IF array_length(running_merge,1)=0 THEN
            running_merge := segment;
        ELSE
            running_merge := running_merge || segment;
        END IF;

    -- loop end
    END LOOP;

    -- ====== ^^^ LOOP END ===========================================================================

    -- merge the segments with the convex hull so we can polygonize
    running_merge := running_merge || ST_ExteriorRing(ST_Convexhull(ST_Collect(running_merge||geomin))) ;

    -- multilines version
    WITH
    a as(
     SELECT unnest(running_merge) as geo
    )
    SELECT ST_collect(geo) into geomout from a;

    -- return some stuff
    RETURN geomout;

END;
$$ language plpgsql IMMUTABLE;


-- ============ test query ==========================================================================

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
