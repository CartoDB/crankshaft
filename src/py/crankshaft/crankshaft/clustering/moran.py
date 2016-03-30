"""
Moran's I geostatistics (global clustering & outliers presence)
"""

# TODO: Fill in local neighbors which have null/NoneType values with the
#       average of the their neighborhood

import numpy as np
import pysal as ps
import plpy

# High level interface ---------------------------------------

def moran(subquery, attr_name,
          permutations, geom_col, id_col, w_type, num_ngbrs):
    """
    Moran's I (global)
    Implementation building neighbors with a PostGIS database and Moran's I
     core clusters with PySAL.
    Andy Eschbacher
    """
    qvals = {"id_col": id_col,
             "attr1": attr_name,
             "geom_col": geom_col,
             "subquery": subquery,
             "num_ngbrs": num_ngbrs}

    query = construct_neighbor_query(w_type, qvals)

    plpy.notice('** Query: %s' % query)

    try:
        result = plpy.execute(query)
        ## if there are no neighbors, exit
        if len(result) == 0:
            return zip([None], [None])
        plpy.notice('** Query returned with %d rows' % len(result))
    except plpy.SPIError:
        plpy.error('Error: areas of interest query failed, check input parameters')
        plpy.notice('** Query failed: "%s"' % query)
        plpy.notice('** Error: %s' % plpy.SPIError)
        return zip([None], [None])

    ## collect attributes
    attr_vals = get_attributes(result)

    ## calculate weights
    weight = get_weight(result, w_type, num_ngbrs)

    ## calculate moran global
    moran_global = ps.esda.moran.Moran(attr_vals, weight, permutations=permutations)

    return zip([moran_global.I], [moran_global.EI])

def moran_local(subquery, attr,
                permutations, geom_col, id_col, w_type, num_ngbrs):
    """
    Moran's I implementation for PL/Python
    Andy Eschbacher
    """

    # geometries with attributes that are null are ignored
    # resulting in a collection of not as near neighbors

    qvals = {"id_col": id_col,
             "attr1": attr,
             "geom_col": geom_col,
             "subquery": subquery,
             "num_ngbrs": num_ngbrs}

    query = construct_neighbor_query(w_type, qvals)

    try:
        result = plpy.execute(query)
        if len(result) == 0:
            return zip([None], [None], [None], [None], [None])
    except plpy.SPIError:
        plpy.error('Error: areas of interest query failed, check input parameters')
        plpy.notice('** Query failed: "%s"' % query)
        return zip([None], [None], [None], [None], [None])

    attr_vals = get_attributes(result)
    weight = get_weight(result, w_type)

    # calculate LISA values
    lisa = ps.esda.moran.Moran_Local(attr_vals, weight,
                                     permutations=permutations)

    # find quadrants for each geometry
    quads = quad_position(lisa.q)

    plpy.notice('** Finished calculations')
    return zip(lisa.Is, quads, lisa.p_sim, weight.id_order, lisa.y)

def moran_rate(subquery, numerator, denominator,
               permutations, geom_col, id_col, w_type, num_ngbrs):
    """
    Moran's I Rate (global)
    Andy Eschbacher
    """
    qvals = {"id_col": id_col,
             "attr1": numerator,
             "attr2": denominator,
             "geom_col": geom_col,
             "subquery": subquery,
             "num_ngbrs": num_ngbrs}

    query = construct_neighbor_query(w_type, qvals)

    plpy.notice('** Query: %s' % query)

    try:
        result = plpy.execute(query)
        if len(result) == 0:
            ## if there are no values returned, exit
            return zip([None], [None])
        plpy.notice('** Query returned with %d rows' % len(result))
    except plpy.SPIError:
        plpy.error('Error: areas of interest query failed, check input parameters')
        plpy.notice('** Query failed: "%s"' % query)
        plpy.notice('** Error: %s' % plpy.SPIError)
        return zip([None], [None])

    ## collect attributes
    numer = get_attributes(result, 1)
    denom = get_attributes(result, 2)

    weight = get_weight(result, w_type, num_ngbrs)

    ## calculate moran global rate
    lisa_rate = ps.esda.moran.Moran_Rate(numer, denom, weight,
                                         permutations=permutations)

    return zip([lisa_rate.I], [lisa_rate.EI])

