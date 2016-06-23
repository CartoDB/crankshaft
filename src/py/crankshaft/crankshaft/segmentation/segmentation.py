"""
Segmentation creation and prediction
"""

import sklearn
import numpy as np
import plpy
from sklearn.ensemble import GradientBoostingRegressor
from sklearn import metrics
from sklearn.cross_validation import train_test_split

# High level interface ---------------------------------------

def replace_nan_with_mean(array):
    indices = np.where(np.isnan(array)) #returns an array of rows and column indices
    for row, col in zip(*indices):
            array[row,col] = np.mean(array[~np.isnan(array[:,col]), col])
    return array

def get_data(variable, feature_columns, query):
    columns  = ','.join(['array_agg("{col}") as "{col}"'.format(col=col) for col in feature_columns])
    data = plpy.execute('''select array_agg("{variable}") as target, {columns} from ({query}) as a'''.format(
        variable = variable,
        columns = columns,
        query = query
        ))
    target = np.array(data[0]['target'])
    features = np.column_stack([np.array(data[0][col], dtype=float) for col in feature_columns])

    return replace_nan_with_mean(target), replace_nan_with_mean(features)


def create_and_predict_segment_agg(target, features, target_features, target_ids,model_parameters):
    clean_target = replace_nan_with_mean(target)
    clean_features = replace_nan_with_mean(features)
    target_features = replace_nan_with_mean(target_features)

    model, accuracy = train_model(clean_target,clean_features, model_parameters, 0.2)
    prediction = model.predict(target_features)
    return zip(target_ids, prediction, np.full(prediction.shape, accuracy))



def create_and_predict_segment(query,variable,target_query,model_params):
    """
    generate a segment with machine learning
    Stuart Lynn
    """

    columns = plpy.execute('select * from  ({query}) a  limit 1  '.format(query=query))[0].keys()

    feature_columns = set(columns) - set([variable, 'cartodb_id', 'the_geom', 'the_geom_webmercator'])
    target,features = get_data(variable, feature_columns, query)

    model, accuracy = train_model(target,features, model_params, 0.2)
    cartodb_ids, result = predict_segment(model,feature_columns,target_query)
    return zip(cartodb_ids, result, np.full(result.shape, accuracy ))


def train_model(target,features,model_params,test_split):
    features_train, features_test, target_train, target_test = train_test_split(features, target, test_size=test_split)
    model = GradientBoostingRegressor(**model_params)
    model.fit(features_train, target_train)
    accuracy = calculate_model_accuracy(model,features,target)
    return model, accuracy

def calculate_model_accuracy(model,features,target):
    prediction = model.predict(features)
    return metrics.mean_squared_error(prediction,target)

def predict_segment(model,features,target_query):
    """
    predict a segment with machine learning
    Stuart Lynn
    """

    batch_size = 1000
    joined_features  = ','.join(['"{0}"::numeric'.format(a) for a in features])

    cursor = plpy.cursor('select Array[{joined_features}] features from ({target_query}) a'.format(
        joined_features=joined_features,
        target_query= target_query
    ))

    results = []

    while True:
        rows  = cursor.fetch(batch_size)
        if not rows:
            break
        batch  = np.row_stack([np.array(row['features'], dtype=float) for row in rows])

        #Need to fix this. Should be global mean. This will cause weird effects
        batch  = replace_nan_with_mean(batch)
        prediction   = model.predict(batch)
        results.append(prediction)


    cartodb_ids = plpy.execute('select array_agg(cartodb_id order by cartodb_id) as cartodb_ids from ({0}) a '.format(target_query))[0]['cartodb_ids']
    return  cartodb_ids, np.concatenate(results)


