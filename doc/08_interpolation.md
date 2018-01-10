## Spacial interpolation

Function to interpolate a numeric attribute of a point in a scatter dataset of points, using one of three methos:

* [Nearest neighbor(s)](https://en.wikipedia.org/wiki/Nearest-neighbor_interpolation)
* [Barycentric](https://en.wikipedia.org/wiki/Barycentric_coordinate_system)
* [IDW](https://en.wikipedia.org/wiki/Inverse_distance_weighting)

### CDB_SpatialInterpolation (query text, point geometry, method integer DEFAULT 1, p1 integer DEFAULT 0, ps integer DEFAULT 0)

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| query   | text | query that returns at least `the_geom` and a numeric value as `attrib` |
| point   | geometry | The target point to calc the value |
| method   | integer     | 0:nearest neighbor, 1: barycentric, 2: IDW|
| p1   | integer     | limit the number of neighbors, IDW: 0->no limit, NN: 0-> closest one|
| p2   | integer     | IDW: order of distance decay, 0-> order 1|

### CDB_SpatialInterpolation (geom geometry[], values numeric[], point geometry, method integer DEFAULT 1, p1 integer DEFAULT 0, ps integer DEFAULT 0)

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| geom   | geometry[]  | Array of points's geometries |
| values | numeric[]   | Array of points' values for the param under study|
| point   | geometry | The target point to calc the value |
| method   | integer     | 0:nearest neighbor, 1: barycentric, 2: IDW|
| p1   | integer     | limit the number of neighbors, IDW: 0->no limit, NN: 0-> closest one|
| p2   | integer     | IDW: order of distance decay, 0-> order 1|

### Returns

| Column Name | Type | Description |
|-------------|------|-------------|
| value  | numeric | Interpolated value at the given point, `-888.888` if the given point is out of the boundaries of the source points set |

Default values:
* -888.888: when using Barycentric, the target point is out of the realm of the input points
* -777.777: asking for a method not available

#### Example Usage

```sql
WITH a as (
    SELECT
        array_agg(the_geom) as geomin,
        array_agg(temp::numeric) as colin
    FROM table_4804232032
)
SELECT
    cdb_crankshaft.CDB_SpatialInterpolation(
        geomin,
        colin,
        CDB_latlng(41.38, 2.15),
        1)
FROM
    a
```
