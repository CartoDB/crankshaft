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
LANGUAGE plpgsql VOLATILE PARALLEL RESTRICTED;
