-- Moran's I Global Measure (public-facing)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestGlobal(
      subquery TEXT,
      column_name TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (moran NUMERIC, significance NUMERIC)
AS $$
  from crankshaft.clustering import Moran
  # TODO: use named parameters or a dictionary
  moran = Moran()
  return moran.global_stat(subquery, column_name, w_type,
                           num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;

-- Moran's I Local (internal function) - DEPRECATED
CREATE OR REPLACE FUNCTION
  _CDB_AreasOfInterestLocal(
      subquery TEXT,
      column_name TEXT,
      w_type TEXT,
      num_ngbrs INT,
      permutations INT,
      geom_col TEXT,
      id_col TEXT)
RETURNS TABLE (
    moran NUMERIC,
    quads TEXT,
    significance NUMERIC,
    rowid INT,
    vals NUMERIC)
AS $$
  from crankshaft.clustering import Moran
  moran = Moran()
  result = moran.local_stat(subquery, column_name, w_type,
                            num_ngbrs, permutations, geom_col, id_col)
  # remove spatial lag
  return [(r[6], r[0], r[1], r[7], r[5]) for r in result]
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;

-- Moran's I Local (internal function)
CREATE OR REPLACE FUNCTION
  _CDB_MoransILocal(
      subquery TEXT,
      column_name TEXT,
      w_type TEXT,
      num_ngbrs INT,
      permutations INT,
      geom_col TEXT,
      id_col TEXT)
RETURNS TABLE (
    quads TEXT,
    significance NUMERIC,
    spatial_lag NUMERIC,
    spatial_lag_std NUMERIC,
    orig_val NUMERIC,
    orig_val_std NUMERIC,
    moran_stat NUMERIC,
    rowid INT)
AS $$

from crankshaft.clustering import Moran
moran = Moran()
return moran.local_stat(subquery, column_name, w_type,
                        num_ngbrs, permutations, geom_col, id_col)

$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;


-- Moran's I Local (public-facing function)
--  Replaces CDB_AreasOfInterestLocal
CREATE OR REPLACE FUNCTION
  CDB_MoransILocal(
    subquery TEXT,
    column_name TEXT,
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (
    quads TEXT,
    significance NUMERIC,
    spatial_lag NUMERIC,
    spatial_lag_std NUMERIC,
    orig_val NUMERIC,
    orig_val_std NUMERIC,
    moran_stat NUMERIC,
    rowid INT)
AS $$

  SELECT
    quads, significance, spatial_lag, spatial_lag_std,
    orig_val, orig_val_std, moran_stat, rowid
  FROM cdb_crankshaft._CDB_MoransILocal(
    subquery, column_name, w_type,
    num_ngbrs, permutations, geom_col, id_col);

$$ LANGUAGE SQL VOLATILE PARALLEL UNSAFE;

-- Moran's I Local (public-facing function) - DEPRECATED
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestLocal(
    subquery TEXT,
    column_name TEXT,
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocal(subquery, column_name, w_type, num_ngbrs, permutations, geom_col, id_col);

$$ LANGUAGE SQL VOLATILE PARALLEL UNSAFE;

-- Moran's I only for HH and HL (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialHotspots(
    subquery TEXT,
    column_name TEXT,
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id')
    RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocal(subquery, column_name, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('HH', 'HL');

$$ LANGUAGE SQL VOLATILE PARALLEL UNSAFE;

-- Moran's I only for LL and LH (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialColdspots(
    subquery TEXT,
    attr TEXT,
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id')
    RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocal(subquery, attr, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('LL', 'LH');

$$ LANGUAGE SQL VOLATILE PARALLEL UNSAFE;

-- Moran's I only for LH and HL (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialOutliers(
    subquery TEXT,
    attr TEXT,
    w_type TEXT DEFAULT 'knn',
    num_ngbrs INT DEFAULT 5,
    permutations INT DEFAULT 99,
    geom_col TEXT DEFAULT 'the_geom',
    id_col TEXT DEFAULT 'cartodb_id')
    RETURNS TABLE (moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocal(subquery, attr, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('HL', 'LH');

$$ LANGUAGE SQL VOLATILE PARALLEL UNSAFE;

-- Moran's I Global Rate (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestGlobalRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (moran FLOAT, significance FLOAT)
AS $$
  from crankshaft.clustering import Moran
  moran = Moran()
  # TODO: use named parameters or a dictionary
  return moran.global_rate_stat(subquery, numerator, denominator, w_type,
                                num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;


-- Moran's I Local Rate (internal function) - DEPRECATED
CREATE OR REPLACE FUNCTION
  _CDB_AreasOfInterestLocalRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT,
      num_ngbrs INT,
      permutations INT,
      geom_col TEXT,
      id_col TEXT)
RETURNS
TABLE(
    moran NUMERIC,
    quads TEXT,
    significance NUMERIC,
    rowid INT,
    vals NUMERIC)
AS $$
  from crankshaft.clustering import Moran
  moran = Moran()
  # TODO: use named parameters or a dictionary
  result = moran.local_rate_stat(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col)
  # remove spatial lag
  return [(r[6], r[0], r[1], r[7], r[4]) for r in result]
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;

-- Moran's I Local Rate (public-facing function) - DEPRECATED
CREATE OR REPLACE FUNCTION
  CDB_AreasOfInterestLocalRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocalRate(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col);

$$ LANGUAGE SQL VOLATILE PARALLEL UNSAFE;

-- Internal function
CREATE OR REPLACE FUNCTION
  _CDB_MoransILocalRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT,
      num_ngbrs INT,
      permutations INT,
      geom_col TEXT,
      id_col TEXT)
RETURNS
TABLE(
    quads TEXT,
    significance NUMERIC,
    spatial_lag NUMERIC,
    spatial_lag_std NUMERIC,
    orig_val NUMERIC,
    orig_val_std NUMERIC,
    moran_stat NUMERIC,
    rowid INT)
AS $$
from crankshaft.clustering import Moran
moran = Moran()
return moran.local_rate_stat(
    subquery,
    numerator,
    denominator,
    w_type,
    num_ngbrs,
    permutations,
    geom_col,
    id_col
)
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;

-- Moran's I Rate
-- Replaces CDB_AreasOfInterestLocalRate
CREATE OR REPLACE FUNCTION
  CDB_MoransILocalRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS
TABLE(
    quads TEXT,
    significance NUMERIC,
    spatial_lag NUMERIC,
    spatial_lag_std NUMERIC,
    orig_val NUMERIC,
    orig_val_std NUMERIC,
    moran_stat NUMERIC,
    rowid INT)
AS $$

SELECT
  quads, significance, spatial_lag, spatial_lag_std,
  orig_val, orig_val_std, moran_stat, rowid
FROM cdb_crankshaft._CDB_MoransILocalRate(
  subquery, numerator, denominator, w_type,
  num_ngbrs, permutations, geom_col, id_col);

$$ LANGUAGE SQL VOLATILE PARALLEL UNSAFE;

-- Moran's I Local Rate only for HH and HL (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialHotspotsRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocalRate(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('HH', 'HL');

$$ LANGUAGE SQL VOLATILE PARALLEL UNSAFE;

-- Moran's I Local Rate only for LL and LH (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialColdspotsRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocalRate(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('LL', 'LH');

$$ LANGUAGE SQL VOLATILE PARALLEL UNSAFE;

-- Moran's I Local Rate only for LH and HL (public-facing function)
CREATE OR REPLACE FUNCTION
  CDB_GetSpatialOutliersRate(
      subquery TEXT,
      numerator TEXT,
      denominator TEXT,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
      permutations INT DEFAULT 99,
      geom_col TEXT DEFAULT 'the_geom',
      id_col TEXT DEFAULT 'cartodb_id')
RETURNS
TABLE(moran NUMERIC, quads TEXT, significance NUMERIC, rowid INT, vals NUMERIC)
AS $$

  SELECT moran, quads, significance, rowid, vals
  FROM cdb_crankshaft._CDB_AreasOfInterestLocalRate(subquery, numerator, denominator, w_type, num_ngbrs, permutations, geom_col, id_col)
  WHERE quads IN ('HL', 'LH');

$$ LANGUAGE SQL VOLATILE PARALLEL UNSAFE;
