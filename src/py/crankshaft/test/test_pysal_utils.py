import unittest

import crankshaft.pysal_utils as pu
from crankshaft import random_seeds
from collections import OrderedDict


class PysalUtilsTest(unittest.TestCase):
    """Testing class for utility functions related to PySAL integrations"""

    def setUp(self):
        self.params1 = OrderedDict([("id_col", "cartodb_id"),
                                    ("attr1", "andy"),
                                    ("attr2", "jay_z"),
                                    ("subquery", "SELECT * FROM a_list"),
                                    ("geom_col", "the_geom"),
                                    ("num_ngbrs", 321)])

        self.params2 = OrderedDict([("id_col", "cartodb_id"),
                                    ("numerator", "price"),
                                    ("denominator", "sq_meters"),
                                    ("subquery", "SELECT * FROM pecan"),
                                    ("geom_col", "the_geom"),
                                    ("num_ngbrs", 321)])

        self.params3 = OrderedDict([("id_col", "cartodb_id"),
                                    ("numerator", "sq_meters"),
                                    ("denominator", "price"),
                                    ("subquery", "SELECT * FROM pecan"),
                                    ("geom_col", "the_geom"),
                                    ("num_ngbrs", 321)])

        self.params_array = {"id_col": "cartodb_id",
                             "time_cols": ["_2013_dec", "_2014_jan", "_2014_feb"],
                             "subquery": "SELECT * FROM a_list",
                             "geom_col": "the_geom",
                             "num_ngbrs": 321}

    def test_query_attr_select(self):
        """Test query_attr_select"""

        ans1 = ("i.\"andy\"::numeric As attr1, "
                "i.\"jay_z\"::numeric As attr2, ")

        ans2 = ("i.\"price\"::numeric As attr1, "
                "i.\"sq_meters\"::numeric As attr2, ")

        ans3 = ("i.\"sq_meters\"::numeric As attr1, "
                "i.\"price\"::numeric As attr2, ")

        ans_array = ("i.\"_2013_dec\"::numeric As attr1, "
                     "i.\"_2014_jan\"::numeric As attr2, "
                     "i.\"_2014_feb\"::numeric As attr3, ")

        self.assertEqual(pu.query_attr_select(self.params1), ans1)
        self.assertEqual(pu.query_attr_select(self.params2), ans2)
        self.assertEqual(pu.query_attr_select(self.params3), ans3)
        self.assertEqual(pu.query_attr_select(self.params_array), ans_array)

    def test_query_attr_where(self):
        """Test pu.query_attr_where"""

        ans1 = ("idx_replace.\"andy\" IS NOT NULL AND "
                "idx_replace.\"jay_z\" IS NOT NULL")

        ans_array = ("idx_replace.\"_2013_dec\" IS NOT NULL AND "
                     "idx_replace.\"_2014_jan\" IS NOT NULL AND "
                     "idx_replace.\"_2014_feb\" IS NOT NULL")

        self.assertEqual(pu.query_attr_where(self.params1), ans1)
        self.assertEqual(pu.query_attr_where(self.params_array), ans_array)

    def test_knn(self):
        """Test knn neighbors constructor"""

        ans1 = "SELECT i.\"cartodb_id\" As id, " \
                     "i.\"andy\"::numeric As attr1, " \
                     "i.\"jay_z\"::numeric As attr2, " \
                     "(SELECT ARRAY(SELECT j.\"cartodb_id\" " \
                                   "FROM (SELECT * FROM a_list) As j " \
                                   "WHERE " \
                                    "i.\"cartodb_id\" <> j.\"cartodb_id\" AND " \
                                    "j.\"andy\" IS NOT NULL AND " \
                                    "j.\"jay_z\" IS NOT NULL " \
                                   "ORDER BY " \
                                    "j.\"the_geom\" <-> i.\"the_geom\" ASC " \
                      "LIMIT 321)) As neighbors " \
              "FROM (SELECT * FROM a_list) As i " \
              "WHERE i.\"andy\" IS NOT NULL AND " \
                    "i.\"jay_z\" IS NOT NULL " \
              "ORDER BY i.\"cartodb_id\" ASC;"

        ans_array = "SELECT i.\"cartodb_id\" As id, " \
              "i.\"_2013_dec\"::numeric As attr1, " \
              "i.\"_2014_jan\"::numeric As attr2, " \
              "i.\"_2014_feb\"::numeric As attr3, " \
              "(SELECT ARRAY(SELECT j.\"cartodb_id\" " \
                            "FROM (SELECT * FROM a_list) As j " \
                            "WHERE i.\"cartodb_id\" <> j.\"cartodb_id\" AND " \
                                  "j.\"_2013_dec\" IS NOT NULL AND " \
                                  "j.\"_2014_jan\" IS NOT NULL AND " \
                                  "j.\"_2014_feb\" IS NOT NULL " \
                            "ORDER BY j.\"the_geom\" <-> i.\"the_geom\" ASC " \
                            "LIMIT 321)) As neighbors " \
              "FROM (SELECT * FROM a_list) As i " \
              "WHERE i.\"_2013_dec\" IS NOT NULL AND " \
                    "i.\"_2014_jan\" IS NOT NULL AND " \
                    "i.\"_2014_feb\" IS NOT NULL "\
              "ORDER BY i.\"cartodb_id\" ASC;"

        self.assertEqual(pu.knn(self.params1), ans1)
        self.assertEqual(pu.knn(self.params_array), ans_array)

    def test_queen(self):
        """Test queen neighbors constructor"""

        ans1 = "SELECT i.\"cartodb_id\" As id, " \
                     "i.\"andy\"::numeric As attr1, " \
                     "i.\"jay_z\"::numeric As attr2, " \
                     "(SELECT ARRAY(SELECT j.\"cartodb_id\" " \
                                   "FROM (SELECT * FROM a_list) As j " \
                                   "WHERE " \
                                   "i.\"cartodb_id\" <> j.\"cartodb_id\" AND " \
                                   "ST_Touches(i.\"the_geom\", " \
                                              "j.\"the_geom\") AND " \
                                   "j.\"andy\" IS NOT NULL AND " \
                                   "j.\"jay_z\" IS NOT NULL)" \
                                  ") As neighbors " \
              "FROM (SELECT * FROM a_list) As i " \
              "WHERE i.\"andy\" IS NOT NULL AND " \
                    "i.\"jay_z\" IS NOT NULL " \
              "ORDER BY i.\"cartodb_id\" ASC;"

        self.assertEqual(pu.queen(self.params1), ans1)

    def test_construct_neighbor_query(self):
        """Test construct_neighbor_query"""

        # Compare to raw knn query
        self.assertEqual(pu.construct_neighbor_query('knn', self.params1),
                         pu.knn(self.params1))

    def test_get_attributes(self):
        """Test get_attributes"""

        ## need to add tests

        self.assertEqual(True, True)

    def test_get_weight(self):
        """Test get_weight"""

        self.assertEqual(True, True)

    def test_empty_zipped_array(self):
        """Test empty_zipped_array"""
        ans2 = [(None, None)]
        ans4 = [(None, None, None, None)]
        self.assertEqual(pu.empty_zipped_array(2), ans2)
        self.assertEqual(pu.empty_zipped_array(4), ans4)
