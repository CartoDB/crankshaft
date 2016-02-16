import unittest
import numpy as np

import unittest


# from mock_plpy import MockPlPy
# plpy = MockPlPy()
#
# import sys
# sys.modules['plpy'] = plpy
from helper import plpy

# import crankshaft.clustering as cc
import crankshaft.clustering as cc


class MoranTest(unittest.TestCase):
    """Testing class for Moran's I functions."""

    def setUp(self):
        plpy._reset()
        self.params = {"id_col": "cartodb_id",
                       "attr1": "andy",
                       "attr2": "jay_z",
                       "table": "a_list",
                       "geom_col": "the_geom",
                       "num_ngbrs": 321}

    def test_map_quads(self):
        """Test map_quads."""
        self.assertEqual(cc.map_quads(1), 'HH')
        self.assertEqual(cc.map_quads(2), 'LH')
        self.assertEqual(cc.map_quads(3), 'LL')
        self.assertEqual(cc.map_quads(4), 'HL')
        self.assertEqual(cc.map_quads(33), None)
        self.assertEqual(cc.map_quads('andy'), None)

    def test_query_attr_select(self):
        """Test query_attr_select."""

        ans = "i.\"{attr1}\"::numeric As attr1, " \
              "i.\"{attr2}\"::numeric As attr2, "

        self.assertEqual(cc.query_attr_select(self.params), ans)

    def test_query_attr_where(self):
        """Test query_attr_where."""

        ans = "idx_replace.\"{attr1}\" IS NOT NULL AND "\
              "idx_replace.\"{attr2}\" IS NOT NULL AND "\
              "idx_replace.\"{attr2}\" <> 0"

        self.assertEqual(cc.query_attr_where(self.params), ans)

    def test_knn(self):
        """Test knn function."""

        ans = "SELECT i.\"cartodb_id\" As id, i.\"andy\"::numeric As attr1, " \
              "i.\"jay_z\"::numeric As attr2, (SELECT ARRAY(SELECT j.\"cartodb_id\" " \
              "FROM \"a_list\" As j WHERE j.\"andy\" IS NOT NULL AND " \
              "j.\"jay_z\" IS NOT NULL AND j.\"jay_z\" <> 0 ORDER BY " \
              "j.\"the_geom\" <-> i.\"the_geom\" ASC LIMIT 321 OFFSET 1 ) ) " \
              "As neighbors FROM \"a_list\" As i WHERE i.\"andy\" IS NOT " \
              "NULL AND i.\"jay_z\" IS NOT NULL AND i.\"jay_z\" <> 0 ORDER " \
              "BY i.\"cartodb_id\" ASC;"

        self.assertEqual(cc.knn(self.params), ans)

    def test_queen(self):
        """Test queen neighbors function."""

        ans = "SELECT i.\"cartodb_id\" As id, i.\"andy\"::numeric As attr1, " \
              "i.\"jay_z\"::numeric As attr2, (SELECT ARRAY(SELECT " \
              "j.\"cartodb_id\" FROM \"a_list\" As j WHERE ST_Touches(" \
              "i.\"the_geom\", j.\"the_geom\") AND j.\"andy\" IS NOT NULL " \
              "AND j.\"jay_z\" IS NOT NULL AND j.\"jay_z\" <> 0)) As " \
              "neighbors FROM \"a_list\" As i WHERE i.\"andy\" IS NOT NULL " \
              "AND i.\"jay_z\" IS NOT NULL AND i.\"jay_z\" <> 0 ORDER BY " \
              "i.\"cartodb_id\" ASC;"

        self.assertEqual(cc.queen(self.params), ans)

    def test_get_query(self):
        """Test get_query."""

        ans = "SELECT i.\"cartodb_id\" As id, i.\"andy\"::numeric As attr1, " \
              "i.\"jay_z\"::numeric As attr2, (SELECT ARRAY(SELECT " \
              "j.\"cartodb_id\" FROM \"a_list\" As j WHERE j.\"andy\" IS " \
              "NOT NULL AND j.\"jay_z\" IS NOT NULL AND j.\"jay_z\" <> 0 " \
              "ORDER BY j.\"the_geom\" <-> i.\"the_geom\" ASC LIMIT 321 " \
              "OFFSET 1 ) ) As neighbors FROM \"a_list\" As i WHERE " \
              "i.\"andy\" IS NOT NULL AND i.\"jay_z\" IS NOT NULL AND " \
              "i.\"jay_z\" <> 0 ORDER BY i.\"cartodb_id\" ASC;"

        self.assertEqual(cc.get_query('knn', self.params), ans)

    def test_get_attributes(self):
        """Test get_attributes."""

        ## need to add tests

        self.assertEqual(True, True)

    def test_get_weight(self):
        """Test get_weight."""

        self.assertEqual(True, True)


    def test_quad_position(self):
        """Test lisa_sig_vals."""

        quads = np.array([1, 2, 3, 4], np.int)

        ans = np.array(['HH', 'LH', 'LL', 'HL'])
        test_ans = cc.quad_position(quads)

        self.assertTrue((test_ans == ans).all())

    def test_moran_local(self):
         """Test Moran's I local"""
         plpy._define_result('select', [
           { 'id': 1, 'attr1': 100.0, 'neighbors': [2,4,5,7,8] },
           { 'id': 2, 'attr1': 110.0, 'neighbors': [1,4,5,6,7] },
           { 'id': 3, 'attr1':  90.0, 'neighbors': [1,4,5,7,8] },
           { 'id': 4, 'attr1': 100.0, 'neighbors': [1,2,5,7,8] },
           { 'id': 5, 'attr1': 100.0, 'neighbors': [1,2,3,7,8] },
           { 'id': 6, 'attr1': 105.0, 'neighbors': [1,2,3,7,8] },
           { 'id': 7, 'attr1': 105.0, 'neighbors': [1,2,3,6,8] },
           { 'id': 8, 'attr1': 105.0, 'neighbors': [1,2,3,6,7] },
           { 'id': 9, 'attr1': 120.0, 'neighbors': [1,2,5,6,7] }
         ])
         result = cc.moran_local('table', 'value', 0.05, 5, 99, 'the_geom', 'cartodb_id', 'knn')
         # TODO: check results!
