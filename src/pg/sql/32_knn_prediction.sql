
CREATE OR REPLACE FUNCTION CDB_knnWeightedAverage(source_geom geometry(Point, 4326), target_geoms geometry(Point, 4326)[], target_vals numeric[], num_neighbors INT)
RETURNS numeric
AS $$
DECLARE
  weighted_avg numeric;
  vals numeric[];
  distances numeric[];
  idx INT;
BEGIN

  IF array_length(target_geoms, 1) IS NULL
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
     LIMIT $4) As j'
  USING source_geom, target_geoms, target_vals, num_neighbors
  INTO vals, distances;
  weighted_avg := (SELECT sum(  v / coalesce(nullif(d, 0), 1)) /
                          sum(1.0 / coalesce(nullif(d, 0), 1))
                   FROM (SELECT unnest(vals) As v, unnest(distances) As d) As x);
  RETURN weighted_avg;
END;
$$ LANGUAGE plpgsql;
