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
language plpgsql VOLATILE PARALLEL UNSAFE;

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
language plpgsql IMMUTABLE PARALLEL SAFE;
