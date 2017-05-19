"""class for fetching data"""
import plpy
import pysal_utils as pu
import numpy as np

class AnalysisDataProvider(object):
    """Analysis providers for crankshaft functions. These rely on database
    access through `plpy`"""
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

    def get_column(self, subquery, column, dtype=float, id_col='cartodb_id',
                   condition=None):
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
              FROM ({subquery}) As _wrap {filter}
        '''.format(subquery=subquery,
                   column=column,
                   id_col=id_col,
                   filter='WHERE {}'.format(condition) if condition else '')

        resp = plpy.execute(query)
        return np.array(resp[0]['col'], dtype=dtype)

    def get_reduced_column(self, drain_query, capacity,
                           source_query, amount,
                           dtype=float, id_col='cartodb_id'):
        """
        Retrieve the column from the specified table from a connected
        PostgreSQL database.

        Args:
            source_query (str): source_query to retrieve column from
            column (str): column to retrieve
            dtype (type): data type in column (e.g, float, int, str)
            id_col (str, optional): Column name for index. Defaults to
                `cartodb_id`.

        Returns:
            numpy.array: column from table as a NumPy array

        """
        query = '''
            WITH cte AS (
              SELECT
                  d."{capacity}" - coalesce(s."source_claimed", 0) As
                    reduced_capacity,
                  d."{id_col}"
                FROM
                  ({drain_query}) As d
              LEFT JOIN
                  (SELECT
                      "drain_id",
                      sum("{amount}") As source_claimed
                     FROM ({source_query}) As _wrap
                   GROUP BY "drain_id") As s
                  ON
                  d."{id_col}" = s."drain_id"
              )
            SELECT
                array_agg("reduced_capacity"
                          ORDER BY "{id_col}" ASC) As col
              FROM cte
        '''.format(capacity=capacity,
                   id_col=id_col,
                   drain_query=drain_query,
                   amount=amount,
                   source_query=source_query)

        resp = plpy.execute(query)
        return np.array(resp[0]['col'], dtype=dtype)

    def get_distance_matrix(self, table, origin_ids, destination_ids):
        """Transforms a SQL table origin-destination table into a distance
        matrix.

        :param query: Table that has the data needed for building the
            distance matrix. Query should have the following columns:
            - origin_id (int)
            - destination_id (int)
            - length_km (numeric)
        :type query: str
        :param origin_ids: List of origin IDs
        :type origin_ids: list of ints
        :param destination_ids: List of origin IDs
        :type destination_ids: list of ints
        :returns: 2D array of distances from all origins to all destinations
        :rtype: numpy.array
        """
        try:
            resp = plpy.execute('''
                SELECT "origin_id", "destination_id", "length_km"
                FROM (SELECT * FROM "{table}") as _wrap
            '''.format(table=table))
        except plpy.SPIError as err:
            plpy.error("Failed to build distance matrix: {}".format(err))

        pairs = {(row['origin_id'], row['destination_id']): row['length_km']
                 for row in resp}
        distance_matrix = np.array([
            pairs[(origin, destination)]
            for destination in destination_ids
            for origin in origin_ids
        ])

        return np.array(distance_matrix,
                        dtype=float).reshape((len(destination_ids),
                                              len(origin_ids)))


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
