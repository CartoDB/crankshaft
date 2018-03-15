\pset format unaligned
\set ECHO none
\i test/fixtures/ml_values.sql
SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- second version (query, not specifying features)
WITH expected AS (
  SELECT
    generate_series(1000, 1020) AS id,
    unnest(ARRAY[4.5656517130822492,
                 1.7928053473230694,
                 1.0283378773916563,
                 2.6586517814904593,
                 2.9699056242935944,
                 3.9550646059951347,
                 4.1662572444459745,
                 3.8126334839264162,
                 1.8809821053623488,
                 1.6349065129019873,
                 3.0391288591472954,
                 3.3035970359672553,
                 1.5835471589451968,
                 3.7530378537263638,
                 1.0833589653009252,
                 3.8104965452882897,
                 2.665217959294802,
                 1.5850334252802472,
                 3.679401198805563,
                 3.5332033186588636 ]) AS expected
    LIMIT 20
), training as (
  SELECT
    array_agg(target)::numeric[] as target,
    cdb_crankshaft.CDB_PyAgg(Array[x1, x2, x3]::numeric[]) as features
  FROM (SELECT * FROM ml_values ORDER BY cartodb_id asc) as _w
  WHERE class = 'train'
), testing As (
  SELECT
    cdb_crankshaft.CDB_PyAgg(Array[x1, x2, x3]::numeric[]) as features,
    array_agg(cartodb_id)::numeric[] as cartodb_ids
  FROM (SELECT * FROM ml_values ORDER BY cartodb_id asc) as _w
  WHERE class = 'test'
), prediction AS (
  SELECT
    *
  FROM
    cdb_crankshaft.CDB_CreateAndPredictSegment(
        (SELECT target FROM training),
        (SELECT features FROM training),
        (SELECT features FROM testing),
        (SELECT cartodb_ids FROM testing)
      )
)
SELECT
  abs(e.expected - p.prediction) <= 1e-1 AS within_tolerance
FROM expected e, prediction p
WHERE e.id = p.cartodb_id
LIMIT 20;
SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- second version (query, not specifying features)
WITH expected AS (
  SELECT
    generate_series(1000, 1020) AS id,
    unnest(ARRAY[4.5656517130822492,
                 1.7928053473230694,
                 1.0283378773916563,
                 2.6586517814904593,
                 2.9699056242935944,
                 3.9550646059951347,
                 4.1662572444459745,
                 3.8126334839264162,
                 1.8809821053623488,
                 1.6349065129019873,
                 3.0391288591472954,
                 3.3035970359672553,
                 1.5835471589451968,
                 3.7530378537263638,
                 1.0833589653009252,
                 3.8104965452882897,
                 2.665217959294802,
                 1.5850334252802472,
                 3.679401198805563,
                 3.5332033186588636 ]) AS expected
    LIMIT 20
), prediction AS (
  SELECT
    cartodb_id::integer id,
    prediction
  FROM cdb_crankshaft.CDB_CreateAndPredictSegment(
    'SELECT target, x1, x2, x3 FROM ml_values WHERE class = $$train$$ ORDER BY cartodb_id asc',
    'target',
    'SELECT cartodb_id, x1, x2, x3 FROM ml_values WHERE class = $$test$$ ORDER BY cartodb_id asc'
  )
  LIMIT 20
)
SELECT
  abs(e.expected - p.prediction) <= 1e-1 AS within_tolerance
FROM expected e, prediction p
WHERE e.id = p.id;

SELECT cdb_crankshaft._cdb_random_seeds(1234);
-- third version (query, specifying features)
WITH expected AS (
  SELECT
    generate_series(1000, 1020) AS id,
    unnest(ARRAY[4.5656517130822492,
                 1.7928053473230694,
                 1.0283378773916563,
                 2.6586517814904593,
                 2.9699056242935944,
                 3.9550646059951347,
                 4.1662572444459745,
                 3.8126334839264162,
                 1.8809821053623488,
                 1.6349065129019873,
                 3.0391288591472954,
                 3.3035970359672553,
                 1.5835471589451968,
                 3.7530378537263638,
                 1.0833589653009252,
                 3.8104965452882897,
                 2.665217959294802,
                 1.5850334252802472,
                 3.679401198805563,
                 3.5332033186588636 ]) AS expected
    LIMIT 20
), prediction AS (
  SELECT
    cartodb_id::integer id,
    prediction
  FROM cdb_crankshaft.CDB_CreateAndPredictSegment(
    'SELECT target, x1, x2, x3 FROM ml_values WHERE class = $$train$$',
    'target',
    Array['x1', 'x2', 'x3'],
    'SELECT cartodb_id, x1, x2, x3 FROM ml_values WHERE class = $$test$$'
  )
  LIMIT 20
)
SELECT
  abs(e.expected - p.prediction) <= 1e-1 AS within_tolerance
FROM expected e, prediction p
WHERE e.id = p.id;
