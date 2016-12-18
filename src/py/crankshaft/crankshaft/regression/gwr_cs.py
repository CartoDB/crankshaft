import numpy as np
from gwr.base.gwr import GWR
from gwr.base.sel_bw import Sel_BW
import plpy
import crankshaft.pysal_utils as pu
import json


def gwr(subquery, dep_var, ind_vars, bw=None,
        fixed=False, kernel='bisquare'):
    """
    subquery: 'select * from demographics'
    dep_var: 'pctbachelor'
    ind_vars: ['intercept', 'pctpov', 'pctrural', 'pctblack']
    bw: value of bandwidth, if None then select optimal
    fixed: False (kNN) or True ('distance')
    kernel: 'bisquare' (default), or 'exponential', 'gaussian'
    """

    # query_result = subquery
    params = {'geom_col': 'the_geom',
              'id_col': 'cartodb_id',
              'subquery': subquery,
              'dep_var': dep_var,
              'ind_vars': ind_vars}

    try:
        query = pu.gwr_query(params)
        plpy.notice(query)
        query_result = plpy.execute(query)
    except plpy.SPIError, err:
        plpy.notice(query)
        plpy.error('Analysis failed: %s' % err)

    # unique ids and variable names list
    rowid = np.array(query_result[0]['rowid'], dtype=np.int)

    # TODO: should x, y be centroids? point on surface?
    #       lat, long coordinates
    x = np.array(query_result[0]['x'])
    y = np.array(query_result[0]['y'])
    coords = zip(x, y)

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

    # calculate bandwidth if none is supplied
    plpy.notice(str(bw))
    if bw is None:
        bw = Sel_BW(coords, Y, X,
                    fixed=fixed, kernel=kernel).search()
    plpy.notice(str(bw))
    model = GWR(coords, Y, X, bw,
                fixed=fixed, kernel=kernel).fit()

    # TODO: iterate from 0, n-1 and fill objects like this, for a
    #       column called coeffs:
    #       {'pctrural': ..., 'pctpov': ..., ...}
    #       Follow the same structure for other outputs

    coefficients = []
    stand_errs = []
    t_vals = []
    predicted = model.predy.flatten()
    residuals = model.resid_response
    r_squared = model.localR2.flatten()
    bw = np.repeat(float(bw), n)

    for idx in xrange(n):
        coefficients.append(json.dumps({var: model.params[idx, k]
                                        for k, var in enumerate(ind_vars)}))
        stand_errs.append(json.dumps({var: model.bse[idx, k]
                                      for k, var in enumerate(ind_vars)}))
        t_vals.append(json.dumps({var: model.tvalues[idx, k]
                                  for k, var in enumerate(ind_vars)}))

    plpy.notice(str(zip(coefficients, stand_errs, t_vals,
                        predicted, residuals, r_squared, rowid, bw)))
    return zip(coefficients, stand_errs, t_vals,
               predicted, residuals, r_squared, rowid, bw)

def gwr_predict(subquery, dep_var, ind_vars, bw=None,
        fixed=False, kernel='bisquare'):
    """
    subquery: 'select * from demographics'
    dep_var: 'pctbachelor'
    ind_vars: ['intercept', 'pctpov', 'pctrural', 'pctblack']
    bw: value of bandwidth, if None then select optimal
    fixed: False (kNN) or True ('distance')
    kernel: 'bisquare' (default), or 'exponential', 'gaussian'
    """

    # query_result = subquery
    params = {'geom_col': 'the_geom',
              'id_col': 'cartodb_id',
              'subquery': subquery,
              'dep_var': dep_var,
              'ind_vars': ind_vars}

    try:
        query = pu.gwr_predict_query(params)
        plpy.notice(query)
        query_result = plpy.execute(query)
    except plpy.SPIError, err:
        plpy.notice(query)
        plpy.error('Analysis failed: %s' % err)

    # unique ids and variable names list
    rowid = np.array(query_result[0]['rowid'], dtype=np.int)

    # TODO: should x, y be centroids? point on surface?
    #       lat, long coordinates
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
        plpy.error('No rows flagged for prediction: verify that rows denoting'
                'prediction locations have a dependent variable value of Null')

    # split dependent variable (only need training which is non-Null's)
    Y_train = Y[train].reshape((-1,1))
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
