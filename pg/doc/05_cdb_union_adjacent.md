### Union Adjacent

This is an aggregate function that will take a set of polygons and return a geometry array
of regions where the polygons are continuous. Basically it combines polygons
which are touching in to single polygons.

It takes a single value:

* `geometry` a list of geometries to be clustered and joined

and returns

* `geometry[]` an array of the joined geometries.

An example usage would be something like:

```postgresql
  with joined_polygons as (
    select cdb_union_adjacent(the_geom) regions from some_table
  )
  select unnest(region) the_geom from joined_polygons
```

which will produce a table with regions of continuous polygons from the original
table.
