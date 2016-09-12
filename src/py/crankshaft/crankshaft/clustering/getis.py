"""
Moran's I geostatistics (global clustering & outliers presence)
"""

# TODO: Fill in local neighbors which have null/NoneType values with the
#       average of the their neighborhood

import pysal as ps
import plpy
from collections import OrderedDict

# crankshaft module
import crankshaft.pysal_utils as pu

# High level interface ---------------------------------------

def getis_ord(subquery, attr,
              w_type, num_ngbrs, geom_col, id_col):
    """
    Getis-Ord's G
    Implementation building neighbors with a PostGIS database and Getis-Ord's G
     hotspot/coldspot analysis with PySAL.
    Andy Eschbacher
    """

    # geometries with attributes that are null are ignored
    # resulting in a collection of not as near neighbors if kNN is chosen

    qvals = OrderedDict([("id_col", id_col),
                         ("attr1", attr),
                         ("geom_col", geom_col),
                         ("subquery", subquery),
                         ("num_ngbrs", num_ngbrs)])

    query = pu.construct_neighbor_query(w_type, qvals)

    try:
        result = plpy.execute(query)
        # if there are no neighbors, exit
        if len(result) == 0:
            return pu.empty_zipped_array(3)
    except plpy.SPIError, err:
        plpy.error('Query failed: %s' % err)

    attr_vals = pu.get_attributes(result)
    weight = pu.get_weight(result, w_type, num_ngbrs)

    # calculate LISA values
    getis = ps.esda.getisord.G_Local(attr_vals, weight, star=True)

    return zip(getis.z_sim, getis.p_sim, weight.id_order)
