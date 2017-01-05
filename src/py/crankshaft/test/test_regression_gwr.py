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
                SELECT array_agg(ST_X(ST_Centroid(the_geom))) As x,
                       array_agg(ST_Y(ST_Centroid(the_geom))) As y,
                       array_agg(pctbach) As dep_var,
                       array_agg(pctpov) As attr1,
                       array_agg(pcteld) As attr2,
                       array_agg(pctrural) As attr3,
                       array_agg(pctfb) As attr4,
                       array_agg(pctblack) As attr5,
                       array_agg(cartodb_id) As rowid
                FROM g_utm
                WHERE pctbach is not NULL AND
                      pctpov IS NOT NULL AND
                      pcteld IS NOT NULL AND
                      pctrural IS NOT NULL AND
                      pctfb IS NOT NULL AND
                      pctblack IS NOT NULL
        """
        self.data = json.loads(
              open(fixture_file('gwr_packed_data.json')).read())
        self.knowns = json.loads(
              open(fixture_file('gwr_packed_knowns.json')).read())
        self.params = {'subquery': 'select * from table',
                       'dep_var': 'pctbach',
                       'ind_vars': ['pctpov', 'pcteld', 'pctrural', 'pctfb',
                                    'pctblack'],
                       'bw': 90.000,
                       'fixed': False}

    def test_gwr(self):
        """
        """

        gwr = GWR(FakeDataProvider(self.data))
        gwr_resp = gwr.gwr(self.params['subquery'], self.params['dep_var'],
                           self.params['ind_vars'], bw=self.params['bw'],
                           fixed=self.params['fixed'])

        # unpack response
        coeffs, stand_errs, t_vals, predicteds, residuals, r_squareds, bws, rowids = zip(*gwr_resp)

        # known_coeffs = self.knowns['coeffs']
        pctpov_coeff = self.knowns['est_pctpov']
        pctpov_se = self.knowns['se_pctpov']
        ids = self.knowns['area_key']
        resp_idx = None

        print sorted(pctpov_coeff[:10])
        print sorted(
                [json.loads(coeffs[i])['pctpov']
                 for i in xrange(len(coeffs))][:10])

        for idx, val in enumerate(pctpov_coeff):
            print idx, val, ids[idx], rowids[rowids.index(ids[idx])]
            resp_idx = rowids.index(ids[idx])
            if resp_idx is None:
                print('missed lookup on {0}'.format(ids[idx]))
            print('comparison: %f, %f' % (val, json.loads(coeffs[resp_idx])['pctpov']))
            # print('comparison: %f, %f' % (pctpov_se[idx], ))
            # self.assertAlmostEquals(val, coeffs[resp_idx])

        assert False

        # labels = [a[1] for a in clusters]
        # c1 = [a for a in clusters if a[1] == 0]
        # c2 = [a for a in clusters if a[1] == 1]
        #
        # self.assertEqual(len(np.unique(labels)), 2)
        # self.assertEqual(len(c1), 20)
        # self.assertEqual(len(c2), 20)
