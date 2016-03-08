### Moran's I

#### What is Moran's I and why is it significant for CartoDB?

Moran's I is a geostatistical calculation which gives a measure of the global
clustering and presence of outliers within the geographies in a map. Here global
means over all of the geographies in a dataset. Imagine mapping the incidence
rates of cancer in neighborhoods of a city. If there were areas covering several
neighborhoods with abnormally low rates of cancer, those areas are positively
spatially correlated with one another and would be considered a cluster. If
there was a single neighborhood with a high rate but with all neighbors on
average having a low rate, it would be considered a spatial outlier.

While Moran's I gives a global snapshot, there are local indicators for
clustering called Local Indicators of Spatial Autocorrelation. Clustering is a
process related to autocorrelation -- i.e., a process that compares a
geography's attribute to the attribute in neighbor geographies.

For the example of cancer rates in neighborhoods, since these neighborhoods have
a high value for rate of cancer, and all of their neighbors do as well, they are
designated as "High High" or simply **HH**. For areas with multiple neighborhoods
with low rates of cancer, they are designated as "Low Low" or **LL**. HH and LL
naturally fit into the concept of clustering and are in the correlated
variables.

"Anticorrelated" geogs are in **LH** and **HL** regions -- that is, regions
where a geog has a high value and it's neighbors, on average, have a low value
(or vice versa). An example of this is a "gated community" or placement of a
city housing project in a rich region. These deliberate developments have
opposite median income as compared to the neighbors around them. They have a
high (or low) value while their neighbors have a low (or high) value. They exist
typically as islands, and in rare circumstances can extend as chains dividing
**LL** or **HH**.

Strong policies such as rent stabilization (probably) tend to prevent the
clustering of high rent areas as they integrate middle class incomes. Luxury
apartment buildings, which are a kind of gated community, probably tend to skew
an area's median income upwards while housing projects have the opposite effect.
What are the nuggets in the analysis?

Two functions are available to compute Moran I statistics:

* `cdb_moran_local` computes Moran I measures, quad classification and
  significance values from numerial values associated to geometry entities
  in an input table. The geometries should be contiguous polygons When
  then `queen` `w_type` is used.
* `cdb_moran_local_rate` computes the same statistics using a ratio between
  numerator and denominator columns of a table.

The parameters for `cdb_moran_local` are:

* `table` name of the table that contains the data values
* `attr` name of the column
* `signficance` significance threshold for the quads values
* `num_ngbrs` number of neighbors to consider (default: 5)
* `permutations` number of random permutations for calculation of
  pseudo-p values (default: 99)
* `geom_column` number of the geometry column (default: "the_geom")
* `id_col` PK column of the table (default: "cartodb_id")
* `w_type` Weight types: can be "knn" for k-nearest neighbor weights
  or "queen" for contiguity based weights.

The function returns a table with the following columns:

* `moran` Moran's value
* `quads` quad classification ('HH', 'LL', 'HL', 'LH' or 'Not significant')
* `significance` significance value
* `ids` id of the corresponding record in the input table

Function `cdb_moran_local_rate` only differs in that the `attr` input
parameter is substituted by `numerator` and `denominator`.
