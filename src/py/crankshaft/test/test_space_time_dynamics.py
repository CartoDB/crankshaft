import unittest
import numpy as np

import unittest


# from mock_plpy import MockPlPy
# plpy = MockPlPy()
#
# import sys
# sys.modules['plpy'] = plpy
from helper import plpy, fixture_file

import crankshaft.space_time_dynamics as std
from crankshaft import random_seeds
import json

class SpaceTimeTests(unittest.TestCase):
    """Testing class for Markov Functions."""

    def setUp(self):
        plpy._reset()
        self.params = {"id_col": "cartodb_id",
                       "time_cols": ['dec_2013', 'jan_2014', 'feb_2014'],
                       "subquery": "SELECT * FROM a_list",
                       "geom_col": "the_geom",
                       "num_ngbrs": 321}
        self.neighbors_data = json.loads(open(fixture_file('neighbors_markov.json')).read())
        # self.moran_data = json.loads(open(fixture_file('markov.json')).read())

        self.time_data = np.array([i * np.ones(10, dtype=float) for i in range(10)]).T

        self.transition_matrix = np.array([
                [[ 0.96341463, 0.0304878 , 0.00609756, 0.        , 0.        ],
                 [ 0.06040268, 0.83221477, 0.10738255, 0.        , 0.        ],
                 [ 0.        , 0.14      , 0.74      , 0.12      , 0.        ],
                 [ 0.        , 0.03571429, 0.32142857, 0.57142857, 0.07142857],
                 [ 0.        , 0.        , 0.        , 0.16666667, 0.83333333]],
                [[ 0.79831933, 0.16806723, 0.03361345, 0.        , 0.        ],
                 [ 0.0754717 , 0.88207547, 0.04245283, 0.        , 0.        ],
                 [ 0.00537634, 0.06989247, 0.8655914 , 0.05913978, 0.        ],
                 [ 0.        , 0.        , 0.06372549, 0.90196078, 0.03431373],
                 [ 0.        , 0.        , 0.        , 0.19444444, 0.80555556]],
                [[ 0.84693878, 0.15306122, 0.        , 0.        , 0.        ],
                 [ 0.08133971, 0.78947368, 0.1291866 , 0.        , 0.        ],
                 [ 0.00518135, 0.0984456 , 0.79274611, 0.0984456 , 0.00518135],
                 [ 0.        , 0.        , 0.09411765, 0.87058824, 0.03529412],
                 [ 0.        , 0.        , 0.        , 0.10204082, 0.89795918]],
                [[ 0.8852459 , 0.09836066, 0.        , 0.01639344, 0.        ],
                 [ 0.03875969, 0.81395349, 0.13953488, 0.        , 0.00775194],
                 [ 0.0049505 , 0.09405941, 0.77722772, 0.11881188, 0.0049505 ],
                 [ 0.        , 0.02339181, 0.12865497, 0.75438596, 0.09356725],
                 [ 0.        , 0.        , 0.        , 0.09661836, 0.90338164]],
                [[ 0.33333333, 0.66666667, 0.        , 0.        , 0.        ],
                 [ 0.0483871 , 0.77419355, 0.16129032, 0.01612903, 0.        ],
                 [ 0.01149425, 0.16091954, 0.74712644, 0.08045977, 0.        ],
                 [ 0.        , 0.01036269, 0.06217617, 0.89637306, 0.03108808],
                 [ 0.        , 0.        , 0.        , 0.02352941, 0.97647059]]]
                 )

    def test_spatial_markov(self):
        """Test Spatial Markov."""
        data = [ { 'id': d['id'],
                   'attr1': d['y1929'],
                   'attr2': d['y1930'],
                   'attr3': d['y1931'],
                   'neighbors': d['neighbors'] } for d in self.neighbors_data]

        plpy._define_result('select', data)
        random_seeds.set_random_seeds(1234)

        result = std.spatial_markov_trend('subquery', ['y1929', 'y1930', 'y1931', 'y1932', 'y1933', 'y1934', 'y1935', 'y1936', 'y1937', 'y1938', 'y1939'], 1, 99, 'the_geom', 'cartodb_id', 'knn', 5)

        print 'result == None? ', result == None
        result = [(row[0], row[1]) for row in result]
        print result[0]
        assertTrue(result[0] == None)
        # expected = self.moran_data
        # for ([res_val, res_quad], [exp_val, exp_quad]) in zip(result, expected):
        #     self.assertAlmostEqual(res_val, exp_val)



    def test_rebin_data(self):
        """Test rebin_data"""
        ## sample in double the time (even case since 10 % 2 = 0):
        ##   (0+1)/2, (2+3)/2, (4+5)/2, (6+7)/2, (8+9)/2
        ## = 0.5,     2.5,     4.5,     6.5,     8.5
        ans_even = np.array([(i + 0.5) * np.ones(10, dtype=float)
                             for i in range(0, 10, 2)]).T

        self.assertTrue(np.array_equal(std.rebin_data(self.time_data, 2), ans_even))

        ## sample in triple the time (uneven since 10 % 3 = 1):
        ##   (0+1+2)/3, (3+4+5)/3, (6+7+8)/3, (9)/1
        ## = 1,         4,         7,         9
        ans_odd  = np.array([i * np.ones(10, dtype=float)
                             for i in (1, 4, 7, 9)]).T
        self.assertTrue(np.array_equal(std.rebin_data(self.time_data, 3), ans_odd))

    def test_get_prob_dist(self):
        """Test get_prob_dist"""
        lag_indices = np.array([1, 2, 3, 4])
        unit_indices = np.array([1, 3, 2, 4])
        answer = np.array([
            [ 0.0754717 , 0.88207547, 0.04245283, 0.        , 0.        ],
            [ 0.        , 0.        , 0.09411765, 0.87058824, 0.03529412],
            [ 0.0049505 , 0.09405941, 0.77722772, 0.11881188, 0.0049505 ],
            [ 0.        , 0.        , 0.        , 0.02352941, 0.97647059]
        ])
        result = std.get_prob_dist(self.transition_matrix, lag_indices, unit_indices)

        self.assertTrue(np.array_equal(result, answer))

    def test_get_prob_stats(self):
        """Test get_prob_stats"""

        probs = np.array([
            [ 0.0754717 , 0.88207547, 0.04245283, 0.        , 0.        ],
            [ 0.        , 0.        , 0.09411765, 0.87058824, 0.03529412],
            [ 0.0049505 , 0.09405941, 0.77722772, 0.11881188, 0.0049505 ],
            [ 0.        , 0.        , 0.        , 0.02352941, 0.97647059]
        ])
        unit_indices = np.array([1, 3, 2, 4])
        answer_up = np.array([0.04245283, 0.03529412, 0.12376238, 0.])
        answer_down = np.array([0.0754717, 0.09411765, 0.0990099, 0.02352941])
        answer_trend = np.array([-0.03301887 / 0.88207547, -0.05882353 / 0.87058824,  0.02475248 / 0.77722772, -0.02352941 / 0.97647059])
        answer_volatility = np.array([ 0.34221495,  0.33705421,  0.29226542,  0.38834223])

        result = std.get_prob_stats(probs, unit_indices)
        result_up = result[0]
        result_down = result[1]
        result_trend = result[2]
        result_volatility = result[3]

        self.assertTrue(np.allclose(result_up, answer_up))
        self.assertTrue(np.allclose(result_down, answer_down))
        self.assertTrue(np.allclose(result_trend, answer_trend))
        self.assertTrue(np.allclose(result_volatility, answer_volatility))
