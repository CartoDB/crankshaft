"""
  max-p clustering
"""

import pysal as ps
import numpy as np
import random

import crankshaft.pysal_utils as pu
from crankshaft.analysis_data_provider import AnalysisDataProvider


class MaxP:
    def __init__(self, data_provider=None):
        if data_provider:
            self.data_provider = data_provider
        else:
            self.data_provider = AnalysisDataProvider()

    def maxp(self, subquery, colnames, floor=1,
             geom_col='the_geom', id_col='cartodb_id'):
        """
            Inputs:
            @param subquery (text): subquery to expose the data need for the
                                    analysis. This query needs to expose all
                                    of the columns in `colnames`, `id_col`, and
                                    `geom_col`
            @param colnames (list): list of column names (as strings)
            @param floor (float): ...
            @param geom_col (text): geometry column used for calculating the
                                    spatial neighborhood
            @param id_col (text): id column used for keeping the identity of
                                  the data
            Outputs: a list of tuples with the following columns:

            classification_id: group that the geometry belongs to
            rowid: identifier from id_col
        """
        params = {'subquery': subquery,
                  'colnames': colnames,
                  'id_col': id_col,
                  'geom_col': geom_col}

        resp = self.data_provider.get_maxp(params)

        attr_vals = pu.get_attributes(resp, len(colnames))

        weight = pu.get_weight(resp, w_type='queen')
        r = ps.Maxp(weight, attr_vals,
                    floor=floor,
                    floor_variable=np.ones((weight.n, 1)))

        cluster_classes = get_cluster_classes(weight.id_order, r.regions)
        r.inference()
        return zip(cluster_classes, [r.pvalue] * len(weight.id_order),
                   weight.id_order)


def get_cluster_classes(ids, clusters):
    """

    """
    cluster_classes = []
    for i in ids:
        for r_id, r in enumerate(clusters):
            if i in r:
                cluster_classes.append(r_id)
    return cluster_classes
