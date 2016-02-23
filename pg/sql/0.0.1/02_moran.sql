-- Moran's I (global)
CREATE OR REPLACE FUNCTION
  cdb_moran (
      t TEXT,
      attr_name TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS TABLE (moran FLOAT, quads TEXT, significance FLOAT, ids INT)
AS $$
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran(t, attr, significance, num_ngbrs, permutations, geom_col, id_col, w_type)
$$ LANGUAGE plpythonu;

-- Moran's I Local
CREATE OR REPLACE FUNCTION
  cdb_moran_local (
      t TEXT,
      attr TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS TABLE (moran FLOAT, quads TEXT, significance FLOAT, ids INT)
AS $$
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran_local(t, attr, permutations, geom_col, id_col, w_type, num_ngbrs)
$$ LANGUAGE plpythonu;

-- Moran's I Rate (global)
CREATE OR REPLACE FUNCTION
  cdb_moran_rate (
      t TEXT,
      numerator TEXT,
      denominator TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS TABLE (moran FLOAT, quads TEXT, significance FLOAT, ids INT)
AS $$
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran_rate(t, numerator, denominator, permutations, geom_col, id_col, w_type, num_ngbrs)
$$ LANGUAGE plpythonu;


-- Moran's I Local Rate
CREATE OR REPLACE FUNCTION
  cdb_moran_local_rate(
      t TEXT,
      numerator TEXT,
      denominator TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS TABLE(moran FLOAT, quads TEXT, significance FLOAT, ids INT, y numeric)
AS $$
  from crankshaft.clustering import moran_local_rate
  # TODO: use named parameters or a dictionary
  return moran_local_rate(t, numerator, denominator, significance, num_ngbrs, permutations, geom_column, id_col, w_type)
$$ LANGUAGE plpythonu;

-- Moran's I Local Bivariate
CREATE OR REPLACE FUNCTION
  cdb_moran_local_bv(
      t TEXT,
      attr1 TEXT,
      attr2 TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS TABLE(moran FLOAT, quads TEXT, significance FLOAT, ids INT, y numeric)
AS $$
  from crankshaft.clustering import moran_local_bv
  # TODO: use named parameters or a dictionary
  return moran_local_bv(t, attr1, attr2, permutations, geom_col, id_col, w_type, num_ngbrs)
$$ LANGUAGE plpythonu;
