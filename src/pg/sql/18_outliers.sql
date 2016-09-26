CREATE OR REPLACE FUNCTION CDB_StaticOutlier(attr numeric, threshold numeric)
RETURNS numeric
AS $$
BEGIN

  RETURN attr > threshold;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION CDB_PercentOutlier(attr numeric[], outlier_fraction numeric, ids int[])
RETURNS TABLE(outlier boolean, rowid int)
AS $$
DECLARE
  avg_val numeric;
  out_vals boolean[];
BEGIN

  SELECT avg(i) INTO avg_val FROM unnest(attr) As x(i);

  SELECT array_agg( i > avg_val * outlier_fraction) INTO out_vals
  FROM unnest(attr) As x(i);

  RETURN QUERY
  SELECT unnest(out_vals) As outlier,
         unnest(ids) As rowid;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CDB_StdDevOutlier(attrs numeric[], num_deviations numeric, ids int[])
RETURNS TABLE(outlier boolean, rowid int)
AS $$
DECLARE
  stddev_val numeric;
  avg_val numeric;
  out_vals boolean[];
BEGIN

  SELECT stddev(i), avg(i) INTO stddev_val, avg_val
  FROM unnest(attrs) As x(i);

  SELECT array_agg(abs(i - avg_val) / stddev_val > num_deviations) INTO out_vals
  FROM unnest(attrs) As x(i);


  RETURN QUERY
  SELECT unnest(out_vals) As outlier,
         unnest(ids) As rowid;
END;
$$ LANGUAGE plpgsql;
