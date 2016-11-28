import numpy as np
from gwr.base.gwr import GWR
from gwr.base.sel_bw import Sel_BW


def gwr(subquery, dep_var, ind_vars,
        fixed=False, kernel='bisquare'):
    """
    subquery: 'select * from demographics'
    dep_var: 'pctbachelor'
    ind_vars: ['intercept', 'pctpov', 'pctrural', 'pctblack']
    fixed: False (kNN) or True ('distance')
    kernel: 'bisquare' (default), or 'exponential', 'gaussian'
    """

    # query_result = subquery
    # rowid = np.array(query_result[0]['rowid'])
    params = {'geom_col': 'the_geom',
              'id_col': 'cartodb_id',
              'subquery': subquery,
              'dep_var': dep_var,
              'ind_vars': ind_vars}

    try:
        query_result = plpy.execute(pu.gwr_query(params))
    except plpy.SPIError, err:
        plpy.error('Analysis failed: %s' % err)

    # TODO: should x, y be centroids? point on surface?
    #       lat, long coordinates
    x = np.array(query_result[0]['x'])
    y = np.array(query_result[0]['y'])
    coords = zip(x, y)

    # extract dependent variable
    Y = query_result[0]['dep_var'].reshape((-1, 1))

    n = Y.shape[0]
    k = len(ind_vars)
    X = np.zeros((n, k))

    for attr in range(0, k):
        attr_name = 'attr' + str(attr + 1)
        X[:, attr] = np.array(
          query_result[0][attr_name]).flatten()

    # calculate bandwidth
    bw = Sel_BW(coords, Y, X,
                fixed=fixed, kernel=kernel).search()
    model = GWR(coords, Y, X, bw,
                fixed=fixed, kernel=kernel).fit()

    # TODO: iterate from 0, n-1 and fill objects like this, for a
    #       column called coeffs:
    #       {'pctrural': ..., 'pctpov': ..., ...}
    #       Follow the same structure for other outputs
    coefficients = model.params.reshape((-1,))
    t_vals = model.tvalues.reshape((-1,))
    stand_errs = model.bse.reshape((-1))
    predicted = np.repeat(model.predy.reshape((-1,)), k+1)
    residuals = np.repeat(model.resid_response.reshape((-1,)), k+1)
    r_squared = np.repeat(model.localR2.reshape((-1,)), k+1)
    rowid = np.tile(rowid, k+1).reshape((-1,))
    ind_vars.insert(0, 'intercept')
    var_name = np.tile(ind_vars, n).reshape((-1,))
    return zip(coefficients, stand_errs, t_vals, predicted, residuals, r_squared, rowid, var_name)
