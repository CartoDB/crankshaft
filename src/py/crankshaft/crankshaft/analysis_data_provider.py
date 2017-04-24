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
        except plpy.SPIError as err:
            plpy.error('Analysis failed: %s' % err)

    def get_markov(self, w_type, params):
        """fetch data for spatial markov"""
        try:
            query = pu.construct_neighbor_query(w_type, params)
            data = plpy.execute(query)

            if len(data) == 0:
                return pu.empty_zipped_array(4)

            return data
        except plpy.SPIError as err:
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
        except plpy.SPIError as err:
            plpy.error('Analysis failed: %s' % err)
            return pu.empty_zipped_array(2)

    def get_nonspatial_kmeans(self, query):
        """fetch data for non-spatial kmeans"""
        try:
            data = plpy.execute(query)
            return data
        except plpy.SPIError as err:
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
        except plpy.SPIError as err:
            plpy.error('Analysis failed: %s' % err)

    def get_column(self, subquery, column, dtype=float, id_col='cartodb_id'):
        """
        Retrieve the column from the specified table from a connected
        PostgreSQL database.

        Args:
            subquery (str): subquery to retrieve column from
            column (str): column to retrieve
            dtype (type): data type in column (e.g, float, int, str)
            id_col (str, optional): Column name for index. Defaults to
                `cartodb_id`.

        Returns:
            numpy.array: column from table as a NumPy array
        """
        query = '''
            SELECT array_agg("{column}" ORDER BY "{id_col}" ASC) as col
              FROM ({subquery}) As _wrap
        '''.format(subquery=subquery,
                   column=column,
                   id_col=id_col)

        resp = plpy.execute(query)
        return np.array(resp[0]['col'], dtype=dtype)

    def get_pairwise_distances(self, drain_query, source_query,
                               id_col='cartodb_id'):
        """Retuns the pairwise distances between row i and j for all i in
        drain_query and j in source_query

        Args:
            drain_query (str): Query that exposes the `the_geom` and
                `cartodb_id` (or what is specified in `id_col`) of the dataset
                for 'drain' locations
            source_query (str): Query that exposes the `the_geom` and
                `cartodb_id` (or what is specified in `id_col`) of the dataset
                for 'source' locations
            id_col (str, optional): Column name for table index. Defaults to
                `cartodb_id`.

        Returns:
            numpy.array: A len(s) by len(d) array of distances from source i to
                drain j
        """
        query = '''
            SELECT array_agg(ST_Distance(d."the_geom"::geography,
                                         s."the_geom"::geography) / 1000.0
                             ORDER BY d."{id_col}" ASC)  as dist
              FROM ({drain_query}) AS d, ({source_query}) AS s
            GROUP BY s."{id_col}"
            ORDER BY s."{id_col}" ASC
        '''.format(drain_query=drain_query,
                   source_query=source_query,
                   id_col=id_col)

        resp = plpy.execute(query)

        # len(s) x len(d) matrix
        return np.array([np.array(row['dist'], dtype=float)
                         for row in resp], dtype=float)
