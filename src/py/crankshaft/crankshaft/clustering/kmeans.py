from sklearn.cluster import KMeans
import plpy

def kmeans(query, no_clusters, no_init=20):
    data = plpy.execute('''select array_agg(cartodb_id order by cartodb_id) as ids,
        array_agg(ST_X(the_geom) order by cartodb_id) xs,
        array_agg(ST_Y(the_geom) order by cartodb_id) ys from ({query}) a
    '''.format(query=query))

    xs  = data[0]['xs']
    ys  = data[0]['ys']
    ids = data[0]['ids']

    km = KMeans(n_clusters= no_clusters, n_init=no_init)
    labels = km.fit_predict(zip(xs,ys))
    return zip(ids,labels)

