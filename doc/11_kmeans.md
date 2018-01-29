## K-Means Functions

k-means clustering is a popular technique for finding clusters in data by minimizing the intra-cluster 'distance' and maximizing the inter-cluster 'distance'. The distance is defined in the parameter space of the variables entered.

### CDB_KMeans(subquery text, no_clusters integer)

This function attempts to find `no_clusters` clusters within the input data based on the geographic distribution. It will return a table with ids and the cluster classification of each point input assuming `the_geom` is not null-valued. If `the_geom` is null-valued, the point will not be considered in the analysis.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | TEXT | SQL query that exposes the data to be analyzed (e.g., `SELECT * FROM interesting_table`). This query must have the geometry column name `the_geom` and id column name `cartodb_id` unless otherwise specified in the input arguments |
| no\_clusters | INTEGER | The number of clusters to find |

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| cartodb\_id | INTEGER | The row id of the row from the input table |
| cluster\_no | INTEGER | The cluster that this point belongs to |


#### Example Usage

```sql
SELECT
    customers.*,
    km.cluster_no
FROM
    cdb_crankshaft.CDB_KMeans('SELECT * from customers' , 6) As km,
    customers
WHERE
    customers.cartodb_id = km.cartodb_id
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
SELECT
    ST_Transform(km.the_geom, 3857) As the_geom_webmercator,
    km.class
FROM
    cdb_crankshaft.CDB_WeightedMean(
        'SELECT *, customer_value FROM customers',
        'customer_value',
        'cluster_no') As km
```

## CDB_KMeansNonspatial(subquery text, colnames text[], no_clusters int)

K-means clustering classifies the rows of your dataset into `no_clusters` by finding the centers (means) of the variables in `colnames` and classifying each row by it's proximity to the nearest center. This method partitions space into distinct Voronoi cells.

As a standard machine learning method, k-means clustering is an unsupervised learning technique that finds the natural clustering of values. For instance, it is useful for finding subgroups in census data leading to demographic segmentation.

### Arguments

| Name | Type | Description |
|------|------|-------------|
| query | TEXT | SQL query to expose the data to be used in the analysis (e.g., `SELECT * FROM iris_data`). It should contain at least the columns specified in `colnames` and the `id_colname`. |
| colnames | TEXT[] | Array of columns to be used in the analysis (e.g., `Array['petal_width', 'sepal_length', 'petal_length']`). |
| no\_clusters | INTEGER | Number of clusters for the classification of the data |
| id\_col (optional) | TEXT | The id column (default: 'cartodb_id') for identifying rows |
| standarize (optional) | BOOLEAN | Setting this to true (default) standardizes the data to have a mean at zero and a standard deviation of 1 |

### Returns

A table with the following columns.

| Column | Type | Description |
|--------|------|-------------|
| cluster_label | TEXT | Label that a cluster belongs to, number from 0 to `no_clusters - 1`. |
| cluster_center | JSON | Center of the cluster that a row belongs to. The keys of the JSON object are the `colnames`, with values that are the center of the respective cluster |
| silhouettes | NUMERIC | [Silhouette score](http://scikit-learn.org/stable/modules/generated/sklearn.metrics.silhouette_score.html#sklearn.metrics.silhouette_score) of the cluster label |
| inertia | NUMERIC | Sum of squared distances of samples to their closest cluster center |
| rowid | BIGINT | id of the original row for associating back with the original data |

### Example Usage

```sql
SELECT
    customers.*,
    km.cluster_label,
    km.cluster_center,
    km.silhouettes
FROM
    cdb_crankshaft.CDB_KMeansNonspatial(
        'SELECT * FROM customers',
        Array['customer_value', 'avg_amt_spent', 'home_median_income'],
        7) As km,
    customers
WHERE
    customers.cartodb_id = km.rowid
```

### Resources

-   Read more in [scikit-learn's documentation](http://scikit-learn.org/stable/modules/clustering.html#k-means)
-   [K-means basics](https://www.datascience.com/blog/introduction-to-k-means-clustering-algorithm-learn-data-science-tutorials)
