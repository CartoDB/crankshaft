\pset format unaligned
\set ECHO all
\i test/fixtures/ppoints.sql
\i test/fixtures/ppoints2.sql

-- Areas of Interest functions perform some nondeterministic computations
-- (to estimate the significance); we will set the seeds for the RNGs
-- that affect those results to have repeateble results

-- Moran's I Global
SELECT cdb_crankshaft._cdb_random_seeds(1234);

SELECT round(moran, 4) As moran, round(significance, 4) As significance
  FROM cdb_crankshaft.CDB_AreasOfInterestGlobal('SELECT * FROM ppoints', 'value') m(moran, significance);

-- Moran's I Local
SELECT cdb_crankshaft._cdb_random_seeds(1234);

SELECT ppoints.code, m.quads
  FROM ppoints
  JOIN cdb_crankshaft.CDB_AreasOfInterestLocal('SELECT * FROM ppoints', 'value') m
    ON ppoints.cartodb_id = m.rowid
  ORDER BY ppoints.code;

SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- Moran's I local
SELECT
  ppoints.code, m.quads,
  abs(avg(m.orig_val_std) OVER ()) < 1e-6 as diff_orig,
  CASE WHEN m.quads = 'HL' THEN m.orig_val_std > m.spatial_lag_std
       WHEN m.quads = 'HH' THEN m.orig_val_std >= 0 and m.spatial_lag_std >= 0
       WHEN m.quads = 'LH' THEN m.orig_val_std < m.spatial_lag_std
       WHEN m.quads = 'LL' THEN m.orig_val_std <= 0 and m.spatial_lag_std <= 0
       ELSE null END as expected,
  moran_stat is not null moran_stat_not_null,
  significance >= 0.001 significance_not_null, -- greater than 1/1000 (default)
  abs(m.orig_val - ppoints.value) <= 1e-6 as value_comparison
  FROM ppoints
  JOIN cdb_crankshaft.CDB_MoransILocal('SELECT * FROM ppoints', 'value') m
    ON ppoints.cartodb_id = m.rowid
  ORDER BY ppoints.code;

SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- Spatial Hotspots
SELECT ppoints.code, m.quads
  FROM ppoints
  JOIN cdb_crankshaft.CDB_GetSpatialHotspots('SELECT * FROM ppoints', 'value') m
    ON ppoints.cartodb_id = m.rowid
  ORDER BY ppoints.code;

SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- Spatial Coldspots
SELECT ppoints.code, m.quads
  FROM ppoints
  JOIN cdb_crankshaft.CDB_GetSpatialColdspots('SELECT * FROM ppoints', 'value') m
    ON ppoints.cartodb_id = m.rowid
  ORDER BY ppoints.code;

SELECT cdb_crankshaft._cdb_random_seeds(1234);

  -- Spatial Outliers
SELECT ppoints.code, m.quads
  FROM ppoints
  JOIN cdb_crankshaft.CDB_GetSpatialOutliers('SELECT * FROM ppoints', 'value') m
    ON ppoints.cartodb_id = m.rowid
  ORDER BY ppoints.code;


SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- Areas of Interest (rate)
SELECT ppoints2.code, m.quads
  FROM ppoints2
  JOIN cdb_crankshaft.CDB_AreasOfInterestLocalRate('SELECT * FROM ppoints2', 'numerator', 'denominator') m
    ON ppoints2.cartodb_id = m.rowid
  ORDER BY ppoints2.code;

SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- Moran's I local rate
SELECT
  ppoints2.code, m.quads,
  abs(avg(m.orig_val_std) OVER ()) < 1e-6 as diff_orig,
  CASE WHEN m.quads = 'HL' THEN m.orig_val_std > m.spatial_lag_std
       WHEN m.quads = 'HH' THEN m.orig_val_std >= 0 and m.spatial_lag_std >= 0
       WHEN m.quads = 'LH' THEN m.orig_val_std < m.spatial_lag_std
       WHEN m.quads = 'LL' THEN m.orig_val_std <= 0 and m.spatial_lag_std <= 0
       ELSE null END as expected,
  moran_stat is not null moran_stat_not_null,
  significance >= 0.001 significance_not_null -- greater than 1/1000 (default)
  FROM ppoints2
  JOIN cdb_crankshaft.CDB_MoransILocalRate('SELECT * FROM ppoints2', 'numerator', 'denominator') m
    ON ppoints2.cartodb_id = m.rowid
  ORDER BY ppoints2.code;

SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- Spatial Hotspots (rate)
SELECT ppoints2.code, m.quads
  FROM ppoints2
  JOIN cdb_crankshaft.CDB_GetSpatialHotspotsRate('SELECT * FROM ppoints2', 'numerator', 'denominator') m
    ON ppoints2.cartodb_id = m.rowid
  ORDER BY ppoints2.code;

SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- Spatial Coldspots (rate)
SELECT ppoints2.code, m.quads
  FROM ppoints2
  JOIN cdb_crankshaft.CDB_GetSpatialColdspotsRate('SELECT * FROM ppoints2', 'numerator', 'denominator') m
    ON ppoints2.cartodb_id = m.rowid
  ORDER BY ppoints2.code;

SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- Spatial Outliers (rate)
SELECT ppoints2.code, m.quads
  FROM ppoints2
  JOIN cdb_crankshaft.CDB_GetSpatialOutliersRate('SELECT * FROM ppoints2', 'numerator', 'denominator') m
    ON ppoints2.cartodb_id = m.rowid
  ORDER BY ppoints2.code;
