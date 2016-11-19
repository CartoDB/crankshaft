"""class for fetching data"""
import plpy


class QueryRunner:
    def get_markov(self, query):
        try:
            data = plpy.execute(query)

            if len(data) == 0:
                return pu.empty_zipped_array(4)

            return data
        except plpy.SPIError, err:
            plpy.error('Analysis failed: %s' % err)

    def get_moran(self, query):
        """fetch data for moran's i analyses"""
        try:
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

    def get_spatial_kmeans(self, query):
        """fetch data for spatial kmeans"""
        try:
            data = plpy.execute(query)
            return data
        except plpy.SPIError, err:
            plpy.error("Analysis failed: %s" % err)
