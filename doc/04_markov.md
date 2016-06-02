## Spatial Markov

### CDB_SpatialMarkov(subquery text, column_names text array)

This function takes time series data associated with geometries and outputs likelihoods that the next value of a geometry will move up, down, or stay static as compared to the most recent measurement. For more information, read about [Spatial Dynamics in PySAL](https://pysal.readthedocs.io/en/v1.11.0/users/tutorials/dynamics.html).

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | TEXT | SQL query that exposes the data to be analyzed (e.g., `SELECT * FROM real_estate_history`). This query must have the geometry column name `the_geom` and id column name `cartodb_id` unless otherwise specified in the input arguments |
| column_names | TEXT Array | Names of column that form the history of measurements for the geometries (e.g., `Array['y2011', 'y2012', 'y2013', 'y2014', 'y2015', 'y2016']`). |
| num_classes (optional) | INT | Number of quantile classes to separate data into. |
| weight type (optional) | TEXT | Type of weight to use when finding neighbors. Currently available options are 'knn' (default) and 'queen'. Read more about weight types in [PySAL's weights documentation](https://pysal.readthedocs.io/en/v1.11.0/users/tutorials/weights.html). |
| num_ngbrs (optional) | INT | Number of neighbors if using k-nearest neighbors weight type. Defaults to 5. |
| permutations (optional) | INT | Number of permutations to check against a random arrangement of the values in `column_name`. This influences the accuracy of the output field `significance`. Defaults to 99. |
| geom_col (optional) | TEXT | The column name for the geometries. Defaults to `'the_geom'` |
| id_col (optional) | TEXT | The column name for the unique ID of each geometry/value pair. Defaults to `'cartodb_id'`. |

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| trend | NUMERIC |  |
| trend_up | NUMERIC |  |
| trend_down | NUMERIC | The statistical significance (from 0 to 1) of a cluster or outlier classification. Lower numbers are more significant. |
| volatility | NUMERIC | A measure of the variance of the probabilities returned from the Spatial Markov predictions |
| rowid | NUMERIC | id of the row that corresponds to the `id_col` (by default `cartodb_id` of the input rows)  |


#### Example Usage

```sql
SELECT
  c.the_geom,
  m.trend,
  m.trend_up,
  m.trend_down,
  m.volatility
FROM CDB_SpatialMarkov('SELECT * FROM nyc_real_estate'
                       Array['m03y2009','m03y2010','m03y2011','m03y2012','m03y2013','m03y2014','m03y2015','m03y2016']) As m
JOIN nyc_real_estate As c
ON c.cartodb_id = m.rowid;
```
