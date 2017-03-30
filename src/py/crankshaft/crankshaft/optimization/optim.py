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
            'recycle_rate': kwargs.get('recycle_rate', 0.0)}

        # model data
        self.model_data = {
            'drain_capacity': self.data_provider.get_column(drain_table,
                                                            capacity_column),
            'source_amount': (self.model_params['amount_per_unit'] *
                              (1. - self.model_params['recycle_rate']) *
                              self.data_provider.get_column(source_table,
                                                            production_column)),
            'marginal_cost': self.data_provider.get_column(drain_table,
                                                           marginal_column)}

        # database ids
        self.ids = {
            'drain': self.data_provider.get_column(drain_table,
                                                   'cartodb_id',
                                                   dtype=int),
            'source': self.data_provider.get_column(source_table,
                                                    'cartodb_id',
                                                    dtype=int)}
        # derivative data
        self.n_sources = len(self.ids['source'])
        self.n_drains = len(self.ids['drain'])
        self.cost = self.calc_cost(source_table,
                                   drain_table)

    def _check_constraints(self):
        """Check if inputs are within constraints"""
        if self.model_data['source_amount'].sum() > self.model_data['drain_capacity'].sum():
            plpy.error("Solution not possible. Drain capacity is smaller "
                       "than total source production.")

    def output(self):
        """..."""

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
                           self.cost[drain_index[i],
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

    def calc_cost(self, source_table, drain_table):
        """
        Populate an d x s matrix according to the cost equation

        :returns: d x s matrix of costs from area i to plant j
        :rtype: NumPy matrix
        """
        distances = self.data_provider.get_pairwise_distances(source_table,
                                                              drain_table)
        costs = np.array([self.cost_func(distance,
                                         self.model_data['source_amount'][pair[1]],
                                         self.model_data['marginal_cost'][pair[0]])
                          for pair, distance in np.ndenumerate(distances)])
        return costs.reshape(distances.shape)

    def optim(self):
        """solve linear optimization problem
        Equations of the form:

        minimize   c'*x
        subject to G*x <= h
                   A*x = b
                   x[k] is binary
        :returns: Assignments array (of 1s and 0s) of shape c.T
        :rtype: NumPy array
        """
        # ---
        # costs
        # elements chosen to minimize sum
        cost = cvxopt.matrix(self.cost.ravel('F'))

        # ---
        # equality constraint variables
        # each area is serviced once
        A = cvxopt.spmatrix(1.,
                            [i // self.n_drains
                             for i in range(self.n_drains * self.n_sources)],
                            range(self.n_drains * self.n_sources))
        b = cvxopt.matrix(np.ones((self.n_sources, 1)), tc='d')

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
        assign_shape = (self.cost.shape[1], self.cost.shape[0])

        # Note: assignments needs to be shaped like self.cost.T
        return np.array(assignments,
                        dtype=int).flatten().reshape(assign_shape)
