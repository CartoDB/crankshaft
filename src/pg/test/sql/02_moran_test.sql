\i test/fixtures/ppoints.sql
\i test/fixtures/ppoints2.sql

-- Moral functions perform some nondeterministic computations
-- (to estimate the significance); we will set the seeds for the RNGs
-- that affect those results to have repeateble results
SELECT cdb_crankshaft._cdb_random_seeds(1234);

SELECT ppoints.code, m.quads
  FROM ppoints
  JOIN cdb_crankshaft.cdb_moran_local('ppoints', 'value') m
    ON ppoints.cartodb_id = m.ids
  ORDER BY ppoints.code;

SELECT cdb_crankshaft._cdb_random_seeds(1234);

SELECT ppoints2.code, m.quads
  FROM ppoints2
  JOIN cdb_crankshaft.cdb_moran_local_rate('ppoints2', 'numerator', 'denominator') m
    ON ppoints2.cartodb_id = m.ids
  ORDER BY ppoints2.code;
