## Contour maps

Function to generate a contour map from an scatter dataset of points, using one of three methos:

* [Nearest neighbor](https://en.wikipedia.org/wiki/Nearest-neighbor_interpolation)
* [Barycentric](https://en.wikipedia.org/wiki/Barycentric_coordinate_system)
* [IDW](https://en.wikipedia.org/wiki/Inverse_distance_weighting)

### CDB_Contour (geom geometry[], values numeric[], resolution integer, buffer numeric, method, classmethod integer, steps integer)

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| geom   | geometry[]  | Array of points's geometries |
| values | numeric[]   | Array of points' values for the param under study|
| resolution   | integer     | Size in meters of the cells in the grid|
| buffer   | numeric     | Value between 0 and 1 for spatial buffer of the set of points
| method   | integer     | 0:nearest neighbor, 1: barycentric, 2: IDW|
| classmethod   | integer     | 0:equals, 1: heads&tails, 2:jenks, 3:quantiles |
| steps   | integer     | Number of steps in the classification|

### Returns
Returns a table object

| Name | Type | Description |
|------|------|-------------|
| the_geom   | geometry  | Geometries of the classified contour map|
| avg_value | numeric   | Avg value of the area|
| min_value | numeric   | Min value of the area|
| max_value | numeric   | Max value of the areal|
| bin | integer   | Index of the class of the area|

#### Example Usage

```sql
WITH a AS (
    SELECT
    ARRAY[800, 700, 600, 500, 400, 300, 200, 100]::numeric[] AS vals,
    ARRAY[ST_GeomFromText('POINT(2.1744 41.403)'),ST_GeomFromText('POINT(2.1228 41.380)'),ST_GeomFromText('POINT(2.1511 41.374)'),ST_GeomFromText('POINT(2.1528 41.413)'),ST_GeomFromText('POINT(2.165 41.391)'),ST_GeomFromText('POINT(2.1498 41.371)'),ST_GeomFromText('POINT(2.1533 41.368)'),ST_GeomFromText('POINT(2.131386 41.41399)')] AS g
)
SELECT
    foo.*
FROM
    a,
    CDB_contour(a.g, a.vals, 500, 0.0, 1,3,5) foo;
```
