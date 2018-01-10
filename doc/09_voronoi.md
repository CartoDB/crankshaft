## Voronoi

Function to construct the [Voronoi Diagram](https://en.wikipedia.org/wiki/Voronoi_diagram) from a dataset of scatter points, clipped to the significant area

PostGIS wil include this in future versions ([doc for dev branch](http://postgis.net/docs/manual-dev/ST_Voronoi.html)) and will perform faster for sure, but in the meantime...


### CDB_Voronoi (geom geometry[], buffer numeric DEFAULT 0.5, tolerance numeric DEFAULT 1e-9)

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| geom   | geometry[]  | Array of points's geometries |
| buffer | numeric   | enlargment ratio for the envelope area used for the restraints|
| tolerance   | numeric |  Delaunay tolerance, optional |

### Returns

| Column Name | Type | Description |
|-------------|------|-------------|
| geom  | geometry collection | Collection of polygons of the Voronoi cells|


#### Example Usage

```sql
WITH a AS (
    SELECT
        ARRAY[
            ST_GeomFromText('POINT(2.1744 41.403)', 4326),
            ST_GeomFromText('POINT(2.1228 41.380)', 4326),
            ST_GeomFromText('POINT(2.1511 41.374)', 4326),
            ST_GeomFromText('POINT(2.1528 41.413)', 4326),
            ST_GeomFromText('POINT(2.165 41.391)', 4326),
            ST_GeomFromText('POINT(2.1498 41.371)', 4326),
            ST_GeomFromText('POINT(2.1533 41.368)', 4326),
            ST_GeomFromText('POINT(2.131386 41.41399)', 4326)
        ] AS geomin
)
SELECT
    ST_TRANSFORM(
        (ST_Dump(cdb_crankshaft.CDB_Voronoi(geomin, 0.2, 1e-9))).geom,
        3857) as the_geom_webmercator
FROM a;
```
