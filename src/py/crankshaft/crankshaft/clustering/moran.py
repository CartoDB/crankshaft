"""
Moran's I geostatistics (global clustering & outliers presence)
Functionality relies on a combination of `PySAL
<http://pysal.readthedocs.io/en/latest/>`__ and the data providered provided in
the class instantiation (which defaults to PostgreSQL's plpy module's `database
access functions <https://www.postgresql.org/docs/10/static/plpython.html>`__).
"""

from collections import OrderedDict
import pysal as ps

# crankshaft module
import crankshaft.pysal_utils as pu
from crankshaft.analysis_data_provider import AnalysisDataProvider

# High level interface ---------------------------------------


class Moran(object):
    """Class for calculation of Moran's I statistics (global, local, and local
    rate)

    Parameters:
      data_provider (:obj:`AnalysisDataProvider`): Class for fetching data. See
        the `crankshaft.analysis_data_provider` module for more information.
    """
    def __init__(self, data_provider=None):
        if data_provider is None:
            self.data_provider = AnalysisDataProvider()
        else:
            self.data_provider = data_provider

    def global_stat(self, subquery, attr_name,
                    w_type, num_ngbrs, permutations, geom_col, id_col):
        """
        Moran's I (global)
        Implementation building neighbors with a PostGIS database and Moran's I
         core clusters with PySAL.

        Args:

          subquery (str): Query to give access to the data needed. This query
            must give access to ``attr_name``, ``geom_col``, and ``id_col``.
          attr_name (str): Column name of data to analyze
          w_type (str): Type of spatial weight. Must be one of `knn`
            or `queen`. See `PySAL documentation
            <http://pysal.readthedocs.io/en/latest/users/tutorials/weights.html>`__
            for more information.
          num_ngbrs (int): If using `knn` for ``w_type``, this
            specifies the number of neighbors to be used to define the spatial
            neighborhoods.
          permutations (int): Number of permutations for performing
            conditional randomization to find the p-value. Higher numbers
            takes a longer time for getting results.
          geom_col (str): Name of the geometry column in the dataset for
            finding the spatial neighborhoods.
          id_col (str): Row index for each value. Usually the database index.

        """
        params = OrderedDict([("id_col", id_col),
                              ("attr1", attr_name),
                              ("geom_col", geom_col),
                              ("subquery", subquery),
                              ("num_ngbrs", num_ngbrs)])

        result = self.data_provider.get_moran(w_type, params)

        # collect attributes
        attr_vals = pu.get_attributes(result)

        # calculate weights
        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate moran global
        moran_global = ps.esda.moran.Moran(attr_vals, weight,
                                           permutations=permutations)

        return zip([moran_global.I], [moran_global.EI])

    def local_stat(self, subquery, attr,
                   w_type, num_ngbrs, permutations, geom_col, id_col):
        """
        Moran's I (local)

        Args:

          subquery (str): Query to give access to the data needed. This query
            must give access to ``attr_name``, ``geom_col``, and ``id_col``.
          attr (str): Column name of data to analyze
          w_type (str): Type of spatial weight. Must be one of `knn`
            or `queen`. See `PySAL documentation
            <http://pysal.readthedocs.io/en/latest/users/tutorials/weights.html>`__
            for more information.
          num_ngbrs (int): If using `knn` for ``w_type``, this
            specifies the number of neighbors to be used to define the spatial
            neighborhoods.
          permutations (int): Number of permutations for performing
            conditional randomization to find the p-value. Higher numbers
            takes a longer time for getting results.
          geom_col (str): Name of the geometry column in the dataset for
            finding the spatial neighborhoods.
          id_col (str): Row index for each value. Usually the database index.

        Returns:
          list of tuples: Where each tuple consists of the following values:
            - quadrants classification (one of `HH`, `HL`, `LL`, or `LH`)
            - p-value
            - spatial lag
            - standardized spatial lag (centered on the mean, normalized by the
              standard deviation)
            - original value
            - standardized value
            - Moran's I statistic
            - original row index
        """

        # geometries with attributes that are null are ignored
        # resulting in a collection of not as near neighbors

        params = OrderedDict([("id_col", id_col),
                              ("attr1", attr),
                              ("geom_col", geom_col),
                              ("subquery", subquery),
                              ("num_ngbrs", num_ngbrs)])

        result = self.data_provider.get_moran(w_type, params)

        attr_vals = pu.get_attributes(result)
        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate LISA values
        lisa = ps.esda.moran.Moran_Local(attr_vals, weight,
                                         permutations=permutations)

        # find quadrants for each geometry
        quads = quad_position(lisa.q)

        # calculate spatial lag
        lag = ps.weights.spatial_lag.lag_spatial(weight, lisa.y)
        lag_std = ps.weights.spatial_lag.lag_spatial(weight, lisa.z)

        return zip(
            quads,
            lisa.p_sim,
            lag,
            lag_std,
            lisa.y,
            lisa.z,
            lisa.Is,
            weight.id_order
        )

    def global_rate_stat(self, subquery, numerator, denominator,
                         w_type, num_ngbrs, permutations, geom_col, id_col):
        """
        Moran's I Rate (global)

        Args:

          subquery (str): Query to give access to the data needed. This query
            must give access to ``attr_name``, ``geom_col``, and ``id_col``.
          numerator (str): Column name of numerator to analyze
          denominator (str): Column name of the denominator
          w_type (str): Type of spatial weight. Must be one of `knn`
            or `queen`. See `PySAL documentation
            <http://pysal.readthedocs.io/en/latest/users/tutorials/weights.html>`__
            for more information.
          num_ngbrs (int): If using `knn` for ``w_type``, this
            specifies the number of neighbors to be used to define the spatial
            neighborhoods.
          permutations (int): Number of permutations for performing
            conditional randomization to find the p-value. Higher numbers
            takes a longer time for getting results.
          geom_col (str): Name of the geometry column in the dataset for
            finding the spatial neighborhoods.
          id_col (str): Row index for each value. Usually the database index.
        """
        params = OrderedDict([("id_col", id_col),
                              ("attr1", numerator),
                              ("attr2", denominator),
                              ("geom_col", geom_col),
                              ("subquery", subquery),
                              ("num_ngbrs", num_ngbrs)])

        result = self.data_provider.get_moran(w_type, params)

        # collect attributes
        numer = pu.get_attributes(result, 1)
        denom = pu.get_attributes(result, 2)

        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate moran global rate
        lisa_rate = ps.esda.moran.Moran_Rate(numer, denom, weight,
                                             permutations=permutations)

        return zip([lisa_rate.I], [lisa_rate.EI])

    def local_rate_stat(self, subquery, numerator, denominator,
                        w_type, num_ngbrs, permutations, geom_col, id_col):
        """
        Moran's I Local Rate

        Args:

          subquery (str): Query to give access to the data needed. This query
            must give access to ``attr_name``, ``geom_col``, and ``id_col``.
          numerator (str): Column name of numerator to analyze
          denominator (str): Column name of the denominator
          w_type (str): Type of spatial weight. Must be one of `knn`
            or `queen`. See `PySAL documentation
            <http://pysal.readthedocs.io/en/latest/users/tutorials/weights.html>`__
            for more information.
          num_ngbrs (int): If using `knn` for ``w_type``, this
            specifies the number of neighbors to be used to define the spatial
            neighborhoods.
          permutations (int): Number of permutations for performing
            conditional randomization to find the p-value. Higher numbers
            takes a longer time for getting results.
          geom_col (str): Name of the geometry column in the dataset for
            finding the spatial neighborhoods.
          id_col (str): Row index for each value. Usually the database index.

        Returns:
          list of tuples: Where each tuple consists of the following values:
            - quadrants classification (one of `HH`, `HL`, `LL`, or `LH`)
            - p-value
            - spatial lag
            - standardized spatial lag (centered on the mean, normalized by the
              standard deviation)
            - original value (roughly numerator divided by denominator)
            - standardized value
            - Moran's I statistic
            - original row index
        """
        # geometries with values that are null are ignored
        # resulting in a collection of not as near neighbors

        params = OrderedDict([("id_col", id_col),
                              ("numerator", numerator),
                              ("denominator", denominator),
                              ("geom_col", geom_col),
                              ("subquery", subquery),
                              ("num_ngbrs", num_ngbrs)])

        result = self.data_provider.get_moran(w_type, params)

        # collect attributes
        numer = pu.get_attributes(result, 1)
        denom = pu.get_attributes(result, 2)

        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate LISA values
        lisa = ps.esda.moran.Moran_Local_Rate(numer, denom, weight,
                                              permutations=permutations)

        # find quadrants for each geometry
        quads = quad_position(lisa.q)

        # spatial lag
        lag = ps.weights.spatial_lag.lag_spatial(weight, lisa.y)
        lag_std = ps.weights.spatial_lag.lag_spatial(weight, lisa.z)

        return zip(
            quads,
            lisa.p_sim,
            lag,
            lag_std,
            lisa.y,
            lisa.z,
            lisa.Is,
            weight.id_order
        )

    def local_bivariate_stat(self, subquery, attr1, attr2,
                             permutations, geom_col, id_col,
                             w_type, num_ngbrs):
        """
            Moran's I (local) Bivariate (untested)
        """

        params = OrderedDict([("id_col", id_col),
                              ("attr1", attr1),
                              ("attr2", attr2),
                              ("geom_col", geom_col),
                              ("subquery", subquery),
                              ("num_ngbrs", num_ngbrs)])

        result = self.data_provider.get_moran(w_type, params)

        # collect attributes
        attr1_vals = pu.get_attributes(result, 1)
        attr2_vals = pu.get_attributes(result, 2)

        # create weights
        weight = pu.get_weight(result, w_type, num_ngbrs)

        # calculate LISA values
        lisa = ps.esda.moran.Moran_Local_BV(attr1_vals, attr2_vals, weight,
                                            permutations=permutations)

        # find clustering of significance
        lisa_sig = quad_position(lisa.q)

        return zip(lisa.Is, lisa_sig, lisa.p_sim, weight.id_order)

# Low level functions ----------------------------------------


def map_quads(coord):
    """
    Map a quadrant number to Moran's I designation
    HH=1, LH=2, LL=3, HL=4
    Args:
      coord (int): quadrant of a specific measurement
    Returns:
      classification (one of 'HH', 'LH', 'LL', or 'HL')
    """
    if coord == 1:
        return 'HH'
    elif coord == 2:
        return 'LH'
    elif coord == 3:
        return 'LL'
    elif coord == 4:
        return 'HL'
    return None


def quad_position(quads):
    """
    Map all quads

    Args:
      quads (:obj:`numpy.ndarray`): an array of quads classified by
      1-4 (PySAL default)
    Returns:
      list: an array of quads classied by 'HH', 'LL', etc.
    """
    return [map_quads(q) for q in quads]
