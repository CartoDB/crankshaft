CREATE OR REPLACE FUNCTION CDB_contour2(
    IN geomin geometry[],
    IN colin numeric[],
    IN classmethod integer,
    IN steps integer
    )
RETURNS geometry  AS $$
DECLARE
    breaks numeric[];
    gs geometry[];
    g geometry;
    vertex geometry[];
    v1 numeric;
    v2 numeric;
    v3 numeric;
    bu integer[];
    inter numeric[];
    interp12 geometry[];
    interp23 geometry[];
    interp31 geometry[];
    segment geometry[];
    running_merge geometry[];
    geomout geometry;
    i integer;
    cell_breaks integer[];
    running_breaks integer[];
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

    -- generate the TIN
    WITH
        a as (SELECT unnest(geomin) AS e),
        b as (SELECT ST_DelaunayTriangles(ST_Collect(a.e),0.001, 0) AS t FROM a),
        c as (SELECT (ST_Dump(t)).geom AS v FROM b)
    SELECT array_agg(v) INTO gs FROM c;

    -- RAISE NOTICE 'TIN size: %',array_length(gs,1);
    i:= 0;

    -- ======================================================================================

    -- loop in the TIN
    FOREACH g IN ARRAY gs
    LOOP
        -- retrieve the value of each vertex
        WITH a AS (SELECT (ST_DumpPoints(g)).geom AS v)
        SELECT array_agg(v) INTO vertex FROM a;

        WITH a AS(SELECT unnest(geomin) as geo, unnest(colin) as c)
        SELECT c INTO v1 FROM a WHERE ST_Equals(geo, vertex[1]);

        WITH a AS(SELECT unnest(geomin) as geo, unnest(colin) as c)
        SELECT c INTO v2 FROM a WHERE ST_Equals(geo, vertex[2]);

        WITH a AS(SELECT unnest(geomin) as geo, unnest(colin) as c)
        SELECT c INTO v3 FROM a WHERE ST_Equals(geo, vertex[3]);

        -- RAISE NOTICE 'Cell: %', i;
        -- i := i +1;

        -- retrieve the bucket index of each vertex
        bu := ARRAY[width_bucket(v1, breaks), width_bucket(v2, breaks), width_bucket(v3, breaks)];

        -- RAISE NOTICE ' - BU: %',bu;

        -- continue when there is no contour line crossing the current cell
        CONTINUE WHEN bu[1] = bu[2] and bu[1] = bu[3];

        -- we have contour lines in this cell, let's find their intersections with triangle sides
        interp12 := array_fill(null::geometry, ARRAY[steps]);
        IF bu[1] <> bu[2] THEN
            SELECT array_agg((t.x-v1)/(v2-v1)) INTO inter FROM unnest(breaks) as t(x);
            -- RAISE NOTICE ' - Inter 12: %', inter;

            WITH a as(
                SELECT
                    CASE WHEN t.x BETWEEN 0 AND 1 THEN
                    ST_LineInterpolatePoint(ST_MakeLine(vertex[1], vertex[2]),t.x)
                    ELSE null::geometry END as point
                FROM unnest(inter) as t(x)
            )
            SELECT
                array_agg(point) INTO interp12
            FROM a;
        END IF;

        interp23 := array_fill(null::geometry, ARRAY[steps]);
        IF bu[2] <> bu[3] THEN
            SELECT array_agg((t.x-v2)/(v3-v2)) INTO inter FROM unnest(breaks) as t(x);
            -- RAISE NOTICE ' - Inter 23: %', inter;

            WITH a as(
                SELECT
                    CASE WHEN t.x BETWEEN 0 AND 1 THEN
                    ST_LineInterpolatePoint(ST_MakeLine(vertex[2], vertex[3]),t.x)
                    ELSE null::geometry END as point
                FROM unnest(inter) as t(x)
            )
            SELECT
                array_agg(point) INTO interp23
            FROM a;
        END IF;

        interp31 := array_fill(null::geometry, ARRAY[steps]);
        IF bu[3] <> bu[1] THEN
            SELECT array_agg((t.x-v3)/(v1-v3)) INTO inter FROM unnest(breaks) as t(x);
            -- RAISE NOTICE ' - Inter 31: %', inter;

            WITH a as(
                SELECT
                    CASE WHEN t.x BETWEEN 0 AND 1 THEN
                    ST_LineInterpolatePoint(ST_MakeLine(vertex[3], vertex[1]),t.x)
                    ELSE null::geometry END as point
                FROM unnest(inter) as t(x)
            )
            SELECT
                array_agg(point) INTO interp31
            FROM a;
        END IF;

        -- create segments crossing the cell per bucket
        WITH
        a as(
            SELECT
            generate_series(1,steps) as break,
            unnest(interp12) as p12,
            unnest(interp23) as p23,
            unnest(interp31) as p31
        ),
        b as(
            SELECT
                break,
                ST_MakeLine(ARRAY[p12, p23, p31]::geometry[]) as segm
            FROM a
            WHERE
                (p12 is not null and p23 is not null and ST_equals(p12, p23)=false) OR
                (p23 is not null and p31 is not null and ST_equals(p23, p31)=false) OR
                (p31 is not null and p12 is not null and ST_equals(p31, p12)=false)
        )
        SELECT
            array_agg(break), array_agg(segm) INTO cell_breaks, segment
        FROM b
        WHERE
            segm IS NOT null AND
            ST_IsEmpty(segm) = false;

        -- RAISE NOTICE ' - Segments: %',array_length(segment,1);

        -- concat the segments and breaks
        IF array_length(running_merge,1)=0 THEN
            running_merge := segment;
            running_breaks := cell_breaks;
        ELSE
            running_merge := running_merge || segment ;
            running_breaks := running_breaks || cell_breaks;
        END IF;

    -- loop end
    END LOOP;

    -- RAISE NOTICE 'TOTAL segment: %',array_length(running_merge,1);

    -- ======================================================================================

    running_merge := running_merge || ST_ExteriorRing(ST_Convexhull(ST_Collect(geomin))) ;

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



-- ////////////////////////////////////////////////////////////

-- merge and polygonize the results

    WITH
    partials as(
        SELECT
            ST_LineMerge(ST_Collect(t.x)) as v
        FROM
            unnest(running_merge) as t(x)
        WHERE
            t.x IS NOT null AND
            ST_IsEmpty(t.x) = false
    ),
    cells as(
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
            ) as geo
        FROM
            partials
    ),
    geo_set as(
        SELECT
        (st_dump(v.geo)).geom as geo
        FROM cells v
    )
    SELECT
        geo INTO geomout
    FROM
        geo_set
    WHERE
        ST_GeometryType(geo) = 'ST_Polygon';


-- ////////////////////////////////////////////////////////////


with
a as(
  SELECT
  array_agg(the_geom) as geomin,
  array_agg(real_capacity) as colin
  FROM uk_fcc
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
  *,
  st_transform(the_geom::geometry, 3857) as the_geom_webmercator
  from b;
