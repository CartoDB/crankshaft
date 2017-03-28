"""optimization"""
import sys
import cvxopt
from cvxopt.glpk import ilp
import numpy as np
import plpy
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
        # derivative data
        self.distances = self.data_provider.get_pairwise_distances(source_table,
                                                                   drain_table)
        self.n_areas = len(self.waste_in_area)
        self.n_plants = len(self.distances)
        self.cost = self.calc_cost()

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
        return costs

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
        c = cvxopt.matrix(self.cost.ravel('F'))

        # equality constraint variables
        # each area is serviced once
        A = cvxopt.spmatrix(1., [i // self.n_plants
                                 for i in range(self.n_plants * self.n_areas)],
                                range(self.n_plants * self.n_areas))
        b = cvxopt.matrix(np.ones((self.n_areas, 1)), tc='d')

        # inequality constraint variables
        # each plant never goes over capacity
        h = cvxopt.matrix(self.plant_capacity)
        G = cvxopt.spmatrix(np.repeat(self.waste_in_area, self.n_plants),
                            [i % self.n_plants
                             for i in range(self.n_plants * self.n_areas)],
                            range(self.n_plants * self.n_areas))

        # solve
        sol, x = ilp(c=c, G=G, h=h, A=A, b=b)
        # assignment = np.array(x).reshape((self.n_areas, self.n_plants))
        if sol != 'optimal':
            raise Exception("Solution not soluble: {}".format(sol))

        return np.array(x)
