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
        except Exception as err:
            plpy.error('Analysis failed: {}'.format(err))

        return []

    return wrapper


class AnalysisDataProvider(object):
    @verify_data
    def get_getis(self, w_type, params):
        """fetch data for getis ord's g"""
        query = pu.construct_neighbor_query(w_type, params)
        return plpy.execute(query)

    @verify_data
    def get_markov(self, w_type, params):
        """fetch data for spatial markov"""
        query = pu.construct_neighbor_query(w_type, params)
        return plpy.execute(query)

    @verify_data
    def get_moran(self, w_type, params):
        """fetch data for moran's i analyses"""
        query = pu.construct_neighbor_query(w_type, params)
        return plpy.execute(query)

    @verify_data
    def get_nonspatial_kmeans(self, query):
        """fetch data for non-spatial kmeans"""
        return plpy.execute(query)

    @verify_data
    def get_spatial_kmeans(self, params):
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
    def get_gwr(self, params):
        """fetch data for gwr analysis"""
        query = pu.gwr_query(params)
        return plpy.execute(query)

    def get_gwr_predict(self, params):
        """fetch data for gwr predict"""
        query = pu.gwr_predict_query(params)
        return plpy.execute(query)
