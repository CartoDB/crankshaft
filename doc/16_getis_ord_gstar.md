## Getis-Ord's G\*

Getis-Ord's G\* is a geo-statistical measurement of the intensity of clustering of high or low values. The clustering of high values can be referred to as "hotspots" because these are areas of high activity or large (relative to the global mean) measurement values. Coldspots are clustered areas with low activity or small measurement values.

### CDB_GetisOrdsG(subquery text, column_name text)

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | text | A query of the data you want to pass to the function. It must include `column_name`, a geometry column (usually `the_geom`) and an id column (usually `cartodb_id`) |
| column_name | text | This is the column of interest for performing this analysis on. This column should be a numeric type. |
| w_type (optional) | text | Type of weight to use when finding neighbors. Currently available options are 'knn' (default) and 'queen'. Read more about weight types in [PySAL's weights documentation.](https://pysal.readthedocs.io/en/v1.11.0/users/tutorials/weights.html) |
| num_ngbrs (optional) | integer | Default: 5. If `knn` is chosen, this will set the number of neighbors. If `knn` is not chosen, any entered value will be ignored. Use `NULL` if not choosing `knn`. |
| permutations (optional) | integer | The number of permutations for calculating p-values. Default: 999 |
| geom_col (optional) | text | The column where the geometry information is stored. The format must be PostGIS Geometry type (SRID 4326). Default: `the_geom`. |
| id_col (optional) | text | The column that has the unique row identifier. |

### Returns

Returns a table with the following columns.

| Name | Type | Description |
|------|------|-------------|
| z_score | numeric | z-score, a measure of the intensity of clustering of high values (hotspots) or low values (coldspots). Positive values represent 'hotspots', while negative values represent 'coldspots'. |
| p_value | numeric  | p-value, a measure of the significance of the intensity of clustering |
| p_z_sim | numeric | p-value based on standard normal approximation from permutations |
| rowid | integer | The original `id_col` that can be used to associate the outputs with the original geometry and inputs |

#### Example Usage

The following query returns the original table augmented with the values calculated from the Getis-Ord's G\* analysis.

```sql
SELECT i.*, m.z_score, m.p_value
  FROM cdb_crankshaft.CDB_GetisOrdsG('SELECT * FROM incident_reports_clustered',
                                     'num_incidents') As m
  JOIN incident_reports_clustered As i
    ON i.cartodb_id = m.rowid;
```
