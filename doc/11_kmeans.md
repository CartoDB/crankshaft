## K-Means Functions

### CDB_KMeans(subquery text, no_clusters INTEGER)

This function attempts to find n clusters within the input data. It will return a table to CartoDB ids and 
the number of the cluster each point in the input was assigend to.


#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | TEXT | SQL query that exposes the data to be analyzed (e.g., `SELECT * FROM interesting_table`). This query must have the geometry column name `the_geom` and id column name `cartodb_id` unless otherwise specified in the input arguments |
| no\_clusters | INTEGER | The number of clusters to try and find |

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| cartodb\_id | INTEGER | The CartoDB id of the row in the input table.|
| cluster\_no | INTEGER | The cluster that this point belongs to. |


#### Example Usage

```sql
SELECT 
    customers.*, 
    km.cluster_no 
    FROM cdb_crankshaft.CDB_Kmeans('SELECT * from customers' , 6) km, customers_3
    WHERE customers.cartodb_id = km.cartodb_id
```

### CDB_WeightedMean(subquery text, weight_column text, category_column text)

Function that computes the weighted centroid of a number of clusters by some weight column.

### Arguments 

| Name | Type | Description |
|------|------|-------------|
| subquery | TEXT | SQL query that exposes the data to be analyzed (e.g., `SELECT * FROM interesting_table`). This query must have the geometry column and the columns specified as the weight and category columns|
| weight\_column | TEXT | The name of the column to use as a weight |
| category\_column | TEXT | The name of the column to use as a category |

### Returns 

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| the\_geom | GEOMETRY | A point for the weighted cluster center |
| class | INTEGER | The cluster class | 

### Example Usage 

```sql 
SELECT ST_TRANSFORM(the_geom, 3857) as the_geom_webmercator, class 
FROM cdb_crankshaft.cdb_weighted_mean('SELECT *, customer_value FROM customers','customer_value','cluster_no')
```
