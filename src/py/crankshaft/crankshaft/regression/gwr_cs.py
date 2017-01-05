"""
    Geographically weighted regression
"""
import numpy as np
from gwr.base.gwr import GWR as pysal_GWR
from gwr.base.sel_bw import Sel_BW
import json
from crankshaft.analysis_data_provider import AnalysisDataProvider


class GWR:
    def __init__(self, data_provider=None):
        if data_provider:
            self.data_provider = data_provider
        else:
            self.data_provider = AnalysisDataProvider()

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
        query_result = self.data_provider.get_gwr(params)

        # unique ids and variable names list
        rowid = np.array(query_result[0]['rowid'], dtype=np.int)

        # x, y are centroids of input geometries
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
        if bw is None:
            bw = Sel_BW(coords, Y, X,
                        fixed=fixed, kernel=kernel).search()
        model = pysal_GWR(coords, Y, X, bw,
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
                   predicted, residuals, r_squared, bw, rowid)

    def gwr_predict(self, subquery, dep_var, ind_vars,
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

        query_result = self.data_provider.get_gwr_predict(params)

        # unique ids and variable names list
        rowid = np.array(query_result[0]['rowid'], dtype=np.int)

        x = np.array(query_result[0]['x'])
        y = np.array(query_result[0]['y'])
        coords = np.array(zip(x, y))

        # extract dependent variable
        Y = np.array(query_result[0]['dep_var']).reshape((-1, 1))

        n = Y.shape[0]
        k = len(ind_vars)
        X = np.zeros((n, k))

        for attr in range(0, k):
            attr_name = 'attr' + str(attr + 1)
            X[:, attr] = np.array(
              query_result[0][attr_name]).flatten()

        # add intercept variable name
        ind_vars.insert(0, 'intercept')

        # split data into "training" and "test" for predictions
        # create index to split based on null y values
        train = np.where(Y != np.array(None))[0]
        test = np.where(Y == np.array(None))[0]

        if len(test) < 1:
            plpy.error('No rows flagged for prediction: verify that rows '
                       'denoting prediction locations have a dependent '
                       'variable value of null')

        # split dependent variable (only need training which is non-Null's)
        Y_train = Y[train].reshape((-1, 1))
        Y_train = Y_train.astype(np.float)

        # split coords
        coords_train = coords[train]
        coords_test = coords[test]

        # split explanatory variables
        X_train = X[train]
        X_test = X[test]

        # calculate bandwidth if none is supplied
        if bw is None:
            bw = Sel_BW(coords_train, Y_train, X_train,
                        fixed=fixed, kernel=kernel).search()

        # estimate model and predict at new locations
        model = GWR(coords_train, Y_train, X_train, bw,
                    fixed=fixed, kernel=kernel).predict(coords_test, X_test)

        coefficients = []
        stand_errs = []
        t_vals = []
        r_squared = model.localR2.flatten()
        predicted = model.predy.flatten()

        m = len(model.predy)
        for idx in xrange(m):
            coefficients.append(json.dumps({var: model.params[idx, k]
                                            for k, var in enumerate(ind_vars)}))
            stand_errs.append(json.dumps({var: model.bse[idx, k]
                                          for k, var in enumerate(ind_vars)}))
            t_vals.append(json.dumps({var: model.tvalues[idx, k]
                                      for k, var in enumerate(ind_vars)}))

        return zip(coefficients, stand_errs, t_vals,
                   r_squared, predicted, rowid)
