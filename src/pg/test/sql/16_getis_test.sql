\pset format unaligned
\set ECHO all
\i test/fixtures/getis_data.sql

-- set random seed
SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- test against PySAL example dataset
SELECT z_score, p_value
FROM cdb_crankshaft.CDB_GetisOrdsG(
  'select * from getis_data',
  'hr8893', 'knn', 5, 999,
  'the_geom', 'cartodb_id') As t(z_score, p_value, p_z_sim)
WHERE p_value <= 0.05;
