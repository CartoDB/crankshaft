\i test/fixtures/touching_polygons.sql

WITH joined_polygons AS (
  SELECT cdb_crankshaft.cdb_union_adjacent(the_geom) the_geom FROM touching_polygons
),
unnested_polygons as (
  select unnest(joined_polygons.the_geom) the_geom from joined_polygons
)
select ST_ASTEXT(unnested_polygons.the_geom) from unnested_polygons;
