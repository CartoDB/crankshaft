"""
Moran's I geostatistics (global clustering & outliers presence)
"""

# TODO: Fill in local neighbors which have null/NoneType values with the
#       average of the their neighborhood

import pysal as ps
import plpy
from collections import OrderedDict
from crankshaft.query_runner import QueryRunner

# crankshaft module
import crankshaft.pysal_utils as pu

# High level interface ---------------------------------------


class Moran:
    def __init__(self, query_runner=None):
        if query_runner is None:
            self.query_runner = QueryRunner()
        else:
            self.query_runner = query_runner

    def global_stat(self, subquery, attr_name,
                    w_type, num_ngbrs, permutations, geom_col, id_col):
        """
        Moran's I (global)
        Implementation building neighbors with a PostGIS database and Moran's I
         core clusters with PySAL.
        Andy Eschbacher
        """
        qvals = OrderedDict([("id_col", id_col),
                             ("attr1", attr_name),
                             ("geom_col", geom_col),
                             ("subquery", subquery),
                             ("num_ngbrs", num_ngbrs)])

        query = pu.construct_neighbor_query(w_type, qvals)

        result = self.query_runner.get_moran(query)

        # collect attributes
        attr_vals = pu.get_attributes(result)

        # calculate weights
        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate moran global
        moran_global = ps.esda.moran.Moran(attr_vals, weight,
                                           permutations=permutations)

        return zip([moran_global.I], [moran_global.EI])

    def local_stat(self, subquery, attr,
                   w_type, num_ngbrs, permutations, geom_col, id_col):
        """
        Moran's I implementation for PL/Python
        Andy Eschbacher
        """

        # geometries with attributes that are null are ignored
        # resulting in a collection of not as near neighbors

        qvals = OrderedDict([("id_col", id_col),
                             ("attr1", attr),
                             ("geom_col", geom_col),
                             ("subquery", subquery),
                             ("num_ngbrs", num_ngbrs)])

        query = pu.construct_neighbor_query(w_type, qvals)

        result = self.query_runner.get_moran(query)

        attr_vals = pu.get_attributes(result)
        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate LISA values
        lisa = ps.esda.moran.Moran_Local(attr_vals, weight,
                                         permutations=permutations)

        # find quadrants for each geometry
        quads = quad_position(lisa.q)

        return zip(lisa.Is, quads, lisa.p_sim, weight.id_order, lisa.y)

    def global_rate_stat(self, subquery, numerator, denominator,
                         w_type, num_ngbrs, permutations, geom_col, id_col):
        """
        Moran's I Rate (global)
        Andy Eschbacher
        """
        qvals = OrderedDict([("id_col", id_col),
                             ("attr1", numerator),
                             ("attr2", denominator)
                             ("geom_col", geom_col),
                             ("subquery", subquery),
                             ("num_ngbrs", num_ngbrs)])

        query = pu.construct_neighbor_query(w_type, qvals)

        result = self.query_runner.get_moran(query)

        # collect attributes
        numer = pu.get_attributes(result, 1)
        denom = pu.get_attributes(result, 2)

        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate moran global rate
        lisa_rate = ps.esda.moran.Moran_Rate(numer, denom, weight,
                                             permutations=permutations)

        return zip([lisa_rate.I], [lisa_rate.EI])

    def local_rate_stat(self, subquery, numerator, denominator,
                        w_type, num_ngbrs, permutations, geom_col, id_col):
        """
            Moran's I Local Rate
            Andy Eschbacher
        """
        # geometries with values that are null are ignored
        # resulting in a collection of not as near neighbors

        qvals = OrderedDict([("id_col", id_col),
                             ("numerator", numerator),
                             ("denominator", denominator),
                             ("geom_col", geom_col),
                             ("subquery", subquery),
                             ("num_ngbrs", num_ngbrs)])

        query = pu.construct_neighbor_query(w_type, qvals)

        result = self.query_runner.get_moran(query)

        # collect attributes
        numer = pu.get_attributes(result, 1)
        denom = pu.get_attributes(result, 2)

        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate LISA values
        lisa = ps.esda.moran.Moran_Local_Rate(numer, denom, weight,
                                              permutations=permutations)

        # find quadrants for each geometry
        quads = quad_position(lisa.q)

        return zip(lisa.Is, quads, lisa.p_sim, weight.id_order, lisa.y)

    def local_bivariate_stat(self, subquery, attr1, attr2,
                             permutations, geom_col, id_col,
                             w_type, num_ngbrs):
        """
            Moran's I (local) Bivariate (untested)
        """

        qvals = OrderedDict([("id_col", id_col),
                             ("attr1", attr1),
                             ("attr2", attr2),
                             ("geom_col", geom_col),
                             ("subquery", subquery),
                             ("num_ngbrs", num_ngbrs)])

        query = pu.construct_neighbor_query(w_type, qvals)

        result = self.query_runner.get_moran(query)

        # collect attributes
        attr1_vals = pu.get_attributes(result, 1)
        attr2_vals = pu.get_attributes(result, 2)

        # create weights
        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate LISA values
        lisa = ps.esda.moran.Moran_Local_BV(attr1_vals, attr2_vals, weight,
                                            permutations=permutations)

        # find clustering of significance
        lisa_sig = quad_position(lisa.q)

        return zip(lisa.Is, lisa_sig, lisa.p_sim, weight.id_order)

# Low level functions ----------------------------------------


def map_quads(coord):
    """
        Map a quadrant number to Moran's I designation
        HH=1, LH=2, LL=3, HL=4
        Input:
        @param coord (int): quadrant of a specific measurement
        Output:
            classification (one of 'HH', 'LH', 'LL', or 'HL')
    """
    if coord == 1:
        return 'HH'
    elif coord == 2:
        return 'LH'
    elif coord == 3:
        return 'LL'
    elif coord == 4:
        return 'HL'
    else:
        return None


def quad_position(quads):
    """
        Produce Moran's I classification based of n
        Input:
        @param quads ndarray: an array of quads classified by
          1-4 (PySAL default)
        Output:
        @param list: an array of quads classied by 'HH', 'LL', etc.
    """
    return [map_quads(q) for q in quads]
