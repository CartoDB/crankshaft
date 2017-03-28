"""class for fetching data"""
import plpy
import pysal_utils as pu
import numpy as np

class AnalysisDataProvider(object):
    def get_getis(self, w_type, params):
        """fetch data for getis ord's g"""
        try:
            query = pu.construct_neighbor_query(w_type, params)
            result = plpy.execute(query)
            # if there are no neighbors, exit
            if len(result) == 0:
                return pu.empty_zipped_array(4)
            else:
                return result
        except plpy.SPIError, err:
            plpy.error('Analysis failed: %s' % err)

    def get_markov(self, w_type, params):
        """fetch data for spatial markov"""
        try:
            query = pu.construct_neighbor_query(w_type, params)
            data = plpy.execute(query)

            if len(data) == 0:
                return pu.empty_zipped_array(4)

            return data
        except plpy.SPIError, err:
            plpy.error('Analysis failed: %s' % err)

    def get_moran(self, w_type, params):
        """fetch data for moran's i analyses"""
        try:
            query = pu.construct_neighbor_query(w_type, params)
            data = plpy.execute(query)

            # if there are no neighbors, exit
            if len(data) == 0:
                return pu.empty_zipped_array(2)
            return data
        except plpy.SPIError, err:
            plpy.error('Analysis failed: %s' % e)
            return pu.empty_zipped_array(2)

    def get_nonspatial_kmeans(self, query):
        """fetch data for non-spatial kmeans"""
        try:
            data = plpy.execute(query)
            return data
        except plpy.SPIError, err:
            plpy.error('Analysis failed: %s' % err)

    def get_spatial_kmeans(self, params):
        """fetch data for spatial kmeans"""
        query = ("SELECT "
                 "array_agg({id_col} ORDER BY {id_col}) as ids,"
                 "array_agg(ST_X({geom_col}) ORDER BY {id_col}) As xs,"
                 "array_agg(ST_Y({geom_col}) ORDER BY {id_col}) As ys "
                 "FROM ({subquery}) As a "
                 "WHERE {geom_col} IS NOT NULL").format(**params)
        try:
            data = plpy.execute(query)
            return data
        except plpy.SPIError, err:
            plpy.error('Analysis failed: %s' % err)

    def get_column(self, table, column):
        """
        """
        query = '''
            SELECT array_agg("{column}" ORDER BY "cartodb_id" ASC) as col
              FROM "{table}"
        '''.format(table=table, column=column)
        resp = plpy.execute(query)
        return np.array(resp[0]['col'], dtype=float)

    def get_pairwise_distances(self, drain, source):
        """retuns the pairwise distances between row i and j for all i in table1 and j in table1"""
        query = '''
            SELECT array_agg(ST_Distance(d."the_geom"::geography,
                                         s."the_geom"::geography) / 1000.0
                             ORDER BY d."cartodb_id" ASC)  as dist
              FROM "{drain}" as d, "{source}" as s
            GROUP BY s."cartodb_id"
            ORDER BY s."cartodb_id" ASC
        '''.format(drain=drain, source=source)

        resp = plpy.execute(query)

        # len(s) x len(d) matrix
        return np.array([np.array(row['dist'], dtype=float)
                         for row in resp], dtype=float)

