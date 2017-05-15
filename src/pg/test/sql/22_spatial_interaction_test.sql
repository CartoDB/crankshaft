SET client_min_messages TO WARNING;
\set ECHO none
\pset format unaligned

\i test/fixtures/spatial_interactions.sql

-- Gravity Model
\echo '--> gravity model'
SELECT
  a.cartodb_id,
  spint.predicted,
  a.flow_data,
  round((spint.coeffs->>'origin_i')::numeric, 4) As coeff_origin_i,
  round((spint.coeffs->>'destination_j')::numeric, 4) As coeff_destination_j,
  round((spint.coeffs->>'intercept')::numeric, 4) As coeff_intercept,
  round(spint.r_squared, 4) As r_squared,
  round(spint.aic, 4) as aic
FROM cdb_crankshaft.CDB_SpIntGravity('select * from austria_test',
  'flow_data',
  Array['origin_i'],
  Array['destination_j'],
  'dij') As spint
JOIN austria_test As a
on a.cartodb_id = spint.rowid
ORDER BY a.cartodb_id ASC
LIMIT 2;


-- Production-constrained
\echo '--> production-constrained'
SELECT
  a.cartodb_id,
  spint.predicted,
  a.flow_data,
  round((spint.coeffs->>'origin_4016')::numeric, 4) As coeff_origin_4016,
  round((spint.coeffs->>'destination_j')::numeric, 4) As coeff_destination_j,
  round((spint.coeffs->>'intercept')::numeric, 4) As coeff_intercept,
  round(spint.r_squared, 4) As r_squared,
  round(spint.aic, 4) as aic
FROM cdb_crankshaft.CDB_SpIntProduction('select * from austria_test',
  'flow_data',
  'origin_i',
  Array['destination_j'],
  'dij') As spint
JOIN austria_test As a
on a.cartodb_id = spint.rowid
ORDER BY a.cartodb_id ASC
LIMIT 2;


-- Attraction-constrained
\echo '--> attraction-constrained'
SELECT
  a.cartodb_id,
  -- spint.coeffs::text,
  spint.predicted,
  a.flow_data,
  round((spint.coeffs->>'dest_5790')::numeric, 4) As coeff_dest_at34,
  round((spint.coeffs->>'destination_j')::numeric, 4) As coeff_destination_j,
  round((spint.coeffs->>'intercept')::numeric, 4) As coeff_intercept,
  round((spint.coeffs->>'dij')::numeric, 4) As coeff_cost,
  round(spint.r_squared, 4) As r_squared,
  round(spint.aic, 4) as aic
FROM cdb_crankshaft.CDB_SpIntAttraction('select * from austria_test',
  'flow_data',
  'origin_i',
  Array['destination_j'],
  'dij') As spint
JOIN austria_test As a
on a.cartodb_id = spint.rowid
ORDER BY a.cartodb_id ASC
LIMIT 2;


-- Doubly-constrained
\echo '--> doubly-constrained'
SELECT
  a.cartodb_id,
  -- spint.coeffs::text,
  spint.predicted,
  a.flow_data,
  round((spint.coeffs->>'dest_25741')::numeric, 4) As coeff_dest_25741,
  round((spint.coeffs->>'origin_4897')::numeric, 4) As coeff_origin_4897,
  round((spint.coeffs->>'intercept')::numeric, 4) As coeff_intercept,
  round((spint.coeffs->>'dij')::numeric, 4) As coeff_cost,
  round(spint.r_squared, 4) As r_squared,
  round(spint.aic, 4) as aic
FROM cdb_crankshaft.CDB_SpIntDoubly('select * from austria_test',
  'flow_data',
  'origin_i',
  'destination_j',
  'dij') As spint
JOIN austria_test As a
on a.cartodb_id = spint.rowid
ORDER BY a.cartodb_id ASC
LIMIT 2;


-- Local Production-constrained
\echo '--> local gravity'
SELECT
  a.cartodb_id,
  a.flow_data,
  round((spint.coeffs->>'origin_i')::numeric, 4) As coeff_origin_i,
  round((spint.coeffs->>'destination_j')::numeric, 4) As coeff_destination_j,
  round((spint.coeffs->>'dij')::numeric, 4) As coeff_cost,
  round(spint.r_squared, 4) As r_squared,
  round(spint.aic, 4) as aic
FROM cdb_crankshaft.CDB_SpIntLocalGravity('select * from austria_test',
  'flow_data',
  Array['origin_i'],
  Array['destination_j'],
  'origin',
  'dij') As spint
JOIN austria_test As a
on a.cartodb_id = spint.rowid
ORDER BY a.cartodb_id ASC
LIMIT 10;


-- Local Production-constrained
\echo '--> local production-constrained'
SELECT
  a.cartodb_id,
  a.flow_data,
  round((spint.coeffs->>'destination_j')::numeric, 4) As coeff_destination_j,
  round((spint.coeffs->>'dij')::numeric, 4) As coeff_cost,
  round(spint.r_squared, 4) As r_squared,
  round(spint.aic, 4) as aic
FROM cdb_crankshaft.CDB_SpIntLocalProduction('select * from austria_test',
  'flow_data',
  'origin',
  Array['destination_j'],
  'dij') As spint
JOIN austria_test As a
on a.cartodb_id = spint.rowid
ORDER BY a.cartodb_id ASC
LIMIT 10;

-- Local Production-constrained
\echo '--> local attraction-constrained'
SELECT
  a.cartodb_id,
  a.flow_data,
  round((spint.coeffs->>'origin_i')::numeric, 4) As coeff_origin_i,
  round((spint.coeffs->>'dij')::numeric, 4) As coeff_cost,
  round(spint.r_squared, 4) As r_squared,
  round(spint.aic, 4) as aic
FROM cdb_crankshaft.CDB_SpIntLocalAttraction('select * from austria_test',
  'flow_data',
  'destination',
  Array['origin_i'],
  'dij') As spint
JOIN austria_test As a
on a.cartodb_id = spint.rowid
ORDER BY a.cartodb_id ASC
LIMIT 10;
