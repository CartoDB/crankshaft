## Spacial interpolation

Function to construct the [Voronoi Diagram](https://en.wikipedia.org/wiki/Voronoi_diagram) from a dataset of scatter points, clipped to the significant area

PostGIS wil include this in future versions ([doc for dev branch](http://postgis.net/docs/manual-dev/ST_Voronoi.html)) and will perform faster for sure, but in the meantime...


### CDB_Voronoi (geom geometry[], buffer numeric DEFAULT 0.5, tolerance numeric DEFAULT 1e-9)

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| geom   | geometry[]  | Array of points's geometries |
| buffer | numeric   | enlargment ratio for the envelope area used for the restraints|
| tolerance   | geometry | The target point to calc the value |

### Returns

| Column Name | Type | Description |
|-------------|------|-------------|
| geom  | geometry collection | Collection of polygons of the Voronoi cells|


#### Example Usage

```sql
WITH a AS (
    SELECT
    ARRAY[ST_GeomFromText('POINT(2.1744 41.403)'),ST_GeomFromText('POINT(2.1228 41.380)'),ST_GeomFromText('POINT(2.1511 41.374)'),ST_GeomFromText('POINT(2.1528 41.413)'),ST_GeomFromText('POINT(2.165 41.391)'),ST_GeomFromText('POINT(2.1498 41.371)'),ST_GeomFromText('POINT(2.1533 41.368)'),ST_GeomFromText('POINT(2.131386 41.41399)')] AS geomin
)
SELECT
    CDB_voronoi(geomin, 0.2, 1e-9) as result
FROM a;
```
