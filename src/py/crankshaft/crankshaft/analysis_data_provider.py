"""class for fetching data"""
import plpy
import pysal_utils as pu

NULL_VALUE_ERROR = ('No usable data passed to analysis. Check your input rows '
                    'for null values and fill in appropriately.')


def verify_data(func):
    """decorator to verify data result before returning to algorithm"""
    def wrapper(*args, **kwargs):
        """Error checking"""
        try:
            data = func(*args, **kwargs)
            if not data:
                plpy.error(NULL_VALUE_ERROR)
            else:
                return data
        except plpy.SPIError as err:
            plpy.error('Analysis failed: {}'.format(err))

        return []

    return wrapper


class AnalysisDataProvider(object):
    """Data fetching class for pl/python functions"""
    @verify_data
    def get_getis(self, w_type, params):  # pylint: disable=no-self-use
        """fetch data for getis ord's g"""
        query = pu.construct_neighbor_query(w_type, params)
        return plpy.execute(query)

    @verify_data
    def get_markov(self, w_type, params):  # pylint: disable=no-self-use
        """fetch data for spatial markov"""
        query = pu.construct_neighbor_query(w_type, params)
        return plpy.execute(query)

    @verify_data
    def get_moran(self, w_type, params):  # pylint: disable=no-self-use
        """fetch data for moran's i analyses"""
        query = pu.construct_neighbor_query(w_type, params)
        return plpy.execute(query)

    @verify_data
    def get_nonspatial_kmeans(self, params):  # pylint: disable=no-self-use
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
        agg_cols = ', '.join([
            'array_agg({0}) As arr_col{1}'.format(val, idx+1)
            for idx, val in enumerate(params['colnames'])
        ])
        query = '''
            SELECT {cols}, array_agg({id_col}) As rowid
            FROM ({subquery}) As a
        '''.format(subquery=params['subquery'],
                   id_col=params['id_col'],
                   cols=agg_cols).strip()
        return plpy.execute(query)

    @verify_data
    def get_segmentation_model_data(self, params):  # pylint: disable=R0201
        """
           fetch data for Segmentation
        params = {"subquery": query,
                  "target": variable,
                  "features": feature_columns}
        """
        columns = ', '.join(['array_agg("{col}") As "{col}"'.format(col=col)
                             for col in params['features']])
        query = '''
                SELECT
                  array_agg("{target}") As target,
                  {columns}
                FROM ({subquery}) As q
                '''.format(subquery=params['subquery'],
                           target=params['target'],
                           columns=columns)
        return plpy.execute(query)

    @verify_data
    def get_segmentation_data(self, params):  # pylint: disable=no-self-use
        """
            params = {"subquery": target_query,
                      "id_col": id_col}
        """
        query = '''
                SELECT
                  array_agg("{id_col}" ORDER BY "{id_col}") as "ids"
                FROM ({subquery}) as q
                 '''.format(**params)
        return plpy.execute(query)

    @verify_data
    def get_segmentation_predict_data(self, params):  # pylint: disable=R0201
        """
            fetch data for Segmentation
            params = {"subquery": target_query,
                      "feature_columns": feature_columns}
        """
        joined_features = ', '.join(['"{}"::numeric'.format(a)
                                     for a in params['feature_columns']])
        query = '''
                SELECT
                  Array[{joined_features}] As features
                FROM ({subquery}) as q
                '''.format(subquery=params['subquery'],
                           joined_features=joined_features)
        return plpy.cursor(query)

    @verify_data
    def get_spatial_kmeans(self, params):  # pylint: disable=no-self-use
        """fetch data for spatial kmeans"""
        query = '''
                SELECT
                  array_agg("{id_col}" ORDER BY "{id_col}") as ids,
                  array_agg(ST_X("{geom_col}") ORDER BY "{id_col}") As xs,
                  array_agg(ST_Y("{geom_col}") ORDER BY "{id_col}") As ys
                FROM ({subquery}) As a
                WHERE "{geom_col}" IS NOT NULL
                '''.format(**params)
        return plpy.execute(query)

    @verify_data
    def get_gwr(self, params):  # pylint: disable=no-self-use
        """fetch data for gwr analysis"""
        query = pu.gwr_query(params)
        return plpy.execute(query)

    @verify_data
    def get_gwr_predict(self, params):  # pylint: disable=no-self-use
        """fetch data for gwr predict"""
        query = pu.gwr_predict_query(params)
        return plpy.execute(query)
