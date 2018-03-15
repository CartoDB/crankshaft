"""
Segmentation creation and prediction
"""

import numpy as np
from sklearn.ensemble import GradientBoostingRegressor
from sklearn import metrics
from sklearn.cross_validation import train_test_split
from crankshaft.analysis_data_provider import AnalysisDataProvider

# NOTE: added optional param here


class Segmentation(object):
    """
        Add docstring
    """

    def __init__(self, data_provider=None):
        if data_provider is None:
            self.data_provider = AnalysisDataProvider()
        else:
            self.data_provider = data_provider

    def create_and_predict_segment_agg(self, target, features, target_features,
                                       target_ids, model_parameters):
        """
        Version of create_and_predict_segment that works on arrays that come
            straight form the SQL calling the function.

            Input:
                @param target: The 1D array of length NSamples containing the
                target variable we want the model to predict
                @param features: The 2D array of size NSamples * NFeatures that
                    form the input to the model
                @param target_ids: A 1D array of target_ids that will be used
                to associate the results of the prediction with the rows which
                    they come from
                @param model_parameters: A dictionary containing parameters for
                the model.
        """
        clean_target, _ = replace_nan_with_mean(target)
        clean_features, _ = replace_nan_with_mean(features)
        target_features,  _ = replace_nan_with_mean(target_features)

        model, accuracy = train_model(clean_target, clean_features,
                                      model_parameters, 0.2)
        prediction = model.predict(target_features)
        accuracy_array = [accuracy] * prediction.shape[0]
        return zip(target_ids, prediction, accuracy_array)

    def create_and_predict_segment(self, query, variable, feature_columns,
                                   target_query, model_params,
                                   id_col='cartodb_id'):
        """
        generate a segment with machine learning
        Stuart Lynn
                @param query: subquery that data is pulled from for packaging
                @param variable: name of the target variable
                @param feature_columns: list of column names
                @target_query: The query to run to obtain the data to predict
                @param model_params: A dictionary of model parameters, the full
                        specification can be found on the
                        scikit learn page for [GradientBoostingRegressor]
                        (http://scikit-learn.org/stable/modules/generated/sklearn.ensemble.GradientBoostingRegressor.html)
        """
        params = {"subquery": target_query,
                  "id_col": id_col}

        (target, features, target_mean,
            feature_means) = self.clean_data(query, variable, feature_columns)

        model, accuracy = train_model(target, features, model_params, 0.2)
        result = self.predict_segment(model, feature_columns, target_query,
                                      feature_means)
        accuracy_array = [accuracy] * result.shape[0]

        rowid = self.data_provider.get_segmentation_data(params)
        '''
        rowid = [{'ids': [2.9, 4.9, 4, 5, 6]}]
        '''
        return zip(rowid[0]['ids'], result, accuracy_array)

    def predict_segment(self, model, feature_columns, target_query,
                        feature_means):
        """
        Use the provided model to predict the values for the new feature set
            Input:
                @param model: The pretrained model
                @features_col: A list of features to use in the
                    model prediction (list of column names)
                @target_query: The query to run to obtain the data to predict
                    on and the cartodb_ids associated with it.
        """

        batch_size = 1000
        params = {"subquery": target_query,
                  "feature_columns": feature_columns}

        results = []
        cursors = self.data_provider.get_segmentation_predict_data(params)
        '''
         cursors = [{'features': [[m1[0],m2[0],m3[0]],[m1[1],m2[1],m3[1]],
                                  [m1[2],m2[2],m3[2]]]}]
        '''

        while True:
            rows = cursors.fetch(batch_size)
            if not rows:
                break
            batch = np.row_stack([np.array(row['features'])
                                  for row in rows]).astype(float)

            batch = replace_nan_with_mean(batch, feature_means)[0]
            prediction = model.predict(batch)
            results.append(prediction)

        # NOTE: we removed the cartodb_ids calculation in here
        return np.concatenate(results)

    def clean_data(self, query, variable, feature_columns):
        """
            Add docstring
        """
        params = {"subquery": query,
                  "target": variable,
                  "features": feature_columns}

        data = self.data_provider.get_segmentation_model_data(params)

        '''
        data = [{'target': [2.9, 4.9, 4, 5, 6],
        'feature1': [1,2,3,4], 'feature2' : [2,3,4,5]}]
        '''

        # extract target data from data_provider object
        target = np.array(data[0]['target'], dtype=float)

        # put n feature data arrays into an n x m array of arrays
        features = np.column_stack([np.array(data[0][col])
                                    for col in feature_columns]).astype(float)

        features, feature_means = replace_nan_with_mean(features)
        target, target_mean = replace_nan_with_mean(target)
        return target, features, target_mean, feature_means


def replace_nan_with_mean(array, means=None):
    """
        Input:
            @param array: an array of floats which may have null-valued
                          entries
        Output:
            array with nans filled in with the mean of the dataset
    """

    # returns an array of rows and column indices
    nanvals = np.isnan(array)
    indices = np.where(nanvals)

    def loops(array, axis):
        try:
            return np.shape(array)[axis]
        except IndexError:
            return 1
    ran = loops(array, 1)

    if means is None:
        means = {}

        if ran == 1:
            array = np.array(array)
            means[0] = np.mean(array[~np.isnan(array)])
            for row in zip(*indices):
                array[row] = means[0]
        else:
            for col in range(ran):
                means[col] = np.mean(array[~np.isnan(array[:, col]), col])
            for row, col in zip(*indices):
                array[row, col] = means[col]
    else:
        if ran == 1:
            for row in zip(*indices):
                array[row] = means[0]
        else:
            for row, col in zip(*indices):
                array[row, col] = means[col]

    return array, means


def train_model(target, features, model_params, test_split):
    """
        Train the Gradient Boosting model on the provided data to calculate
        the accuracy of the model
        Input:
            @param target: 1D Array of the variable that the model is to be
                trained to predict
            @param features: 2D Array NSamples *NFeatures to use in training
                the model
            @param model_params: A dictionary of model parameters, the full
                specification can be found on the
                scikit learn page for [GradientBoostingRegressor]
                (http://scikit-learn.org/stable/modules/generated/sklearn.ensemble.GradientBoostingRegressor.html)
            @parma test_split: The fraction of the data to be withheld for
                testing the model / calculating the accuray
    """
    features_train, features_test, \
        target_train, target_test = train_test_split(features, target,
                                                     test_size=test_split)
    model = GradientBoostingRegressor(**model_params)
    model.fit(features_train, target_train)
    accuracy = calculate_model_accuracy(model, features_test, target_test)
    return model, accuracy


def calculate_model_accuracy(model, features_test, target_test):
    """
        Calculate the mean squared error of the model prediction
        Input:
            @param model: model trained from input features
            @param features_test: test features set to make prediction from
            @param target_test: test target set to compare predictions to
        Output:
            mean squared error of the model prection compared target_test
    """
    prediction = model.predict(features_test)
    return metrics.mean_squared_error(prediction, target_test)
