"""class for fetching data"""
import plpy
import pysal_utils as pu

NULL_VALUE_ERROR = ('No usable data passed to analysis. Check your input rows '
                    'for null values and fill in appropriately.')


def verify_data(f):
    def wrapper(*args, **kwargs):
        try:
            data = f(*args, **kwargs)
            if len(data) == 0:
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
