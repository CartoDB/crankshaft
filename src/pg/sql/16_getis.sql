-- Getis-Ord's G
-- Hotspot/Coldspot Analysis tool
CREATE OR REPLACE FUNCTION
  CDB_GetisOrdsG(
      subquery TEXT,
      column_name TEXT,
      w_type TEXT,
      num_ngbrs INT,
      permutations INT,
      geom_col TEXT,
      id_col TEXT)
RETURNS TABLE (z_val NUMERIC, p_val NUMERIC, rowid BIGINT)
AS $$
  from crankshaft.clustering import getis
  return getis_ord(subquery, column_name, w_type, num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu;
