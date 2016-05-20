-- Moran's I (global)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterest_Global (
      subquery TEXT,
      attr_name TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS TABLE (moran NUMERIC, significance NUMERIC)
AS $$
  plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran(subquery, attr, num_ngbrs, permutations, geom_col, id_col, w_type)
$$ LANGUAGE plpythonu;

-- Moran's I Local
CREATE OR REPLACE FUNCTION
  _CDB_AreasOfInterest_Local(
      subquery TEXT,
      attr TEXT,
      permutations INT,
      geom_col TEXT,
      id_col TEXT,
      w_type TEXT,
      num_ngbrs INT)
RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, ids INT, y NUMERIC)
AS $$
  plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran_local(subquery, attr, permutations, geom_col, id_col, w_type, num_ngbrs)
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterest_Local(
    subquery TEXT,
    attr TEXT,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id',
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5)
RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, ids INT, y NUMERIC)
AS $$

  SELECT moran, quads, significance, ids, y
  FROM cdb_crankshaft._CDB_AreasOfInterest_Local(subquery, attr, permutations, geom_col, id_col, w_type, num_ngbrs);

$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION
  CDB_GetSpatialHotspots(
    subquery TEXT,
    attr TEXT,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id',
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5)
    RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, ids INT, y NUMERIC)
AS $$

  SELECT moran, quads, significance, ids, y
  FROM cdb_crankshaft._CDB_AreasOfInterest_Local(subquery, attr, permutations, geom_col, id_col, w_type, num_ngbrs)
  WHERE quads IN ('HH', 'HL');

$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION
  CDB_GetSpatialColdspots(
    subquery TEXT,
    attr TEXT,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id',
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5)
    RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, ids INT, y NUMERIC)
AS $$

  SELECT moran, quads, significance, ids, y
  FROM cdb_crankshaft._CDB_AreasOfInterest_Local(subquery, attr, permutations, geom_col, id_col, w_type, num_ngbrs)
  WHERE quads IN ('LL', 'LH');

$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION
  CDB_GetSpatialOutliers(
    subquery TEXT,
    attr TEXT,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id',
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5)
    RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, ids INT, y NUMERIC)
AS $$

  SELECT moran, quads, significance, ids, y
  FROM cdb_crankshaft._CDB_AreasOfInterest_Local(subquery, attr, permutations, geom_col, id_col, w_type, num_ngbrs)
  WHERE quads IN ('HL', 'LH');

$$ LANGUAGE SQL;

-- Moran's I Rate (global)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterest_Global_Rate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS TABLE (moran FLOAT, significance FLOAT)
AS $$
  plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran_rate(subquery, numerator, denominator, permutations, geom_col, id_col, w_type, num_ngbrs)
$$ LANGUAGE plpythonu;


-- Moran's I Local Rate
CREATE OR REPLACE FUNCTION
  _CDB_AreasOfInterest_Local_Rate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      permutations INT,
      geom_col TEXT,
      id_col TEXT,
      w_type TEXT,
      num_ngbrs INT)
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, ids INT, y NUMERIC)
AS $$
  plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
  from crankshaft.clustering import moran_local_rate
  # TODO: use named parameters or a dictionary
  return moran_local_rate(subquery, numerator, denominator, permutations, geom_col, id_col, w_type, num_ngbrs)
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterest_Local_Rate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, ids INT, y NUMERIC)
AS $$

  SELECT moran, quads, significance, ids, y
  FROM cdb_crankshaft._CDB_AreasOfInterest_Local_Rate(subquery, numerator, denominator, permutations, geom_col, id_col, w_type, num_ngbrs);

$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION
  CDB_GetSpatialHotspots_Rate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, ids INT, y NUMERIC)
AS $$

  SELECT moran, quads, significance, ids, y
  FROM cdb_crankshaft._CDB_AreasOfInterest_Local_Rate(subquery, numerator, denominator, permutations, geom_col, id_col, w_type, num_ngbrs)
  WHERE quads IN ('HH', 'HL');

$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION
  CDB_GetSpatialColdspots_Rate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, ids INT, y NUMERIC)
AS $$

  SELECT moran, quads, significance, ids, y
  FROM cdb_crankshaft._CDB_AreasOfInterest_Local_Rate(subquery, numerator, denominator, permutations, geom_col, id_col, w_type, num_ngbrs)
  WHERE quads IN ('LL', 'LH');

$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION
  CDB_GetSpatialOutliers_Rate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5)
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, ids INT, y NUMERIC)
AS $$

  SELECT moran, quads, significance, ids, y
  FROM cdb_crankshaft._CDB_AreasOfInterest_Local_Rate(subquery, numerator, denominator, permutations, geom_col, id_col, w_type, num_ngbrs)
  WHERE quads IN ('HL', 'LH');

$$ LANGUAGE SQL;

-- -- Moran's I Local Bivariate
-- CREATE OR REPLACE FUNCTION
--   cdb_moran_local_bv(
--       subquery TEXT,
--       attr1 TEXT,
--       attr2 TEXT,
--       permutations INT DEFAULT 99,
--       geom_col TEXT DEFAULT 'the_geom',
--       id_col TEXT DEFAULT 'cartodb_id',
--       w_type TEXT DEFAULT 'knn',
--       num_ngbrs INT DEFAULT 5)
-- RETURNS TABLE(moran FLOAT, quads TEXT, significance FLOAT, ids INT, y numeric)
-- AS $$
--   from crankshaft.clustering import moran_local_bv
--   # TODO: use named parameters or a dictionary
--   return moran_local_bv(t, attr1, attr2, permutations, geom_col, id_col, w_type, num_ngbrs)
-- $$ LANGUAGE plpythonu;
