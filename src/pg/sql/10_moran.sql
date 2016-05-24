-- Moran's I Global Measure (public-facing)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestGlobal (
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

-- Moran's I Local (internal function)
CREATE OR REPLACE FUNCTION
  _CDB_AreasOfInterestLocal(
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

-- Moran's I Local (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestLocal(
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

-- Moran's I only for HH and HL (public-facing function)
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

-- Moran's I only for LL and LH (public-facing function)
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

-- Moran's I only for LH and HL (public-facing function)
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

-- Moran's I Global Rate (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestGlobalRate(
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


-- Moran's I Local Rate (internal function)
CREATE OR REPLACE FUNCTION
  _CDB_AreasOfInterestLocalRate(
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

-- Moran's I Local Rate (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestLocalRate(
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

-- Moran's I Local Rate only for HH and HL (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialHotspotsRate(
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

-- Moran's I Local Rate only for LL and LH (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialColdspotsRate(
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

-- Moran's I Local Rate only for LH and HL (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialOutliersRate(
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
