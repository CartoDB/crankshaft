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
$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;

--
-- Calculate the equal interval bins for a given column
--
-- @param in_array A numeric array of numbers to determine the best
--                   to determine the bin boundary
--
-- @param breaks The number of bins you want to find.
--
--
-- Returns: upper edges of bins
--
--

CREATE OR REPLACE FUNCTION CDB_EqualIntervalBins ( in_array NUMERIC[], breaks INT ) RETURNS NUMERIC[] as $$
DECLARE
    diff numeric;
    min_val numeric;
    max_val numeric;
    tmp_val numeric;
    i INT := 1;
    reply numeric[];
BEGIN
    SELECT min(e), max(e) INTO min_val, max_val FROM ( SELECT unnest(in_array) e ) x WHERE e IS NOT NULL;
    diff = (max_val - min_val) / breaks::numeric;
    LOOP
        IF i < breaks THEN
            tmp_val = min_val + i::numeric * diff;
            reply = array_append(reply, tmp_val);
            i := i+1;
        ELSE
            reply = array_append(reply, max_val);
            EXIT;
        END IF;
    END LOOP;
    RETURN reply;
END;
$$ language plpgsql IMMUTABLE PARALLEL SAFE;

--
-- Determine the Heads/Tails classifications from a numeric array
--
-- @param in_array A numeric array of numbers to determine the best
--            bins based on the Heads/Tails method.
--
-- @param breaks The number of bins you want to find.
--
--

CREATE OR REPLACE FUNCTION CDB_HeadsTailsBins ( in_array NUMERIC[], breaks INT) RETURNS NUMERIC[] as $$
DECLARE
    element_count INT4;
    arr_mean numeric;
    i INT := 2;
    reply numeric[];
BEGIN
    -- get the total size of our row
    element_count := array_upper(in_array, 1) - array_lower(in_array, 1);
    -- ensure the ordering of in_array
    SELECT array_agg(e) INTO in_array FROM (SELECT unnest(in_array) e ORDER BY e) x;
    -- stop if no rows
    IF element_count IS NULL THEN
        RETURN NULL;
    END IF;
    -- stop if our breaks are more than our input array size
    IF element_count < breaks THEN
        RETURN in_array;
    END IF;

    -- get our mean value
    SELECT avg(v) INTO arr_mean FROM (  SELECT unnest(in_array) as v ) x;

    reply = Array[arr_mean];
    -- slice our bread
    LOOP
        IF i > breaks THEN  EXIT;  END IF;
        SELECT avg(e) INTO arr_mean FROM ( SELECT unnest(in_array) e) x WHERE e > reply[i-1];
        IF arr_mean IS NOT NULL THEN
            reply = array_append(reply, arr_mean);
        END IF;
        i := i+1;
    END LOOP;
    RETURN reply;
END;
$$ language plpgsql IMMUTABLE PARALLEL SAFE;

--
-- Determine the Jenks classifications from a numeric array
--
-- @param in_array A numeric array of numbers to determine the best
--            bins based on the Jenks method.
--
-- @param breaks The number of bins you want to find.
--
-- @param iterations The number of different starting positions to test.
--
-- @param invert Optional wheter to return the top of each bin (default)
--               or the bottom. BOOLEAN, default=FALSE.
--
--


CREATE OR REPLACE FUNCTION CDB_JenksBins ( in_array NUMERIC[], breaks INT, iterations INT DEFAULT 5, invert BOOLEAN DEFAULT FALSE) RETURNS NUMERIC[] as $$
DECLARE
    element_count INT4;
    arr_mean NUMERIC;
    bot INT;
    top INT;
    tops INT[];
    classes INT[][];
    i INT := 1; j INT := 1;
    curr_result NUMERIC[];
    best_result NUMERIC[];
    seedtarget TEXT;
    quant NUMERIC[];
    shuffles INT;
