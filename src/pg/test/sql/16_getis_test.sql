\pset format unaligned
\set ECHO all
\i test/fixtures/getis_data.sql

-- set random seed
SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- test against PySAL example dataset 'stl_hom'
SELECT rowid, round(z_score, 4) As z_score, round(p_value, 4) As p_value
FROM cdb_crankshaft.CDB_GetisOrdsG(
  'select * from getis_data',
  'hr8893', 'queen', NULL, 999,
  'the_geom', 'cartodb_id') As t(z_score, p_value, p_z_sim, rowid)
WHERE round(p_value, 4) <= 0.05
ORDER BY rowid ASC;
