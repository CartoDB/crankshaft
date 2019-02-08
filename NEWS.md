0.8.2 (2019-02-07)
------------------
* Update dependencies to match what it's being used in production.
* Update travis to xenial, PG10 and 11, and postgis 2.6
* Compatibility with PG11

0.8.1 (2018-03-12)
------------------
* Adds improperly added version files

0.8.0 (2018-03-12)
------------------
* Adds `CDB_MoransILocal*` functions that return spatial lag [#202](https://github.com/CartoDB/crankshaft/pull/202)

0.7.0 (2018-02-23)
------------------
* Updated Moran and Markov documentation [#179](https://github.com/CartoDB/crankshaft/pull/179) [#155](https://github.com/CartoDB/crankshaft/pull/155)
* Updated examples in documentation [#193](https://github.com/CartoDB/crankshaft/pull/193)
* Better error management for empty values [#157](https://github.com/CartoDB/crankshaft/pull/157)
* Added nonspatial kmeans with class framework [#150](https://github.com/CartoDB/crankshaft/pull/150)
* Added multipolygons and geometry collections support to PIA analyssis [#165](https://github.com/CartoDB/crankshaft/pull/165)
* Upgraded PySAL to v1.14.3 [#198](https://github.com/CartoDB/crankshaft/pull/198)

0.6.1 (2017-11-23)
------------------
* Added VOLATILITY and PARALLEL categories to PostgreSQL functions [#183](https://github.com/CartoDB/crankshaft/pull/183)

0.6.0 (2017-11-08)
------------------
* Adds new functions: `CDB_GWR` and `CDB_GWR_Predict`

0.5.2 (2017-05-12)
------------------
* Fixes missing comma for dict creation #172

0.5.1 (2016-12-12)
------------------
* Fixed problem with the upgrade file from 0.4.2 to 0.5.0 that hasn't changes that should be there (as per ethervoid).

0.5.0 (2016-12-12)
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
