--DO NOT MODIFY THIS FILE, IT IS GENERATED FROM SOURCES

-- Complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION crankshaft" to load this file. \quit

-- Version number of the extension release
CREATE OR REPLACE FUNCTION cdb_crankshaft_version()
RETURNS text AS $$
  SELECT '0.0.4'::text;
$$ language 'sql' STABLE STRICT;

--------------------------------------------------------------------------------

-- Spatial Markov

DROP FUNCTION
  CDB_SpatialMarkovTrend (
      subquery TEXT,
      time_cols TEXT[],
      num_classes INT,
      w_type TEXT,
      num_ngbrs INT,
  	  permutations INT,
  	  geom_col TEXT,
  	  id_col TEXT);


--------------------------------------------------------------------------------

-- Spatial interpolation

DROP FUNCTION CDB_SpatialInterpolation(
    IN geomin geometry[],
    IN colin numeric[],
    IN point geometry,
    IN method integer,
    IN p1 numeric,
    IN p2 numeric
    );

DROP FUNCTION CDB_SpatialInterpolation(
    IN query text,
    IN point geometry,
    IN method integer,
    IN p1 numeric,
    IN p2 numeric
    );

--------------------------------------------------------------------------------

-- Segmentation stuff

DROP FUNCTION
  CDB_CreateAndPredictSegment (
      query TEXT,
      variable_name TEXT,
      target_table TEXT,
      n_estimators INTEGER,
      max_depth INTEGER,
      subsample DOUBLE PRECISION,
      learning_rate DOUBLE PRECISION,
      min_samples_leaf INTEGER);

DROP FUNCTION
  CDB_CreateAndPredictSegment(
    target NUMERIC[],
    features NUMERIC[],
    target_features NUMERIC[],
    target_ids NUMERIC[],
    n_estimators INTEGER,
    max_depth INTEGER,
    subsample DOUBLE PRECISION,
    learning_rate DOUBLE PRECISION,
    min_samples_leaf INTEGER);

--------------------------------------------------------------------------------

-- PyAgg stuff

DROP AGGREGATE CDB_PyAgg(NUMERIC[]);
DROP FUNCTION CDB_PyAggS(Numeric[], Numeric[]);