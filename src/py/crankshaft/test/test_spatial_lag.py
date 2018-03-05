import unittest
import numpy as np

from helper import fixture_file
from crankshaft.spatial_lag import SpatialLag
from crankshaft.analysis_data_provider import AnalysisDataProvider
import crankshaft.pysal_utils as pu
from crankshaft import random_seeds
import json
from collections import OrderedDict


class FakeDataProvider(AnalysisDataProvider):
    """Data provider for existing parsed data"""
    def __init__(self, mock_data):
        self.mock_result = mock_data

    def get_neighbor(self, w_type, params):  # pylint: disable=unused-argument
        """mock get_neighbor"""
        return self.mock_result


class SpatialLagTest(unittest.TestCase):
    """Testing class for Spatial Lag function"""

    def setUp(self):
        self.params = {"id_col": "cartodb_id",
                       "attr1": "mehak",
                       "subquery": "SELECT * FROM m_list",
                       "geom_col": "the_geom",
                       "num_ngbrs": 10}
        self.neighbors_data = json.loads(
            open(fixture_file('lag_data.json')).read())
        self.lag_result = json.loads(
            open(fixture_file('lag_result.json')).read())

    def test_local_stat(self):
        """Test Spatial Lag function"""
        data = [OrderedDict([('id', d['id']),
                             ('attr1', d['value']),
                             ('neighbors', d['neighbors'])])
                for d in self.neighbors_data]

        spatial = SpatialLag(FakeDataProvider(data))
        result = spatial.spatial_lag('subquery', 'value',
                                     'knn', 5, 'the_geom', 'cartodb_id')
        result = [(row[0], row[1]) for row in result]
        zipped_values = zip(result, self.lag_result)

        for ([res_lag, _], [_, exp_lag]) in zipped_values:
            self.assertEqual(res_lag, exp_lag)
