from sklearn.cluster import KMeans
import plpy


def kmeans(query, no_clusters, no_init=20):
    """

    """
    full_query = '''
      SELECT array_agg(cartodb_id ORDER BY cartodb_id) as ids,
             array_agg(ST_X(the_geom) ORDER BY cartodb_id) xs,
             array_agg(ST_Y(the_geom) ORDER BY cartodb_id) ys
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


def kmeans_nonspatial(query, colnames, num_clusters=5,
                      id_col='cartodb_id', standarize=True):
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
    out_id_colname = 'rowids'
    # TODO: need a random seed?

    full_query = '''
        SELECT {cols}, array_agg({id_col}) As {out_id_colname}
        FROM ({query}) As a
    '''.format(query=query,
               id_col=id_col,
               out_id_colname=out_id_colname,
               cols=', '.join(['array_agg({0}) As col{1}'.format(val, idx)
                               for idx, val in enumerate(colnames)]))

    try:
        db_resp = plpy.execute(full_query)
        plpy.notice('query: %s' % full_query)
    except plpy.SPIError, err:
        plpy.error('k-means cluster analysis failed: %s' % err)

    # fill array with values for kmeans clustering
    if standarize:
        cluster_columns = _scale_data(
          _extract_columns(db_resp, id_col='cartodb_id'))
    else:
        cluster_columns = _extract_columns(db_resp)

    # TODO: decide on optimal parameters for most cases
    #       Are there ways of deciding parameters based on inputs?
    kmeans = KMeans(n_clusters=num_clusters,
                    random_state=0).fit(cluster_columns)

    return zip(kmeans.predict(X),
               map(str, kmeans.cluster_centers_[kmeans.labels_]),
               db_resp[0][out_id_colname])


def _extract_columns(db_resp, id_col):
    """
        Extract the features from the query and pack them into a NumPy array
        db_resp (plpy data object): result of the kmeans request
        id_col (string): name of column which has the row id (not a feature of
                         the analysis)
    """
    return np.array([db_resp[0][c] for c in db_resp.colnames()
                     if c != id_col],
                    dtype=float).T

# -- Preprocessing steps


def _scale_data(features):
    """
        Scale all input columns to center on 0 with a standard devation of 1
        features (numpy array): an array of dimension (n_features, n_samples)
    """
    from sklearn.preprocessing import StandardScaler
    return StandardScaler().fit_transform(features)
