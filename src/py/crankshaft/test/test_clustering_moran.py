import unittest
import numpy as np

from helper import fixture_file
from crankshaft.clustering import Moran
from crankshaft.analysis_data_provider import AnalysisDataProvider
import crankshaft.pysal_utils as pu
from crankshaft import random_seeds
import json
from collections import OrderedDict


class FakeDataProvider(AnalysisDataProvider):
    def __init__(self, mock_data):
        self.mock_result = mock_data

    def get_moran(self, w_type, params):
        return self.mock_result


class MoranTest(unittest.TestCase):
    """Testing class for Moran's I functions"""

    def setUp(self):
        self.params = {"id_col": "cartodb_id",
                       "attr1": "andy",
                       "attr2": "jay_z",
                       "subquery": "SELECT * FROM a_list",
                       "geom_col": "the_geom",
                       "num_ngbrs": 321}
        self.params_markov = {"id_col": "cartodb_id",
                              "time_cols": ["_2013_dec", "_2014_jan",
                                            "_2014_feb"],
                              "subquery": "SELECT * FROM a_list",
                              "geom_col": "the_geom",
                              "num_ngbrs": 321}
        self.neighbors_data = json.loads(
          open(fixture_file('neighbors.json')).read())
        self.moran_data = json.loads(
          open(fixture_file('moran.json')).read())

    def test_map_quads(self):
        """Test map_quads"""
        from crankshaft.clustering import map_quads
        self.assertEqual(map_quads(1), 'HH')
        self.assertEqual(map_quads(2), 'LH')
        self.assertEqual(map_quads(3), 'LL')
        self.assertEqual(map_quads(4), 'HL')
        self.assertEqual(map_quads(33), None)
        self.assertEqual(map_quads('andy'), None)

    def test_quad_position(self):
        """Test lisa_sig_vals"""
        from crankshaft.clustering import quad_position

        quads = np.array([1, 2, 3, 4], np.int)

        ans = np.array(['HH', 'LH', 'LL', 'HL'])
        test_ans = quad_position(quads)

        self.assertTrue((test_ans == ans).all())

    def test_local_stat(self):
        """Test Moran's I local"""
        data = [OrderedDict([('id', d['id']),
                             ('attr1', d['value']),
                             ('neighbors', d['neighbors'])])
                for d in self.neighbors_data]

        moran = Moran(FakeDataProvider(data))
        random_seeds.set_random_seeds(1234)
        result = moran.local_stat('subquery', 'value',
                                  'knn', 5, 99, 'the_geom', 'cartodb_id')
        result = [(row[0], row[1]) for row in result]
        zipped_values = zip(result, self.moran_data)

        for ([res_val, res_quad], [exp_val, exp_quad]) in zipped_values:
            self.assertAlmostEqual(res_val, exp_val)
            self.assertEqual(res_quad, exp_quad)

    def test_moran_local_rate(self):
        """Test Moran's I rate"""
        data = [{'id': d['id'],
                 'attr1': d['value'],
                 'attr2': 1,
                 'neighbors': d['neighbors']} for d in self.neighbors_data]

        random_seeds.set_random_seeds(1234)
        moran = Moran(FakeDataProvider(data))
        result = moran.local_rate_stat('subquery', 'numerator', 'denominator',
                                       'knn', 5, 99, 'the_geom', 'cartodb_id')
        result = [(row[0], row[1]) for row in result]

        zipped_values = zip(result, self.moran_data)

        for ([res_val, res_quad], [exp_val, exp_quad]) in zipped_values:
            self.assertAlmostEqual(res_val, exp_val)

    def test_moran(self):
        """Test Moran's I global"""
        data = [{'id': d['id'],
                 'attr1': d['value'],
                 'neighbors': d['neighbors']} for d in self.neighbors_data]
        random_seeds.set_random_seeds(1235)
        moran = Moran(FakeDataProvider(data))
        result = moran.global_stat('table', 'value',
                                   'knn', 5, 99, 'the_geom',
                                   'cartodb_id')

        result_moran = result[0][0]
        expected_moran = np.array([row[0] for row in self.moran_data]).mean()
        self.assertAlmostEqual(expected_moran, result_moran, delta=10e-2)
