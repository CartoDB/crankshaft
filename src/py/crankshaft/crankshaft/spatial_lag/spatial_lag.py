"""
Spatial Lag (using local kNN neighbors identifying spatial lag for a feature)
"""

import pysal as ps
from collections import OrderedDict
from crankshaft.analysis_data_provider import AnalysisDataProvider

# crankshaft module
import crankshaft.pysal_utils as pu

# High level interface ---------------------------------------


class Spatial:
    def __init__(self, data_provider=None):
        if data_provider is None:
            self.data_provider = AnalysisDataProvider()
        else:
            self.data_provider = data_provider

    def spatial_lag(self, subquery, attr,
                    w_type, num_ngbrs, geom_col, id_col):
        """
        Querying spatial lags for kNN neighbors
        """

        # geometries with attributes that are null are ignored
        # resulting in a collection of not as near neighbors

        params = OrderedDict([("id_col", id_col),
                              ("attr1", attr),
                              ("geom_col", geom_col),
                              ("subquery", subquery),
                              ("num_ngbrs", num_ngbrs)])

        result = self.data_provider.get_neighbor(w_type, params)

        attr_vals = pu.get_attributes(result)
        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate spatial_lag values

        lag = ps.weights.spatial_lag.lag_spatial(weight, attr_vals)

        return zip(lag, weight.id_order)
