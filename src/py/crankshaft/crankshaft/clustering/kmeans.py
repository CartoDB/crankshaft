from sklearn.cluster import KMeans
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
        full_query = ("SELECT "
                      "array_agg(cartodb_id ORDER BY cartodb_id) as ids,"
                      "array_agg(ST_X(the_geom) ORDER BY cartodb_id) xs,"
                      "array_agg(ST_Y(the_geom) ORDER BY cartodb_id) ys "
                      "FROM ({query}) As a "
                      "WHERE the_geom IS NOT NULL").format(query=query)

        data = self.data_provider.get_spatial_kmeans(full_query)

        # Unpack query response
        xs = data[0]['xs']
        ys = data[0]['ys']
        ids = data[0]['ids']

        km = KMeans(n_clusters=no_clusters, n_init=no_init)
        labels = km.fit_predict(zip(xs, ys))
        return zip(ids, labels)
