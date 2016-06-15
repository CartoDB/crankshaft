
CREATE OR REPLACE FUNCTION CDB_knnWeightedAverage(source_geom geometry(Point, 4326), target_geoms geometry(Point, 4326)[], target_vals numeric[], num_neighbors INT)
RETURNS numeric
AS $$
DECLARE
  weighted_avg numeric;
  vals numeric[];
  distances numeric[];
  idx INT;
BEGIN

  IF array_length(target_geoms) IS NULL
  THEN
    RETURN NULL;
  END IF;

  EXECUTE
  'SELECT
     array_agg(vals),
     array_agg(ST_Distance($1::geography, geoms::geography)) As dist
   FROM (
     SELECT geoms, vals FROM (
       SELECT unnest($2) As geoms, unnest($3) As vals
     ) As i
     ORDER BY $1 <-> geoms
     LIMIT 5) As j'
  USING source_geom, target_geoms, target_vals
  INTO vals, distances;

  IF 0 = Any(distances)
  THEN
    FOR idx IN 1..array_length(distances, 1)
    LOOP
      IF distances[idx] = 0
      THEN
        weighted_avg := vals[idx];
        RAISE DEBUG 'zero distance at %, returning val %', idx, weighted_avg;
        RETURN weighted_avg;
      END IF;
    END LOOP;
  ELSE
    weighted_avg := (SELECT sum(v / d) / sum(1.0 / d) FROM (SELECT unnest(vals) As v, unnest(distances) As d) As x);
    RETURN weighted_avg;
  END IF;
END;
$$ LANGUAGE plpgsql;
