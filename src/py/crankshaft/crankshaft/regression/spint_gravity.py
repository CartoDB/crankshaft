import numpy as np
from spint.base.gravity import Gravity, Production, Attraction, Doubly
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
    
    # concatenate origin and dest variables into one list for query
    ind_vars = o_vars + d_vars

    # query_result = subquery
    params = {'id_col': 'cartodb_id',
              'subquery': subquery,
              'dep_var': flows,
              'ind_vars': ind_vars,
              'cost': cost}

    try:
        query = pu.gravity_query(params)
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
    n = flows.shape[0]
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
    for attr in range(0, d):
        attr_name = 'attr' + str(attr + 1 + o)
        d_vars[:, attr] = np.array(
          query_result[0][attr_name]).flatten() 

    # finally cost
    cost = np.array(query_result[0]['cost'], dtype=np.float).flatten()

    #add intercept variable name
    ind_vars.insert(0, 'intercept')
    
    model = Gravity(flows, o_vars, d_vars, cost, cost_func, Quasi=Quasi).fit()
    plpy.notice(str(model.params)) 
    coefficients = []
    stand_errs = []
    t_vals = []
    predicted = model.yhat
    r_squared = np.repeat(model.pseudoR2, n)
    aic = np.repeat(model.AIC, n)
    
    for idx in xrange(n):
        coefficients.append(json.dumps({var: model.params[k] for k, var in
            enumerate(ind_vars)}))
        stand_errs.append(json.dumps({var: model.std_err[k] for k, var in
            enumerate(ind_vars)}))
        t_vals.append(json.dumps({var: model.tvalues[k] for k, var in
            enumerate(ind_vars)}))
        
    return zip(coefficients, stand_errs, t_vals, predicted, r_squared, aic, rowid)

def production(subquery, flows, origins, d_vars, cost, cost_func, Quasi=False):
    """
    subquery: 'select * from demographics'
    flows: 'flow_count'
    origins: ['origin_name1', 'origin_name_2', 'origin_name_3']
    d_vars: ['dest_var_1', 'dest_var_2', 'dest_var_3']
    cost: 'distance' | 'time'
    cost_func: 'exp' for exponential decay | 'pow' for power decay
    Quasi: boolean with True for estimate QuasiPoisson model
    """
    # variable names list
    ind_vars = d_vars[:]

    # query_result = subquery
    params = {'id_col': 'cartodb_id',
              'subquery': subquery,
              'dep_var': flows,
              'ind_vars': d_vars,
              'origins': origins,
              'cost': cost}

    try:
        query = pu.production_query(params)
        plpy.notice(query)
        query_result = plpy.execute(query)
    except plpy.SPIError, err:
        plpy.notice(query)
        plpy.error('Analysis failed: %s' % err)

    #unique ids and variable names list 
    rowid = np.array(query_result[0]['rowid'], dtype=np.int)
    
    # origin names variable for fixed effects (constraints)
    origins = np.array(query_result[0]['origins'])

    # extract dependent variable
    flows = np.array(query_result[0]['dep_var']).reshape((-1, 1))

    # extract origin variables, dest variables and cost variable
    n = flows.shape[0]
    d = len(d_vars)
    d_vars = np.zeros((n, d))

    # then dests
    for attr in range(0, d):
        attr_name = 'attr' + str(attr + 1)
        d_vars[:, attr] = np.array(
          query_result[0][attr_name]).flatten() 

    # finally cost
    cost = np.array(query_result[0]['cost'], dtype=np.float).flatten()

    #add fixed effects and intercept variable name list
    for x, var in enumerate(np.unique(origins)):
    	ind_vars.insert(x, 'origin_' + str(var))
    ind_vars.pop(0)
    ind_vars.insert(0, 'intercept')
    
    plpy.notice(str(flows))
    plpy.notice(str(origins))
    plpy.notice(str(d_vars))
    plpy.notice(str(cost))

    model = Production(flows, origins, d_vars, cost, cost_func, Quasi=Quasi).fit()
    plpy.notice(str(model.params)) 
    coefficients = []
    stand_errs = []
    t_vals = []
    predicted = model.yhat
    r_squared = np.repeat(model.pseudoR2, n)
    aic = np.repeat(model.AIC, n)
   
    for idx in xrange(n):
        coefficients.append(json.dumps({var: model.params[k] for k, var in
            enumerate(ind_vars)}))
        stand_errs.append(json.dumps({var: model.std_err[k] for k, var in
            enumerate(ind_vars)}))
        t_vals.append(json.dumps({var: model.tvalues[k] for k, var in
            enumerate(ind_vars)}))
        
    return zip(coefficients, stand_errs, t_vals, predicted, r_squared, aic, rowid)
