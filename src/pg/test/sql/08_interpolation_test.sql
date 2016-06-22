\pset format unaligned
\set ECHO all

WITH a AS (
    SELECT
    ARRAY[800, 700, 600, 500, 400, 300, 200, 100] AS vals,
    ARRAY[ST_GeomFromText('POINT(2.1744 41.403)'),ST_GeomFromText('POINT(2.1228 41.380)'),ST_GeomFromText('POINT(2.1511 41.374)'),ST_GeomFromText('POINT(2.1528 41.413)'),ST_GeomFromText('POINT(2.165 41.391)'),ST_GeomFromText('POINT(2.1498 41.371)'),ST_GeomFromText('POINT(2.1533 41.368)'),ST_GeomFromText('POINT(2.131386 41.41399)')] AS g
)
SELECT (cdb_crankshaft.CDB_SpatialInterpolation(g, vals, ST_GeomFromText('POINT(2.154 41.37)'), 1) - 780.79470198683925288365) / 780.79470198683925288365 < 0.001 FROM a;
