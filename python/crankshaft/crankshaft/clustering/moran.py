"""
Moran's I geostatistics (global clustering & outliers presence)
"""

# TODO: Fill in local neighbors which have null/NoneType values with the
#       average of the their neighborhood

import numpy as np
import pysal as ps
import plpy

# High level interface ---------------------------------------

def moran_local(t, attr, significance, num_ngbrs, permutations, geom_column, id_col, w_type):
    """
    Moran's I implementation for PL/Python
    Andy Eschbacher
    """
    # TODO: ensure that the significance output can be smaller that 1e-3 (0.001)
    # TODO: make a wishlist of output features (zscores, pvalues, raw local lisa, what else?)

    plpy.notice('** Constructing query')

    # geometries with attributes that are null are ignored
    # resulting in a collection of not as near neighbors

    qvals = {"id_col": id_col,
            "attr1": attr,
            "geom_col": geom_column,
             "table": t,
             "num_ngbrs": num_ngbrs}

    q = get_query(w_type, qvals)

    try:
        r = plpy.execute(q)
        plpy.notice('** Query returned with %d rows' % len(r))
    except plpy.SPIError:
        plpy.notice('** Query failed: "%s"' % q)
        plpy.notice('** Exiting function')
        return zip([None], [None], [None], [None])

    y = get_attributes(r, 1)
    w = get_weight(r, w_type)

    # calculate LISA values
    lisa = ps.Moran_Local(y, w)

    # find units of significance
    lisa_sig = lisa_sig_vals(lisa.p_sim, lisa.q, significance)

    plpy.notice('** Finished calculations')

    return zip(lisa.Is, lisa_sig, lisa.p_sim, w.id_order)


# Low level functions ----------------------------------------

def map_quads(coord):
    """
        Map a quadrant number to Moran's I designation
        HH=1, LH=2, LL=3, HL=4
        Input:
        :param coord (int): quadrant of a specific measurement
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
        :param params: dict of information used in query (column names,
                       table name, etc.)
    """

    attrs = [k for k in params
             if k not in ('id_col', 'geom_col', 'table', 'num_ngbrs')]

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
                    if k not in ('id_col', 'geom_col', 'table', 'num_ngbrs')])

    attr_string = []

    for attr in attrs:
        attr_string.append("idx_replace.\"{%s}\" IS NOT NULL" % attr)

    if len(attrs) == 2:
        attr_string.append("idx_replace.\"{%s}\" <> 0" % attrs[1])

    out = " AND ".join(attr_string)

    return out

def knn(params):
    """SQL query for k-nearest neighbors.
        :param vars: dict of values to fill template
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
                              "FROM \"{table}\" As j " \
                              "WHERE %(attr_where_j)s " \
                              "ORDER BY j.\"{geom_col}\" <-> i.\"{geom_col}\" ASC " \
                              "LIMIT {num_ngbrs} OFFSET 1 ) " \
                ") As neighbors " \
            "FROM \"{table}\" As i " \
            "WHERE " \
                "%(attr_where_i)s " \
            "ORDER BY i.\"{id_col}\" ASC;" % replacements

    return query.format(**params)

## SQL query for finding queens neighbors (all contiguous polygons)
def queen(params):
    """SQL query for queen neighbors.
        :param params: dict of information to fill query
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
                 "FROM \"{table}\" As j " \
                 "WHERE ST_Touches(i.\"{geom_col}\", j.\"{geom_col}\") AND " \
                 "%(attr_where_j)s)" \
                ") As neighbors " \
            "FROM \"{table}\" As i " \
            "WHERE " \
                "%(attr_where_i)s " \
            "ORDER BY i.\"{id_col}\" ASC;" % replacements

    return query.format(**params)

## to add more weight methods open a ticket or pull request

def get_query(w_type, query_vals):
    """Return requested query.
        :param w_type: type of neighbors to calculate (knn or queen)
        :param query_vals: values used to construct the query
    """

    if w_type == 'knn':
        return knn(query_vals)
    else:
        return queen(query_vals)

def get_attributes(query_res, attr_num):
    """
        :param query_res: query results with attributes and neighbors
        :param attr_num: attribute number (1, 2, ...)
    """
    return np.array([x['attr' + str(attr_num)] for x in query_res], dtype=np.float)

## Build weight object
def get_weight(query_res, w_type='queen', num_ngbrs=5):
    """
        Construct PySAL weight from return value of query
        :param query_res: query results with attributes and neighbors
    """
    if w_type == 'knn':
        row_normed_weights = [1.0 / float(num_ngbrs)] * num_ngbrs
        weights = {x['id']: row_normed_weights for x in query_res}
    elif w_type == 'queen':
        weights = {x['id']: [1.0 / len(x['neighbors'])] * len(x['neighbors'])
                            if len(x['neighbors']) > 0
                            else [] for x in query_res}

    neighbors = {x['id']: x['neighbors'] for x in query_res}

    return ps.W(neighbors, weights)

def quad_position(quads):
    """
        Produce Moran's I classification based of n
    """

    lisa_sig = np.array([map_quads(q) for q in quads])

    return lisa_sig

def lisa_sig_vals(pvals, quads, threshold):
    """
        Produce Moran's I classification based of n
    """

    sig = (pvals <= threshold)

    lisa_sig = np.empty(len(sig), np.chararray)

    for idx, val in enumerate(sig):
        if val:
            lisa_sig[idx] = map_quads(quads[idx])
        else:
            lisa_sig[idx] = 'Not significant'

    return lisa_sig
