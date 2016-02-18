-- Function by Stuart Lynn for a simple interpolation of a value
-- from a polygon table over an arbitrary polygon
-- (weighted by the area proportion overlapped)
CREATE OR REPLACE
FUNCTION cdb_overlap_sum(geom geometry, target_table_name text, target_column text)
  RETURNS numeric AS
$$
DECLARE
	result numeric;
BEGIN
  EXECUTE Format('
    SELECT sum(%I*ST_Area(St_Intersection($1, a.the_geom))/ST_Area(a.the_geom))
    FROM %I AS a
    WHERE $1 && a.the_geom
  ', target_column, target_table_name)
  USING geom
  INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql;
