"""
    Utilities module for generic PySAL functionality, mainly centered on translating queries into numpy arrays or PySAL weights objects
"""

import numpy as np
import pysal as ps

def construct_neighbor_query(w_type, query_vals):
    """Return query (a string) used for finding neighbors
        @param w_type text: type of neighbors to calculate ('knn' or 'queen')
        @param query_vals dict: values used to construct the query
    """

    if w_type == 'knn':
        return knn(query_vals)
    else:
        return queen(query_vals)

## Build weight object
def get_weight(query_res, w_type='knn', num_ngbrs=5):
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
                              "WHERE " \
                                "i.\"{id_col}\" <> j.\"{id_col}\" AND " \
                                "%(attr_where_j)s " \
                              "ORDER BY " \
                                "j.\"{geom_col}\" <-> i.\"{geom_col}\" ASC " \
                              "LIMIT {num_ngbrs})" \
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
                 "WHERE i.\"{id_col}\" <> j.\"{id_col}\" AND " \
                       "ST_Touches(i.\"{geom_col}\", j.\"{geom_col}\") AND " \
                       "%(attr_where_j)s)" \
                ") As neighbors " \
            "FROM ({subquery}) As i " \
            "WHERE " \
                "%(attr_where_i)s " \
            "ORDER BY i.\"{id_col}\" ASC;" % replacements

    return query.format(**params)

## to add more weight methods open a ticket or pull request

def get_attributes(query_res, attr_num=1):
    """
        @param query_res: query results with attributes and neighbors
        @param attr_num: attribute number (1, 2, ...)
    """
    return np.array([x['attr' + str(attr_num)] for x in query_res], dtype=np.float)

def empty_zipped_array(num_nones):
    """
        prepare return values for cases of empty weights objects (no neighbors)
        Input:
        @param num_nones int: number of columns (e.g., 4)
        Output:
        [(None, None, None, None)]
    """

    return [tuple([None] * num_nones)]
