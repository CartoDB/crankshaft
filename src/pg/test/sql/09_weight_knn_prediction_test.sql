\pset format unaligned
\set ECHO all
\i fixtures/knn_test.sql

select cdb_knnweightedaverage(cdb_latlng(0,0),array_agg(the_geom),array_agg(val),4) from knn_test;

select cdb_knnweightedaverage(cdb_latlng(0,0),array_agg(the_geom),array_agg(val),3) from knn_test;

select cdb_knnweightedaverage(cdb_latlng(0,0),array_agg(the_geom),array_agg(val),2) from knn_test;

select cdb_knnweightedaverage(cdb_latlng(0,0),array_agg(the_geom),array_agg(val),1) from knn_test;

select cdb_knnweightedaverage(cdb_latlng(0,0),array_agg(the_geom),array_agg(val),2) from knn_test;

select cdb_knnweightedaverage(cdb_latlng(1,0),array_agg(the_geom),array_agg(val),2) from knn_test;

select cdb_knnweightedaverage(cdb_latlng(-1,0),array_agg(the_geom),array_agg(val),2) from knn_test;

select cdb_knnweightedaverage(cdb_latlng(-1,1),array_agg(the_geom),array_agg(val),2) from knn_test;
