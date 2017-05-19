"""optimization"""
import plpy
import numpy as np
import cvxopt
from cvxopt import solvers
from crankshaft.analysis_data_provider import AnalysisDataProvider

class Optim(object):
    """Linear optimization class for logistics cost minimization
    Optimization for logistics
    based on models:
      - source_amount * (marginal_cost + transport_cost * distance)
    """

    def __init__(self, source_query, drain_query, dist_matrix_table,
                 capacity_column, production_column, marginal_column,
                 **kwargs):

        # set data provider - defaults to SQL database access
        self.data_provider = kwargs.get('data_provider',
                                        AnalysisDataProvider())
        # model parameters
        self.model_params = {
            'dist_cost': kwargs.get('dist_cost', 0.15),
            'dist_threshold': kwargs.get('dist_threshold', None),
            'solver': kwargs.get('solver', 'glpk')}
        self._check_model_params()

        # database ids
        self.ids = {
            'drain': self.data_provider.get_column(
                drain_query,
                'cartodb_id',
                id_col='cartodb_id',
                dtype=int),
            'source_free': self.data_provider.get_column(
                source_query,
                'cartodb_id',
                dtype=int,
                condition='drain_id is null'),
            'source_fixed': self.data_provider.get_column(
                source_query,
                'cartodb_id',
                dtype=int,
                condition='drain_id is not null')}

        # model data
        self.model_data = {
            'drain_capacity': self.data_provider.get_reduced_column(
                drain_query,
                capacity_column,
                source_query,
                production_column,
                id_col='cartodb_id',
                dtype=int),
            'source_amount': self.data_provider.get_column(source_query,
                                                           production_column,
                                                           condition='drain_id is null'),
            'marginal_cost': self.data_provider.get_column(
                drain_query,
                marginal_column),
            'distance':
                self.data_provider.get_distance_matrix(dist_matrix_table,
                                                       self.ids['source_free'],
                                                       self.ids['drain'])}
        self.model_data['cost'] = self.calc_cost()
        self.n_sources = len(self.ids['source_free'])
        self.n_drains = len(self.ids['drain'])

    def _check_constraints(self):
        """Check if inputs are within constraints"""
        total_capacity = self.model_data['drain_capacity'].sum()
        total_amount = self.model_data['source_amount'].sum()
        if total_amount > total_capacity:
            raise ValueError("Solution not possible. Drain capacity is "
                             "smaller than total source production.")
        elif total_capacity <= 0:
            raise ValueError("Capacity must be greater than zero")

        plpy.notice('Capacity: {total_capacity}, '
                    'Amount: {total_amount} '
                    '({perc}%)'.format(total_capacity=total_capacity,
                                       total_amount=total_amount,
                                       perc=100.0 * total_amount / total_capacity))
        return None

    def _check_model_params(self):
        """Ensure model parameters are well formed"""

        if (self.model_params['dist_threshold'] <= 0 and
                self.model_params['dist_threshold'] is not None):
            raise ValueError("`dist_threshold` must be greater than zero")

        if (self.model_params['dist_cost'] is None or
                self.model_params['dist_cost'] < 0):
            raise ValueError("`dist_cost` must be greater than zero")

        if self.model_params['solver'] not in (None, 'glpk'):
            raise ValueError("`solver` must be one of 'glpk' (default) "
                             "or None.")

        return None

    def output(self):
        """Output the calculated 'optimal' assignments if solution is not infeasible.

        :returns: List of source id/drain id pairs and the associated cost of
        transport from source to drain
        :rtype: List of tuples
        """
        # retrieve fractional assignments
        assignments = self.optim()

        # crosswalks for matrix index -> cartodb_id
        drain_id_crosswalk = {}
        for idx, cid in enumerate(self.ids['drain']):
            # matrix index -> cartodb_id
            drain_id_crosswalk[idx] = cid

        source_id_crosswalk = {}
        for idx, cid in enumerate(self.ids['source_free']):
            # matrix index -> cartodb_id
            source_id_crosswalk[idx] = cid

        # find non-zero entries
        source_index, drain_index = np.nonzero(assignments)
        # returns:
        #   - drain_id
        #   - source_id
        #   - cost of that pairing
        #   - amount sent via that pairing
        assigned_costs = [(
            drain_id_crosswalk[drain_index[idx]],
            source_id_crosswalk[source_val],
            self.model_data['cost'][drain_index[idx], source_val],
            round(self.model_data['source_amount'][source_val] *
                  assignments[source_val, drain_index[idx]], 6)
            )
                          for idx, source_val in enumerate(source_index)]
        return assigned_costs

    def cost_func(self, distance, waste, marginal):
        """
        cost equation

        :param distance: distance (in km)
        :type distance: float
        :param waste: number of tons of waste. This was previously calculated
        as self.model_params['amount_per_unit'] * number of people minus the recycle_rate
        :type waste: numeric
        :param marginal: intrinsic cost per ton of a plant
        :type marginal: numeric
        :returns: cost
        :rtype: numeric

        Note: dist_cost is the cost per ton (0.15 GBP/ton)
        """
        return waste * (marginal + self.model_params['dist_cost'] * distance)

    def calc_cost(self):
        """
        Populate an d x s matrix according to the cost equation

        :returns: d x s matrix of costs from area i to plant j
        :rtype: numpy.array
        """
        costs = np.array(
            [self.cost_func(distance,
                            self.model_data['source_amount'][pair[1]],
                            self.model_data['marginal_cost'][pair[0]])
             for pair, distance in np.ndenumerate(self.model_data['distance'])])
        return costs.reshape(self.model_data['distance'].shape)

    def optim(self):
        """solve linear optimization problem
        Equations of the form:

        minimize   c'*x     by assigning x values
        subject to G*x <= h
                   A*x = b
                   0 <= x[k] <= 1
        :returns: Fractional assignments array (of 1s and 0s) of shape c.T.
            Value at position (i, j) corresponds to the fraction of source
            `i`'s supply to drain `j`.

        :rtype: numpy.array
        """
        n_pairings = self.n_sources * self.n_drains

        # ---
        # costs
        # elements chosen to minimize sum
        cost = np.nan_to_num(self.model_data['cost'])
        cost = cvxopt.matrix(cost.ravel('F'))

        # ---
        # equality constraint variables
        # each area is serviced once
        A = cvxopt.spmatrix(1.,
                            [i // self.n_drains
                             for i in range(n_pairings)],
                            range(n_pairings), tc='d')
        b = cvxopt.matrix([1.] * self.n_sources, tc='d')

        # make nan's in cost impossible
        if np.isnan(self.model_data['distance']).any():
            i_vals, j_vals = np.where(np.isnan(self.model_data['distance']))
            for idx, i_val in enumerate(i_vals):
                i = int(i_val)
                j = int(i_val * self.n_drains + j_vals[idx])
                A[i, j] = 0

        # knock out values above distance threshold
        if self.model_params['dist_threshold']:
            j_vals, i_vals = np.where(self.model_data['distance'] >
                                      self.model_params['dist_threshold'])
            for idx, ival in enumerate(i_vals):
                A[int(ival), int(ival * self.n_drains + j_vals[idx])] = 0

        # ---
        # inequality constraint variables
        # each plant never goes over capacity
        drain_capacity = cvxopt.matrix([
            cvxopt.matrix(self.model_data['drain_capacity'], tc='d'),
            cvxopt.matrix([1.] * n_pairings, tc='d'),
            cvxopt.matrix([0.] * n_pairings, tc='d')
        ])

        # inequality maxima
        ineq_maxs = cvxopt.sparse([
            cvxopt.spmatrix(
                np.repeat(self.model_data['source_amount'], self.n_drains),
                [i % self.n_drains for i in range(n_pairings)],
                range(n_pairings), tc='d'),
            cvxopt.spmatrix(1.,
                            range(n_pairings),
                            range(n_pairings)),
            cvxopt.spmatrix(-1.,
                            range(n_pairings),
                            range(n_pairings))
            ], tc='d')
        for var in (cost, ineq_maxs, drain_capacity, A, b):
            plpy.notice('size: {}'.format(var.size))
        plpy.notice('{}, {}, {}'.format(n_pairings, self.n_sources, self.n_drains))
        # solve
        sol = solvers.lp(c=cost, G=ineq_maxs, h=drain_capacity,
                         A=A, b=b, solver=self.model_params['solver'])
        if sol['status'] != 'optimal':
            raise Exception("No solution possible: {}".format(sol))

        # NOTE: assignments needs to be shaped like self.model_data['cost'].T
        return np.array(sol['x'],
                        dtype=float)\
                   .flatten()\
                   .reshape((self.model_data['cost'].shape[1],
                             self.model_data['cost'].shape[0]))
