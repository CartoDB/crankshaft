## TINMAP function

Generates a fake contour map, in the form of a TIN map, from a set of scattered points.Depends on **CDB_Densify**.

Its iterative nature lets the user smooth the final result as much as desired, but with a exponential time cost increase.

### CDB_TINmap(geomin geometry[], colin numeric[], iterations integer)

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| geomin   | geometry[]  | Array of points geometries |
| colin | numeric[]   | Array of points' values |
| iterations   | integer     | Number of iterations |

### Returns

Returns a table object

| Name | Type | Description |
|------|------|-------------|
| geomout   | geometry  | Geometries of new dataset of polygons|
| colout | numeric   | Values of each cell|

#### Example Usage

```sql
WITH data as (
    SELECT
        ARRAY[7.0,8.0,1.0,2.0,3.0,5.0,6.0,4.0] as colin,
        ARRAY[ST_GeomFromText('POINT(2.1744 41.4036)'),
			ST_GeomFromText('POINT(2.1228 41.3809)'),
			ST_GeomFromText('POINT(2.1511 41.3742)'),
			ST_GeomFromText('POINT(2.1528 41.4136)'),
			ST_GeomFromText('POINT(2.165 41.3917)'),
			ST_GeomFromText('POINT(2.1498 41.3713)'),
			ST_GeomFromText('POINT(2.1533 41.3683)'),
			ST_GeomFromText('POINT(2.131386 41.413998)')] as geomin
)
SELECT cdb_crankshaft.CDB_TINmap(geomin, colin, 2)
FROM data
```

