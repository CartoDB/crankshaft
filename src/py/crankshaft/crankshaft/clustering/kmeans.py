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
