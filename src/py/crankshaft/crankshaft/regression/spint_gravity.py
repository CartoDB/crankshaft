import numpy as np
from spint.base.gravity import Gravity
import plpy
import crankshaft.pysal_utils as pu
import json


def gravity(subquery, flows, o_vars, d_vars, cost, cost_func, Quasi=False):
    """
    subquery: 'select * from demographics'
    flows: 'flow_count'
    o_vars: ['origin_var_1', 'origin_var_2', 'origin_var_3']
    d_vars: ['dest_var_1', 'dest_var_2', 'dest_var_3']
    cost: 'distance' | 'time'
    cost_func: 'exp' for exponential decay | 'pow' for power decay
    Quasi: boolean with True for estimate QuasiPoisson model
    """
    
    # concatenate origin, dest, and cost variables into one list for query
    ind_vars = o_vars + d_vars
    ind_vars.insert(-1, cost)

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

    #unique ids and variable names list 
    rowid = np.array(query_result[0]['rowid'], dtype=np.int)
    
    # extract dependent variable
    flows = np.array(query_result[0]['dep_var']).reshape((-1, 1))

    # extract origin variables, dest variables and cost variable
    n = Y.shape[0]
    o = len(o_vars)
    d = len(d_vars)
    o_vars = np.zeros((n, o))
    d_vars = np.zeros((n, d))

    # first origins
    for attr in range(0, o):
        attr_name = 'attr' + str(attr + 1)
        o_vars[:, attr] = np.array(
          query_result[0][attr_name]).flatten()
    
    # then dests
    for attr in range(o, d):
        attr_name = 'attr' + str(attr + 1 + o)
        o_vars[:, attr] = np.array(
          query_result[0][attr_name]).flatten()
    
    # finally cost
    attr_name = 'sttr' + str(attr + 1 + o + d)
    cost = np.array(query_results[0][attr_name]).flatten()

    #add intercept variable name
    ind_vars.insert(0, 'intercept')

    model = Gravity(flows, o_vars, d_vars, cost, cost_func, Quasi=Quasi).fit()
    
    coefficients = []
    stand_errs = []
    t_vals = []
    predicted = model.yhat
    r_squared = np.repeat(model.pseudoR2, n)
    aic = np.repeat(model.AIC, n)

    for idx in xrange(n):
        coefficients.append(json.dumps({var: model.params[idx,k] for k, var in
            enumerate(ind_vars)}))
        stand_errs.append(json.dumps({var: model.std_err[idx,k] for k, var in
            enumerate(ind_vars)}))
        t_vals.append(json.dumps({var: model.tvalues[idx,k] for k, var in
            enumerate(ind_vars)}))
        
    plpy.notice(str(zip(coefficients, stand_errs, t_vals, predicted, r_squared,
        aic, rowid)))
    return zip(coefficients, stand_errs, t_vals, predicted, r_squared, aic, rowid)
