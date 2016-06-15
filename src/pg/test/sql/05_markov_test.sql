SET client_min_messages TO WARNING;
\set ECHO none
\pset format unaligned
\i test/fixtures/markov_usjoin_example.sql

-- Areas of Interest functions perform some nondeterministic computations
-- (to estimate the significance); we will set the seeds for the RNGs
-- that affect those results to have repeatable results
SELECT cdb_crankshaft._cdb_random_seeds(1234);

SELECT
  m1.cartodb_id,
  CASE WHEN m1.cartodb_id = 1 THEN (m2.trend - 0.0714285714286) / 0.0714285714286 < 0.01
       WHEN m1.cartodb_id = 2 THEN (m2.trend - 0.222222222222) / 0.222222222222  < 0.01
       WHEN m1.cartodb_id = 3 THEN (m2.trend - 0.0526315789474) / 0.0526315789474  < 0.01
       ELSE NULL END As trend_test,
  CASE WHEN m1.cartodb_id = 1 THEN (m2.trend_up - 0.0666666666667) / 0.0666666666667  < 0.01
       WHEN m1.cartodb_id = 2 THEN (m2.trend_up - 0.181818181818) / 0.181818181818  < 0.01
       WHEN m1.cartodb_id = 3 THEN (m2.trend_up - 0.05) / 0.05  < 0.01
       ELSE NULL END As trend_up_test,
  CASE WHEN m1.cartodb_id = 1 THEN m2.trend_down = 0.0
       WHEN m1.cartodb_id = 2 THEN m2.trend_down = 0.0
       WHEN m1.cartodb_id = 3 THEN m2.trend_down = 0.0
       ELSE NULL END As trend_down_test,
  CASE WHEN m1.cartodb_id = 1 THEN (m2.volatility - 0.367574633389) / 0.367574633389  < 0.1
       WHEN m1.cartodb_id = 2 THEN (m2.volatility - 0.317010832258) / 0.317010832258  < 0.1
       WHEN m1.cartodb_id = 3 THEN (m2.volatility - 0.37549966711) / 0.37549966711  < 0.1
       ELSE NULL END As volatility_test
  FROM markov_usjoin_example As m1
  JOIN cdb_crankshaft.CDB_SpatialMarkovTrend('SELECT * FROM markov_usjoin_example ORDER BY cartodb_id DESC', Array['y1995', 'y1996', 'y1997', 'y1998', 'y1999', 'y2000', 'y2001', 'y2002', 'y2003', 'y2004', 'y2005', 'y2006', 'y2007', 'y2008', 'y2009']::text[], 5::int, 'knn'::text, 5::int, 0::int, 'the_geom'::text, 'cartodb_id'::text) As m2
    ON m1.cartodb_id = m2.rowid
ORDER BY m1.cartodb_id
LIMIT 3;