BEGIN
    -- get the total size of our row
    element_count := array_length(in_array, 1); --array_upper(in_array, 1) - array_lower(in_array, 1);
    -- ensure the ordering of in_array
    SELECT array_agg(e) INTO in_array FROM (SELECT unnest(in_array) e ORDER BY e) x;
    -- stop if no rows
    IF element_count IS NULL THEN
        RETURN NULL;
    END IF;
    -- stop if our breaks are more than our input array size
    IF element_count < breaks THEN
        RETURN in_array;
    END IF;

    shuffles := LEAST(GREATEST(floor(2500000.0/(element_count::float*iterations::float)), 1), 750)::int;
    -- get our mean value
    SELECT avg(v) INTO arr_mean FROM (  SELECT unnest(in_array) as v ) x;

    -- assume best is actually Quantile
    SELECT cdb_crankshaft.CDB_QuantileBins(in_array, breaks) INTO quant;

    -- if data is very very large, just return quant and be done
    IF element_count > 5000000 THEN
        RETURN quant;
    END IF;

    -- change quant into bottom, top markers
    LOOP
        IF i = 1 THEN
            bot = 1;
        ELSE
            -- use last top to find this bot
            bot = top+1;
        END IF;
        IF i = breaks THEN
            top = element_count;
        ELSE
            SELECT count(*) INTO top FROM ( SELECT unnest(in_array) as v) x WHERE v <= quant[i];
        END IF;
        IF i = 1 THEN
            classes = ARRAY[ARRAY[bot,top]];
        ELSE
            classes = ARRAY_CAT(classes,ARRAY[bot,top]);
        END IF;
        IF i > breaks THEN EXIT; END IF;
        i = i+1;
    END LOOP;

    best_result = cdb_crankshaft.CDB_JenksBinsIteration( in_array, breaks, classes, invert, element_count, arr_mean, shuffles);

    --set the seed so we can ensure the same results
    SELECT setseed(0.4567) INTO seedtarget;
    --loop through random starting positions
    LOOP
        IF j > iterations-1 THEN  EXIT;  END IF;
        i = 1;
        tops = ARRAY[element_count];
        LOOP
            IF i = breaks THEN  EXIT;  END IF;
            SELECT array_agg(distinct e) INTO tops FROM (SELECT unnest(array_cat(tops, ARRAY[floor(random()*element_count::float)::int])) as e ORDER BY e) x WHERE e != 1;
            i = array_length(tops, 1);
        END LOOP;
        i = 1;
        LOOP
            IF i > breaks THEN  EXIT;  END IF;
            IF i = 1 THEN
                bot = 1;
            ELSE
                bot = top+1;
            END IF;
            top = tops[i];
            IF i = 1 THEN
                classes = ARRAY[ARRAY[bot,top]];
            ELSE
                classes = ARRAY_CAT(classes,ARRAY[bot,top]);
            END IF;
            i := i+1;
        END LOOP;
        curr_result = cdb_crankshaft.CDB_JenksBinsIteration( in_array, breaks, classes, invert, element_count, arr_mean, shuffles);

        IF curr_result[1] > best_result[1] THEN
            best_result = curr_result;
            j = j-1; -- if we found a better result, add one more search
        END IF;
        j = j+1;
    END LOOP;

    RETURN (best_result)[2:array_upper(best_result, 1)];
END;
$$ language plpgsql VOLATILE PARALLEL RESTRICTED;



--
-- Perform a single iteration of the Jenks classification
--

CREATE OR REPLACE FUNCTION CDB_JenksBinsIteration ( in_array NUMERIC[], breaks INT, classes INT[][], invert BOOLEAN, element_count INT4, arr_mean NUMERIC, max_search INT DEFAULT 50) RETURNS NUMERIC[] as $$
DECLARE
    tmp_val numeric;
    new_classes int[][];
    tmp_class int[];
    i INT := 1;
    j INT := 1;
    side INT := 2;
    sdam numeric;
    gvf numeric := 0.0;
    new_gvf numeric;
    arr_gvf numeric[];
    class_avg numeric;
    class_max_i INT;
    class_min_i INT;
    class_max numeric;
    class_min numeric;
    reply numeric[];
