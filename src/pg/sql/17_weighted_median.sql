CREATE OR REPLACE FUNCTION CDB_WeightedMedianCenter(geoms geometry[], vals numeric[])
RETURNS geometry(Point, 4326)
AS $$
DECLARE
  i INT;
  median_val numeric;
  median_index INT;
BEGIN

  -- find the median value
  SELECT percentile_disc(0.5) WITHIN GROUP (ORDER BY v) INTO median_val
    FROM unnest(vals) As x(v);

  -- find the index of the median value
  FOR i in 1..array_length(vals, 1)
  LOOP
    IF vals[i] < median_val
    THEN
      median_index := i;
      EXIT;
    END IF;
  END LOOP;

  -- return the geometry that has the median value of the dataset
  IF ST_GeometryType(geoms[median_index]) <> 'ST_Point'
  THEN
    RETURN ST_Centroid(geoms[median_index]);
  ELSE
    RETURN geoms[median_index];
  END IF;

END;
$$ LANGUAGE plpgsql;
