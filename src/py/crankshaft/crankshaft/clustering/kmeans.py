from sklearn.cluster import KMeans
import numpy as np

from crankshaft.analysis_data_provider import AnalysisDataProvider


class Kmeans(object):
    def __init__(self, data_provider=None):
        if data_provider is None:
            self.data_provider = AnalysisDataProvider()
        else:
            self.data_provider = data_provider

    def spatial(self, query, no_clusters, no_init=20):
        """
            find centers based on clusters of latitude/longitude pairs
            query: SQL query that has a WGS84 geometry (the_geom)
        """
        params = {"subquery": query,
                  "geom_col": "the_geom",
                  "id_col": "cartodb_id"}

        result = self.data_provider.get_spatial_kmeans(params)

        # Unpack query response
        xs = result[0]['xs']
        ys = result[0]['ys']
        ids = result[0]['ids']

        km = KMeans(n_clusters=no_clusters, n_init=no_init)
        labels = km.fit_predict(zip(xs, ys))
        return zip(ids, labels)

    def nonspatial(self, subquery, colnames, no_clusters=5,
                   standardize=True, id_col='cartodb_id'):
        """
        Arguments:
            query (string): A SQL query to retrieve the data required to do the
                            k-means clustering analysis, like so:
                            SELECT * FROM iris_flower_data
            colnames (list): a list of the column names which contain the data
                             of interest, like so: ['sepal_width',
                                                    'petal_width',
                                                    'sepal_length',
                                                    'petal_length']
            no_clusters (int): number of clusters (greater than zero)
            id_col (string): name of the input id_column

        Returns:
            A list of tuples with the following columns:
            cluster labels: a label for the cluster that the row belongs to
            centers: center of the cluster that this row belongs to
            silhouettes: silhouette measure for this value
            rowid: row that these values belong to (corresponds to the value in
                   `id_col`)
        """
        import json
        from sklearn import metrics

        params = {
            "colnames": colnames,
            "subquery": subquery,
            "id_col": id_col
        }

        data = self.data_provider.get_nonspatial_kmeans(params)

        # fill array with values for k-means clustering
        if standardize:
            cluster_columns = _scale_data(
              _extract_columns(data))
        else:
            cluster_columns = _extract_columns(data)

        kmeans = KMeans(n_clusters=no_clusters,
                        random_state=0).fit(cluster_columns)

        centers = [json.dumps(dict(zip(colnames, c)))
                   for c in kmeans.cluster_centers_[kmeans.labels_]]

        silhouettes = metrics.silhouette_samples(cluster_columns,
                                                 kmeans.labels_,
                                                 metric='sqeuclidean')

        return zip(kmeans.labels_,
                   centers,
                   silhouettes,
                   [kmeans.inertia_] * kmeans.labels_.shape[0],
                   data[0]['rowid'])


# -- Preprocessing steps

def _extract_columns(data):
    """
        Extract the features from the query and pack them into a NumPy array
        data (list of dicts): result of the kmeans request
    """
    # number of columns minus rowid column
    n_cols = len(data[0]) - 1
    return np.array([data[0]['arr_col{0}'.format(i+1)]
                     for i in xrange(n_cols)],
                    dtype=float).T


def _scale_data(features):
    """
        Scale all input columns to center on 0 with a standard devation of 1
        features (numpy matrix): features of dimension (n_features, n_samples)
    """
    from sklearn.preprocessing import StandardScaler
    scaler = StandardScaler()
    return scaler.fit_transform(features)
