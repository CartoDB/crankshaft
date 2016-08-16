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
        test_d := _Signed_Dist(polygon, ST_Centroid(cell));
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
