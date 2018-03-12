"""
Segmentation creation and prediction
"""

import sklearn
import numpy as np
import plpy
from sklearn.ensemble import GradientBoostingRegressor
from sklearn import metrics
from sklearn.cross_validation import train_test_split

# Lower level functions
#----------------------

def replace_nan_with_mean(array):
    """
        Input:
            @param array: an array of floats which may have null-valued entries
        Output:
            array with nans filled in with the mean of the dataset
    """
    # returns an array of rows and column indices
    indices = np.where(np.isnan(array))

    # iterate through entries which have nan values
    for row, col in zip(*indices):
            array[row, col] = np.mean(array[~np.isnan(array[:, col]), col])

    return array

def get_data(variable, feature_columns, query):
    """
        Fetch data from the database, clean, and package into
          numpy arrays
        Input:
            @param variable: name of the target variable
            @param feature_columns: list of column names
            @param query: subquery that data is pulled from for the packaging
        Output:
            prepared data, packaged into NumPy arrays
    """

    columns = ','.join(['array_agg("{col}") As "{col}"'.format(col=col) for col in feature_columns])

    try:
        data = plpy.execute('''SELECT array_agg("{variable}") As target, {columns} FROM ({query}) As a'''.format(
            variable=variable,
            columns=columns,
            query=query))
    except Exception, e:
        plpy.error('Failed to access data to build segmentation model: %s' % e)

    # extract target data from plpy object
    target = np.array(data[0]['target'])

    # put n feature data arrays into an n x m array of arrays
    features = np.column_stack([np.array(data[0][col], dtype=float) for col in feature_columns])

    return replace_nan_with_mean(target), replace_nan_with_mean(features)

# High level interface
# --------------------

def create_and_predict_segment_agg(target, features, target_features, target_ids, model_parameters):
    """
    Version of create_and_predict_segment that works on arrays that come stright form the SQL calling
    the function.

        Input:
            @param target: The 1D array of lenth NSamples containing the target variable we want the model to predict
            @param features: Thw 2D array of size NSamples * NFeatures that form the imput to the model
            @param target_ids: A 1D array of target_ids that will be used to associate the results of the prediction with the rows which they come from
            @param model_parameters: A dictionary containing parameters for the model.
    """

    clean_target = replace_nan_with_mean(target)
    clean_features = replace_nan_with_mean(features)
    target_features = replace_nan_with_mean(target_features)

    model, accuracy = train_model(clean_target, clean_features, model_parameters, 0.2)
    prediction = model.predict(target_features)
    accuracy_array = [accuracy]*prediction.shape[0]
    return zip(target_ids, prediction, np.full(prediction.shape, accuracy_array))



def create_and_predict_segment(query, variable, target_query, model_params):
    """
    generate a segment with machine learning
    Stuart Lynn
    """

    ## fetch column names
    try:
        columns = plpy.execute('SELECT * FROM ({query}) As a LIMIT 1  '.format(query=query))[0].keys()
    except Exception, e:
        plpy.error('Failed to build segmentation model: %s' % e)

    ## extract column names to be used in building the segmentation model
    feature_columns = set(columns) - set([variable, 'cartodb_id', 'the_geom', 'the_geom_webmercator'])
    ## get data from database
    target, features = get_data(variable, feature_columns, query)

    model, accuracy = train_model(target, features, model_params, 0.2)
    cartodb_ids, result = predict_segment(model, feature_columns, target_query)
    accuracy_array = [accuracy]*result.shape[0]
    return zip(cartodb_ids, result, accuracy_array)


def train_model(target, features, model_params, test_split):
    """
        Train the Gradient Boosting model on the provided data and calculate the accuracy of the model
        Input:
            @param target: 1D Array of the variable that the model is to be trianed to predict
            @param features: 2D Array NSamples * NFeatures to use in trining the model
            @param model_params: A dictionary of model parameters, the full specification can be found on the
                scikit learn page for [GradientBoostingRegressor](http://scikit-learn.org/stable/modules/generated/sklearn.ensemble.GradientBoostingRegressor.html)
            @parma test_split: The fraction of the data to be withheld for testing the model / calculating the accuray
    """
    features_train, features_test, target_train, target_test = train_test_split(features, target, test_size=test_split)
    model = GradientBoostingRegressor(**model_params)
    model.fit(features_train, target_train)
    accuracy = calculate_model_accuracy(model, features, target)
    return model, accuracy

def calculate_model_accuracy(model, features, target):
    """
        Calculate the mean squared error of the model prediction
        Input:
            @param model: model trained from input features
            @param features: features to make a prediction from
            @param target: target to compare prediction to
        Output:
            mean squared error of the model prection compared to the target
    """
    prediction = model.predict(features)
    return metrics.mean_squared_error(prediction, target)

def predict_segment(model, features, target_query):
    """
    Use the provided model to predict the values for the new feature set
        Input:
            @param model: The pretrained model
            @features: A list of features to use in the model prediction (list of column names)
            @target_query: The query to run to obtain the data to predict on and the cartdb_ids associated with it.
    """

    batch_size = 1000
    joined_features = ','.join(['"{0}"::numeric'.format(a) for a in features])

    try:
        cursor = plpy.cursor('SELECT Array[{joined_features}] As features FROM ({target_query}) As a'.format(
            joined_features=joined_features,
            target_query=target_query))
    except Exception, e:
        plpy.error('Failed to build segmentation model: %s' % e)

    results = []

    while True:
        rows = cursor.fetch(batch_size)
        if not rows:
            break
        batch = np.row_stack([np.array(row['features'], dtype=float) for row in rows])

        #Need to fix this. Should be global mean. This will cause weird effects
        batch = replace_nan_with_mean(batch)
        prediction = model.predict(batch)
        results.append(prediction)

    try:
        cartodb_ids = plpy.execute('''SELECT array_agg(cartodb_id ORDER BY cartodb_id) As cartodb_ids FROM ({0}) As a'''.format(target_query))[0]['cartodb_ids']
    except Exception, e:
        plpy.error('Failed to build segmentation model: %s' % e)

    return cartodb_ids, np.concatenate(results)
