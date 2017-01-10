"""class for fetching data"""
import plpy
import pysal_utils as pu


class AnalysisDataProvider:
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

    def get_nonspatial_kmeans(self, params):
        """
            Fetch data for non-spatial k-means.

            Inputs - a dict (params) with the following keys:
                colnames: a (text) list of column names (e.g.,
                          `['andy', 'cookie']`)
                id_col: the name of the id column (e.g., `'cartodb_id'`)
                subquery: the subquery for exposing the data (e.g.,
                          SELECT * FROM favorite_things)
            Output:
                A SQL query for packaging the data for consumption within
                `KMeans().nonspatial`. Format will be a list of length one,
                with the first element a dict with keys ('rowid', 'attr1',
                'attr2', ...)
        """
        agg_cols = ', '.join(['array_agg({0}) As arr_col{1}'.format(val, idx+1)
                              for idx, val in enumerate(params['colnames'])])
        query = '''
            SELECT {cols}, array_agg({id_col}) As rowid
            FROM ({subquery}) As a
        '''.format(subquery=params['subquery'],
                   id_col=params['id_col'],
                   cols=agg_cols).strip()
        try:
            data = plpy.execute(query)
            if len(data) == 0:
                plpy.error('No non-null-valued data to analyze. Check the '
                           'rows and columns of all of the inputs')
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
            if len(data) == 0:
                plpy.error('No non-null-valued data to analyze. Check the '
                           'rows and columns of all of the inputs')
            return data
        except plpy.SPIError, err:
            plpy.error('Analysis failed: %s' % err)
