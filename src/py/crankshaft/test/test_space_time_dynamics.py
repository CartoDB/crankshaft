import unittest
import numpy as np

import unittest


from helper import fixture_file

from crankshaft.space_time_dynamics import Markov
import crankshaft.space_time_dynamics as std
from crankshaft import random_seeds
from crankshaft.analysis_data_provider import AnalysisDataProvider
import json


class FakeDataProvider(AnalysisDataProvider):
    def __init__(self, data):
        self.mock_result = data

    def get_markov(self, w_type, params):
        return self.mock_result


class SpaceTimeTests(unittest.TestCase):
    """Testing class for Markov Functions."""

    def setUp(self):
        self.params = {"id_col": "cartodb_id",
                       "time_cols": ['dec_2013', 'jan_2014', 'feb_2014'],
                       "subquery": "SELECT * FROM a_list",
                       "geom_col": "the_geom",
                       "num_ngbrs": 321}
        self.neighbors_data = json.loads(
          open(fixture_file('neighbors_markov.json')).read())
        self.markov_data = json.loads(open(fixture_file('markov.json')).read())

        self.time_data = np.array([i * np.ones(10, dtype=float)
                                   for i in range(10)]).T

        self.transition_matrix = np.array([
                [[0.96341463, 0.0304878, 0.00609756, 0., 0.],
                 [0.06040268, 0.83221477, 0.10738255, 0., 0.],
                 [0., 0.14, 0.74, 0.12, 0.],
                 [0., 0.03571429, 0.32142857, 0.57142857, 0.07142857],
                 [0., 0., 0., 0.16666667, 0.83333333]],
                [[0.79831933, 0.16806723, 0.03361345, 0., 0.],
                 [0.0754717, 0.88207547, 0.04245283, 0., 0.],
                 [0.00537634, 0.06989247, 0.8655914, 0.05913978, 0.],
                 [0., 0., 0.06372549, 0.90196078, 0.03431373],
                 [0., 0., 0., 0.19444444, 0.80555556]],
                [[0.84693878, 0.15306122, 0., 0., 0.],
                 [0.08133971, 0.78947368, 0.1291866, 0., 0.],
                 [0.00518135, 0.0984456, 0.79274611, 0.0984456, 0.00518135],
                 [0., 0., 0.09411765, 0.87058824, 0.03529412],
                 [0., 0., 0., 0.10204082, 0.89795918]],
                [[0.8852459, 0.09836066, 0., 0.01639344, 0.],
                 [0.03875969, 0.81395349, 0.13953488, 0., 0.00775194],
                 [0.0049505, 0.09405941, 0.77722772, 0.11881188, 0.0049505],
                 [0., 0.02339181, 0.12865497, 0.75438596, 0.09356725],
                 [0., 0., 0., 0.09661836, 0.90338164]],
                [[0.33333333, 0.66666667, 0., 0., 0.],
                 [0.0483871, 0.77419355, 0.16129032, 0.01612903, 0.],
                 [0.01149425, 0.16091954, 0.74712644, 0.08045977, 0.],
                 [0., 0.01036269, 0.06217617, 0.89637306, 0.03108808],
                 [0., 0., 0., 0.02352941, 0.97647059]]]
                 )

    def test_spatial_markov(self):
        """Test Spatial Markov."""
        data = [{'id': d['id'],
                 'attr1': d['y1995'],
                 'attr2': d['y1996'],
                 'attr3': d['y1997'],
                 'attr4': d['y1998'],
                 'attr5': d['y1999'],
                 'attr6': d['y2000'],
                 'attr7': d['y2001'],
                 'attr8': d['y2002'],
                 'attr9': d['y2003'],
                 'attr10': d['y2004'],
                 'attr11': d['y2005'],
                 'attr12': d['y2006'],
                 'attr13': d['y2007'],
                 'attr14': d['y2008'],
                 'attr15': d['y2009'],
                 'neighbors': d['neighbors']} for d in self.neighbors_data]
        # print(str(data[0]))
        markov = Markov(FakeDataProvider(data))
        random_seeds.set_random_seeds(1234)

        result = markov.spatial_trend('subquery',
                                      ['y1995', 'y1996', 'y1997', 'y1998',
                                       'y1999', 'y2000', 'y2001', 'y2002',
                                       'y2003', 'y2004', 'y2005', 'y2006',
                                       'y2007', 'y2008', 'y2009'],
                                      5, 'knn', 5, 0, 'the_geom',
                                      'cartodb_id')

        self.assertTrue(result is not None)
        result = [(row[0], row[1], row[2], row[3], row[4]) for row in result]
        print result[0]
        expected = self.markov_data
        for ([res_trend, res_up, res_down, res_vol, res_id],
             [exp_trend, exp_up, exp_down, exp_vol, exp_id]
             ) in zip(result, expected):
            self.assertAlmostEqual(res_trend, exp_trend)

    def test_get_prob_dist(self):
        """Test get_prob_dist"""
        lag_indices = np.array([1, 2, 3, 4])
        unit_indices = np.array([1, 3, 2, 4])
        answer = np.array([
            [0.0754717, 0.88207547, 0.04245283, 0., 0.],
            [0., 0., 0.09411765, 0.87058824, 0.03529412],
            [0.0049505, 0.09405941, 0.77722772, 0.11881188, 0.0049505],
            [0., 0., 0., 0.02352941, 0.97647059]
        ])
        result = std.get_prob_dist(self.transition_matrix,
                                   lag_indices, unit_indices)

        self.assertTrue(np.array_equal(result, answer))

    def test_get_prob_stats(self):
        """Test get_prob_stats"""

        probs = np.array([
            [0.0754717, 0.88207547, 0.04245283, 0., 0.],
            [0., 0., 0.09411765, 0.87058824, 0.03529412],
            [0.0049505, 0.09405941, 0.77722772, 0.11881188, 0.0049505],
            [0., 0., 0., 0.02352941, 0.97647059]
        ])
        unit_indices = np.array([1, 3, 2, 4])
        answer_up = np.array([0.04245283, 0.03529412, 0.12376238, 0.])
        answer_down = np.array([0.0754717, 0.09411765, 0.0990099, 0.02352941])
        answer_trend = np.array([-0.03301887 / 0.88207547,
                                 -0.05882353 / 0.87058824,
                                 0.02475248 / 0.77722772,
                                 -0.02352941 / 0.97647059])
        answer_volatility = np.array([0.34221495,  0.33705421,
                                      0.29226542,  0.38834223])

        result = std.get_prob_stats(probs, unit_indices)
        result_up = result[0]
        result_down = result[1]
        result_trend = result[2]
        result_volatility = result[3]

        self.assertTrue(np.allclose(result_up, answer_up))
        self.assertTrue(np.allclose(result_down, answer_down))
        self.assertTrue(np.allclose(result_trend, answer_trend))
        self.assertTrue(np.allclose(result_volatility, answer_volatility))
