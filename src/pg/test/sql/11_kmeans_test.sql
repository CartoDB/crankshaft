\pset format unaligned
\set ECHO all

-- spatial kmeans
SELECT
    count(DISTINCT cluster_no) as clusters
FROM
    cdb_crankshaft.cdb_kmeans('select * from ppoints', 2);

-- weighted mean
SELECT
    count(*) clusters
FROM (
    SELECT
        cdb_crankshaft.CDB_WeightedMean(the_geom, value::NUMERIC),
        code
    FROM ppoints
    GROUP BY code
) p;

-- nonspatial kmeans
SELECT
    cluster_label,
    cluster_center,
    silhouettes,
    inertia,
    rowid
FROM cdb_crankshaft.CDB_KMeansNonspatial(
    'SELECT unnest(Array[1, 1, 10, 10]) As col1, unnest(Array[100, 100, 2, 2]) As col2 FROM ppoints',
    Array['col1', 'col2']::text[],
    2);