def moran_local_rate(subquery, numerator, denominator,
                     permutations, geom_col, id_col, w_type, num_ngbrs):
    """
        Moran's I Local Rate
        Andy Eschbacher
    """
    # geometries with values that are null are ignored
    # resulting in a collection of not as near neighbors

    query = construct_neighbor_query(w_type,
                                     {"id_col": id_col,
                                      "numerator": numerator,
                                      "denominator": denominator,
                                      "geom_col": geom_col,
                                      "subquery": subquery,
                                      "num_ngbrs": num_ngbrs})

    try:
        result = plpy.execute(query)
        plpy.notice('** Query returned with %d rows' % len(result))
        if len(result) == 0:
            return zip([None], [None], [None], [None], [None])
    except plpy.SPIError:
        plpy.error('Error: areas of interest query failed, check input parameters')
        plpy.notice('** Query failed: "%s"' % query)
        plpy.notice('** Error: %s' % plpy.SPIError)
        return zip([None], [None], [None], [None], [None])

    ## collect attributes
    numer = get_attributes(result, 1)
    denom = get_attributes(result, 2)

    weight = get_weight(result, w_type, num_ngbrs)

    # calculate LISA values
    lisa = ps.esda.moran.Moran_Local_Rate(numer, denom, weight,
                                          permutations=permutations)

    # find units of significance
    quads = quad_position(lisa.q)

    return zip(lisa.Is, quads, lisa.p_sim, weight.id_order, lisa.y)

def moran_local_bv(subquery, attr1, attr2,
                   permutations, geom_col, id_col, w_type, num_ngbrs):
    """
        Moran's I (local) Bivariate (untested)
    """
    plpy.notice('** Constructing query')

    qvals = {"num_ngbrs": num_ngbrs,
             "attr1": attr1,
             "attr2": attr2,
             "subquery": subquery,
             "geom_col": geom_col,
             "id_col": id_col}

    query = construct_neighbor_query(w_type, qvals)

    try:
        result = plpy.execute(query)
        plpy.notice('** Query returned with %d rows' % len(result))
        if len(result) == 0:
            return zip([None], [None], [None], [None])
    except plpy.SPIError:
        plpy.error('Error: areas of interest query failed, check input parameters')
        plpy.notice('** Query failed: "%s"' % query)
        return zip([None], [None], [None], [None])

    ## collect attributes
    attr1_vals = get_attributes(result, 1)
    attr2_vals = get_attributes(result, 2)

    # create weights
    weight = get_weight(result, w_type, num_ngbrs)

    # calculate LISA values
    lisa = ps.esda.moran.Moran_Local_BV(attr1_vals, attr2_vals, weight,
                                        permutations=permutations)

    plpy.notice("len of Is: %d" % len(lisa.Is))

    # find clustering of significance
    lisa_sig = quad_position(lisa.q)

    plpy.notice('** Finished calculations')

    return zip(lisa.Is, lisa_sig, lisa.p_sim, weight.id_order)


# Low level functions ----------------------------------------

