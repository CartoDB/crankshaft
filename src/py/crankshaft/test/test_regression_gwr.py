import unittest
import numpy as np

from helper import fixture_file
from crankshaft.regression import GWR
from crankshaft.analysis_data_provider import AnalysisDataProvider

from crankshaft import random_seeds
import json


class FakeDataProvider(AnalysisDataProvider):
    def __init__(self, mocked_result):
        self.mocked_result = mocked_result

    def get_gwr(self, params):
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
        self.data = json.loads(
              open(fixture_file('gwr_packed_data.json')).read())
        self.knowns = json.loads(
              open(fixture_file('gwr_packed_knowns.json')).read())
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
        gwr_resp = gwr.gwr(self.params['subquery'], self.params['dep_var'],
                           self.params['ind_vars'], bw=self.params['bw'],
                           fixed=self.params['fixed'])

        # unpack response
        coeffs, stand_errs, t_vals, t_vals_filtered, predicteds, residuals, r_squareds, bws, rowids = zip(*gwr_resp)

        # known_coeffs = self.knowns['coeffs']
        # data packed from https://github.com/TaylorOshan/pysal/blob/a44c5541e2e0d10a99ff05edc1b7f81b70f5a82f/pysal/examples/georgia/georgia_BS_NN_listwise.csv
        coeff_known_pctpov = self.knowns['est_pctpov']
        tval_known_pctblack = self.knowns['t_pctrural']
        pctpov_se = self.knowns['se_pctpov']
        ids = self.knowns['area_key']
        resp_idx = None

        print sorted(coeff_known_pctpov[:10])
        print sorted(
                [json.loads(coeffs[i])['pctpov']
                 for i in xrange(len(coeffs))][:10])
        with open('gwr_test_data.json', 'w') as f:
            print("writing to file")
            f.write(str(zip(rowids, coeffs)))

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
