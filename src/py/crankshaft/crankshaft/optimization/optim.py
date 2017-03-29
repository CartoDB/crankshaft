"""optimization"""
import plpy
import numpy as np
import cvxopt
from cvxopt.glpk import ilp
from crankshaft.analysis_data_provider import AnalysisDataProvider

class Optim(object):
    """Linear optimization class for logistics cost minimization"""

    def __init__(self, drain_table, source_table, capacity_column,
                 production_column, marginal_column, **kwargs):

        # set data provider (defaults to SQL database access
        self.data_provider = kwargs.get('data_provider',
                                        AnalysisDataProvider())

        # optional params
        self.waste_per_person = kwargs.get('waste_per_person', 0.01)
        self.recycle_rate = kwargs.get('recycle_rate', 0.0)
        self.dist_cost = kwargs.get('dist_cost', 0.15)

        # data sources
        self.drain_table = drain_table
        self.source_table = source_table

        # model data
        self.plant_capacity = self.data_provider.get_column(drain_table,
                                                            capacity_column)
        self.waste_in_area = (0.01 * (1. - self.recycle_rate) *
                              self.data_provider.get_column(source_table,
                                                            production_column))
        self.marginal_cost = self.data_provider.get_column(drain_table,
                                                           marginal_column)
        # database ids
        self.drain_ids = self.data_provider.get_column(drain_table,
                                                       'cartodb_id',
                                                       dtype=int)
        self.source_ids = self.data_provider.get_column(source_table,
                                                        'cartodb_id',
                                                        dtype=int)
        # derivative data
        self.distances = self.data_provider.get_pairwise_distances(source_table,
                                                                   drain_table)
        self.n_areas = len(self.waste_in_area)
        self.n_plants = len(self.distances)
        self.cost = self.calc_cost()

    def output(self):
        """..."""

        # n_drains x n_sources matrix (row, column)
        assignments = self.optim()
        # 
        plpy.notice("self.cost.shape: {}".format(str(self.cost.shape)))
        plpy.notice("self.cost: {}".format(self.cost))
        # 
        plpy.notice(assignments)
        plpy.notice("assignments.shape: {}".format(str(assignments.shape)))
        
        # crosswalks for matrix index -> cartodb_id
        drain_id_crosswalk = {}
        for idx, cid in enumerate(self.drain_ids):
            # matrix index -> cartodb_id
            drain_id_crosswalk[idx] = cid
        # plpy.notice(drain_id_crosswalk)
        
        source_id_crosswalk = {}
        for idx, cid in enumerate(self.source_ids):
            # matrix index -> cartodb_id
            source_id_crosswalk[idx] = cid
        # plpy.notice(source_id_crosswalk)
        
        # find non-zero entries
        nonzeros = np.nonzero(assignments)
        plpy.notice("nonzeros: {}".format(str(nonzeros)))
        source_index, drain_index = nonzeros[0], nonzeros[1]
        # 
        plpy.notice(source_index)
        plpy.notice(drain_index)
        assigned_costs = [(drain_id_crosswalk[drain_index[i]],
                           source_id_crosswalk[source_index[i]],
                           self.cost[drain_index[i],
                                     source_index[i]])
                          for i in range(len(source_index))]
        return assigned_costs

    def test(self):
        """
        just plpy.notice the stored information
        """

        plpy.notice(self.source_table)
        plpy.notice(self.drain_table)
        plpy.notice(self.distances)
        plpy.notice(self.plant_capacity)
        plpy.notice(self.waste_in_area)
        return None

    def cost_func(self, distance, waste, marginal):
        """
        cost equation
        """
        return waste * (marginal + self.dist_cost * distance)

    def calc_cost(self):
        """
        Populate an d x s matrix according to the cost equation

        :returns: d x s matrix of costs from area i to plant j
        :rtype: NumPy matrix
        """
        plpy.notice('self.waste_in_area: {}'.format(str(self.waste_in_area.shape)))
        plpy.notice(self.waste_in_area)
        plpy.notice('self.marginal_cost: {}'.format(str(self.marginal_cost.shape)))
        plpy.notice(self.marginal_cost)
        plpy.notice('self.distances: {}'.format(str(self.distances.shape)))
        plpy.notice(self.distances)
        costs = np.array([self.cost_func(distance,
                                         self.waste_in_area[pair[1]],
                                         self.marginal_cost[pair[0]])
                          for pair, distance in np.ndenumerate(self.distances)])
        return costs.reshape(self.distances.shape)

    def optim(self):
        """solve linear optimization problem
        Equations of the form:

        minimize   c'*x
        subject to G*x <= h
                   A*x = b
                   x[k] is binary
        """
        # costs
        # elements chosen to minimize sum
        # NOTE: used to be ravel('F')
        c = cvxopt.matrix(self.cost.ravel('F'))

        # equality constraint variables
        # each area is serviced once
        A = cvxopt.spmatrix(1., 
                            [i // self.n_plants
                             for i in range(self.n_plants * self.n_areas)],
                            range(self.n_plants * self.n_areas))
        b = cvxopt.matrix(np.ones((self.n_areas, 1)), tc='d')

        # inequality constraint variables
        # each plant never goes over capacity
        h = cvxopt.matrix(self.plant_capacity, tc='d')
        G = cvxopt.spmatrix(np.repeat(self.waste_in_area, self.n_plants),
                            [i % self.n_plants
                             for i in range(self.n_plants * self.n_areas)],
                            range(self.n_plants * self.n_areas))
        binary_entries = set(range(len(c)))
        # solve
        (sol, x) = ilp(c=c, G=G, h=h, A=A, b=b, B=binary_entries)
        # assignment = np.array(x).reshape((self.n_areas, self.n_plants))
        if sol != 'optimal':
            raise Exception("No solution possible: {}".format(sol))
        x_shape = (self.cost.shape[1], self.cost.shape[0])
        # Note: x needs to be shaped like self.cost.T
        return np.array(x, dtype=int).flatten().reshape(x_shape)
