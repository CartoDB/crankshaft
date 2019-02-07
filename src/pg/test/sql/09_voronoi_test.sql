\pset format unaligned
\set ECHO none

WITH a AS (
    SELECT
    ARRAY[ST_GeomFromText('POINT(2.1744 41.403)', 4326),ST_GeomFromText('POINT(2.1228 41.380)', 4326),ST_GeomFromText('POINT(2.1511 41.374)', 4326),ST_GeomFromText('POINT(2.1528 41.413)', 4326),ST_GeomFromText('POINT(2.165 41.391)', 4326),ST_GeomFromText('POINT(2.1498 41.371)', 4326),ST_GeomFromText('POINT(2.1533 41.368)', 4326),ST_GeomFromText('POINT(2.131386 41.41399)', 4326)] AS geomin
),
b as(
    SELECT
        (st_dump(cdb_crankshaft.CDB_voronoi(geomin, 0.2, 1e-9))).geom as result
    FROM a
)
SELECT
    abs(avg(st_area(result)) - 0.000178661700690617) < 1e-6 as within_tolerance
FROM b;
