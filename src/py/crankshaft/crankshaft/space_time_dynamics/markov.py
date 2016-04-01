"""
Spatial dynamics measurements using Spatial Markov
"""


import numpy as np
import pysal as ps
import plpy
import crankshaft.pysal_utils as pu

def spatial_markov_trend(subquery, time_cols, num_time_per_bin,
                         permutations, geom_col, id_col, w_type, num_ngbrs):
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

    if num_time_per_bin < 1:
        plpy.error('Error: number of time bins must be >= 1')

    qvals = {"id_col": id_col,
             "time_cols": time_cols,
             "geom_col": geom_col,
             "subquery": subquery,
             "num_ngbrs": num_ngbrs}

    query = pu.construct_neighbor_query(w_type, qvals)

    try:
        query_result = plpy.execute(query)
    except plpy.SPIError, err:
        plpy.notice('** Query failed with exception %s: %s' % (err, query))
        plpy.error('Spatial Markov failed: check the input parameters')
        return zip([None], [None], [None], [None], [None])

    ## build weight
    weights = pu.get_weight(query_result, w_type)

    ## prep time data
    t_data = get_time_data(query_result, time_cols)
    ## rebin time data
    if num_time_per_bin > 1:
        ## rebin
        t_data = rebin_data(t_data, int(num_time_per_bin))

    print 'shape of t_data %d, %d' % t_data.shape
    print 'number of weight objects: %d, %d' % (weights.sparse).shape
    print 'first num elements: %f' % t_data[0, 0]
    # ls = ps.lag_spatial(weights, t_data)

    sp_markov_result = ps.Spatial_Markov(t_data,
                                         weights,
                                         k=7,
                                         fixed=False,
                                         permutations=permutations)

    ## get lag classes
    lag_classes = ps.Quantiles(ps.lag_spatial(weights, t_data[:, -1]), k=7).yb

    ## look up probablity distribution for each unit according to class and lag class
    prob_dist = get_prob_dist(sp_markov_result.P, lag_classes, sp_markov_result.classes[:, -1])

    ## find the ups and down and overall distribution of each cell
    trend_up, trend_down, trend, volatility = get_prob_stats(prob_dist,
                                                             sp_markov_result.classes[:, -1])

    ## output the results

    return zip(trend, trend_up, trend_down, volatility, weights.id_order)

def get_time_data(markov_data, time_cols):
    """
        Extract the time columns and bin appropriately
    """
    num_attrs = len(time_cols)
    return np.array([[x['attr' + str(i)] for x in markov_data]
                     for i in range(1, num_attrs+1)], dtype=float).transpose()

def rebin_data(time_data, num_time_per_bin):
    """
        Convert an n x l matrix into an (n/m) x l matrix where the values are
         reduced (averaged) for the intervening states:
          1 2 3 4    1.5 3.5
          5 6 7 8 -> 5.5 7.5
          9 8 7 6    8.5 6.5
          5 4 3 2    4.5 2.5

          if m = 2, the 4 x 4 matrix is transformed to a 2 x 4 matrix.

        This process effectively resamples the data at a longer time span n
         units longer than the input data.
        For cases when there is a remainder (remainder(5/3) = 2), the remaining
         two columns are binned together as the last time period, while the
         first three are binned together for the first period.

        Input:
          @param time_data n x l  ndarray: measurements of an attribute at
           different time intervals
          @param num_time_per_bin int: number of columns to average into a new
           column
        Output:
          ceil(n / m) x l ndarray of resampled time series
    """

    if time_data.shape[1] % num_time_per_bin == 0:
        ## if fit is perfect, then use it
        n_max = time_data.shape[1] / num_time_per_bin
    else:
        ## fit remainders into an additional column
        n_max = time_data.shape[1] / num_time_per_bin + 1

    return np.array([time_data[:, num_time_per_bin * i:num_time_per_bin * (i+1)].mean(axis=1)
                     for i in range(n_max)]).T
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
            @param trend_down ndarray(float): sum of probabilities for downard
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
        trend[i] = (trend_up[i] - trend_down[i]) / prob_dist[i, unit_indices[i]]

    ## calculate volatility of distribution
    volatility = prob_dist.std(axis=1)

    return trend_up, trend_down, trend, volatility
