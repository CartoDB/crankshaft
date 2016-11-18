from sklearn.cluster import KMeans
import plpy
import numpy as np


class QueryRunner:
    def get_moran(self, query):
        """fetch data for moran's i analyses"""
        try:
            result = plpy.execute(query)
            # if there are no neighbors, exit
            if len(result) == 0:
                return pu.empty_zipped_array(2)
        except plpy.SPIError, e:
            plpy.error('Analysis failed: %s' % e)
            return pu.empty_zipped_array(2)

    def get_columns(self, query, standarize):
        """fetch data for non-spatial kmeans"""
        try:
            db_resp = plpy.execute(query)
        except plpy.SPIError, err:
            plpy.error('Analysis failed: %s' % err)

        return db_resp

    def get_result(self, query):
        """fetch data for spatial kmeans"""
        try:
            data = plpy.execute(query)
        except plpy.SPIError, err:
            plpy.error("Analysis failed: %s" % err)
        return data


class Kmeans:
    def __init__(self, query_runner=None):
        if query_runner is None:
            self.query_runner = QueryRunner()
        else:
            self.query_runner = query_runner

    def spatial(self, query, no_clusters, no_init=20):
        """
            find centers based on clusters of latitude/longitude pairs
            query: SQL query that has a WGS84 geometry (the_geom)
        """
        full_query = ("SELECT "
                      "array_agg(cartodb_id ORDER BY cartodb_id) as ids,"
                      "array_agg(ST_X(the_geom) ORDER BY cartodb_id) xs,"
                      "array_agg(ST_Y(the_geom) ORDER BY cartodb_id) ys "
                      "FROM ({query}) As a "
                      "WHERE the_geom IS NOT NULL").format(query=query)

        data = self.query_runner.get_result(full_query)

        # Unpack query response
        xs = data[0]['xs']
        ys = data[0]['ys']
        ids = data[0]['ids']

        km = KMeans(n_clusters=no_clusters, n_init=no_init)
        labels = km.fit_predict(zip(xs, ys))
        return zip(ids, labels)

    def nonspatial(self, query, colnames, num_clusters=5,
                   id_col='cartodb_id', standarize=True):
        """
            query (string): A SQL query to retrieve the data required to do the
                            k-means clustering analysis, like so:
                            SELECT * FROM iris_flower_data
            colnames (list): a list of the column names which contain the data
                             of interest, like so: ["sepal_width",
                                                    "petal_width",
                                                    "sepal_length",
                                                    "petal_length"]
            num_clusters (int): number of clusters (greater than zero)
            id_col (string): name of the input id_column
        """
        import json
        from sklearn import metrics

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

        db_resp = self.query_runner.get_columns(full_query, standarize)

        # fill array with values for k-means clustering
        if standarize:
            cluster_columns = _scale_data(
              _extract_columns(db_resp, colnames))
        else:
            cluster_columns = _extract_columns(db_resp, colnames)

        print str(cluster_columns)
        # TODO: decide on optimal parameters for most cases
        #       Are there ways of deciding parameters based on inputs?
        kmeans = KMeans(n_clusters=num_clusters,
                        random_state=0).fit(cluster_columns)

        centers = [json.dumps(dict(zip(colnames, c)))
                   for c in kmeans.cluster_centers_[kmeans.labels_]]

        silhouettes = metrics.silhouette_samples(cluster_columns,
                                                 kmeans.labels_,
                                                 metric='sqeuclidean')

        return zip(kmeans.labels_,
                   centers,
                   silhouettes,
                   db_resp[0][out_id_colname])


# -- Preprocessing steps

def _extract_columns(db_resp, colnames):
    """
        Extract the features from the query and pack them into a NumPy array
        db_resp (plpy data object): result of the kmeans request
        id_col_name (string): name of column which has the row id (not a
                              feature of the analysis)
    """
    return np.array([db_resp[0][c] for c in colnames],
                    dtype=float).T


def _scale_data(features):
    """
        Scale all input columns to center on 0 with a standard devation of 1

        features (numpy matrix): features of dimension (n_features, n_samples)
    """
    from sklearn.preprocessing import StandardScaler
    return StandardScaler().fit_transform(features)
