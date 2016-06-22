\pset format unaligned
\set ECHO all
\i test/fixtures/ml_values.sql
SELECT cdb_crankshaft._cdb_random_seeds(1234);
SELECT prediction from cdb_crankshaft.CDB_CreateAndPredictSegment('select target,x1,x2,x3 from ml_values where class= $$train$$','target','select cartodb_id, target,x1,x2,x3 from ml_values where class=$$test$$') limit 20
