### Aereal Weighting

Aereal weighting is a simple interpolation technique to assign a value
to a polygon given a set of polygons with one value assigned to each one.

The value is assigned by averaging the values of intersecting areas
weighted by the intersection area.

Its accuracy depends on the values assigned to reference areas being
homogeneous over each area.

The `cdb_overlap_function` takes three required parameters:

* `geometry` a Polygon geometry which defines the area where a value will be
  estimated.
* `table_name`: name of the values table that provides the source values;
  this table must have a geometric column `the_geom` containing the polygons
  to which values are assigned.
* `column_name`: name of the column that contains the values in the values
  table (should be a numeric column)

There's also an additional optional parameter to define the schema to which
the values table belongs. This is necessary only if it is not in the
`search_path`. Note that `table_name` should never include the schema in it.

* `schema_name` name of the schema that contains the values table

This function returns a numeric value resulting from the aggregation
of the polygons in
