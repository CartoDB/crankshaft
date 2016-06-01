## Areas of Interest Functions



### CDB_AreasOfInterestLocal(subquery text, column_name text)

This function classifies your data as being part of a cluster, as an outlier, or or not part of a pattern based the significance of a classification. The classification happens through an autocorrelation statistic called Local Moran's I.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | TEXT | SQL query that exposes the data to be analyzed (e.g., `SELECT * FROM interesting_table`). This query must have the geometry column name `the_geom` and id column name `cartodb_id` unless otherwise specified in the input arguments |
| column_name | TEXT | Name of column (e.g., should `'interesting_value'` instead of `interesting_value` without single quotes) used for the analysis. |
| weight type (optional) | TEXT | Type of weight to use when finding neighbors. Currently available options are 'knn' (default) and 'queen'. Read more about weight types in [PySal's weights documentation](https://pysal.readthedocs.io/en/v1.11.0/users/tutorials/weights.html). |
| num_ngbrs (optional) | INT | Number of neighbors if using k-nearest neighbors weight type. Defaults to 5. |
| permutations (optional) | INT | Number of permutations to check against a random arrangement of the values in `column_name`. This influences the accuracy of the output field `significance`. Defaults to 99. |
| geom_col | TEXT | The column name for the geometries. Defaults to `'the_geom'` |
| id_col | TEXT | The column name for the unique ID of each geometry/value pair. Defaults to `'cartodb_id'`. |

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| moran       | NUMERIC | Value of Moran's I (spatial autocorrelation measure) for the geometry with id of `rowid` |
| quads       | TEXT | Classification of geometry. Result is one of 'HH' (a high value with neighbors high on average), 'LL' (opposite of 'HH'), 'HL' (a high value surrounded by lows on average), and 'LH' (opposite of 'HL'). Null values are returned when nulls exist in the original data. |
| significance | NUMERIC | The statistical significance (from 0 to 1) of a cluster or outlier classification. Lower numbers are more significant. |
| rowid | INT | Row id of the values which correspond to the input rows. |
| vals | NUMERIC | Values from `'column_name'`. |


#### Example Usage

```sql
SELECT
  c.the_geom,
  aoi.quads,
  aoi.significance,
  c.cyclists_per_total_population
FROM CDB_GetAreasOfInterestLocal('SELECT * FROM commute_data'
                                 'cyclists_per_total_population') As aoi
JOIN commute_data As c
ON c.cartodb_id = aoi.rowid;
```


```sql
table(numeric moran_val, text quadrant, numeric significance, int ids, numeric column_values) CDB_AreasOfInterest(text query, text column_name)

table(numeric moran_val, text quadrant, numeric significance, int ids, numeric column_values) CDB_AreasOfInterest(text query, text column_name, int permutations, text geom_column, text id_column, text weight_type, int num_ngbrs)
```

## Description

CDB_AreasOfInterest is a table-returning function that classifies the geometries in a table by an attribute and gives a significance for that classification. This information can be used to find "Areas of Interest" by using the correlation of a geometry's attribute with that of its neighbors. Areas can be clusters, outliers, or neither (depending on which significance value is used).

Inputs:

* `query` (required): an arbitrary query against tables you have access to (e.g., in your account, shared in your organization, or through the Data Observatory). This string must contain the following columns: an id `INT` (e.g., `cartodb_id`), geometry (e.g., `the_geom`), and the numeric attribute which is specified in `column_name`
* `column_name` (required): column to perform the area of interest analysis tool on. The data must be numeric (e.g., `float`, `int`, etc.)
* `permutations` (optional): used to calculate the significance of a classification. Defaults to 99, which is sufficient in most situations.
* `geom_column` (optional): the name of the geometry column. Data must be of type `geometry`.
* `id_column` (optional): the name of the id column (e.g., `cartodb_id`). Data must be of type `int` or `bigint` and have a unique condition on the data.
* `weight_type` (optional): the type of weight used for determining what defines a neighborhood. Options are `knn` or `queen`.
* `num_ngbrs` (optional): the number of neighbors in a neighborhood around a geometry. Only used if `knn` is chosen above.

Outputs:

* `moran_val`: underlying correlation statistic used in analysis
* `quadrant`: human-readable interpretation of classification
* `significance`: significance of classification (closer to 0 is more significant)
* `ids`: id of original geometry (used for joining against original table if desired -- see examples)
* `column_values`: original column values from `column_name`

Availability: crankshaft v0.0.1 and above

## Examples

```sql
SELECT
  t.the_geom_webmercator,
  t.cartodb_id,
  aoi.significance,
  aoi.quadrant As aoi_quadrant
FROM
  observatory.acs2013 As t
JOIN
  crankshaft.CDB_AreasOfInterest('SELECT * FROM observatory.acs2013',
                                 'gini_index')
```

## API Usage

Example

```text
http://eschbacher.cartodb.com/api/v2/sql?q=SELECT * FROM crankshaft.CDB_AreasOfInterest('SELECT * FROM observatory.acs2013','gini_index')
```

Result
```json
{
  time: 0.120,
  total_rows: 100,
  rows: [{
    moran_vals: 0.7213,
    quadrant: 'High area',
    significance: 0.03,
    ids: 1,
    column_value: 0.22
  },
  {
    moran_vals: -0.7213,
    quadrant: 'Low outlier',
    significance: 0.13,
    ids: 2,
    column_value: 0.03
  },
  ...
  ]
}
```

## See Also

crankshaft's areas of interest functions:

* [CDB_AreasOfInterest_Global]()
* [CDB_AreasOfInterest_Rate_Local]()
* [CDB_AreasOfInterest_Rate_Global]()

## Hotspot, Coldspot, and Outlier Functions
