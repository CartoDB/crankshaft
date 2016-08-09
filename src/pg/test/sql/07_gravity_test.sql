WITH t AS (
    SELECT
    ARRAY[1,2,3] AS id,
    ARRAY[7.0,8.0,3.0] AS w,
    ARRAY[ST_GeomFromText('POINT(2.1744 41.4036)'),ST_GeomFromText('POINT(2.1228 41.3809)'),ST_GeomFromText('POINT(2.1511 41.3742)')] AS g
),
s AS (
    SELECT
    ARRAY[10,20,30,40,50,60,70,80] AS id,
    ARRAY[800, 700, 600, 500, 400, 300, 200, 100] AS p,
    ARRAY[ST_GeomFromText('POINT(2.1744 41.403)'),ST_GeomFromText('POINT(2.1228 41.380)'),ST_GeomFromText('POINT(2.1511 41.374)'),ST_GeomFromText('POINT(2.1528 41.413)'),ST_GeomFromText('POINT(2.165 41.391)'),ST_GeomFromText('POINT(2.1498 41.371)'),ST_GeomFromText('POINT(2.1533 41.368)'),ST_GeomFromText('POINT(2.131386 41.41399)')] AS g
)
SELECT
    g.the_geom,
    g.h,
    g.hpop,
    g.dist
FROM
    t,
    s,
    crankshaft.CDB_Gravity(t.id, t.g, t.w, s.id, s.g, s.p, 2, 100000, 3) g;
