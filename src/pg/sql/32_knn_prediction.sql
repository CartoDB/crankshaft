
CREATE OR REPLACE FUNCTION CDB_knnWeightedAverage(source_geom geometry(Point, 4326), target_geoms geometry(Point, 4326)[], target_vals numeric[], num_neighbors INT)
RETURNS numeric
AS $$
DECLARE
  weighted_avg numeric;
  vals numeric[];
  distances numeric[];
BEGIN

  IF array_length(target_geoms, 1) IS NULL
  THEN
    RETURN NULL;
  END IF;

  EXECUTE
  'SELECT
     sum(vals / coalesce(nullif(ST_Distance($1::geography, geoms::geography), 0), 1)) /
     sum( 1.0 / coalesce(nullif(ST_Distance($1::geography, geoms::geography), 0), 1))
   FROM (
     SELECT geoms, vals FROM (
       SELECT unnest($2) As geoms, unnest($3) As vals
     ) As i
     ORDER BY $1 <-> geoms
     LIMIT $4) As j'
  USING source_geom, target_geoms, target_vals, num_neighbors
  INTO weighted_avg;

  RETURN weighted_avg;
END;
$$ LANGUAGE plpgsql;
