0.5.0 (2016-12-15)
------------------
* Updated PULL_REQUEST_TEMPLATE
* Fixed a bug that flips the order of the numerator in denominator for calculating using Moran Local Rate because previously the code sorted the keys alphabetically.
* Add new CDB_GetisOrdsG functions. Getis-Ord's G\* is a geo-statistical measurement of the intensity of clustering of high or low values
* Add new outlier detection functions: CDB_StaticOutlier, CDB_PercentOutlier and CDB_StdDevOutlier
* Updates in the framework for accessing the Python functions.

0.4.2 (2016-09-22)
------------------
* Bugfix for cdb_areasofinterestglobal: import correct modules

0.4.1 (2016-09-21)
------------------
* Let the user set the resolution in CDB_Contour function
* Add Nearest Neighbors method to CDB_SpatialInterpolation
* Improve error reporting for moran and markov functions

0.4.0 (2016-08-30)
------------------
* Add CDB_Contour
* Add CDB_PIA
* Add CDB_Densify
* Add CDB_TINmap

0.3.1 (2016-08-18)
------------------
* Fix Voronoi projection issue
* Fix Voronoi spurious segments issue
* Add tests for interpolation

0.3.0 (2016-08-17)
------------------
* Adds Voronoi function
* Fixes barycenter method in interpolation

0.2.0 (2016-08-11)
------------------
* Adds Gravity Model

0.1.0 (2016-06-29)
------------------
* Adds Spatial Markov function
* Adds Spacial interpolation function
* Adds `CDB_pyAgg (columns Numeric[])` helper function
* Adds Segmentation Functions

0.0.4 (2016-06-20)
------------------
* Remove cartodb extension dependency from tests
* Declare all correct dependencies with correct versions in setup.py

0.0.3 (2016-06-16)
------------------
* Adds new functions: kmeans, weighted centroids.
* Replaces moran functions with new areas of interest naming.

0.0.2 (2016-03-16)
------------------
* New versioning approach using per-version Python virtual environments

0.0.1 (2016-02-22)
------------------
* Preliminar release
