"""optimization"""
import plpy
import numpy as np
import cvxopt
from cvxopt.glpk import ilp
from crankshaft.analysis_data_provider import AnalysisDataProvider

class Optim(object):
    """Linear optimization class for logistics cost minimization
    Optimization for logistics
    based on models:
      - amount_per_unit * (1 - recycle_rate) * population
      - source_amount * (marginal_cost + transport_cost * distance)
    That is, `cost ~ population * distance`
    """

    def __init__(self, drain_table, source_table, capacity_column,
                 production_column, marginal_column, **kwargs):

        # set data provider (defaults to SQL database access
        self.data_provider = kwargs.get('data_provider',
                                        AnalysisDataProvider())
        # model parameters
        self.model_params = {
            'amount_per_unit': kwargs.get('amount_per_unit', 0.01),
            'dist_cost': kwargs.get('dist_cost', 0.15),
            'recycle_rate': kwargs.get('recycle_rate', 0.0),
            'dist_threshold': kwargs.get('dist_threshold', None)}
        self._check_model_params()

        # model data
        self.model_data = {
            'drain_capacity': self.data_provider.get_column(drain_table,
                                                            capacity_column),
            'source_amount': (self.model_params['amount_per_unit'] *
                              (1. - self.model_params['recycle_rate']) *
                              self.data_provider.get_column(source_table,
                                                            production_column)),
            'marginal_cost': self.data_provider.get_column(drain_table,
                                                           marginal_column),
            'distance': self.data_provider.get_pairwise_distances(source_table,
                                                                  drain_table),
            'cost': self.calc_cost()
        }

        # database ids
        self.ids = {
            'drain': self.data_provider.get_column(drain_table,
                                                   'cartodb_id',
                                                   dtype=int),
            'source': self.data_provider.get_column(source_table,
                                                    'cartodb_id',
                                                    dtype=int)}
        self.n_sources = len(self.ids['source'])
        self.n_drains = len(self.ids['drain'])

    def _check_constraints(self):
        """Check if inputs are within constraints"""
        if (self.model_data['source_amount'].sum() >
                self.model_data['drain_capacity'].sum()):
            plpy.error("Solution not possible. Drain capacity is smaller "
                       "than total source production.")
        return None

    def _check_model_params(self):
        """Ensure model parameters are well formed"""

        if (self.model_params['recycle_rate'] is None or
                self.model_params['recycle_rate'] < 0 or
                self.model_params['recycle_rate'] > 1):
            raise ValueError("`recycle_rate` must be between 0 and 1.")

        if (self.model_params['amount_per_unit'] is None or
                self.model_params['amount_per_unit'] < 0):
            raise ValueError("`amount_per_unit` must be greater than zero.")

        if (self.model_params['dist_threshold'] is None or
                self.model_params['dist_threshold'] < 0):
            raise ValueError("`dist_threshold` must be greater than zero")

        if (self.model_params['dist_cost'] is None or
                self.model_params['dist_cost'] < 0):
            raise ValueError("`dist_cost must be greater than zero")

        return None

    def output(self):
        """Output the calculated 'optimal' assignments if solution is not infeasible.

        :returns: List of source id/drain id pairs and the associated cost of
        transport from source to drain
        :rtype: List of tuples
        """

        # n_drains x n_sources matrix (row, column)
        assignments = self.optim()

        # crosswalks for matrix index -> cartodb_id
        drain_id_crosswalk = {}
        for idx, cid in enumerate(self.ids['drain']):
            # matrix index -> cartodb_id
            drain_id_crosswalk[idx] = cid

        source_id_crosswalk = {}
        for idx, cid in enumerate(self.ids['source']):
            # matrix index -> cartodb_id
            source_id_crosswalk[idx] = cid

        # find non-zero entries
        nonzeros = np.nonzero(assignments)
        source_index, drain_index = nonzeros[0], nonzeros[1]
        #
        assigned_costs = [(drain_id_crosswalk[drain_index[i]],
                           source_id_crosswalk[source_index[i]],
                           self.model_data['cost'][drain_index[i],
                                                   source_index[i]])
                          for i in range(len(source_index))]
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
        :rtype: NumPy matrix
        """
        costs = np.array([self.cost_func(distance,
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
                   x[k] is binary
        :returns: Assignments array (of 1s and 0s) of shape c.T
        :rtype: NumPy array
        """
        # ---
        # costs
        # elements chosen to minimize sum
        cost = cvxopt.matrix(self.model_data['cost'].ravel('F'))

        # ---
        # equality constraint variables
        # each area is serviced once
        A = cvxopt.spmatrix(1.,
                            [i // self.n_drains
                             for i in range(self.n_drains * self.n_sources)],
                            range(self.n_drains * self.n_sources))
        b = cvxopt.matrix(np.ones((self.n_sources, 1)), tc='d')

        # knock out values above distance threshold
        if self.model_params['dist_threshold']:
            j_locs, i_locs = np.where(self.model_data['distance'] > 100)
            for idx, ival in enumerate(i_locs):
                A[int(ival), int(ival * 10 + j_locs[idx])] = 0

        # ---
        # inequality constraint variables
        # each plant never goes over capacity
        drain_capacity = cvxopt.matrix(self.model_data['drain_capacity'],
                                       tc='d')
        source_amounts = cvxopt.spmatrix(
            np.repeat(self.model_data['source_amount'], self.n_drains),
            [i % self.n_drains for i in range(self.n_drains * self.n_sources)],
            range(self.n_drains * self.n_sources))

        binary_entries = set(range(self.n_drains * self.n_sources))

        # solve
        (sol, assignments) = ilp(c=cost, G=source_amounts, h=drain_capacity,
                                 A=A, b=b, B=binary_entries)
        if sol != 'optimal':
            raise Exception("No solution possible: {}".format(sol))
        assign_shape = (self.model_data['cost'].shape[1], self.model_data['cost'].shape[0])

        # Note: assignments needs to be shaped like self.model_data['cost'].T
        return np.array(assignments,
                        dtype=int).flatten().reshape(assign_shape)
