\i test/fixtures/ppoints.sql

-- Moral functions perform some nondeterministic computations
-- (to estimate the significance); we will set the seeds for the RNGs
-- that affect those results to have repeateble results
SELECT cdb_crankshaft.cdb_random_seeds(1234);

SELECT ppoints.code, m.quads
  FROM ppoints
  JOIN cdb_crankshaft.cdb_moran_local('ppoints', 'value') m
    ON ppoints.cartodb_id = m.ids
  ORDER BY ppoints.code;
