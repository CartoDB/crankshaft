"""Unit tests for the optimizaiton module"""

import unittest
import numpy as np

from crankshaft.optimization import Optim
from crankshaft.analysis_data_provider import AnalysisDataProvider
import cvxopt

# suppress cvxopt GLPK messages
cvxopt.glpk.options['msg_lev'] = 'GLP_MSG_OFF'


class RawDataProvider(AnalysisDataProvider):
    """Raw data provider for testing purposes"""
    def __init__(self, raw_data):
        self.raw_data = raw_data

    def get_column(self, table, column, dtype=float):
        """Returns requested 'column' of data"""
        if column != 'cartodb_id':
            return np.array(self.raw_data[column], dtype=dtype)
        elif table == 'drain_table':
            return np.arange(1, len(self.raw_data['capacity_col']) + 1)
        elif table == 'source_table':
            return np.arange(1, len(self.raw_data['production_col']) + 1)

    def get_pairwise_distances(self, _source, _drain):
        """Returns pairwise distances"""
        return np.array(self.raw_data['pairwise'], dtype=float)


class OptimTest(unittest.TestCase):
    """Testing class for Optimization module"""

    def setUp(self):
        # self.data = json.loads(
        #     open(fixture_file('optim.json')).read())
        # capacity ~ 0.01 * production given waste_per_person of 0.01
        # so capacity_col = [9, 31] / 100
        self.data = {
            'all_right': {"production_col": [10, 10, 10],
                          "capacity_col": [0.09, 0.31],
                          "marginal_col": [5, 5],
                          "pairwise": [[1, 2, 3], [3, 2, 1]]},
            'all_left': {"production_col": [10, 10, 10],
                         "capacity_col": [0.31, 0.09],
                         "marginal_col": [5, 5],
                         "pairwise": [[1, 2, 3], [3, 2, 1]]},
            '2left': {"production_col": [10, 10, 10],
                      "capacity_col": [0.21, 0.11],
                      "marginal_col": [5, 5],
                      "pairwise": [[1, 2, 3], [3, 2, 1]]},
            'infeasible': {"production_col": [10, 10, 10],
                           "capacity_col": [0.19, 0.11],
                           "marginal_col": [5, 5],
                           "pairwise": [[1, 2, 3], [3, 2, 1]]}}

        self.params = {'waste_per_person': 0.01,
                       'recycle_rate': 0.0,
                       'dist_rate': 0.15,
                       'dist_threshold': None,
                       'data_provider': None}
        self.args = ('drain_table', 'source_table',
                     'capacity_col', 'production_col',
                     'marginal_col')

        # print(self.model_data)
        # print(self.model_params)

    def test_optim_output(self):
        """Test Optim().output"""
        outputs = {'all_right': [2, 2, 2],
                   'all_left': [1, 1, 1],
                   '2left': [1, 1, 2],
                   'infeasible': None}
        for k in self.data:
            if k == 'infeasible':
                continue
            self.params['data_provider'] = RawDataProvider(self.data[k])
            optim = Optim(*self.args, **self.params)
            out_vals = optim.output()
            drain_ids = [row[0] for row in out_vals]
            print(drain_ids)
            print(k)
            self.assertTrue(drain_ids == outputs[k])

        return True

    def test_check_constraints(self):
        """Test optim._check_constraints"""
        for k in self.data:
            self.params['data_provider'] = RawDataProvider(self.data[k])
            print(k)
            try:
                optim = Optim(*self.args, **self.params)
                # pylint: disable=protected-access
                constraint_check = optim._check_constraints() is None
            except ValueError as err:
                # if infeasible, catch and say it's acceptable
                print(k)
                if k == 'infeasible':
                    constraint_check = True
                    print(constraint_check)
                else:
                    raise ValueError(err)
            self.assertTrue(constraint_check)

    # def test_check_model_params(self):
    #     """Test model param defaults are correctly formed"""
    #     for k in self.data:
    #         self.params['data_provider'] = RawDataProvider(self.data[k])
    #         optim = Optim(*self.args, **self.params)
    #         # pylint: disable=protected-access
    #         model_check = optim._check_model_params() is None
    #         self.assertTrue(model_check)

    def test_optim(self):
        """Test optim.optim method"""
        # assert False
        pass
