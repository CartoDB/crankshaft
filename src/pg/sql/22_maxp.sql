-- max-p regionalization

CREATE OR REPLACE FUNCTION
  CDB_MaxP(
      subquery TEXT,
      colnames TEXT[],
      floor_variable TEXT,
      min_size int default 1,
      initial int default 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (region_class text, p_val numeric, rowid bigint)
AS $$
  from crankshaft.clustering import MaxP
  maxp = MaxP()
  return maxp.maxp(subquery, colnames, floor_variable, floor=min_size)
$$ LANGUAGE plpythonu;
