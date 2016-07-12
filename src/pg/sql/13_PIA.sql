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
    best_c geometry;
    best_d numeric;
    test_d numeric;
    test_mx numeric;
    test_h numeric;
    test_tol numeric;
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

    -- grid #0 cell size
    height := ST_YMax(polygon) - ST_YMin(polygon);
    width := ST_XMax(polygon) - ST_XMin(polygon);
    SELECT 0.5*LEAST(height, width) INTO h;

    -- grid #0
    with c1 as(
        SELECT CDB_RectangleGrid(polygon, h, h) as cell
    )
    -- ,c2 as(
    --     SELECT cell FROM c1 WHERE ST_Intersects(cell, polygon)
    -- )
    SELECT array_agg(cell) INTO cells FROM c1;

    -- 1st guess: centroid
    SELECT _Signed_Dist(polygon, ST_Centroid(Polygon)) INTO best_d;

    -- looping the loop
    n := array_length(cells,1);
    i := 1;
    LOOP

        EXIT WHEN i > n;

        -- cell side size
        SELECT ST_XMax(cells[i]) - ST_XMin(cells[i]) INTO test_h;

        -- check distance
        SELECT _Signed_Dist(polygon, ST_Centroid(cells[i])) INTO test_d;
        IF test_d > best_d THEN
            best_d := test_d;
            best_c := cells[i];
        END IF;

        -- longest distance within the cell
        SELECT test_d + (test_h * sqr) INTO test_mx;

        -- if the cell has no chance to contains the desired point, continue
        SELECT test_mx - best_d INTO test_tol;
        IF test_tol <= tolerance THEN
            i := i+1;
            CONTINUE;
        END IF;

        -- resample the cell
        with c1 as(
            SELECT CDB_RectangleGrid(cells[i], test_h/2, test_h/2) as cell
        )
        -- , c2 as(
        --     SELECT cell FROM c1 WHERE ST_Intersects(cell, polygon)
        -- )
        SELECT array_agg(cell) INTO test_cells FROM c1;

        -- concat the new cells to the former array
        cells := cells || test_cells;

        -- prepare next iteration
        n := array_length(cells,1);
        i := i+1;

    END LOOP;

    RETURN ST_Centroid(best_c);

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
