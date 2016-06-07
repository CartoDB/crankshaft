\pset format unaligned
\set ECHO all

SELECT count(DISTINCT cluster_no) as clusters from cdb_crankshaft.cdb_kmeans('select * from ppoints', 2);

SELECT count(*) clusters from cdb_crankshaft.cdb_WeightedMean( 'select *, code::INTEGER as cluster from ppoints' , 'value', 'cluster' );
