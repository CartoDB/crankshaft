CREATE OR REPLACE FUNCTION
  CDB_Contours (
    subquery TEXT,
    grid_size NUMERIC DEFAULT 100,
    bandwidth NUMERIC DEFAULT 0.0001,
    levels NUMERIC[] DEFAULT null
    )
RETURNS table (level Numeric, geom text )
AS $$
  RETURN QUERY
    select level, ST_GeomFromText(geom_text, 4326) as geom from _CDB_Contours(subquery,grid_size,bandwidth,levels);
  RETURN;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION
  _CDB_Contours (
      subquery TEXT,
      grid_size NUMERIC DEFAULT 100,
      bandwidth NUMERIC DEFAULT 0.0001,
      levels NUMERIC[] DEFAULT null
      )
RETURNS table (level Numeric, geom_text text )
AS $$
  from crankshaft.contours import cdb_generate_contours
  # TODO: use named parameters or a dictionary
  return cdb_generate_contours(subquery, grid_size, bandwidth, levels)
$$ LANGUAGE plpythonu;
