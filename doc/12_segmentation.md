
## Segmentation Functions

### CDB_CreateAndPredictSegment (query TEXT,variable_name TEXT,target_query TEXT)

This function trains a [Gradient Boosting](http://scikit-learn.org/stable/modules/generated/sklearn.ensemble.GradientBoostingRegressor.html) model to attempt to predict the target data and then generates predictions for new data.  

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| query | TEXT | The input query to train the algorithum, should have both the variable of interest and the features that will be used to predict it|
| variablei\_name| TEXT | Specify the variable in the query to predict, all other columns are assumed to be features |
| target\_table | TEXT | The query which returns the cartodb\_id and features for the rows your would like to predict the target variable for |
| n\_estimators(optional) |  INTEGER DEFAULT 1200| Number of estimators to be used | 
| max\_depth (optional) | INTEGER DEFAULT 3 | Max tree depth |
| subsample (optional)  |  DOUBLE PRECISION DEFAULT 0.5 | Subsample paramter for GradientBooster|
| learning\_rate(optional) |  DOUBLE PRECISION DEFAULT 0.01| Learning rate for the GradientBooster|
| min\_samples\_leaf(optional) |  INTEGER DEFAULT 1 | Minimum samples to use per leaf|

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| cartodb\_id | INTEGER | The CartoDB id of the row in the target\_query|
| prediction | NUMERIC | The predicted value of the variable of interest |
| accuracy | NUMERIC | The mean squared accuracy of the model. |

#### Example Usage

```sql
SELECT * from cdb_crankshaft.CDB_CreateAndPredictSegment( 
'SELECT agg, median_rent::numeric, male_pop::numeric, female_pop::numeric from late_night_agg',
'agg',
'select ROW_NUMBER ( ) over ()  as cartodb_id, median_rent, male_pop, female_pop from ml_learning_ny');                               
```


### CDB_CreateAndPredictSegment (target NUMERIC[],train_features NUMERIC[], prediction_features Numeric[], prediction_ids NUMERIC[])

This function trains a [Gradient Boosting](http://scikit-learn.org/stable/modules/generated/sklearn.ensemble.GradientBoostingRegressor.html) model to attempt to predict the target data and then generates predictions for new data.  


#### Arguments

| Name | Type | Description |
|------|------|-------------|
| target | NUMERIC[] | An array of target values of the variable you want to predict|
| train\_features| NUMERIC[] | 1D array of length nfeatures\* n\_rows + 1 with the first entry in the array being the number of features in each row. These are the features the model will be trained on. CDB\_Crankshaft.CDB_pyAgg(Array[freature1, feature2, feature3]::Numeric[]) can be used to construct this. |
| prediction\_features | NUMERIC[]] | 1D array of length nfeatures\* n\_rows\_ + 1 with the first entry in the array being the number of features in each row. These are the features that will be used to predict the target variable  CDB\_Crankshaft.CDB\_pyAgg(Array[freature1, feature2, feature3]::Numeric[]) can be used to construct this.  |

| prediction\_ids | NUMERIC[]] | 1D array of length n\_rows with the ids that can use used to rejoin the data with inputs |

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| cartodb\_id | INTEGER | The CartoDB id of the row in the target\_query|
| prediction | NUMERIC | The predicted value of the variable of interest |
| accuracy | NUMERIC | The mean squared accuracy of the model. |
| n\_estimators(optional) |  INTEGER DEFAULT 1200| Number of estimators to be used | 
| max\_depth (optional) | INTEGER DEFAULT 3 | Max tree depth |
| subsample (optional)  |  DOUBLE PRECISION DEFAULT 0.5 | Subsample paramter for GradientBooster|
| learning\_rate(optional) |  DOUBLE PRECISION DEFAULT 0.01| Learning rate for the GradientBooster|
| min\_samples\_leaf(optional) |  INTEGER DEFAULT 1 | Minimum samples to use per leaf|

#### Example Usage

```sql
WITH training AS ( 
    SELECT array_agg(agg) AS target, 
          cdb_crankshaft.CDB_PyAgg(Array[median_rent, male_pop, female_pop]::Numeric[]) AS features
    FROM  late_night_agg), 
target AS (
    SELECT cdb_crankshaft.CDB_PyAgg(Array[median_rent, male_pop, female_pop]::Numeric[]) AS features,
     array_agg(cartodb_id ) AS cartodb_ids FROM late_night_agg)  

SELECT cdb_crankshaft.CDB_CreateAndPredictSegment2(training.target, training.features, target.features, targetcartodb_ids) 
FROM  training, target;                                                                       
`````
