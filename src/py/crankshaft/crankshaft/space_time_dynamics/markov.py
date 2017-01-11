"""
Spatial dynamics measurements using Spatial Markov
"""

# TODO: remove all plpy dependencies

import numpy as np
import pysal as ps
import plpy
import crankshaft.pysal_utils as pu
from crankshaft.analysis_data_provider import AnalysisDataProvider


class Markov:
    def __init__(self, data_provider=None):
        if data_provider is None:
            self.data_provider = AnalysisDataProvider()
        else:
            self.data_provider = data_provider

    def spatial_trend(self, subquery, time_cols, num_classes=7,
                      w_type='knn', num_ngbrs=5, permutations=0,
                      geom_col='the_geom', id_col='cartodb_id'):
        """
            Predict the trends of a unit based on:
            1. history of its transitions to different classes (e.g., 1st
               quantile -> 2nd quantile)
            2. average class of its neighbors

            Inputs:
            @param subquery string: e.g., SELECT the_geom, cartodb_id,
              interesting_time_column FROM table_name
            @param time_cols list of strings: list of strings of column names
            @param num_classes (optional): number of classes to break
              distribution of values into. Currently uses quantile bins.
            @param w_type string (optional): weight type ('knn' or 'queen')
            @param num_ngbrs int (optional): number of neighbors (if knn type)
            @param permutations int (optional): number of permutations for test
              stats
            @param geom_col string (optional): name of column which contains
              the geometries
            @param id_col string (optional): name of column which has the ids
              of the table

            Outputs:
            @param trend_up float: probablity that a geom will move to a higher
              class
            @param trend_down float: probablity that a geom will move to a
              lower class
            @param trend float: (trend_up - trend_down) / trend_static
            @param volatility float: a measure of the volatility based on
              probability stddev(prob array)
        """

        if len(time_cols) < 2:
            plpy.error('More than one time column needs to be passed')

        params = {"id_col": id_col,
                  "time_cols": time_cols,
                  "geom_col": geom_col,
                  "subquery": subquery,
                  "num_ngbrs": num_ngbrs}

        query_result = self.data_provider.get_markov(w_type, params)

        # build weight
        weights = pu.get_weight(query_result, w_type)
        weights.transform = 'r'

        # prep time data
        t_data = pu.get_attributes(query_result, len(time_cols))

        sp_markov_result = ps.Spatial_Markov(t_data,
                                             weights,
                                             k=num_classes,
                                             fixed=False,
                                             permutations=permutations)

        # get lag classes
        lag_classes = ps.Quantiles(
            ps.lag_spatial(weights, t_data[:, -1]),
            k=num_classes).yb

        # look up probablity distribution for each unit according to class and
        #  lag class
        prob_dist = get_prob_dist(sp_markov_result.P,
                                  lag_classes,
                                  sp_markov_result.classes[:, -1])

        # find the ups and down and overall distribution of each cell
        trend_up, trend_down, trend, \
            volatility = get_prob_stats(
                prob_dist,
                sp_markov_result.classes[:, -1])

        # output the results
        return zip(trend, trend_up, trend_down, volatility, weights.id_order)


def get_prob_dist(transition_matrix, lag_indices, unit_indices):
    """
        Given an array of transition matrices, look up the probability
        associated with the arrangements passed

        Input:
        @param transition_matrix ndarray[k,k,k]:
        @param lag_indices ndarray:
        @param unit_indices ndarray:

        Output:
        Array of probability distributions
    """

    return np.array([transition_matrix[(lag_indices[i], unit_indices[i])]
                     for i in range(len(lag_indices))])


def get_prob_stats(prob_dist, unit_indices):
    """
        get the statistics of the probability distributions

        Outputs:
            @param trend_up ndarray(float): sum of probabilities for upward
               movement (relative to the unit index of that prob)
            @param trend_down ndarray(float): sum of probabilities for downward
               movement (relative to the unit index of that prob)
            @param trend ndarray(float): difference of upward and downward
               movements
    """

    num_elements = len(unit_indices)
    trend_up = np.empty(num_elements, dtype=float)
    trend_down = np.empty(num_elements, dtype=float)
    trend = np.empty(num_elements, dtype=float)

    for i in range(num_elements):
        trend_up[i] = prob_dist[i, (unit_indices[i]+1):].sum()
        trend_down[i] = prob_dist[i, :unit_indices[i]].sum()
        if prob_dist[i, unit_indices[i]] > 0.0:
            trend[i] = (trend_up[i] - trend_down[i]) / (
              prob_dist[i, unit_indices[i]])
        else:
            trend[i] = None

    # calculate volatility of distribution
    volatility = prob_dist.std(axis=1)

    return trend_up, trend_down, trend, volatility
