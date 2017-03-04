-- Spatial Lag with kNN neighbors (internal function)
CREATE OR REPLACE FUNCTION
  CDB_SpatialLag(
      subquery TEXT,
      column_name TEXT,
      w_type TEXT,
      num_ngbrs INT,
      geom_col TEXT,
      id_col TEXT)
RETURNS TABLE (lag NUMERIC, rowid INT)
AS $$
  from crankshaft.spatial_lag import Spatial
  spatial = Spatial()
  # TODO: use named parameters or a dictionary
  return spatial.spatial_lag(subquery, column_name, w_type,
                          num_ngbrs, geom_col, id_col)
$$ LANGUAGE plpythonu;
