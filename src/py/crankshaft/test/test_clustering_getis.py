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

class GetisTest(unittest.TestCase):
    """Testing class for Getis-Ord's G funtion"""

    def setUp(self):
        plpy._reset()
        self.neighbors_data = json.loads(open(fixture_file('neighbors_getis.json')).read())
        self.getis_data = json.loads(open(fixture_file('getis.json')).read())

    def test_getis_ord(self):
        """Test Getis-Ord's G*"""
        data = [ { 'id': d['id'],
                   'attr1': d['value'],
                   'neighbors': d['neighbors'] } for d in self.neighbors_data]
        plpy._define_result('select', data)
        random_seeds.set_random_seeds(1234)
        result = cc.getis_ord('subquery', 'value', 'knn', 5, 999, 'the_geom', 'cartodb_id')
        result = [(row[0], row[1]) for row in result]
        expected = np.array(self.getis_data)[:, 0:2]
        for ([res_z, res_p], [exp_z, exp_p]) in zip(result, expected):
            self.assertAlmostEqual(res_z, exp_z, delta=1e-2)
            self.assertAlmostEqual(res_p, exp_p, delta=1e-2)
