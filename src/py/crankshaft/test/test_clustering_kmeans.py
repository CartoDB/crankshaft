import unittest
import numpy as np


# from mock_plpy import MockPlPy
# plpy = MockPlPy()
#
# import sys
# sys.modules['plpy'] = plpy
from helper import plpy, fixture_file
import crankshaft.clustering as cc
import json


class KMeansTest(unittest.TestCase):
    """Testing class for k-means spatial"""

    def setUp(self):
        plpy._reset()
        self.cluster_data = json.loads(
          open(fixture_file('kmeans.json')).read())
        self.params = {"subquery": "select * from table",
                       "no_clusters": "10"}

    def test_kmeans(self):
        """
        """
        data = [{'xs': d['xs'],
                 'ys': d['ys'],
                 'id': d['id']} for d in self.cluster_data]

        plpy._define_result('select', data)
        clusters = cc.kmeans('subquery', 2)
        labels = [a[1] for a in clusters]
        c1 = [a for a in clusters if a[1] == 0]
        c2 = [a for a in clusters if a[1] == 1]

        self.assertEqual(len(np.unique(labels)), 2)
        self.assertEqual(len(c1), 20)
        self.assertEqual(len(c2), 20)
