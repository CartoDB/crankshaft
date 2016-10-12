from sklearn.cluster import KMeans
import plpy


def kmeans(query, no_clusters, no_init=20):
    """

    """
    full_query = '''
      SELECT array_agg(cartodb_id ORDER BY cartodb_id) as ids,
             array_agg(ST_X(the_geom) ORDER BY cartodb_id) xs,
             array_agg(ST_Y(the_geom) ORDER BY cartodb_id)
        FROM ({query}) As a
       WHERE the_geom IS NOT NULL
        '''.format(query=query)
    try:
        data = plpy.execute(full_query)
    except plpy.SPIError, err:
        plpy.error("KMeans cluster failed: %s" % err)

    xs = data[0]['xs']
    ys = data[0]['ys']
    ids = data[0]['ids']

    km = KMeans(n_clusters=no_clusters, n_init=no_init)
    labels = km.fit_predict(zip(xs, ys))
    return zip(ids, labels)


def kmeans_nonspatial(query, colnames, num_clusters=5, id_col='cartodb_id'):
    """
        query (string): A SQL query to retrieve the data required to do the
                        k-means clustering analysis, like so:
                        SELECT * FROM iris_flower_data
        colnames (list): a list of the column names which contain the data of
                         interest, like so: ["sepal_width", "petal_width",
                                             "sepal_length", "petal_length"]
        num_clusters (int): number of clusters (greater than zero)
        id_col (string): name of the input id_column
    """
    import numpy as np
    id_colname = 'rowids'

    full_query = '''
        SELECT {cols}, array_agg({id_col}) As {id_colname}
        FROM ({query}) As a
    '''.format(query=query,
               id_col=id_col,
               id_colname=id_colname,
               cols=', '.join(['array_agg({0}) As col{1}'.format(val, idx)
                               for idx, val in enumerate(colnames)]))

    try:
        data = plpy.execute(full_query)
        plpy.notice('query: %s' % full_query)

        # fill array with values for kmeans clustering
        cluster_columns = np.array([data[0][c] for c in data.colnames() 
                                    if c != 'id_colname'],
                                   dtype=float).T
    except plpy.SPIError, err:
        plpy.error('KMeans cluster failed: %s' % err)

    kmeans = KMeans(n_clusters=num_clusters, random_state=0).fit(cluster_columns)

    # zip(ids, labels, means)
    return zip(kmeans.labels_, map(str, kmeans.cluster_centers_),
               data[0]['rowids'])
