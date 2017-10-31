
-- Find outliers using a static threshold
--
CREATE OR REPLACE FUNCTION CDB_StaticOutlier(column_value numeric, threshold numeric)
RETURNS boolean
AS $$
BEGIN

  RETURN column_value > threshold;

END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE ;

-- Find outliers by a percentage above the threshold
-- TODO: add symmetric option? `is_symmetric boolean DEFAULT false`

CREATE OR REPLACE FUNCTION CDB_PercentOutlier(column_values numeric[], outlier_fraction numeric, ids int[])
RETURNS TABLE(is_outlier boolean, rowid int)
AS $$
DECLARE
  avg_val numeric;
  out_vals boolean[];
BEGIN

  SELECT avg(i) INTO avg_val
    FROM unnest(column_values) As x(i);

  IF avg_val = 0 THEN
    RAISE EXCEPTION 'Mean value is zero. Try another outlier method.';
  END IF;

  SELECT array_agg(
           outlier_fraction < i / avg_val) INTO out_vals
    FROM unnest(column_values) As x(i);

  RETURN QUERY
  SELECT unnest(out_vals) As is_outlier,
         unnest(ids) As rowid;

END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;

-- Find outliers above a given number of standard deviations from the mean

CREATE OR REPLACE FUNCTION CDB_StdDevOutlier(column_values numeric[], num_deviations numeric, ids int[], is_symmetric boolean DEFAULT true)
RETURNS TABLE(is_outlier boolean, rowid int)
AS $$
DECLARE
  stddev_val numeric;
  avg_val numeric;
  out_vals boolean[];
BEGIN

  SELECT stddev(i), avg(i) INTO stddev_val, avg_val
    FROM unnest(column_values) As x(i);

  IF stddev_val = 0 THEN
    RAISE EXCEPTION 'Standard deviation of input data is zero';
  END IF;

  IF is_symmetric THEN
    SELECT array_agg(
             abs(i - avg_val) / stddev_val > num_deviations) INTO out_vals
      FROM unnest(column_values) As x(i);
  ELSE
    SELECT array_agg(
             (i - avg_val) / stddev_val > num_deviations) INTO out_vals
      FROM unnest(column_values) As x(i);
  END IF;

  RETURN QUERY
  SELECT unnest(out_vals) As is_outlier,
         unnest(ids) As rowid;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;
