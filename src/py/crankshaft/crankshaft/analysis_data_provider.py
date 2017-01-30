"""class for fetching data"""
import plpy
import pysal_utils as pu


class AnalysisDataProvider(object):
    """
        Analysis data provider for crankshaft functions. These mostly rely on
        plpy data sources.
    """
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

    def get_segmentation_model_data(self, params):
        """
           fetch data for Segmentation
           params = {"subquery": query,
                     "target": variable,
                     "features": feature_columns}
        """
        columns = ', '.join(['array_agg("{col}") As "{col}"'.format(col=col)
                            for col in params['feature_columns']])
        query = '''
                SELECT
                  array_agg("{target}") As target,
                  {columns}
                FROM ({subquery}) As q
                '''.format(subquery=params['subquery'],
                           target=params['target'],
                           columns=columns)
        try:
            data = plpy.execute(query)
            return data
        except plpy.SPIError, err:
                plpy.error('Failed to build segmentation model: %s' % err)

    def get_segmentation_data(self, params):
        """
            params = {"subquery": target_query,
                      "id_col": id_col}
        """
        query = '''
                SELECT
                  array_agg("{id_col}" ORDER BY "{id_col}") as "ids"
                FROM ({subquery}) as q
                 '''.format(**params)
        try:
            data = plpy.execute(query)
            return data
        except plpy.SPIError, err:
            plpy.error('Failed to build segmentation model: %s' % err)

    def get_segmentation_predict_data(self, params):
        """
            fetch data for Segmentation
            params = {"subquery": target_query,
                      "feature_columns": feature_columns}
        """
        joined_features = ', '.join(['"{}"::numeric'.format(a)
                                     for a in params['feature_columns']])
        query = '''
                SELECT
                  Array({joined_features}) As features
                FROM ({subquery}) as q
                '''.format(subquery=params['subquery'],
                           joined_features=joined_features)
        try:
            cursor = plpy.cursor(query)
            return cursor
        except plpy.SPIError, err:
            plpy.error('Failed to build segmentation model: %s' % err)
