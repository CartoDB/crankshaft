\pset format unaligned
\set ECHO all
\i test/fixtures/spatial_lag_file.sql

-- Spatial Lag test

SELECT m.rowid, m.spatial_lag
  FROM spatial_lag_file
  JOIN cdb_crankshaft.CDB_SpatialLag('SELECT * FROM spatial_lag_file', 'value', 'knn',5, 'the_geom','cartodb_id') m
    ON spatial_lag_file.cartodb_id = m.rowid
  ORDER BY spatial_lag_file.cartodb_id;
