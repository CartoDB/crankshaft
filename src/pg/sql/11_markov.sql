-- Spatial Markov

-- input table format:
-- id | geom | date_1 | date_2 | date_3
--  1 | Pt1  | 12.3   | 13.1   | 14.2
--  2 | Pt2  | 11.0   | 13.2   | 12.5
--  ...
-- Sample Function call:
-- SELECT CDB_SpatialMarkov('SELECT * FROM real_estate',
--                          Array['date_1', 'date_2', 'date_3'])

CREATE OR REPLACE FUNCTION
  CDB_SpatialMarkovTrend (
      subquery TEXT,
      time_cols TEXT[],
      num_classes INT DEFAULT 7,
      w_type TEXT DEFAULT 'knn',
      num_ngbrs INT DEFAULT 5,
  	  permutations INT DEFAULT 99,
  	  geom_col TEXT DEFAULT 'the_geom',
  	  id_col TEXT DEFAULT 'cartodb_id')
RETURNS TABLE (trend NUMERIC, trend_up NUMERIC, trend_down NUMERIC, volatility NUMERIC, rowid INT)
AS $$

  from crankshaft.space_time_dynamics import Markov
  markov = Markov()

  ## TODO: use named parameters or a dictionary
  return markov.spatial_trend(subquery, time_cols, num_classes, w_type, num_ngbrs, permutations, geom_col, id_col)
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;

-- input table format: identical to above but in a predictable format
-- Sample function call:
-- SELECT cdb_spatial_markov('SELECT * FROM real_estate',
--                           'date_1')


-- CREATE OR REPLACE FUNCTION
--   cdb_spatial_markov (
--       subquery TEXT,
--       time_col_min text,
--       time_col_max text,
--       date_format text, -- '_YYYY_MM_DD'
--       num_time_per_bin INT DEFAULT 1,
--   	  permutations INT DEFAULT 99,
--   	  geom_column TEXT DEFAULT 'the_geom',
--   	  id_col TEXT DEFAULT 'cartodb_id',
--       w_type TEXT DEFAULT 'knn',
--       num_ngbrs int DEFAULT 5)
-- RETURNS TABLE (moran FLOAT, quads TEXT, significance FLOAT, ids INT)
-- AS $$
--   plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
--   from crankshaft.clustering import moran_local
--   # TODO: use named parameters or a dictionary
--   return spatial_markov(subquery, time_cols, permutations, geom_column, id_col, w_type, num_ngbrs)
-- $$ LANGUAGE plpythonu;
--
-- -- input table format:
-- -- id | geom | date  | measurement
-- --  1 | Pt1  | 12/3  | 13.2
-- --  2 | Pt2  | 11/5  | 11.3
-- --  3 | Pt1  | 11/13 | 12.9
-- --  4 | Pt3  | 12/19 | 10.1
-- -- ...
--
-- CREATE OR REPLACE FUNCTION
--   cdb_spatial_markov (
--       subquery TEXT,
--       time_col text,
--       num_time_per_bin INT DEFAULT 1,
--   	  permutations INT DEFAULT 99,
--   	  geom_column TEXT DEFAULT 'the_geom',
--   	  id_col TEXT DEFAULT 'cartodb_id',
--       w_type TEXT DEFAULT 'knn',
--       num_ngbrs int DEFAULT 5)
-- RETURNS TABLE (moran FLOAT, quads TEXT, significance FLOAT, ids INT)
-- AS $$
--   plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
--   from crankshaft.clustering import moran_local
--   # TODO: use named parameters or a dictionary
--   return spatial_markov(subquery, time_cols, permutations, geom_column, id_col, w_type, num_ngbrs)
-- $$ LANGUAGE plpythonu;
