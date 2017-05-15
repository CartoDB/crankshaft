import unittest
import numpy as np


# from mock_plpy import MockPlPy
# plpy = MockPlPy()
#
# import sys
# sys.modules['plpy'] = plpy
from helper import fixture_file
from crankshaft.clustering import MaxP
from crankshaft.analysis_data_provider import AnalysisDataProvider
import crankshaft.clustering as cc

from crankshaft import random_seeds
import json
from collections import OrderedDict


class FakeDataProvider(AnalysisDataProvider):
    def __init__(self, fixturedata):
        self.your_maxp_data = fixturedata

    def get_maxp(self, params):
        """
          Replace this function name with the one used in your algorithm,
          and make sure to use the same function signature that is written
          for this algo in analysis_data_provider.py
        """
        return self.your_maxp_data

class MaxPTest(unittest.TestCase):
    """Testing class for max-p regionalization"""

    def setUp(self):
        self.neighbor_data = json.loads(
          open(fixture_file('maxp.json')).read())
        self.neighbor_data = self.neighbor_data['rows']
        self.params = {"subquery": "select * from fake_table",
                       "colnames": ['population','median_hh_income'],
                       "floor_variable": 'population',
                       "floor": 260000}

    def test_maxp(self):
        """
        """
        data = [{'id': d['id'],
                 'attr1': d['attr1'],
                 'attr2':d['attr2'],
                 'neighbors': d['neighbors']} for d in self.neighbor_data]

        random_seeds.set_random_seeds(1234)
        maxp = MaxP(FakeDataProvider(data))
        regions = maxp.maxp('select * from research_nothing',['population','median_hh_income'],floor_variable='population',floor=260000)
        region_labels = [a[0] for a in regions]
        data_regionalized = zip(data,region_labels)
        for i in set(region_labels):
            sum_pop = 0
            for n in data_regionalized:
                if n[1] == i:
                    sum_pop += n[0]['attr1']
            self.assertGreaterEqual(sum_pop, 260000)
