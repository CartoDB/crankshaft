\pset format unaligned
\set ECHO none
\i test/fixtures/ml_values.sql
SELECT cdb_crankshaft._cdb_random_seeds(1234);
SELECT prediction FROM cdb_crankshaft.CDB_CreateAndPredictSegment('SELECT target, x1, x2, x3 FROM ml_values WHERE class = $$train$$','target','SELECT cartodb_id, target, x1, x2, x3 FROM ml_values WHERE class = $$test$$') LIMIT 20;
