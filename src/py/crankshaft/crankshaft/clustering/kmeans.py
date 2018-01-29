from sklearn.cluster import KMeans
from balanced_kmeans import BalancedGroupsKMeans

import numpy as np

from crankshaft.analysis_data_provider import AnalysisDataProvider


class Kmeans:
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

        data = self.data_provider.get_spatial_kmeans(params)

        # Unpack query response
        xs = data[0]['xs']
        ys = data[0]['ys']
        ids = data[0]['ids']

        km = KMeans(n_clusters=no_clusters, n_init=no_init)
        labels = km.fit_predict(zip(xs, ys))
        return zip(ids, labels)

    def spatial_balanced(self, query, no_clusters, no_init=20, target_per_cluster = None, value_column = None):
        params = { "subquery": query,
                   "geom_col": "the_geom",
                   "id_col" "cartodb_id",
                   "value_column" : value_column }

       data = self.data_provider.get_spatial_balanced_kmeans(params)

       xs = data[0]['xs']
       ts = data[0]['ys']
       ids = data[0]['ids']
       values = data[0]['values']

       total_value  = np.sum(values)

       if target_per_cluster is None:
           target_per_cluster = total_value / float(no_clusters)

       km = KmeansBallanced(n_clusters=17,max_iter=100, max_cluster_size=target_per_cluster)
       labels = km.fit_predict(zip(xs,ys), values=values)
       return zip(ids,labels)
