-- Getis-Ord's G
-- Hotspot/Coldspot Analysis tool
CREATE OR REPLACE FUNCTION
  CDB_GetisOrdsG(
      subquery TEXT,
      column_name TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 999,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (z_score NUMERIC, p_value NUMERIC, p_z_sim NUMERIC, rowid BIGINT)
AS $$
  from crankshaft.clustering import Getis
  getis = Getis()
  return getis.getis_ord(subquery, column_name, w_type, num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;

-- TODO: make a version that accepts the values as arrays
