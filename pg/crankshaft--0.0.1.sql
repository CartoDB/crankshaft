-- Internal function.
-- Set the seeds of the RNGs (Random Number Generators)
-- used internally.
CREATE OR REPLACE FUNCTION
_cdb_random_seeds (seed_value INTEGER) RETURNS VOID
AS $$
  from crankshaft import random_seeds
  random_seeds.set_random_seeds(seed_value)
$$ LANGUAGE plpythonu;
-- Moran's I
CREATE OR REPLACE FUNCTION
  cdb_moran_local (
      t TEXT,
  	  attr TEXT,
  	  significance float DEFAULT 0.05,
  	  num_ngbrs INT DEFAULT 5,
  	  permutations INT DEFAULT 99,
  	  geom_column TEXT DEFAULT 'the_geom',
  	  id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn')
RETURNS TABLE (moran FLOAT, quads TEXT, significance FLOAT, ids INT)
AS $$
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran_local(t, attr, significance, num_ngbrs, permutations, geom_column, id_col, w_type)
$$ LANGUAGE plpythonu;

-- Moran's I Local Rate
CREATE OR REPLACE FUNCTION
  cdb_moran_local_rate(t TEXT,
		 numerator TEXT,
		 denominator TEXT,
		 significance FLOAT DEFAULT 0.05,
		 num_ngbrs INT DEFAULT 5,
		 permutations INT DEFAULT 99,
		 geom_column TEXT DEFAULT 'the_geom',
		 id_col TEXT DEFAULT 'cartodb_id',
		 w_type TEXT DEFAULT 'knn')
RETURNS TABLE(moran FLOAT, quads TEXT, significance FLOAT, ids INT, y numeric)
AS $$
  from crankshaft.clustering import moran_local_rate
  # TODO: use named parameters or a dictionary
  return moran_local_rate(t, numerator, denominator, significance, num_ngbrs, permutations, geom_column, id_col, w_type)
$$ LANGUAGE plpythonu;
-- Function by Stuart Lynn for a simple interpolation of a value
-- from a polygon table over an arbitrary polygon
-- (weighted by the area proportion overlapped)
-- Aereal weighting is a very simple form of aereal interpolation.
--
-- Parameters:
--   * geom a Polygon geometry which defines the area where a value will be
--     estimated as the area-weighted sum of a given table/column
--   * target_table_name table name of the table that provides the values
--   * target_column column name of the column that provides the values
--   * schema_name optional parameter to defina the schema the target table
--     belongs to, which is necessary if its not in the search_path.
--     Note that target_table_name should never include the schema in it.
-- Return value:
--   Aereal-weighted interpolation of the column values over the geometry
CREATE OR REPLACE
FUNCTION cdb_overlap_sum(geom geometry, target_table_name text, target_column text, schema_name text DEFAULT NULL)
  RETURNS numeric AS
$$
DECLARE
	result numeric;
  qualified_name text;
BEGIN
  IF schema_name IS NULL THEN
    qualified_name := Format('%I', target_table_name);
  ELSE
    qualified_name := Format('%I.%s', schema_name, target_table_name);
  END IF;
  EXECUTE Format('
    SELECT sum(%I*ST_Area(St_Intersection($1, a.the_geom))/ST_Area(a.the_geom))
    FROM %s AS a
    WHERE $1 && a.the_geom
  ', target_column, qualified_name)
  USING geom
  INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql;
--
-- Creates N points randomly distributed arround the polygon
--
-- @param g - the geometry to be turned in to points
--
-- @param no_points - the number of points to generate
--
-- @params max_iter_per_point - the function generates points in the polygon's bounding box
-- and discards points which don't lie in the polygon. max_iter_per_point specifies how many
-- misses per point the funciton accepts before giving up.
--
-- Returns: Multipoint with the requested points
CREATE OR REPLACE FUNCTION cdb_dot_density(geom geometry , no_points Integer, max_iter_per_point Integer DEFAULT 1000)
RETURNS GEOMETRY AS $$
DECLARE
  extent GEOMETRY;
  test_point Geometry;
  width                NUMERIC;
  height               NUMERIC;
  x0                   NUMERIC;
  y0                   NUMERIC;
  xp                   NUMERIC;
  yp                   NUMERIC;
  no_left              INTEGER;
  remaining_iterations INTEGER;
  points               GEOMETRY[];
  bbox_line            GEOMETRY;
  intersection_line    GEOMETRY;
BEGIN
  extent  := ST_Envelope(geom);
  width   := ST_XMax(extent) - ST_XMIN(extent);
  height  := ST_YMax(extent) - ST_YMIN(extent);
  x0 	  := ST_XMin(extent);
  y0 	  := ST_YMin(extent);
  no_left := no_points;

  LOOP
    if(no_left=0) THEN
      EXIT;
    END IF;
    yp = y0 + height*random();
    bbox_line  = ST_MakeLine(
      ST_SetSRID(ST_MakePoint(yp, x0),4326),
      ST_SetSRID(ST_MakePoint(yp, x0+width),4326)
    );
    intersection_line = ST_Intersection(bbox_line,geom);
  	test_point = ST_LineInterpolatePoint(st_makeline(st_linemerge(intersection_line)),random());
	  points := points || test_point;
	  no_left = no_left - 1 ;
  END LOOP;
  RETURN ST_Collect(points);
END;
$$
LANGUAGE plpgsql VOLATILE
