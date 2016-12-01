import unittest
import numpy as np

from helper import fixture_file

from crankshaft.clustering import Getis
import crankshaft.pysal_utils as pu
from crankshaft import random_seeds
import json
from crankshaft.analysis_data_provider import AnalysisDataProvider

# Fixture files produced as follows
#
# import pysal as ps
# import numpy as np
# import random
#
# # setup variables
# f = ps.open(ps.examples.get_path("stl_hom.dbf"))
# y = np.array(f.by_col['HR8893'])
# w_queen = ps.queen_from_shapefile(ps.examples.get_path("stl_hom.shp"))
#
# out_queen = [{"id": index + 1,
#               "neighbors": [x+1 for x in w_queen.neighbors[index]],
#               "value": val} for index, val in enumerate(y)]
#
# with open('neighbors_queen_getis.json', 'w') as f:
#     f.write(str(out_queen))
#
# random.seed(1234)
# np.random.seed(1234)
# lgstar_queen = ps.esda.getisord.G_Local(y, w_queen, star=True,
#                                         permutations=999)
#
# with open('getis_queen.json', 'w') as f:
#     f.write(str(zip(lgstar_queen.z_sim,
#                     lgstar_queen.p_sim, lgstar_queen.p_z_sim)))


class FakeDataProvider(AnalysisDataProvider):
    def __init__(self, mock_data):
        self.mock_result = mock_data

    def get_getis(self, w_type, param):
        return self.mock_result


class GetisTest(unittest.TestCase):
    """Testing class for Getis-Ord's G* funtion
       This test replicates the work done in PySAL documentation:
          https://pysal.readthedocs.io/en/v1.11.0/users/tutorials/autocorrelation.html#local-g-and-g
    """

    def setUp(self):
        # load raw data for analysis
        self.neighbors_data = json.loads(
          open(fixture_file('neighbors_getis.json')).read())

        # load pre-computed/known values
        self.getis_data = json.loads(
          open(fixture_file('getis.json')).read())

    def test_getis_ord(self):
        """Test Getis-Ord's G*"""
        data = [{'id': d['id'],
                 'attr1': d['value'],
                 'neighbors': d['neighbors']} for d in self.neighbors_data]

        random_seeds.set_random_seeds(1234)
        getis = Getis(FakeDataProvider(data))

        result = getis.getis_ord('subquery', 'value',
                                 'queen', None, 999, 'the_geom',
                                 'cartodb_id')
        result = [(row[0], row[1]) for row in result]
        expected = np.array(self.getis_data)[:, 0:2]
        for ([res_z, res_p], [exp_z, exp_p]) in zip(result, expected):
            self.assertAlmostEqual(res_z, exp_z, delta=1e-2)
