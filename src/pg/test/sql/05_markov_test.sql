SET client_min_messages TO WARNING;
\set ECHO none
\pset format unaligned
\i test/fixtures/markov_usjoin_example.sql

-- Areas of Interest functions perform some nondeterministic computations
-- (to estimate the significance); we will set the seeds for the RNGs
-- that affect those results to have repeatable results
SELECT cdb_crankshaft._cdb_random_seeds(1234);

SELECT m1.cartodb_id, m2.trend, m2.trend_up, m2.trend_down, m2.volatility
  FROM markov_usjoin_example As m1
  JOIN cdb_crankshaft.CDB_SpatialMarkov('SELECT * FROM markov_usjoin_example', Array['y1995', 'y1996', 'y1997', 'y1998', 'y1999', 'y2000', 'y2001', 'y2002', 'y2003', 'y2004', 'y2005', 'y2006', 'y2007', 'y2008', 'y2009']::text[], 5, 'knn', 5, 0, 'the_geom', 'cartodb_id') As m2
    ON m1.cartodb_id = m2.rowid
  ORDER BY m1.cartodb_id;
