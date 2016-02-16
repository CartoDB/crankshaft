CREATE OR REPLACE FUNCTION
cdb_moran_local (
    t TEXT,
	  attr TEXT,
	  significance float DEFAULT 0.05,
	  num_ngbrs INT DEFAULT 5,
	  permutations INT DEFAULT 99,
	  geom_column TEXT DEFAULT 'the_geom',
	  id_col TEXT DEFAULT 'cartodb_id',
	  w_type TEXT DEFAULT 'knn'
)
RETURNS TABLE (
    moran FLOAT,
	  quads TEXT,
	  significance FLOAT,
	  ids INT
)
AS $$
  from crankshaft.clustering import moran_local
  -- TODO: use named parameters or a dictionary
  return moran_local(t, attr, significance, num_ngbrs, permutations, geom_column, id_col, w_type)
$$ LANGUAGE plpython2u;
