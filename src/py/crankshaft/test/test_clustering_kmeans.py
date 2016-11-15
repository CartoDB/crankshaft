import unittest
import numpy as np


# from mock_plpy import MockPlPy
# plpy = MockPlPy()
#
# import sys
# sys.modules['plpy'] = plpy
from helper import plpy, fixture_file, MockDBResponse
import crankshaft.clustering as cc
import json
from collections import OrderedDict


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
                 'ids': d['ids']} for d in self.cluster_data]

        plpy._define_result('select', data)
        clusters = cc.kmeans('subquery', 2)
        labels = [a[1] for a in clusters]
        c1 = [a for a in clusters if a[1] == 0]
        c2 = [a for a in clusters if a[1] == 1]

        self.assertEqual(len(np.unique(labels)), 2)
        self.assertEqual(len(c1), 20)
        self.assertEqual(len(c2), 20)


class KMeansNonspatialTest(unittest.TestCase):
    """Testing class for k-means non-spatial"""

    def setUp(self):
        plpy._reset()

        # self.cluster_data = json.loads(
        #     open(fixture_file('kmeans-nonspatial.json')).read())

        self.params = {"subquery": "SELECT * FROM TABLE",
                       "n_clusters": 5}

    def test_kmeans_nonspatial(self):
        """
            test for k-means non-spatial
        """
        data_raw = [OrderedDict([("col1", [1, 1, 1, 4, 4, 4]),
                                 ("col2", [2, 4, 0, 2, 4, 0]),
                                 ("rowids", [1, 2, 3, 4, 5, 6])])]

        data_obj = MockDBResponse(data_raw, [k for k in data_raw[0]
                                             if k != 'rowids'])
        plpy._define_result('select', data_obj)
        clusters = cc.kmeans_nonspatial('subquery', ['col1', 'col2'], 4)

        cl1 = clusters[0][1]
        cl2 = clusters[3][1]

        for idx, val in enumerate(clusters):
            if idx < 3:
                self.assertEqual(val[1], cl1)
            else:
                self.assertEqual(val[1], cl2)
