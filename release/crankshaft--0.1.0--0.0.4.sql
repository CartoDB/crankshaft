--DO NOT MODIFY THIS FILE, IT IS GENERATED FROM SOURCES

-- Complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION crankshaft" to load this file. \quit

--------------------------------------------------------------------------------

-- Version number of the extension release
CREATE OR REPLACE FUNCTION cdb_crankshaft_version()
RETURNS text AS $$
  SELECT '0.0.4'::text;
$$ language 'sql' STABLE STRICT;

--------------------------------------------------------------------------------

-- PyAgg stuff
DROP FUNCTION CDB_PyAggS(Numeric[], Numeric[]);
DROP AGGREGATE CDB_PyAgg(NUMERIC[]);

--------------------------------------------------------------------------------

-- Segmentation stuff

DROP FUNCTION
  CDB_CreateAndPredictSegment(
    target NUMERIC[],
    features NUMERIC[],
    target_features NUMERIC[],
    target_ids NUMERIC[],
    n_estimators INTEGER DEFAULT 1200,
    max_depth INTEGER DEFAULT 3,
    subsample DOUBLE PRECISION DEFAULT 0.5,
    learning_rate DOUBLE PRECISION DEFAULT 0.01,
    min_samples_leaf INTEGER DEFAULT 1);

DROP FUNCTION
  CDB_CreateAndPredictSegment (
      query TEXT,
      variable_name TEXT,
      target_table TEXT,
      n_estimators INTEGER DEFAULT 1200,
      max_depth INTEGER DEFAULT 3,
      subsample DOUBLE PRECISION DEFAULT 0.5,
      learning_rate DOUBLE PRECISION DEFAULT 0.01,
      min_samples_leaf INTEGER DEFAULT 1);

--------------------------------------------------------------------------------

-- Spatial interpolation

DROP FUNCTION CDB_SpatialInterpolation(
    IN query text,
    IN point geometry,
    IN method integer DEFAULT 1,
    IN p1 numeric DEFAULT 0,
    IN p2 numeric DEFAULT 0
    );

DROP FUNCTION CDB_SpatialInterpolation(
    IN geomin geometry[],
    IN colin numeric[],
    IN point geometry,
    IN method integer DEFAULT 1,
    IN p1 numeric DEFAULT 0,
    IN p2 numeric DEFAULT 0
    );

--------------------------------------------------------------------------------

-- Spatial Markov

DROP FUNCTION
  CDB_SpatialMarkovTrend (
      subquery TEXT,
      time_cols TEXT[],
      num_classes INT DEFAULT 7,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
  	  permutations INT DEFAULT 99,
  	  geom_col TEXT DEFAULT 'the_geom',
  	  id_col TEXT DEFAULT 'cartodb_id');
