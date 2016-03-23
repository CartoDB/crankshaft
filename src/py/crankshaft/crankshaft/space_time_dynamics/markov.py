"""
Spatial dynamics measurements using Spatial Markov
"""


import numpy as np
import pysal as ps
import plpy
from crankshaft.clustering import get_query

def spatial_markov_trend(subquery, time_cols, num_time_per_bin, permutations, geom_col, id_col, w_type, num_ngbrs):
    """
        Predict the trends of a unit based on:
        1. history of its transitions to different classes (e.g., 1st quantile -> 2nd quantile)
        2. average class of its neighbors

        Inputs:

        @param subquery string: e.g., SELECT * FROM table_name
        @param time_cols list (string): list of strings of column names
        @param num_time_per_bin int: number of bins to divide # of time columns into
        @param permutations int: number of permutations for test stats
        @param geom_col string: name of column which contains the geometries
        @param id_col string: name of column which has the ids of the table
        @param w_type string: weight type ('knn' or 'queen')
        @param num_ngbrs int: number of neighbors (if knn type)

        Outputs:
        @param trend_up float: probablity that a geom will move to a higher class
        @param trend_down float: probablity that a geom will move to a lower class
        @param trend float: (trend_up - trend_down) / trend_static
        @param volatility float: a measure of the volatility based on probability stddev(prob array)
        @param
    """

    qvals = {"id_col": id_col,
             "time_cols": time_cols,
             "geom_col": geom_col,
             "subquery": subquery,
             "num_ngbrs": num_ngbrs}

    query = get_query(w_type, qvals)

    try:
        query_result = plpy.execute(query)
    except:
        zip([None],[None],[None])

    ## build weight
    weights = get_weight(query_result, w_type)

    ## prep time data
    t_data = get_time_data(query_result, time_cols)
    ## rebin time data
    if num_time_per_bin > 1:
        ## rebin
        t_data = rebin_data(t_data, num_time_per_bin)

    sp_markov_result = ps.Spatial_Markov(t_data, weights, k=7, fixed=False)

    ## get lags
    lags = ps.lag_spatial(weights, t_data)

    ## get lag classes
    lag_classes = ps.Quantiles(lags.flatten(), k=7).yb

    ## look up probablity distribution for each unit according to class and lag class
    prob_dist = get_prob_dist(lag_classes, sp_markov_result.classes)

    ## find the ups and down and overall distribution of each cell
    trend, trend_up, trend_down, volatility = get_prob_stats(prob_dist)

    ## output the results

    return zip(trend, trend_up, trend_down, volatility, weights.id_order)

def get_time_data(markov_data, time_cols):
    """
        Extract the time columns and bin appropriately
    """
    return np.array([[x[t_col] for x in query_result] for t_col in time_cols], dtype=float)

def rebin_data(time_data, num_time_per_bin):
    """
        convert an n x l matrix into an (n/m) x l matrix where the values are reduced (averaged) for the intervening states:
          1 2 3 4    1.5 3.5
          5 6 7 8 -> 5.5 7.5
          9 8 7 6    8.5 6.5
          5 4 3 2    4.5 2.5

          if m = 2

        This process effectively resamples the data at a longer time span n units longer than the input data.
        For cases when there is a remainder (remainder(5/3) = 2), the remaining two columns are binned together as the last time period, while the first three are binned together.

        Input:
          @param time_data n x l  ndarray: measurements of an attribute at different time intervals
          @param num_time_per_bin int: number of columns to average into a new column
        Output:
          ceil(n / m) x l ndarray of resampled time series
    """

    if time_data.shape[1] % num_time_per_bin == 0:
        ## if fit is perfect, then use it
        n_max = time_data.shape[1] / num_time_per_bin
    else:
        ## fit remainders into an additional column
        n_max = time_data.shape[1] / num_time_per_bin + 1

    return np.array([
             time_data[:,
                num_time_per_bin*i:num_time_per_bin*(i+1)].mean(axis=1)
             for i in range(n_max)]).T
def get_prob_dist(transition_matrix, lag_indices, unit_indices):
    """
        given an array of transition matrices, look up the probability associated with the arrangements passed

        Input:
        @param transition_matrix ndarray[k,k,k]:
        @param lag_indices ndarray:
        @param unit_indices ndarray:

        Output:
        Array of probability distributions
    """

    return np.array([transition_matrix[(lag_indices[i], unit_indices[i])] for i in range(len(lag_indices))])

def get_prob_stats(prob_dist, unit_indices):
# trend, trend_up, trend_down, volatility = get_prob_stats(prob_dist)

    trend_up = np.array([prob_dist[:, i:].sum() for i in unit_indices])
    trend_down = np.array([prob_dist[:, :i].sum() for i in unit_indices])
    trend = trend_up - trend_down
    volatility = prob_dist.std(axis=1)


    return trend_up, trend_down, trend, volatility
