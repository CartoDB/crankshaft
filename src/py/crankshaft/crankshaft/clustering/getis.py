"""
Getis-Ord's G geostatistics (hotspot/coldspot analysis)
"""

import pysal as ps
import plpy
from collections import OrderedDict

# crankshaft module
import crankshaft.pysal_utils as pu

# High level interface ---------------------------------------

def getis_ord(subquery, attr,
              w_type, num_ngbrs, permutations, geom_col, id_col):
    """
    Getis-Ord's G*
    Implementation building neighbors with a PostGIS database and PySAL's Getis-Ord's G*
     hotspot/coldspot module.
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
            return pu.empty_zipped_array(4)
    except plpy.SPIError, err:
        plpy.error('Query failed: %s' % err)

    attr_vals = pu.get_attributes(result)

    ## build PySAL weight object
    weight = pu.get_weight(result, w_type, num_ngbrs)

    # calculate Getis-Ord's G* z- and p-values
    getis = ps.esda.getisord.G_Local(attr_vals, weight,
      star=True, permutations=permutations)

    return zip(getis.z_sim, getis.p_sim, getis.p_z_sim, weight.id_order)
