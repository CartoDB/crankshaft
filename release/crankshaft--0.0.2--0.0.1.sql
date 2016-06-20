CREATE OR REPLACE FUNCTION
cdb_crankshaft._cdb_random_seeds (seed_value INTEGER) RETURNS VOID
AS $$
  from crankshaft import random_seeds
  random_seeds.set_random_seeds(seed_value)
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
cdb_crankshaft.cdb_moran_local (
      t TEXT,
  	  attr TEXT,
  	  significance float DEFAULT 0.05,
  	  num_ngbrs INT DEFAULT 5,
  	  permutations INT DEFAULT 99,
  	  geom_column TEXT DEFAULT 'the_geom',
  	  id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn')
RETURNS TABLE (moran FLOAT, quads TEXT, significance FLOAT, ids INT)
AS $$
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran_local(t, attr, significance, num_ngbrs, permutations, geom_column, id_col, w_type)
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
cdb_crankshaft.cdb_moran_local_rate(t TEXT,
		 numerator TEXT,
		 denominator TEXT,
		 significance FLOAT DEFAULT 0.05,
		 num_ngbrs INT DEFAULT 5,
		 permutations INT DEFAULT 99,
		 geom_column TEXT DEFAULT 'the_geom',
		 id_col TEXT DEFAULT 'cartodb_id',
		 w_type TEXT DEFAULT 'knn')
RETURNS TABLE(moran FLOAT, quads TEXT, significance FLOAT, ids INT, y numeric)
AS $$
  from crankshaft.clustering import moran_local_rate
  # TODO: use named parameters or a dictionary
  return moran_local_rate(t, numerator, denominator, significance, num_ngbrs, permutations, geom_column, id_col, w_type)
$$ LANGUAGE plpythonu;

DROP FUNCTION IF EXISTS cdb_crankshaft.cdb_crankshaft_version();
DROP FUNCTION IF EXISTS cdb_crankshaft._cdb_crankshaft_internal_version();
DROP FUNCTION IF EXISTS cdb_crankshaft._cdb_crankshaft_activate_py();
