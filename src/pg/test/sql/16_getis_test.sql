\pset format unaligned
\set ECHO all
\i test/fixtures/getis_data.sql

-- set random seed
SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- test against PySAL example dataset
SELECT z_score, p_val
FROM cdb_crankshaft.CDB_GetisOrdsG(
  'select * from ppoints2',
  'ratio') As cdb_getisordsg(z_score, p_val, p_z_sim)
WHERE p_val <= 0.05;
