import unittest
import json
import numpy as np


from crankshaft import random_seeds
from helper import fixture_file
from crankshaft.regression import GWR
from crankshaft.analysis_data_provider import AnalysisDataProvider


class FakeDataProvider(AnalysisDataProvider):
    def __init__(self, mocked_result):
        self.mocked_result = mocked_result

    def get_gwr(self, params):
        return self.mocked_result

    def get_gwr_predict(self, params):
        return self.mocked_result


class GWRTest(unittest.TestCase):
    """Testing class for geographically weighted regression (gwr)"""

    def setUp(self):
        """
            fixture packed from canonical GWR georgia dataset using the
            following query:
                SELECT array_agg(x) As x,
                       array_agg(y) As y,
                       array_agg(pctbach) As dep_var,
                       array_agg(pctrural) As attr1,
                       array_agg(pctpov) As attr2,
                       array_agg(pctblack) As attr3,
                       array_agg(areakey) As rowid
                FROM g_utm
                WHERE pctbach is not NULL AND
                      pctrural IS NOT NULL AND
                      pctpov IS NOT NULL AND
                      pctblack IS NOT NULL
        """
        import copy
        # data packed from https://github.com/TaylorOshan/pysal/blob/1d6af33bda46b1d623f70912c56155064463383f/pysal/examples/georgia/GData_utm.csv
        self.data = json.loads(
              open(fixture_file('gwr_packed_data.json')).read())

        # data packed from https://github.com/TaylorOshan/pysal/blob/a44c5541e2e0d10a99ff05edc1b7f81b70f5a82f/pysal/examples/georgia/georgia_BS_NN_listwise.csv
        self.knowns = json.loads(
              open(fixture_file('gwr_packed_knowns.json')).read())

        # data for GWR prediction
        self.data_predict = copy.deepcopy(self.data)
        self.ids_of_unknowns = [13083, 13009, 13281, 13115, 13247, 13169]
        self.idx_ids_of_unknowns = [self.data_predict[0]['rowid'].index(idx)
                                    for idx in self.ids_of_unknowns]

        for idx in self.idx_ids_of_unknowns:
            self.data_predict[0]['dep_var'][idx] = None

        self.predicted_knowns = {13009: 10.879,
                                 13083: 4.5259,
                                 13115: 9.4022,
                                 13169: 6.0793,
                                 13247: 8.1608,
                                 13281: 13.886}

        # params, with ind_vars in same ordering as query above
        self.params = {'subquery': 'select * from table',
                       'dep_var': 'pctbach',
                       'ind_vars': ['pctrural', 'pctpov', 'pctblack'],
                       'bw': 90.000,
                       'fixed': False,
                       'geom_col': 'the_geom',
                       'id_col': 'areakey'}

    def test_gwr(self):
        """
        """
        gwr = GWR(FakeDataProvider(self.data))
        gwr_resp = gwr.gwr(self.params['subquery'],
                           self.params['dep_var'],
                           self.params['ind_vars'],
                           bw=self.params['bw'],
                           fixed=self.params['fixed'])

        # unpack response
        coeffs, stand_errs, t_vals, t_vals_filtered, predicteds, \
            residuals, r_squareds, bws, rowids = zip(*gwr_resp)

        # prepare for comparision
        coeff_known_pctpov = self.knowns['est_pctpov']
        tval_known_pctblack = self.knowns['t_pctrural']
        pctpov_se = self.knowns['se_pctpov']
        ids = self.knowns['area_key']
        resp_idx = None

        # test pctpov coefficient estimates
        for idx, val in enumerate(coeff_known_pctpov):
            resp_idx = rowids.index(ids[idx])
            self.assertAlmostEquals(val,
                                    json.loads(coeffs[resp_idx])['pctpov'],
                                    places=4)
        # test pctrural tvals
        for idx, val in enumerate(tval_known_pctblack):
            resp_idx = rowids.index(ids[idx])
            self.assertAlmostEquals(val,
                                    json.loads(t_vals[resp_idx])['pctrural'],
                                    places=4)

    def test_gwr_predict(self):
        """Testing for GWR_Predict"""
        gwr = GWR(FakeDataProvider(self.data_predict))
        gwr_resp = gwr.gwr_predict(self.params['subquery'],
                                   self.params['dep_var'],
                                   self.params['ind_vars'],
                                   bw=self.params['bw'],
                                   fixed=self.params['fixed'])

        # unpack response
        coeffs, stand_errs, t_vals, \
            r_squareds, predicteds, rowid = zip(*gwr_resp)
        threshold = 0.01

        for i, idx in enumerate(self.idx_ids_of_unknowns):

            known_val = self.predicted_knowns[rowid[i]]
            predicted_val = predicteds[i]
            test_val = abs(known_val - predicted_val) / known_val
            self.assertTrue(test_val < threshold)
