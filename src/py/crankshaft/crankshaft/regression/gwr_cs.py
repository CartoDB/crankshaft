"""
    Geographically weighted regression
"""
import numpy as np
from gwr.base.gwr import GWR
from gwr.base.sel_bw import Sel_BW
import plpy
import crankshaft.pysal_utils as pu
import json
from crankshaft.analysis_data_provider import AnalysisDataProvider


class GWR:
    def __init__(self, analysis_provider=None):
        if analysis_provider:
            self.analysis_provider = analysis_provider
        else:
            self.analysis_provider = AnalysisDataProvider()

    def gwr(self, subquery, dep_var, ind_vars,
            bw=None, fixed=False, kernel='bisquare',
            geom_col='the_geom', id_col='cartodb_id'):
        """
            subquery: 'select * from demographics'
            dep_var: 'pctbachelor'
            ind_vars: ['intercept', 'pctpov', 'pctrural', 'pctblack']
            bw: value of bandwidth, if None then select optimal
            fixed: False (kNN) or True ('distance')
            kernel: 'bisquare' (default), or 'exponential', 'gaussian'
        """

        params = {'geom_col': geom_col,
                  'id_col': id_col,
                  'subquery': subquery,
                  'dep_var': dep_var,
                  'ind_vars': ind_vars}

        # retrieve data
        query_result = self.analysis_data_provider.get_gwr(params)

        # unique ids and variable names list
        rowid = np.array(query_result[0]['rowid'], dtype=np.int)

        # TODO: should x, y be centroids? point on surface?
        #       lat, long coordinates
        x = np.array(query_result[0]['x'], dtype=float)
        y = np.array(query_result[0]['y'], dtype=float)
        coords = zip(x, y)

        # extract dependent variable
        Y = np.array(query_result[0]['dep_var'], dtype=float).reshape((-1, 1))

        n = Y.shape[0]
        k = len(ind_vars)
        X = np.zeros((n, k))

        # extract query result
        for attr in range(0, k):
            attr_name = 'attr' + str(attr + 1)
            X[:, attr] = np.array(
              query_result[0][attr_name], dtype=float).flatten()

        # add intercept variable name
        ind_vars.insert(0, 'intercept')

        # calculate bandwidth if none is supplied
        plpy.notice(str(bw))
        if bw is None:
            bw = Sel_BW(coords, Y, X,
                        fixed=fixed, kernel=kernel).search()
        plpy.notice(str(bw))
        model = GWR(coords, Y, X, bw,
                    fixed=fixed, kernel=kernel).fit()

        # containers for outputs
        coeffs = []
        stand_errs = []
        t_vals = []

        # extracted model information
        predicted = model.predy.flatten()
        residuals = model.resid_response
        r_squared = model.localR2.flatten()
        bw = np.repeat(float(bw), n)

        # create lists of json objs for model outputs
        for idx in xrange(n):
            coeffs.append(json.dumps({var: model.params[idx, k]
                                      for k, var in enumerate(ind_vars)}))
            stand_errs.append(json.dumps({var: model.bse[idx, k]
                                          for k, var in enumerate(ind_vars)}))
            t_vals.append(json.dumps({var: model.tvalues[idx, k]
                                      for k, var in enumerate(ind_vars)}))

        return zip(coeffs, stand_errs, t_vals,
                   predicted, residuals, r_squared, rowid, bw)