BEGIN

    -- Calculate the sum of squared deviations from the array mean (SDAM).
    SELECT sum((arr_mean - e)^2) INTO sdam FROM (  SELECT unnest(in_array) as e ) x;
    --Identify the breaks for the lowest GVF
    LOOP
        i = 1;
        LOOP
            -- get our mean
            SELECT avg(e) INTO class_avg FROM ( SELECT unnest(in_array[classes[i][1]:classes[i][2]]) as e) x;
            -- find the deviation
            SELECT sum((class_avg-e)^2) INTO tmp_val FROM (   SELECT unnest(in_array[classes[i][1]:classes[i][2]]) as e  ) x;
            IF i = 1 THEN
                arr_gvf = ARRAY[tmp_val];
                -- init our min/max map for later
                class_max = arr_gvf[i];
                class_min = arr_gvf[i];
                class_min_i = 1;
                class_max_i = 1;
            ELSE
                arr_gvf = array_append(arr_gvf, tmp_val);
            END IF;
            i := i+1;
            IF i > breaks THEN EXIT; END IF;
        END LOOP;
        -- calculate our new GVF
        SELECT sdam-sum(e) INTO new_gvf FROM (  SELECT unnest(arr_gvf) as e  ) x;
        -- if no improvement was made, exit
        IF new_gvf < gvf THEN EXIT; END IF;
        gvf = new_gvf;
        IF j > max_search THEN EXIT; END IF;
        j = j+1;
        i = 1;
        LOOP
            --establish directionality (uppward through classes or downward)
            IF arr_gvf[i] < class_min THEN
                class_min = arr_gvf[i];
                class_min_i = i;
            END IF;
            IF arr_gvf[i] > class_max THEN
                class_max = arr_gvf[i];
                class_max_i = i;
            END IF;
            i := i+1;
            IF i > breaks THEN EXIT; END IF;
        END LOOP;
        IF class_max_i > class_min_i THEN
            class_min_i = class_max_i - 1;
        ELSE
            class_min_i = class_max_i + 1;
        END IF;
            --Move from higher class to a lower gid order
            IF class_max_i > class_min_i THEN
                classes[class_max_i][1] = classes[class_max_i][1] + 1;
                classes[class_min_i][2] = classes[class_min_i][2] + 1;
            ELSE -- Move from lower class UP into a higher class by gid
                classes[class_max_i][2] = classes[class_max_i][2] - 1;
                classes[class_min_i][1] = classes[class_min_i][1] - 1;
            END IF;
    END LOOP;

    i = 1;
    LOOP
        IF invert = TRUE THEN
            side = 1; --default returns bottom side of breaks, invert returns top side
        END IF;
        reply = array_append(reply, in_array[classes[i][side]]);
        i = i+1;
        IF i > breaks THEN  EXIT; END IF;
    END LOOP;

    RETURN array_prepend(gvf, reply);

END;
$$ language plpgsql IMMUTABLE PARALLEL SAFE;


--
-- Determine the Quantile classifications from a numeric array
--
-- @param in_array A numeric array of numbers to determine the best
--            bins based on the Quantile method.
--
-- @param breaks The number of bins you want to find.
--
--
CREATE OR REPLACE FUNCTION CDB_QuantileBins ( in_array NUMERIC[], breaks INT) RETURNS NUMERIC[] as $$
DECLARE
    element_count INT4;
    break_size numeric;
    tmp_val numeric;
    i INT := 1;
    reply numeric[];
BEGIN
    -- sort our values
    SELECT array_agg(e) INTO in_array FROM (SELECT unnest(in_array) e ORDER BY e ASC) x;
    -- get the total size of our data
    element_count := array_length(in_array, 1);
    break_size :=  element_count::numeric / breaks;
    -- slice our bread
    LOOP
        IF i < breaks THEN
            IF break_size * i % 1 > 0 THEN
                SELECT e INTO tmp_val FROM ( SELECT unnest(in_array) e LIMIT 1 OFFSET ceil(break_size * i) - 1) x;
            ELSE
                SELECT avg(e) INTO tmp_val FROM ( SELECT unnest(in_array) e LIMIT 2 OFFSET ceil(break_size * i) - 1 ) x;
            END IF;
        ELSIF i = breaks THEN
            -- select the last value
            SELECT max(e) INTO tmp_val FROM ( SELECT unnest(in_array) e ) x;
        ELSE
            EXIT;
        END IF;

        reply = array_append(reply, tmp_val);
        i := i+1;
    END LOOP;
    RETURN reply;
END;
$$ language plpgsql IMMUTABLE STRICT PARALLEL SAFE;
