-- test table (polygons, some of which touch and some which dont)
CREATE TABLE touching_polygons(cartodb_id integer, the_geom geometry);
INSERT INTO  touching_polygons VALUES
(1, ST_GeomFromText('POLYGON ((0 0, 1 0,1 1, 0 1, 0 0 ))')),
(2, ST_GeomFromText('POLYGON ((1 0, 2 0, 2 1, 1 1, 1 0))')),
(1, ST_GeomFromText('POLYGON ((0 1, 1 1,1 2, 0 2, 0 1 ))')),
(4, ST_GeomFromText('POLYGON ((3 0, 4 0, 4 1, 3 1, 3 0))')),
(5, ST_GeomFromText('POLYGON ((3 1, 4 1, 4 2, 3 2, 3 1))'));