"""Tests for segmentation functionality"""
import unittest
import json
from collections import OrderedDict

import numpy as np

from crankshaft.analysis_data_provider import AnalysisDataProvider
from crankshaft.segmentation import Segmentation
from helper import fixture_file
from mock_plpy import MockCursor


class RawDataProvider(AnalysisDataProvider):
    """Data Provider to overwrite the default SQL provider"""
    def __init__(self, data, model, predict):
        self.data = data
        self.model = model
        self.predict = predict

    def get_segmentation_data(self, params):  # pylint: disable=unused-argument
        """return data"""
        return self.data

    def get_segmentation_model_data(self, params):  # pylint: disable=W0613
        """return model data"""
        return self.model

    def get_segmentation_predict_data(self, params):  # pylint: disable=W0613
        """return predict data"""
        return self.predict


class SegmentationTest(unittest.TestCase):
    """Testing class for Segmentation functions"""

    def setUp(self):
        self.params = {
            "query": 'SELECT * FROM segmentation_data',
            "variable": 'price',
            "feature_columns": ['m1', 'm2', 'm3', 'm4', 'm5', 'm6'],
            "target_query": 'SELECT * FROM segmentation_result',
            "id_col": 'cartodb_id',
            "model_params": {
                'n_estimators': 1200,
                'max_depth': 3,
                'subsample': 0.5,
                'learning_rate': 0.01,
                'min_samples_leaf': 1
            }
        }
        self.model_data = json.loads(
            open(fixture_file('model_data.json')).read())
        self.data = json.loads(
            open(fixture_file('data.json')).read())
        self.predict_data = json.loads(
            open(fixture_file('predict_data.json')).read())
        self.result_seg = json.loads(
            open(fixture_file('segmentation_result.json')).read())
        self.true_result = json.loads(
            open(fixture_file('true_result.json')).read())

    def test_replace_nan_with_mean(self):
        """test segmentation.test_replace_nan_with_mean"""
        from crankshaft.segmentation import replace_nan_with_mean
        test_array = np.array([1.2, np.nan, 3.2, np.nan, np.nan])
        result = replace_nan_with_mean(test_array, means=None)[0]
        expectation = np.array([1.2, 2.2, 3.2, 2.2, 2.2], dtype=float)
        self.assertItemsEqual(result, expectation)

    def test_create_and_predict_segment(self):
        """test segmentation.test_create_and_predict"""
        from crankshaft.segmentation import replace_nan_with_mean
        results = []
        feature_columns = ['m1', 'm2']
        feat = np.column_stack([np.array(self.model_data[0][col])
                                for col in feature_columns]).astype(float)
        feature_means = replace_nan_with_mean(feat)[1]

        # data_model is of the form:
        #  [OrderedDict([('target', target),
        #                ('features', feat),
        #                ('target_mean', target_mean),
        #                ('feature_means', feature_means),
        #                ('feature_columns', feature_columns)])]
        data_model = self.model_data
        cursor = self.predict_data
        batch = []

        batches = np.row_stack([np.array(row['features'])
                                for row in cursor]).astype(float)
        batches = replace_nan_with_mean(batches, feature_means)[0]
        batch.append(batches)

        data_predict = [OrderedDict([('features', d['features']),
                                     ('batch', batch)])
                        for d in self.predict_data]
        data_predict = MockCursor(data_predict)

        model_parameters = {
            'n_estimators': 1200,
            'max_depth': 3,
            'subsample': 0.5,
            'learning_rate': 0.01,
            'min_samples_leaf': 1
        }
        data = [OrderedDict([('ids', d['ids'])])
                for d in self.data]

        seg = Segmentation(RawDataProvider(data, data_model,
                                           data_predict))

        result = seg.create_and_predict_segment(
            'SELECT * FROM segmentation_test',
            'x_value',
            ['m1', 'm2'],
            'SELECT * FROM segmentation_result',
            model_parameters,
            id_col='cartodb_id')
        results = [(row[1], row[2]) for row in result]
        zipped_values = zip(results, self.result_seg)
        pre_res = [r[0] for r in self.true_result]
        acc_res = [r[1] for r in self.result_seg]

        # test values
        for (res_pre, _), (exp_pre, _) in zipped_values:
            diff = abs(res_pre - exp_pre) / np.mean([res_pre, exp_pre])
            self.assertTrue(diff <= 0.05, msg='diff: {}'.format(diff))
            diff = abs(res_pre - exp_pre) / np.mean([res_pre, exp_pre])
            self.assertTrue(diff <= 0.05, msg='diff: {}'.format(diff))
        prediction = [r[0] for r in results]

        accuracy = np.sqrt(np.mean(
            (np.array(prediction) - np.array(pre_res))**2
        ))

        self.assertEqual(len(results), len(self.result_seg))
        self.assertTrue(accuracy < 0.3 * np.mean(pre_res))
        self.assertTrue(results[0][1] < 0.01)
