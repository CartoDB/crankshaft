SET client_min_messages TO WARNING;
\set ECHO none
\pset format unaligned

WITH a AS (
    SELECT
    ARRAY[800, 700, 600, 500, 400, 300, 200, 100]::numeric[] AS vals,
    ARRAY[ST_GeomFromText('POINT(2.1744 41.403)',4326),ST_GeomFromText('POINT(2.1228 41.380)',4326),ST_GeomFromText('POINT(2.1511 41.374)',4326),ST_GeomFromText('POINT(2.1528 41.413)',4326),ST_GeomFromText('POINT(2.165 41.391)',4326),ST_GeomFromText('POINT(2.1498 41.371)',4326),ST_GeomFromText('POINT(2.1533 41.368)',4326),ST_GeomFromText('POINT(2.131386 41.41399)',4326)] AS g
),
b as(
SELECT
    foo.*
FROM
    a,
    cdb_crankshaft.CDB_contour(a.g, a.vals, 500, 0.0, 1, 3, 5) foo
)
SELECT bin, avg_value from b order by bin;
