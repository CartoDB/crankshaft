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
    sqr := 0.5*(|/2.0);
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
    best_c := polygon;
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
            best_c := cell;
        END IF;

        -- longest distance within the cell
        test_mx := test_d + (test_h * sqr);

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
$$ language plpgsql IMMUTABLE PARALLEL SAFE;



-- signed distance point to polygon with holes
-- negative is the point is out the polygon
-- rev 1. adding MULTIPOLYGON and GEOMETRYCOLLECTION support by @abelvm
CREATE OR REPLACE FUNCTION _Signed_Dist(
    IN polygon geometry,
    IN point geometry
    )
RETURNS numeric  AS $$
DECLARE
    pols geometry[];
    pol geometry;
    i integer;
    j integer;
    within integer;
    w integer;
    holes integer;
    dist numeric;
    d numeric;
BEGIN
    dist := 1e999;
    WITH collection as (SELECT (ST_dump(polygon)).geom as geom) SELECT array_agg(geom) into pols FROM collection;
    FOR j in 1..array_length(pols, 1)
    LOOP
        pol := pols[j];
        d := dist;
        SELECT LEAST(dist, ST_distance(point, ST_ExteriorRing(pol))::numeric) INTO d;
        SELECT CASE WHEN ST_Within(point,pol) THEN 1 ELSE -1 END INTO w;
        SELECT ST_NumInteriorRings(pol) INTO holes;
        IF holes > 0 THEN
            FOR i IN 1..holes
            LOOP
                SELECT LEAST(d, ST_distance(point, ST_InteriorRingN(pol, i))::numeric) INTO d;
            END LOOP;
        END IF;
        IF d < dist THEN
            dist:= d;
            within := w;
        END IF;
    END LOOP;
    dist := dist * within::numeric;
    RETURN dist;
END;
$$ language plpgsql IMMUTABLE PARALLEL SAFE;
