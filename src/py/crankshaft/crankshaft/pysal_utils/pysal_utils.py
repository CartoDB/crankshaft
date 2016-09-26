"""
    Utilities module for generic PySAL functionality, mainly centered on
      translating queries into numpy arrays or PySAL weights objects
"""

import numpy as np
import pysal as ps


def construct_neighbor_query(w_type, query_vals):
    """Return query (a string) used for finding neighbors
        @param w_type text: type of neighbors to calculate ('knn' or 'queen')
        @param query_vals dict: values used to construct the query
    """

    if w_type.lower() == 'knn':
        return knn(query_vals)
    else:
        return queen(query_vals)


# Build weight object
def get_weight(query_res, w_type='knn', num_ngbrs=5):
    """
        Construct PySAL weight from return value of query
        @param query_res dict-like: query results with attributes and neighbors
    """
    # if w_type.lower() == 'knn':
    #     row_normed_weights = [1.0 / float(num_ngbrs)] * num_ngbrs
    #     weights = {x['id']: row_normed_weights for x in query_res}
    # else:
    #     weights = {x['id']: [1.0 / len(x['neighbors'])] * len(x['neighbors'])
    #                         if len(x['neighbors']) > 0
    #                         else [] for x in query_res}

    neighbors = {x['id']: x['neighbors'] for x in query_res}
    print 'len of neighbors: %d' % len(neighbors)

    built_weight = ps.W(neighbors)
    built_weight.transform = 'r'

    return built_weight


def query_attr_select(params):
    """
        Create portion of SELECT statement for attributes inolved in query.
        Defaults to order in the params
        @param params: dict of information used in query (column names,
                       table name, etc.)
            Example:
            OrderedDict([('numerator', 'price'),
                         ('denominator', 'sq_meters'),
                         ('subquery', 'SELECT * FROM interesting_data')])
        Output:
          "i.\"price\"::numeric As attr1, " \
          "i.\"sq_meters\"::numeric As attr2, "
    """

    attr_string = ""
    template = "i.\"%(col)s\"::numeric As attr%(alias_num)s, "

    if 'time_cols' in params:
        # if markov analysis
        attrs = params['time_cols']

        for idx, val in enumerate(attrs):
            attr_string += template % {"col": val, "alias_num": idx + 1}
    else:
        # if moran's analysis
        attrs = [k for k in params
                 if k not in ('id_col', 'geom_col', 'subquery',
                              'num_ngbrs', 'subquery')]

        for idx, val in enumerate(attrs):
            attr_string += template % {"col": params[val],
                                       "alias_num": idx + 1}

    return attr_string


def query_attr_where(params):
    """
      Construct where conditions when building neighbors query
        Create portion of WHERE clauses for weeding out NULL-valued geometries
        Input: dict of params:
            {'subquery': ...,
             'numerator': 'data1',
             'denominator': 'data2',
             '': ...}
        Output:
          'idx_replace."data1" IS NOT NULL AND idx_replace."data2" IS NOT NULL'
        Input:
        {'subquery': ...,
         'time_cols': ['time1', 'time2', 'time3'],
         'etc': ...}
        Output: 'idx_replace."time1" IS NOT NULL AND idx_replace."time2" IS NOT
          NULL AND idx_replace."time3" IS NOT NULL'
    """
    attr_string = []
    template = "idx_replace.\"%s\" IS NOT NULL"

    if 'time_cols' in params:
        # markov where clauses
        attrs = params['time_cols']
        # add values to template
        for attr in attrs:
            attr_string.append(template % attr)
    else:
        # moran where clauses

        # get keys
        attrs = [k for k in params
                 if k not in ('id_col', 'geom_col', 'subquery',
                              'num_ngbrs', 'subquery')]

        # add values to template
        for attr in attrs:
            attr_string.append(template % params[attr])

        if 'denominator' in attrs:
            attr_string.append(
              "idx_replace.\"%s\" <> 0" % params['denominator'])

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


# SQL query for finding queens neighbors (all contiguous polygons)
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

# to add more weight methods open a ticket or pull request


def get_attributes(query_res, attr_num=1):
    """
        @param query_res: query results with attributes and neighbors
        @param attr_num: attribute number (1, 2, ...)
    """
    return np.array([x['attr' + str(attr_num)] for x in query_res],
                    dtype=np.float)


def empty_zipped_array(num_nones):
    """
        prepare return values for cases of empty weights objects (no neighbors)
        Input:
        @param num_nones int: number of columns (e.g., 4)
        Output:
        [(None, None, None, None)]
    """

    return [tuple([None] * num_nones)]
