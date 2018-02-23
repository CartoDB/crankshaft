"""
Getis-Ord's G geostatistics (hotspot/coldspot analysis)
"""

import pysal as ps
from collections import OrderedDict

# crankshaft modules
import crankshaft.pysal_utils as pu
from crankshaft.analysis_data_provider import AnalysisDataProvider

# High level interface ---------------------------------------


class Getis(object):
    def __init__(self, data_provider=None):
        if data_provider is None:
            self.data_provider = AnalysisDataProvider()
        else:
            self.data_provider = data_provider

    def getis_ord(self, subquery, attr,
                  w_type, num_ngbrs, permutations, geom_col, id_col):
        """
        Getis-Ord's G*
        Implementation building neighbors with a PostGIS database and PySAL's
          Getis-Ord's G* hotspot/coldspot module.
        Andy Eschbacher
        """

        # geometries with attributes that are null are ignored
        # resulting in a collection of not as near neighbors if kNN is chosen

        params = OrderedDict([("id_col", id_col),
                              ("attr1", attr),
                              ("geom_col", geom_col),
                              ("subquery", subquery),
                              ("num_ngbrs", num_ngbrs)])

        result = self.data_provider.get_getis(w_type, params)
        attr_vals = pu.get_attributes(result)

        # build PySAL weight object
        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate Getis-Ord's G* z- and p-values
        getis = ps.esda.getisord.G_Local(attr_vals, weight,
                                         star=True, permutations=permutations)

        return zip(getis.z_sim, getis.p_sim, getis.p_z_sim, weight.id_order)
