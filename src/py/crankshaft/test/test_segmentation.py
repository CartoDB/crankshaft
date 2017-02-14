import unittest
import numpy as np
from helper import plpy, fixture_file
from crankshaft.analysis_data_provider import AnalysisDataProvider
from crankshaft.segmentation import Segmentation
import json


class RawDataProvider(AnalysisDataProvider):
    def __init__(self, test, train, predict):
        self.test = test
        self.train = train
        self.predict = predict

    def get_segmentation_data(self, params):
        return self.test

    def get_segmentation_model_data(self, params):
        return self.train

    def get_segmentation_predict_data(self, params):
        return self.predict


class SegmentationTest(unittest.TestCase):
    """Testing class for Segmentation functions"""

    def setUp(self):
        plpy._reset()
        self.params = {"query": 'SELECT * FROM seg_test',
                       "variable": 'price',
                       "feature_columns": ['m1', 'm2', 'm3'],
                       "target_query": 'SELECT * FROM seg_test_target',
                       "id_col": 'cartodb_id',
                       "model_params": {'n_estimators': 1200,
                                        'max_depth': 3,
                                        'subsample': 0.5,
                                        'learning_rate': 0.01,
                                        'min_samples_leaf': 1}
                       }

    def generate_random_data(self, n_samples, random_state, row_type=False):
        x1 = random_state.uniform(size=n_samples)
        # x1 = np.random.rand(n_samples)
        x2 = random_state.uniform(size=n_samples)
        # x2 = np.random.rand(n_samples)
        x3 = random_state.randint(0, 4, size=n_samples)
        # x3 = np.random.rand(n_samples)

        y = x1+x2*x2+x3
        # y = 2*x1 + 1.5*x2 + 3.6*x3 + 8
        cartodb_id = range(len(x1))

        if row_type:
            return [{'features': vals} for vals in zip(x1, x2, x3)], y
        else:
            return [dict(zip(['x1', 'x2', 'x3', 'target', 'cartodb_id'],
                             [x1, x2, x3, y, cartodb_id]))]

    def test_replace_nan_with_mean(self):
        from crankshaft.segmentation import replace_nan_with_mean
        from numpy.testing import assert_array_equal
        test_array = np.array([1.2, np.nan, 3.2, np.nan, np.nan])
        result = replace_nan_with_mean(test_array, means=None)[0]
        expectation = np.array([1.2, 2.2, 3.2, 2.2, 2.2], dtype=float)
        print result
        print type(result)
        assert_array_equal(result, expectation)

    def test_create_and_predict_segment(self):
        from numpy.testing import assert_array_equal

        n_samples = 1000

        random_state_train = np.random.RandomState(13)
        random_state_test = np.random.RandomState(134)
        training_data = self.generate_random_data(n_samples,
                                                  random_state_train)
        test_data, test_y = self.generate_random_data(n_samples,
                                                      random_state_test,
                                                      row_type=True)

        ids = [{'cartodb_ids': range(len(test_data))}]

        '''
        rowid = [{'ids': [2.9, 4.9, 4, 5, 6]}]
        '''
        rows = [{'x1': 0, 'x2': 0, 'x3': 0, 'y': 0, 'cartodb_id': 0}]

        model_parameters = {'n_estimators': 1200,
                            'max_depth': 3,
                            'subsample': 0.5,
                            'learning_rate': 0.01,
                            'min_samples_leaf': 1}
        # print "train: {}".format(test_data)
        # assert 1 == 2
        # select array_agg(target) as "target",
        #        array_agg(x1) as "x1",
        #        etc.
        feature_means = training_data[0]['x1'].mean()
        target_mean = training_data[0]['target'].mean()
        data_train = [{'target': training_data[0]['target'],
                       'x1': training_data[0]['x1'],
                       'x2': training_data[0]['x2'],
                       'x3': training_data[0]['x3']}]

        data_test = [{'id_col': training_data[0]['cartodb_id']}]

        data_predict = [{'feature_columns': test_data}]
        '''
         cursors = [{'features': [[m1[0],m2[0],m3[0]],[m1[1],m2[1],m3[1]],
                                  [m1[2],m2[2],m3[2]]]}]
        '''
        # data = Segmentation(RawDataProvider(test, train, predict))
        '''
        self, query, variable, feature_columns,
                                       target_query, model_params,
                                       id_col='cartodb_id'
        '''
        '''
        data = [{'target': [2.9, 4.9, 4, 5, 6]},
        {'feature1': [1,2,3,4]}, {'feature2' : [2,3,4,5]}
        ]
        '''
        print data_train
        # Before here figure out how to set up the data provider
        # After use data prodiver to run the query and test results.
        seg = Segmentation(RawDataProvider(data_test, data_train,
                                           data_predict))
        # def create_and_predict_segment(self, query, variable, feature_columns
        #                                target_query, model_params,
        #                                id_col='cartodb_id'):
        result = seg.create_and_predict_segment('select * from query',
                                                'target',
                                                ['x1', 'x2', 'x3'],
                                                'select * from target',
                                                model_parameters,
                                                id_col='cartodb_id')

        prediction = [r[1] for r in result]

        accuracy = np.sqrt(np.mean(np.square(np.array(prediction) -
                                             np.array(test_y))))

        self.assertEqual(len(result), len(test_data))
        self.assertTrue(result[0][2] < 0.01)
        self.assertTrue(accuracy < 0.5*np.mean(test_y))
