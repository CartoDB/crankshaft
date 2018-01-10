## Outlier Detection

This set of functions detects the presence of outliers. There are three functions for finding outliers from non-spatial data:

1. Static Outliers
1. Percentage Outliers
1. Standard Deviation Outliers

### CDB_StaticOutlier(column_value numeric, threshold numeric)

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| column_value | numeric | The column of values on which to apply the threshold |
| threshold | numeric | The static threshold which is used to indicate whether a `column_value` is an outlier or not |

### Returns

Returns a boolean (true/false) depending on whether a value is above or below (or equal to) the threshold

| Name | Type | Description |
|------|------|-------------|
| outlier | boolean | classification of whether a row is an outlier or not |

#### Example Usage

With a table `website_visits` and a column of the number of website visits in units of 10,000 visits:

```
| id | visits_10k |
|----|------------|
| 1  | 1 |
| 2  | 3 |
| 3  | 5 |
| 4  | 1 |
| 5  | 32 |
| 6  | 3 |
| 7  | 57 |
| 8  | 2 |
```

```sql
SELECT
  id,
  cdb_crankshaft.CDB_StaticOutlier(visits_10k, 11.0) As outlier,
  visits_10k
FROM website_visits
```

```
| id | outlier | visits_10k |
|----|---------|------------|
| 1  | f | 1 |
| 2  | f | 3 |
| 3  | f | 5 |
| 4  | f | 1 |
| 5  | t | 32 |
| 6  | f | 3 |
| 7  | t | 57 |
| 8  | f | 2 |
```

### CDB_PercentOutlier(column_values numeric[], outlier_fraction numeric, ids int[])

`CDB_PercentOutlier` calculates whether or not a value falls above a given threshold based on a percentage above the mean value of the input values.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| column_values | numeric[] | An array of the values to calculate the outlier classification on |
| outlier_fraction | numeric | The threshold above which a column value divided by the mean of all values is considered an outlier |
| ids | int[] | An array of the unique row ids of the input data (usually `cartodb_id`) |

### Returns

Returns a table of the outlier classification with the following columns

| Name | Type | Description |
|------|------|-------------|
| is_outlier | boolean  | classification of whether a row is an outlier or not |
| rowid | int | original row id (e.g., input `cartodb_id`) of the row which has the outlier classification |

#### Example Usage

This example find outliers which are more than 100% larger than the average (that is, more than 2.0 times larger).

```sql
WITH cte As (
  SELECT
    unnest(Array[1,2,3,4,5,6,7,8]) As id,
    unnest(Array[1,3,5,1,32,3,57,2]) As visits_10k
  )
SELECT
  (cdb_crankshaft.CDB_PercentOutlier(array_agg(visits_10k), 2.0, array_agg(id))).*
FROM cte;
```

Output
```
| outlier | rowid |
|---------+-------|
| f | 1 |
| f | 2 |
| f | 3 |
| f | 4 |
| t | 5 |
| f | 6 |
| t | 7 |
| f | 8 |
```

### CDB_StdDevOutlier(column_values numeric[], num_deviations numeric, ids int[], is_symmetric boolean DEFAULT true)

`CDB_StdDevOutlier` calculates whether or not a value falls above or below a given threshold based on the number of standard deviations from the mean.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| column_values | numeric[] | An array of the values to calculate the outlier classification on |
| num_deviations | numeric | The threshold in units of standard deviation |
| ids | int[] | An array of the unique row ids of the input data (usually `cartodb_id`) |
| is_symmetric (optional) | boolean | Consider outliers that are symmetric about the mean (default: true) |

### Returns

Returns a table of the outlier classification with the following columns

| Name | Type | Description |
|------|------|-------------|
| is_outlier | boolean  | classification of whether a row is an outlier or not |
| rowid | int | original row id (e.g., input `cartodb_id`) of the row which has the outlier classification |

#### Example Usage

This example find outliers which are more than 100% larger than the average (that is, more than 2.0 times larger).

```sql
WITH cte As (
  SELECT
    unnest(Array[1,2,3,4,5,6,7,8]) As id,
    unnest(Array[1,3,5,1,32,3,57,2]) As visits_10k
  )
SELECT
  (cdb_crankshaft.CDB_StdDevOutlier(array_agg(visits_10k), 2.0, array_agg(id))).*
FROM cte;
```

Output
```
| outlier | rowid |
|---------+-------|
| f | 1 |
| f | 2 |
| f | 3 |
| f | 4 |
| f | 5 |
| f | 6 |
| t | 7 |
| f | 8 |
```
