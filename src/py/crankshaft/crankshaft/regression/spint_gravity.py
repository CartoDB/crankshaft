import numpy as np
from spint.base.gravity import Gravity, Production, Attraction, Doubly
import plpy
from crankshaft.analysis_data_provider import AnalysisDataProvider
import crankshaft.pysal_utils as pu
import json


class SpInt(object):
    def __init__(self, data_provider=None):
        if data_provider:
            self.data_provider = data_provider
        else:
            self.data_provider = AnalysisDataProvider()

    def gravity(self, subquery, flows, o_vars, d_vars, cost, cost_func,
                quasi=False, id_col='cartodb_id'):
        """
        subquery: 'select * from demographics'
        flows: 'flow_count'
        o_vars: ['origin_var_1', 'origin_var_2', 'origin_var_3']
        d_vars: ['dest_var_1', 'dest_var_2', 'dest_var_3']
        cost: 'distance' | 'time'
        cost_func: 'exp' for exponential decay | 'pow' for power decay
        quasi: boolean with True for estimate QuasiPoisson model
        """

        # concatenate origin and dest variables into one list for query
        ind_vars = o_vars + d_vars

        # query_result = subquery
        params = {'id_col': id_col,
                  'subquery': subquery,
                  'dep_var': flows,
                  'ind_vars': ind_vars,
                  'cost': cost}

        result = self.data_provider.get_spint_gravity(params)

        # add cost name in var name list
        ind_vars.insert(len(ind_vars), cost)

        # unique ids and variable names list
        rowid = np.array(result[0]['rowid'], dtype=np.int)

        # extract dependent variable
        flows = np.array(result[0]['dep_var']).reshape((-1, 1))

        # extract origin variables, dest variables and cost variable
        n = flows.shape[0]
        o = len(o_vars)
        d = len(d_vars)
        o_vars = np.zeros((n, o))
        d_vars = np.zeros((n, d))

        # first origins
        # TODO: replace with pu.get_attributes (in another branch)
        for attr in range(0, o):
            attr_name = 'attr' + str(attr + 1)
            o_vars[:, attr] = np.array(
              result[0][attr_name]).flatten()

        # then dests
        # TODO: replace with pu.get_attributes (in another branch)
        for attr in range(0, d):
            attr_name = 'attr' + str(attr + 1 + o)
            d_vars[:, attr] = np.array(
              result[0][attr_name]).flatten()

        # finally cost
        cost = np.array(result[0]['cost'], dtype=np.float).flatten()

        # add intercept variable name
        ind_vars.insert(0, 'intercept')

        model = Gravity(flows, o_vars, d_vars, cost,
                        cost_func, Quasi=quasi).fit()
        coeffs = []
        stand_errs = []
        t_vals = []
        predicted = model.yhat
        r_squared = np.repeat(model.pseudoR2, n)
        aic = np.repeat(model.AIC, n)

        for idx in xrange(n):
            coeffs.append(
              json.dumps({var: model.params[k]
                          for k, var in enumerate(ind_vars)}))
            stand_errs.append(
              json.dumps({var: model.std_err[k]
                          for k, var in enumerate(ind_vars)}))
            t_vals.append(
              json.dumps({var: model.tvalues[k]
                          for k, var in enumerate(ind_vars)}))

        return zip(coeffs, stand_errs, t_vals, predicted,
                   r_squared, aic, rowid)

    def production(self, subquery, flows, origins, d_vars, cost, cost_func,
                   quasi=False, id_col='cartodb_id'):
        """
        subquery: 'select * from demographics'
        flows: 'flow_count'
        origins: ['origin_name1', 'origin_name_2', 'origin_name_3']
        d_vars: ['dest_var_1', 'dest_var_2', 'dest_var_3']
        cost: 'distance' | 'time'
        cost_func: 'exp' for exponential decay | 'pow' for power decay
        quasi: boolean with True for estimate QuasiPoisson model
        """
        # variable names list
        ind_vars = d_vars[:]

        # query_result = subquery
        params = {'id_col': id_col,
                  'subquery': subquery,
                  'dep_var': flows,
                  'ind_vars': d_vars,
                  'origins': origins,
                  'cost': cost}

        # TODO: replace query_result with data
        result = self.data_provider.get_spint_production(params)

        # add cost name in var name list
        ind_vars.insert(len(ind_vars), cost)

        # unique ids and variable names list
        rowid = np.array(result[0]['rowid'], dtype=np.int)

        # origin names variable for fixed effects (constraints)
        origins = np.array(result[0]['origins'])

        # extract dependent variable
        flows = np.array(result[0]['dep_var']).reshape((-1, 1))

        # extract origin variables, dest variables and cost variable
        n = flows.shape[0]
        d = len(d_vars)
        d_vars = np.zeros((n, d))

        # then dests
        # TODO: replace with pu.get_attributes
        for attr in range(0, d):
            attr_name = 'attr' + str(attr + 1)
            d_vars[:, attr] = np.array(
              result[0][attr_name]).flatten()

        # finally cost
        cost = np.array(result[0]['cost'], dtype=np.float).flatten()

        # add fixed effects and intercept variable name list
        for x, var in enumerate(np.unique(origins)):
            ind_vars.insert(x, 'origin_' + str(var))

        ind_vars.pop(0)
        ind_vars.insert(0, 'intercept')

        # calibrate model
        model = Production(flows, origins, d_vars, cost, cost_func,
                           Quasi=quasi).fit()

        # format output
        coeffs = []
        stand_errs = []
        t_vals = []
        predicted = model.yhat
        r_squared = np.repeat(model.pseudoR2, n)
        aic = np.repeat(model.AIC, n)

        for idx in xrange(n):
            coeffs.append(
              json.dumps({var: model.params[k]
                          for k, var in enumerate(ind_vars)}))
            stand_errs.append(
              json.dumps({var: model.std_err[k]
                          for k, var in enumerate(ind_vars)}))
            t_vals.append(
              json.dumps({var: model.tvalues[k]
                          for k, var in enumerate(ind_vars)}))

        return zip(coeffs, stand_errs, t_vals,
                   predicted, r_squared, aic, rowid)

    def attraction(self, subquery, flows, destinations, o_vars, cost,
                   cost_func, quasi=False, id_col='cartodb_id'):
        """
        subquery: 'select * from demographics'
        flows: 'flow_count'
        destinations: ['dest_name1', 'dest_name_2', 'dest_name_3']
        o_vars: ['origin_var_1', 'origin_var_2', 'origin_var_3']
        cost: 'distance' | 'time'
        cost_func: 'exp' for exponential decay | 'pow' for power decay
        Quasi: boolean with True for estimate QuasiPoisson model
        """
        # variable names list
        ind_vars = o_vars[:]

        # query_result = subquery
        params = {'id_col': id_col,
                  'subquery': subquery,
                  'dep_var': flows,
                  'ind_vars': o_vars,
                  'destinations': destinations,
                  'cost': cost}

        result = self.data_provider.get_spint_attraction(params)

        # add cost name in var name list
        ind_vars.insert(len(ind_vars), cost)

        # unique ids and variable names list
        rowid = np.array(result[0]['rowid'], dtype=np.int)

        # dest names variable for fixed effects (constraints)
        destinations = np.array(result[0]['destinations'])

        # extract dependent variable
        flows = np.array(result[0]['dep_var']).reshape((-1, 1))

        # extract origin variables, dest variables and cost variable
        n = flows.shape[0]
        o = len(o_vars)
        o_vars = np.zeros((n, o))

        # then dests
        for attr in range(0, o):
            attr_name = 'attr' + str(attr + 1)
            o_vars[:, attr] = np.array(
              result[0][attr_name]).flatten()

        # finally cost
        cost = np.array(result[0]['cost'], dtype=np.float).flatten()

        # add fixed effects and intercept variable name list
        for x, var in enumerate(np.unique(destinations)):
            ind_vars.insert(x, 'dest_' + str(var))

        ind_vars.pop(0)
        ind_vars.insert(0, 'intercept')

        # calibrate model
        model = Attraction(flows, destinations, o_vars, cost, cost_func,
                           Quasi=quasi).fit()

        # format model
        coeffs = []
        stand_errs = []
        t_vals = []
        predicted = model.yhat
        r_squared = np.repeat(model.pseudoR2, n)
        aic = np.repeat(model.AIC, n)

        for idx in xrange(n):
            coeffs.append(
              json.dumps({var: model.params[k]
                          for k, var in enumerate(ind_vars)}))
            stand_errs.append(
              json.dumps({var: model.std_err[k]
                          for k, var in enumerate(ind_vars)}))
            t_vals.append(
              json.dumps({var: model.tvalues[k]
                          for k, var in enumerate(ind_vars)}))

        return zip(coeffs, stand_errs, t_vals, predicted,
                   r_squared, aic, rowid)

    def doubly(self, subquery, flows, origins, destinations, cost, cost_func,
               quasi=False, id_col='cartodb_id'):
        """
        subquery: 'select * from demographics'
        flows: 'flow_count'
        origins: ['origin_name1', 'origin_name_2', 'origin_name_3']
        destinations: ['dest_name1', 'dest_name_2', 'dest_name_3']
        cost: 'distance' | 'time'
        cost_func: 'exp' for exponential decay | 'pow' for power decay
        quasi: boolean with True for estimate QuasiPoisson model
        """

        # query_result = subquery
        params = {'id_col': id_col,
                  'subquery': subquery,
                  'dep_var': flows,
                  'origins': origins,
                  'destinations': destinations,
                  'cost': cost}

        result = self.data_provider.get_spint_doubly(params)

        # add cost name in var name list
        ind_vars = [cost]

        # unique ids and variable names list
        rowid = np.array(result[0]['rowid'], dtype=np.int)

        # dest names variable for fixed effects (constraints)
        origins = np.array(result[0]['origins'])
        destinations = np.array(result[0]['destinations'])

        # extract dependent variable
        flows = np.array(result[0]['dep_var']).reshape((-1, 1))

        # extract origin variables, dest variables and cost variable
        n = flows.shape[0]

        # finally cost
        cost = np.array(result[0]['cost'], dtype=np.float).flatten()

        # add fixed effects and intercept to variable name list
        for x, var in enumerate(np.unique(destinations)):
            ind_vars.insert(x, 'dest_' + str(var))

        ind_vars.pop(0)

        for x, var in enumerate(np.unique(origins)):
            ind_vars.insert(x, 'origin_' + str(var))

        ind_vars.pop(0)
        ind_vars.insert(0, 'intercept')

        # calibrate model
        model = Doubly(flows, origins, destinations, cost, cost_func,
                       Quasi=quasi).fit()

        # format output
        coeffs = []
        stand_errs = []
        t_vals = []
        predicted = model.yhat
        r_squared = np.repeat(model.pseudoR2, n)
        aic = np.repeat(model.AIC, n)

        for idx in xrange(n):
            coeffs.append(
              json.dumps({var: model.params[k]
                          for k, var in enumerate(ind_vars)}))
            stand_errs.append(
              json.dumps({var: model.std_err[k]
                          for k, var in enumerate(ind_vars)}))
            t_vals.append(
              json.dumps({var: model.tvalues[k]
                          for k, var in enumerate(ind_vars)}))

        return zip(coeffs, stand_errs, t_vals, predicted,
                   r_squared, aic, rowid)

    def local_production(self, subquery, flows, origins, d_vars, cost,
                         cost_func, quasi=False, id_col='cartodb_id'):
        """
        subquery: 'select * from demographics'
        flows: 'flow_count'
        origins: ['origin_name1', 'origin_name_2', 'origin_name_3']
        d_vars: ['dest_var_1', 'dest_var_2', 'dest_var_3']
        cost: 'distance' | 'time'
        cost_func: 'exp' for exponential decay | 'pow' for power decay
        quasi: boolean with True for estimate QuasiPoisson model
        """
        # variable names list
        ind_vars = d_vars[:]

        # query_result = subquery
        params = {'id_col': id_col,
                  'subquery': subquery,
                  'dep_var': flows,
                  'ind_vars': d_vars,
                  'origins': origins,
                  'cost': cost}

        result = self.data_provider.get_spint_production(params)

        # add cost name in var name list
        ind_vars.insert(len(ind_vars), cost)

        # unique ids and variable names list
        rowid = np.array(result[0]['rowid'], dtype=np.int)

        # origin names variable for fixed effects (constraints)
        origins = np.array(result[0]['origins'])

        # extract dependent variable
        flows = np.array(result[0]['dep_var']).reshape((-1, 1))

        # extract origin variables, dest variables and cost variable
        n = flows.shape[0]
        d = len(d_vars)
        d_vars = np.zeros((n, d))

        # then dests
        # TODO: replace with pu.get_attributes
        for attr in range(0, d):
            attr_name = 'attr' + str(attr + 1)
            d_vars[:, attr] = np.array(
              result[0][attr_name]).flatten()

        # finally cost
        cost = np.array(result[0]['cost'], dtype=np.float).flatten()

        # calibrate model
        model = Production(flows, origins, d_vars, cost, cost_func,
                           Quasi=quasi)
        local_model = model.local()

        # format output
        coeffs = []
        t_vals = []
        stand_errs = []
        r_squared = local_model['pseudoR2']
        aic = local_model['AIC']

        for idx in xrange(len(np.unique(origins))):
            coeffs.append(
              json.dumps({var: local_model['param' + str(k)][idx]
                          for k, var in enumerate(ind_vars)}))
            t_vals.append(
              json.dumps({var: local_model['tvalue' + str(k)][idx]
                          for k, var in enumerate(ind_vars)}))
            stand_errs.append(
              json.dumps({var: local_model['stde' + str(k)][idx]
                          for k, var in enumerate(ind_vars)}))

        return zip(coeffs, stand_errs, t_vals, r_squared, aic, rowid)

    def local_attraction(self, subquery, flows, destinations, o_vars, cost,
                         cost_func, quasi=False, id_col='cartodb_id'):
        """
        subquery: 'select * from demographics'
        flows: 'flow_count'
        destinations: ['dest_name1', 'dest_name_2', 'dest_name_3']
        o_vars: ['origin_var_1', 'origin_var_2', 'origin_var_3']
        cost: 'distance' | 'time'
        cost_func: 'exp' for exponential decay | 'pow' for power decay
        quasi: boolean with True for estimate QuasiPoisson model
        """
        # variable names list
        ind_vars = o_vars[:]

        # query_result = subquery
        params = {'id_col': id_col,
                  'subquery': subquery,
                  'dep_var': flows,
                  'ind_vars': o_vars,
                  'destinations': destinations,
                  'cost': cost}

        result = self.data_provider.get_spint_attraction(params)

        # add cost name in var name list
        ind_vars.insert(len(ind_vars), cost)

        # unique ids and variable names list
        rowid = np.array(result[0]['rowid'], dtype=np.int)

        # dest names variable for fixed effects (constraints)
        dest_list = np.array(result[0]['destinations'])

        # extract dependent variable
        flows = np.array(result[0]['dep_var']).reshape((-1, 1))

        # extract origin variables, dest variables and cost variable
        n = flows.shape[0]
        o = len(o_vars)
        o_vars = np.zeros((n, o))

        # then dests
        # TODO: replace with pu.get_attributes
        for attr in range(0, o):
            attr_name = 'attr' + str(attr + 1)
            o_vars[:, attr] = np.array(
              result[0][attr_name]).flatten()

        # finally cost
        cost = np.array(result[0]['cost'], dtype=np.float).flatten()

        # calibrate model
        model = Attraction(flows, dest_list, o_vars, cost, cost_func,
                           Quasi=quasi)
        local_model = model.local()

        # format output
        coeffs = []
        t_vals = []
        stand_errs = []
        r_squared = local_model['pseudoR2']
        aic = local_model['AIC']

        for idx in xrange(len(np.unique(dest_list))):
            coeffs.append(
              json.dumps({var: local_model['param' + str(k)][idx]
                          for k, var in enumerate(ind_vars)}))
            t_vals.append(
               json.dumps({var: local_model['tvalue' + str(k)][idx]
                           for k, var in enumerate(ind_vars)}))
            stand_errs.append(
              json.dumps({var: local_model['stde' + str(k)][idx]
                          for k, var in enumerate(ind_vars)}))

        return zip(coeffs, stand_errs, t_vals, r_squared, aic, rowid)

    def local_gravity(self, subquery, flows, o_vars, d_vars, locs, cost,
                      cost_func, quasi=False, id_col='cartodb_id'):
        """
        subquery: 'select * from demographics'
        flows: 'flow_count'
        o_vars: ['origin_var_1', 'origin_var_2', 'origin_var_3']
        d_vars: ['dest_var_1', 'dest_var_2', 'dest_var_3']
        locs: origin_id or destination_id; use origin id's for
        local models focused at each origin and use destination id's for local
        models focused at each destination
        cost: 'distance' | 'time'
        cost_func: 'exp' for exponential decay | 'pow' for power decay
        quasi: boolean with True for estimate QuasiPoisson model
        """

        # concatenate origin and dest variables into one list for query
        ind_vars = o_vars + d_vars

        # query_result = subquery
        params = {'id_col': id_col,
                  'subquery': subquery,
                  'dep_var': flows,
                  'ind_vars': ind_vars,
                  'locs': locs,
                  'cost': cost}

        result = self.data_provider.get_spint_local_gravity(params)

        # add cost name in var name list
        ind_vars.insert(len(ind_vars), cost)

        # unique ids and variable names list
        rowid = np.array(result[0]['rowid'], dtype=np.int)

        # extract dependent variable
        flows = np.array(result[0]['dep_var']).reshape((-1, 1))

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
              result[0][attr_name]).flatten()

        # then dests
        for attr in range(0, d):
            attr_name = 'attr' + str(attr + 1 + o)
            d_vars[:, attr] = np.array(
              result[0][attr_name]).flatten()

        # finally cost
        cost = np.array(result[0]['cost'], dtype=np.float).flatten()

        # get origin or destination id's that are the focus of local models
        locs = np.array(result[0]['locs'])

        # calibrate model
        model = Gravity(flows, o_vars, d_vars, cost, cost_func, Quasi=quasi)
        local_model = model.local(locs, np.unique(locs))

        # format output
        coeffs = []
        t_vals = []
        stand_errs = []
        r_squared = local_model['pseudoR2']
        aic = local_model['AIC']

        for idx in xrange(len(np.unique(locs))):
            coeffs.append(
              json.dumps({var: local_model['param' + str(k)][idx]
                          for k, var in enumerate(ind_vars)}))
            t_vals.append(
              json.dumps({var: local_model['tvalue' + str(k)][idx]
                          for k, var in enumerate(ind_vars)}))
            stand_errs.append(
              json.dumps({var: local_model['stde' + str(k)][idx]
                          for k, var in enumerate(ind_vars)}))

        return zip(coeffs, stand_errs, t_vals, r_squared, aic, rowid)
