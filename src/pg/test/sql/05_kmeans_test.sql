\pset format unaligned
\set ECHO all

SELECT count(DISTINCT cluster_no) as clusters from cdb_crankshaft.cdb_kmeans('select * from ppoints', 2);

SELECT count(*) clusters from (select  cdb_crankshaft.CDB_WeightedMean(the_geom, value::NUMERIC), code from ppoints group by code) p;
