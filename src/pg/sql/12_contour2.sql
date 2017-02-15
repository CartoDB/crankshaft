-- =============================================================================================
--
-- CDB_Contour v2
--
-- Meander triangles
--
-- author: Abel Vázquez
--
-- =============================================================================================

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
    -- interlines geometry;
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

    -- generate the TIN
    WITH
        a as (SELECT unnest(geomin) AS e),
        b as (SELECT ST_DelaunayTriangles(ST_Collect(a.e),0.001, 0) AS t FROM a),
        c as (SELECT (ST_Dump(t)).geom AS v FROM b)
    SELECT array_agg(v) INTO gs FROM c;

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

        -- retrieve the bucket index of each vertex
        bu := ARRAY[width_bucket(v1, breaks), width_bucket(v2, breaks), width_bucket(v3, breaks)];

        -- continue when there is no contour line crossing the current cell
        CONTINUE WHEN bu[1] = bu[2] and bu[1] = bu[3];

        -- we have contour lines in this cell, let's find their intersections with triangle sides
        IF bu[1] <> bu[2] THEN
            SELECT array_agg((t.x-v1)/(v2-v1)) INTO inter FROM unnest(breaks) as t(x);
            WITH a as(
                SELECT
                    ST_Line_Interpolate_Point(ST_MakeLine(vertex[1], vertex[2]),t.x)
                FROM unnest(inter) as t(x)
                WHERE t.x BETWEEN 0 AND 1
            )
            SELECT
                array_agg(g) INTO interp12
            FROM a;
        END IF;

        IF bu[2] <> bu[3] THEN
            SELECT array_agg((t.x-v2)/(v3-v2)) INTO inter FROM unnest(breaks) as t(x);
            WITH a as(
                SELECT
                    ST_Line_Interpolate_Point(ST_MakeLine(vertex[2], vertex[3]),t.x)
                FROM unnest(inter) as t(x)
                WHERE t.x BETWEEN 0 AND 1
            )
            SELECT
                array_agg(g) INTO interp23
            FROM a;
        END IF;

        IF bu[3] <> bu[1] THEN
            SELECT array_agg((t.x-v3)/(v1-v3)) INTO inter FROM unnest(breaks) as t(x);
            WITH a as(
                SELECT
                    ST_Line_Interpolate_Point(ST_MakeLine(vertex[3], vertex[1]),t.x)
                FROM unnest(inter) as t(x)
                WHERE t.x BETWEEN 0 AND 1
            )
            SELECT
                array_agg(g) INTO interp31
            FROM a;
        END IF;

        -- create segments per bucket
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
        )
        SELECT
            array_agg(segm) INTO segment
        FROM b
        WHERE
            segm IS NOT null AND
            ST_IsEmpty(segm) = false;

        -- concat the segments
        SELECT
            CASE
            WHEN array_length(running_merge,1)=0 THEN segment
            ELSE array_cat(running_merge, segment) END
        INTO running_merge;

    -- loop end
    END LOOP;

    segment := unnest(running_merge);
    RETURN ST_Collect(segment);


    -- ======================================================================================

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


    -- return some stuff
    RETURN geomout;

END;
$$ language plpgsql IMMUTABLE;
