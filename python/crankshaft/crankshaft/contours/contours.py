
import matplotlib.pyplot as plt
import numpy as np
import plpy

def contour_to_polygon(contour):
    plpy.notice('appending contour ')
    c = np.append(contour, [contour[0]], axis=0)
    points =','.join( [  " ".join(str(a) for a in b) for b in c])

    return "POLYGON(({points}))::geometry".format(points=points)

def create_countours_count(query,levels,mesh_size=20):
    qresult = plpy.execute( "select ST_X(the_geom)::Numeric as x, ST_Y(the_geom)::Numeric as y from ({query}) a ".format(query=query))
    x =[]
    y =[]
    for a in qresult:
        if a['x'] and a['y']:
            x.append(float(a['x']))
            y.append(float(a['y']))

    plpy.notice(np.shape(x))
    plpy.notice(np.shape(y))

    if None in x:
        plpy.notice("NULL IN LIST X ")
    if None in y:
        plpy.notice("NULL IN LIST Y ")

    x_min,x_max = np.min(x), np.max(x)
    y_min,y_max = np.min(y), np.max(y)
    plpy.notice(x_min)
    plpy.notice(x_max)
    plpy.notice(y_min)
    plpy.notice(y_max)
    plpy.notice(mesh_size)

    x_grid = np.linspace(x_min,x_max, mesh_size)
    y_grid = np.linspace(y_min,y_max, mesh_size)
    range  = [[x_min,x_max],[y_min,y_max]]
    a, xedges, yedges= np.histogram2d(x,y,bins=(mesh_size,mesh_size), range=range)
    a = np.swapaxes(a,0,1)
    plpy.notice("here about to create the contours")

    CS = plt.contour(xedges[1:],yedges[1:] ,a,4,linewidths=0.5, colors='b')
    plpy.notice(levels)
    return[(contour_to_polygon(CS.Cntr.trace((level))[0]), float(level)) for level in levels]
