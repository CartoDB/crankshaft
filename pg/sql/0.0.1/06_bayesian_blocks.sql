CREATE OR REPLACE FUNCTION
  cdb_adaptive_histogram (
      table_name  TEXT,
      column_name TEXT
  )
RETURNS TABLE (bin_start numeric,bin_end numeric,value numeric)

AS $$
  from crankshaft.bayesian_blocks import adaptive_histogram
  return adaptive_histogram(table_name,column_name)
$$ LANGUAGE plpythonu;
