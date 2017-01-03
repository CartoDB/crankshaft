CREATE OR REPLACE FUNCTION _cdb_final_union_adjacent( joined_geoms geometry[] )
RETURNS geometry[] AS $$
BEGIN
    RETURN joined_geoms;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION _cdb_state_update_union_adjacent(clusters geometry[], new_geom  geometry)
RETURNS geometry[] AS $$
DECLARE
  joins  geometry[] :='{}';
  unjoined geometry[] :='{}';
  i integer;
  combined geometry;
BEGIN
  joins := (select array_agg(g)
            from unnest(clusters) a(g)
            where ST_TOUCHES(g, new_geom));

  unjoined := (select array_agg(g)
               from unnest(clusters) a(g)
               where ST_TOUCHES(g, new_geom) = false);

  IF array_length(joins, 1) > 0 THEN
    joins := array_append(joins, new_geom);
    combined := ST_UNION(joins);
  ELSE
    combined := new_geom;
  END IF;

  unjoined := array_append(unjoined, combined);
  RETURN unjoined;
END
$$
LANGUAGE plpgsql;

CREATE AGGREGATE cdb_union_adjacent(geometry)(
  SFUNC=_cdb_state_update_union_adjacent,
  STYPE=geometry[],
  FINALFUNC=_cdb_final_union_adjacent,
  INITCOND='{}'
);