def map_quads(coord):
    """
        Map a quadrant number to Moran's I designation
        HH=1, LH=2, LL=3, HL=4
        Input:
        @param coord (int): quadrant of a specific measurement
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

def query_attr_select(params):
    """
        Create portion of SELECT statement for attributes inolved in query.
        @param params: dict of information used in query (column names,
                       table name, etc.)
    """

    attrs = [k for k in params
             if k not in ('id_col', 'geom_col', 'subquery', 'num_ngbrs')]

    template = "i.\"{%(col)s}\"::numeric As attr%(alias_num)s, "

    attr_string = ""

    for idx, val in enumerate(sorted(attrs)):
        attr_string += template % {"col": val, "alias_num": idx + 1}

    return attr_string

def query_attr_where(params):
    """
        Create portion of WHERE clauses for weeding out NULL-valued geometries
    """
    attrs = sorted([k for k in params
                    if k not in ('id_col', 'geom_col', 'subquery', 'num_ngbrs')])

    attr_string = []

    for attr in attrs:
        attr_string.append("idx_replace.\"{%s}\" IS NOT NULL" % attr)

    if len(attrs) == 2:
        attr_string.append("idx_replace.\"{%s}\" <> 0" % attrs[1])

    out = " AND ".join(attr_string)

    return out

def knn(params):
    """SQL query for k-nearest neighbors.
        @param vars: dict of values to fill template
    """

    attr_select = query_attr_select(params)
    attr_where = query_attr_where(params)

    replacements = {"attr_select": attr_select,
                    "attr_where_i": attr_where.replace("idx_replace", "i"),
                    "attr_where_j": attr_where.replace("idx_replace", "j")}

    query = "SELECT " \
                "i.\"{id_col}\" As id, " \
                "%(attr_select)s" \
                "(SELECT ARRAY(SELECT j.\"{id_col}\" " \
                              "FROM ({subquery}) As j " \
                              "WHERE %(attr_where_j)s " \
                              "ORDER BY j.\"{geom_col}\" <-> i.\"{geom_col}\" ASC " \
                              "LIMIT {num_ngbrs} OFFSET 1 ) " \
                ") As neighbors " \
            "FROM ({subquery}) As i " \
            "WHERE " \
                "%(attr_where_i)s " \
            "ORDER BY i.\"{id_col}\" ASC;" % replacements

    return query.format(**params)

## SQL query for finding queens neighbors (all contiguous polygons)
def queen(params):
    """SQL query for queen neighbors.
        @param params dict: information to fill query
    """
    attr_select = query_attr_select(params)
    attr_where = query_attr_where(params)

    replacements = {"attr_select": attr_select,
                    "attr_where_i": attr_where.replace("idx_replace", "i"),
                    "attr_where_j": attr_where.replace("idx_replace", "j")}

    query = "SELECT " \
                "i.\"{id_col}\" As id, " \
                "%(attr_select)s" \
                "(SELECT ARRAY(SELECT j.\"{id_col}\" " \
                 "FROM ({subquery}) As j " \
                 "WHERE ST_Touches(i.\"{geom_col}\", j.\"{geom_col}\") AND " \
                 "%(attr_where_j)s)" \
                ") As neighbors " \
            "FROM ({subquery}) As i " \
            "WHERE " \
                "%(attr_where_i)s " \
            "ORDER BY i.\"{id_col}\" ASC;" % replacements

    return query.format(**params)

## to add more weight methods open a ticket or pull request

def construct_neighbor_query(w_type, query_vals):
    """Return requested query.
        @param w_type text: type of neighbors to calculate ('knn' or 'queen')
        @param query_vals dict: values used to construct the query
    """

    if w_type == 'knn':
        return knn(query_vals)
    else:
        return queen(query_vals)

def get_attributes(query_res, attr_num=1):
    """
        @param query_res: query results with attributes and neighbors
        @param attr_num: attribute number (1, 2, ...)
    """
    return np.array([x['attr' + str(attr_num)] for x in query_res], dtype=np.float)

## Build weight object
def get_weight(query_res, w_type='queen', num_ngbrs=5):
    """
        Construct PySAL weight from return value of query
        @param query_res: query results with attributes and neighbors
    """
    if w_type == 'knn':
        row_normed_weights = [1.0 / float(num_ngbrs)] * num_ngbrs
        weights = {x['id']: row_normed_weights for x in query_res}
    else:
        weights = {x['id']: [1.0 / len(x['neighbors'])] * len(x['neighbors'])
                            if len(x['neighbors']) > 0
                            else [] for x in query_res}

    neighbors = {x['id']: x['neighbors'] for x in query_res}

    return ps.W(neighbors, weights)

def quad_position(quads):
    """
        Produce Moran's I classification based of n
        Input:
        @param quads ndarray: an array of quads classified by
          1-4 (PySAL default)
        Output:
        @param ndarray: an array of quads classied by 'HH', 'LL', etc.
    """

    lisa_sig = np.array([map_quads(q) for q in quads])

    return lisa_sig
