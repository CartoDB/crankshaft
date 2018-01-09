## Areas of Interest Functions

A family of analyses to uncover groupings of areas with consistently high or low values (clusters) and smaller areas with values unlike those around them (outliers). A cluster is labeled by an 'HH' (high value compared to the entire dataset in an area with other high values), or its opposite 'LL'. An outlier is labeled by an 'LH' (low value surrounded by high values) or an 'HL' (the opposite). Each cluster and outlier classification has an associated p-value, a measure of how significant the pattern of highs and lows is compared to a random distribution.

These functions have two forms: local and global. The local versions classify every input geometry while the global function gives a rating of the overall clustering characteristics of the dataset. Both forms accept an optional denomiator (see the rate versions) if, for example, working with count data and a denominator is needed.

### Notes

*   Rows with null values will be omitted from this analysis. To ensure they are added to the analysis, fill the null-valued cells with an appropriate value such as the mean of a column, the mean of the most recent two time steps, or use a `LEFT JOIN` to get null outputs from the analysis.
*   Input query can only accept tables (datasets) in the users database account. Common table expressions (CTEs) do not work as an input unless specified within the `subquery` argument.

### CDB_AreasOfInterestLocal(subquery text, column_name text)

This function classifies your data as being part of a cluster, as an outlier, or not part of a pattern based the significance of a classification. The classification happens through an autocorrelation statistic called Local Moran's I.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | TEXT | SQL query that exposes the data to be analyzed (e.g., `SELECT * FROM interesting_table`). This query must have the geometry column name `the_geom` and id column name `cartodb_id` unless otherwise specified in the input arguments |
| column_name | TEXT | Name of column (e.g., should be `'interesting_value'` instead of `interesting_value` without single quotes) used for the analysis. |
| weight type (optional) | TEXT | Type of weight to use when finding neighbors. Currently available options are 'knn' (default) and 'queen'. Read more about weight types in [PySAL's weights documentation](https://pysal.readthedocs.io/en/v1.11.0/users/tutorials/weights.html). |
| num_ngbrs (optional) | INT | Number of neighbors if using k-nearest neighbors weight type. Defaults to 5. |
| permutations (optional) | INT | Number of permutations to check against a random arrangement of the values in `column_name`. This influences the accuracy of the output field `significance`. Defaults to 99. |
| geom_col (optional) | TEXT | The column name for the geometries. Defaults to `'the_geom'` |
| id_col (optional) | TEXT | The column name for the unique ID of each geometry/value pair. Defaults to `'cartodb_id'`. |

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| moran | NUMERIC | Value of Moran's I (spatial autocorrelation measure) for the geometry with id of `rowid` |
| quads | TEXT | Classification of geometry. Result is one of 'HH' (a high value with neighbors high on average), 'LL' (opposite of 'HH'), 'HL' (a high value surrounded by lows on average), and 'LH' (opposite of 'HL'). Null values are returned when nulls exist in the original data. |
| significance | NUMERIC | The statistical significance (from 0 to 1) of a cluster or outlier classification. Lower numbers are more significant. |
| rowid | INT | Row id of the values which correspond to the input rows. |
| vals | NUMERIC | Values from `'column_name'`. |



#### Example Usage

```sql
SELECT
  c.the_geom,
  aoi.quads,
  aoi.significance,
  c.num_cyclists_per_total_population
FROM
  cdb_crankshaft.CDB_AreasOfInterestLocal(
    'SELECT * FROM commute_data'
    'num_cyclists_per_total_population') As aoi
JOIN commute_data As c
ON c.cartodb_id = aoi.rowid;
```

### CDB_AreasOfInterestGlobal(subquery text, column_name text)

This function identifies the extent to which geometries cluster (the groupings of geometries with similarly high or low values relative to the mean) or form outliers (areas where geometries have values opposite of their neighbors). The output of this function gives values between -1 and 1 as well as a significance of that classification. Values close to 0 mean that there is little to no distribution of values as compared to what one would see in a randomly distributed collection of geometries and values.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | TEXT | SQL query that exposes the data to be analyzed (e.g., `SELECT * FROM interesting_table`). This query must have the geometry column name `the_geom` and id column name `cartodb_id` unless otherwise specified in the input arguments |
| column_name | TEXT | Name of column (e.g., should be `'interesting_value'` instead of `interesting_value` without single quotes) used for the analysis. |
| weight type (optional) | TEXT | Type of weight to use when finding neighbors. Currently available options are 'knn' (default) and 'queen'. Read more about weight types in [PySAL's weights documentation](https://pysal.readthedocs.io/en/v1.11.0/users/tutorials/weights.html). |
| num_ngbrs (optional) | INT | Number of neighbors if using k-nearest neighbors weight type. Defaults to 5. |
| permutations (optional) | INT | Number of permutations to check against a random arrangement of the values in `column_name`. This influences the accuracy of the output field `significance`. Defaults to 99. |
| geom_col (optional) | TEXT | The column name for the geometries. Defaults to `'the_geom'` |
| id_col (optional) | TEXT | The column name for the unique ID of each geometry/value pair. Defaults to `'cartodb_id'`. |

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| moran | NUMERIC | Value of Moran's I (spatial autocorrelation measure) for the entire dataset. Values closer to one indicate cluster, closer to -1 mean more outliers, and near zero indicates a random distribution of data. |
| significance | NUMERIC | The statistical significance of the `moran` measure. |

#### Examples

```sql
SELECT
    *
FROM
    cdb_crankshaft.CDB_AreasOfInterestGlobal(
        'SELECT * FROM commute_data',
        'num_cyclists_per_total_population')
```

### CDB_AreasOfInterestLocalRate(subquery text, numerator_column text, denominator_column text)

Just like `CDB_AreasOfInterestLocal`, this function classifies your data as being part of a cluster, as an outlier, or not part of a pattern based the significance of a classification. This function differs in that it calculates the classifications based on input `numerator` and `denominator` columns for finding the areas where there are clusters and outliers for the resulting rate of those two values.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | TEXT | SQL query that exposes the data to be analyzed (e.g., `SELECT * FROM interesting_table`). This query must have the geometry column name `the_geom` and id column name `cartodb_id` unless otherwise specified in the input arguments |
| numerator | TEXT | Name of the numerator for forming a rate to be used in analysis. |
| denominator | TEXT | Name of the denominator for forming a rate to be used in analysis. |
| weight type (optional) | TEXT | Type of weight to use when finding neighbors. Currently available options are 'knn' (default) and 'queen'. Read more about weight types in [PySAL's weights documentation](https://pysal.readthedocs.io/en/v1.11.0/users/tutorials/weights.html). |
| num_ngbrs (optional) | INT | Number of neighbors if using k-nearest neighbors weight type. Defaults to 5. |
| permutations (optional) | INT | Number of permutations to check against a random arrangement of the values in `column_name`. This influences the accuracy of the output field `significance`. Defaults to 99. |
| geom_col (optional) | TEXT | The column name for the geometries. Defaults to `'the_geom'` |
| id_col (optional) | TEXT | The column name for the unique ID of each geometry/value pair. Defaults to `'cartodb_id'`. |

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| moran | NUMERIC | Value of Moran's I (spatial autocorrelation measure) for the geometry with id of `rowid` |
| quads | TEXT | Classification of geometry. Result is one of 'HH' (a high value with neighbors high on average), 'LL' (opposite of 'HH'), 'HL' (a high value surrounded by lows on average), and 'LH' (opposite of 'HL'). Null values are returned when nulls exist in the original data. |
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
FROM
    cdb_crankshaft.CDB_AreasOfInterestLocalRate(
        'SELECT * FROM commute_data'
        'num_cyclists',
        'total_population') As aoi
JOIN commute_data As c
ON c.cartodb_id = aoi.rowid;
```

### CDB_AreasOfInterestGlobalRate(subquery text, column_name text)

This function identifies the extent to which geometries cluster (the groupings of geometries with similarly high or low values relative to the mean) or form outliers (areas where geometries have values opposite of their neighbors). The output of this function gives values between -1 and 1 as well as a significance of that classification. Values close to 0 mean that there is little to no distribution of values as compared to what one would see in a randomly distributed collection of geometries and values.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | TEXT | SQL query that exposes the data to be analyzed (e.g., `SELECT * FROM interesting_table`). This query must have the geometry column name `the_geom` and id column name `cartodb_id` unless otherwise specified in the input arguments |
| numerator | TEXT | Name of the numerator for forming a rate to be used in analysis. |
| denominator | TEXT | Name of the denominator for forming a rate to be used in analysis. |
| weight type (optional) | TEXT | Type of weight to use when finding neighbors. Currently available options are 'knn' (default) and 'queen'. Read more about weight types in [PySAL's weights documentation](https://pysal.readthedocs.io/en/v1.11.0/users/tutorials/weights.html). |
| num_ngbrs (optional) | INT | Number of neighbors if using k-nearest neighbors weight type. Defaults to 5. |
| permutations (optional) | INT | Number of permutations to check against a random arrangement of the values in `column_name`. This influences the accuracy of the output field `significance`. Defaults to 99. |
| geom_col (optional) | TEXT | The column name for the geometries. Defaults to `'the_geom'` |
| id_col (optional) | TEXT | The column name for the unique ID of each geometry/value pair. Defaults to `'cartodb_id'`. |

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| moran | NUMERIC | Value of Moran's I (spatial autocorrelation measure) for the entire dataset. Values closer to one indicate cluster, closer to -1 mean more outliers, and near zero indicates a random distribution of data. |
| significance | NUMERIC | The statistical significance of the `moran` measure. |

#### Examples

```sql
SELECT
    *
FROM
    cdb_crankshaft.CDB_AreasOfInterestGlobalRate(
        'SELECT * FROM commute_data',
        'num_cyclists',
        'total_population')
```

## Hotspot, Coldspot, and Outlier Functions

These functions are convenience functions for extracting only information that you are interested in exposing based on the outputs of the `CDB_AreasOfInterest` functions. For instance, you can use `CDB_GetSpatialHotspots` to output only the classifications of `HH` and `HL`.

### Non-rate functions

#### CDB_GetSpatialHotspots
This function's inputs and outputs exactly mirror `CDB_AreasOfInterestLocal` except that the outputs are filtered to be only 'HH' and 'HL' (areas of high values). For more information about this function's use, see `CDB_AreasOfInterestLocal`.

#### CDB_GetSpatialColdspots
This function's inputs and outputs exactly mirror `CDB_AreasOfInterestLocal` except that the outputs are filtered to be only 'LL' and 'LH' (areas of low values). For more information about this function's use, see `CDB_AreasOfInterestLocal`.

#### CDB_GetSpatialOutliers
This function's inputs and outputs exactly mirror `CDB_AreasOfInterestLocal` except that the outputs are filtered to be only 'HL' and 'LH' (areas where highs or lows are surrounded by opposite values on average). For more information about this function's use, see `CDB_AreasOfInterestLocal`.

### Rate functions

#### CDB_GetSpatialHotspotsRate

This function's inputs and outputs exactly mirror `CDB_AreasOfInterestLocalRate` except that the outputs are filtered to be only 'HH' and 'HL' (areas of high values). For more information about this function's use, see `CDB_AreasOfInterestLocalRate`.

#### CDB_GetSpatialColdspotsRate

This function's inputs and outputs exactly mirror `CDB_AreasOfInterestLocalRate` except that the outputs are filtered to be only 'LL' and 'LH' (areas of low values). For more information about this function's use, see `CDB_AreasOfInterestLocalRate`.

#### CDB_GetSpatialOutliersRate

This function's inputs and outputs exactly mirror `CDB_AreasOfInterestLocalRate` except that the outputs are filtered to be only 'HL' and 'LH' (areas where highs or lows are surrounded by opposite values on average). For more information about this function's use, see `CDB_AreasOfInterestLocalRate`.
