import unittest
import numpy as np


from helper import fixture_file
from crankshaft.clustering import Kmeans
from crankshaft.analysis_data_provider import AnalysisDataProvider
import crankshaft.clustering as cc
from crankshaft import random_seeds

import json
from collections import OrderedDict


class FakeDataProvider(AnalysisDataProvider):
    def __init__(self, mocked_result):
        self.mocked_result = mocked_result

    def get_spatial_kmeans(self, query):
        return self.mocked_result

    def get_nonspatial_kmeans(self, query):
        return self.mocked_result


class KMeansTest(unittest.TestCase):
    """Testing class for k-means spatial"""

    def setUp(self):
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

        random_seeds.set_random_seeds(1234)
        kmeans = Kmeans(FakeDataProvider(data))
        clusters = kmeans.spatial('subquery', 2)
        labels = [a[1] for a in clusters]
        c1 = [a for a in clusters if a[1] == 0]
        c2 = [a for a in clusters if a[1] == 1]

        self.assertEqual(len(np.unique(labels)), 2)
        self.assertEqual(len(c1), 20)
        self.assertEqual(len(c2), 20)


class KMeansNonspatialTest(unittest.TestCase):
    """Testing class for k-means non-spatial"""

    def setUp(self):
        self.params = {"subquery": "SELECT * FROM TABLE",
                       "n_clusters": 5}

    def test_kmeans_nonspatial(self):
        """
            test for k-means non-spatial
        """
        # data from:
        # http://scikit-learn.org/stable/modules/generated/sklearn.cluster.KMeans.html#sklearn-cluster-kmeans
        data_raw = [OrderedDict([("arr_col1", [1, 1, 1, 4, 4, 4]),
                                 ("arr_col2", [2, 4, 0, 2, 4, 0]),
                                 ("rowid", [1, 2, 3, 4, 5, 6])])]

        random_seeds.set_random_seeds(1234)
        kmeans = Kmeans(FakeDataProvider(data_raw))
        clusters = kmeans.nonspatial('subquery', ['col1', 'col2'], 2)

        cl1 = clusters[0][0]
        cl2 = clusters[3][0]

        for idx, val in enumerate(clusters):
            if idx < 3:
                self.assertEqual(val[0], cl1)
            else:
                self.assertEqual(val[0], cl2)

        # raises exception for no data
        with self.assertRaises(Exception):
            kmeans = Kmeans(FakeDataProvider([]))
            kmeans.nonspatial('subquery', ['col1', 'col2'], 2)
