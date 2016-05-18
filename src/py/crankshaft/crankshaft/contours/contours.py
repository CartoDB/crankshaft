from scipy.stats import gaussian_kde
from scipy.interpolate import griddata
import numpy as np 
from sklearn.neighbors import KernelDensity
from skimage.measure import find_contours
import plpy


def cdb_generate_contours(query, grid_size, bandwidth, levels):
    data   = plpy.execute( 'select ST_X(the_geom) as x , ST_Y(the_geom) as y from ({query})')
    xs, ys = [d['x'], d['y'] from data]
    return generate_contours(xs,xy,grid_size,bandwidth,levels)
    
def scale_coord(coord, x_range,y_range,grid_size):
    return [coord[0]*(x_range[1]-x_range[0])/grid_size+x_range[0],
            coord[1]*(y_range[1]-y_range[0])/grid_size+y_range[0]]
    
def make_wkt(data,x_range, y_range, grid_size):
    joined = ','.join([' '.join(map(str,scale_coord(coord_pair, x_range, y_range, grid_size))) for coord_pair in data])
    return '({0})'.format(joined)
    
def make_multi_line(data,x_range,y_range, grid_size):
    joined = ','.join([ make_wkt(ring,x_range,y_range,grid_size)  for ring in data ])
    return 'MULTILINESTRING({0})'.format(joined)

def generate_contours(xs,ys, grid_res=100, bandwidth=0.0001, levels=None):
    max_y, min_y = ys.max(), ys.min()
    max_x, min_x = xs.max(), xs.min()
    positions = np.vstack([ys,xs]).T
    grid_x,grid_y = np.meshgrid(np.linspace(min_x, max_x , grid_res), np.linspace(min_y, max_y, grid_res))
    xy = np.vstack([grid_y.ravel(), grid_x.ravel()]).T
    xy *= np.pi / 180.

    kde = KernelDensity(bandwidth=0.0001, metric='haversine',
                        kernel='gaussian', algorithm='ball_tree')
    kde.fit(positions*np.pi/180.)
    results = np.exp(kde.score_samples(xy))
    results = results.reshape((grid_x.shape[0], grid_y.shape[0]))
    
    if not levels:
        levels = np.linspace(results.min(), results.max(),60)

    CS = [find_contours(results, level) for level in levels]
    
    vertices = []
    for contours,level in zip(CS,levels):
        if len(contours)>0:
            multiline = make_multi_line(contours, (min_x,max_x), (min_y, max_y), grid_res)
            vertices.append([level, multiline ])
    
    return vertices
