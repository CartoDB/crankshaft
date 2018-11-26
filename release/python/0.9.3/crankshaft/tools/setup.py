from test.helper import plpy, fixture_file
from crankshaft.analysis_data_provider import AnalysisDataProvider
import json
import crankshaft

class RawDataProvider(AnalysisDataProvider):
    def __init__(self, fixturedata):
        self.your_algo_data = fixturedata
    def get_moran(self, params):
        """
          Replace this function name with the one used in your algorithm,
          and make sure to use the same function signature that is written
          for this algo in analysis_data_provider.py
        """
        return self.your_algo_data
