"""
    Based on the Weiszfeld algorithm:
      https://en.wikipedia.org/wiki/Geometric_median
"""


# import plpy
import numpy as np
from numpy.linalg import norm


def median_center(tablename, geom_col, num_iters=50, tolerance=0.001):

    query = '''
        SELECT array_agg(ST_X({geom_col})) As x_coords,
               array_agg(ST_Y({geom_col})) As y_coords
          FROM {tablename}
    '''.format(geom_col=geom_col, tablename=tablename)

    try:
        resp = plpy.execute(query)
        data = np.vstack((resp['x_coords'][0],
                          resp['y_coords'][0])).T

        plpy.notice('coords: %s' % str(coords))
    except Exception, err:
        # plpy.error('Analysis failed: %s' % err)
        print('No plpy')
        data = np.array([[1.2 * np.random.random() + 10.,
                          1.1 * (np.random.random() - 1.) + 3.]
                        for i in range(1, 100)])

    # initialize 'median center' to be the mean
    coords_center_temp = data.mean(axis=0)

    # plpy.notice('temp_center: %s' % str(coords_center_temp))
    print('temp_center: %s' % str(coords_center_temp))

    for i in range(0, num_iters):
        old_coords_center = coords_center_temp.copy()
        denom = denominator(coords_center_temp, data)
        coords_center_temp = np.sum([data[j] * numerator(coords_center_temp,
                                                         data[j])
                                     for j in range(len(data))], axis=0)
        coords_center_temp = coords_center_temp / denom

        print("Pass #%d" % i)
        print("max, min of data: %0.4f, %0.4f" % (data.max(), data.min()))
        print('temp_center: %s' % str(coords_center_temp))
        print("Change in center: %0.4f" % np.linalg.norm(old_coords_center -
                                                         coords_center_temp))
        print("Center coords: %s" % str(coords_center_temp))
        print("Objective Function: %0.4f" % obj_func(coords_center_temp, data))

    return coords_center_temp


def obj_func(center_coords, data):
    """

    """
    return np.linalg.norm(center_coords - data)


def numerator(center_coords, data_i):
    """

    """
    return np.reciprocal(np.linalg.norm(center_coords - data_i))


def denominator(center_coords, data):
    """

    """
    return np.reciprocal(np.linalg.norm(data - center_coords))
