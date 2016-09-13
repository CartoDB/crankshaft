-- Getis-Ord's G
-- Hotspot/Coldspot Analysis tool
CREATE OR REPLACE FUNCTION
  CDB_GetisOrdsG(
      subquery TEXT,
      column_name TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (z_val NUMERIC, p_val NUMERIC, p_z_sim NUMERIC, rowid BIGINT)
AS $$
  from crankshaft.clustering import getis_ord
  return getis_ord(subquery, column_name, w_type, num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu;
