import unittest
import numpy as np


# from mock_plpy import MockPlPy
# plpy = MockPlPy()
#
# import sys
# sys.modules['plpy'] = plpy
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

    def get_nonspatial_kmeans(self, query, standarize):
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
