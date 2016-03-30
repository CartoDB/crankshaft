import unittest
import numpy as np


# from mock_plpy import MockPlPy
# plpy = MockPlPy()
#
# import sys
# sys.modules['plpy'] = plpy
from helper import plpy, fixture_file

import crankshaft.clustering as cc
import crankshaft.pysal_utils as pu
from crankshaft import random_seeds
import json

class MoranTest(unittest.TestCase):
    """Testing class for Moran's I functions"""

    def setUp(self):
        plpy._reset()
        self.params = {"id_col": "cartodb_id",
                       "attr1": "andy",
                       "attr2": "jay_z",
                       "subquery": "SELECT * FROM a_list",
                       "geom_col": "the_geom",
                       "num_ngbrs": 321}
        self.neighbors_data = json.loads(open(fixture_file('neighbors.json')).read())
        self.moran_data = json.loads(open(fixture_file('moran.json')).read())

    def test_map_quads(self):
        """Test map_quads"""
        self.assertEqual(cc.map_quads(1), 'HH')
        self.assertEqual(cc.map_quads(2), 'LH')
        self.assertEqual(cc.map_quads(3), 'LL')
        self.assertEqual(cc.map_quads(4), 'HL')
        self.assertEqual(cc.map_quads(33), None)
        self.assertEqual(cc.map_quads('andy'), None)

    def test_quad_position(self):
        """Test lisa_sig_vals"""

        quads = np.array([1, 2, 3, 4], np.int)

        ans = np.array(['HH', 'LH', 'LL', 'HL'])
        test_ans = cc.quad_position(quads)

        self.assertTrue((test_ans == ans).all())

    def test_moran_local(self):
        """Test Moran's I local"""
        data = [ { 'id': d['id'], 'attr1': d['value'], 'neighbors': d['neighbors'] } for d in self.neighbors_data]
        plpy._define_result('select', data)
        random_seeds.set_random_seeds(1234)
        result = cc.moran_local('subquery', 'value', 99, 'the_geom', 'cartodb_id', 'knn', 5)
        result = [(row[0], row[1]) for row in result]
        expected = self.moran_data
        for ([res_val, res_quad], [exp_val, exp_quad]) in zip(result, expected):
            self.assertAlmostEqual(res_val, exp_val)
            self.assertEqual(res_quad, exp_quad)

    def test_moran_local_rate(self):
        """Test Moran's I rate"""
        data = [ { 'id': d['id'], 'attr1': d['value'], 'attr2': 1, 'neighbors': d['neighbors'] } for d in self.neighbors_data]
        plpy._define_result('select', data)
        random_seeds.set_random_seeds(1234)
        result = cc.moran_local_rate('subquery', 'numerator', 'denominator', 99, 'the_geom', 'cartodb_id', 'knn', 5)
        print 'result == None? ', result == None
        result = [(row[0], row[1]) for row in result]
        expected = self.moran_data
        for ([res_val, res_quad], [exp_val, exp_quad]) in zip(result, expected):
            self.assertAlmostEqual(res_val, exp_val)

    def test_moran(self):
        """Test Moran's I global"""
        data = [{ 'id': d['id'], 'attr1': d['value'], 'neighbors': d['neighbors'] } for d in self.neighbors_data]
        plpy._define_result('select', data)
        random_seeds.set_random_seeds(1235)
        result = cc.moran('table', 'value', 99, 'the_geom', 'cartodb_id', 'knn', 5)
        print 'result == None?', result == None
        result_moran = result[0][0]
        expected_moran = np.array([row[0] for row in self.moran_data]).mean()
        self.assertAlmostEqual(expected_moran, result_moran, delta=10e-2)
