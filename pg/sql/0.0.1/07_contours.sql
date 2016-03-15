

CREATE OR REPLACE FUNCTION
  cdb_contours_count (
      query TEXT,
      levels NUMERIC[]
  )
RETURNS TABLE (the_geom geometry , level Numeric)
AS $$
  from crankshaft.contours import create_countours_count
  return create_countours_count(query,levels)
$$ LANGUAGE plpythonu;
