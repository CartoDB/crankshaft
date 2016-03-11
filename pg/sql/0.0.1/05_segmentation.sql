CREATE OR REPLACE FUNCTION
  cdb_create_segment (
      segment_name TEXT,
      table_name TEXT,
  	  column_name TEXT,
      geoid_column TEXT DEFAULT 'geoid',
      census_table TEXT DEFAULT 'block_groups'
  )
RETURNS NUMERIC
AS $$
  from crankshaft import segmentation
  # TODO: use named parameters or a dictionary
  return segmentation.create_segment(segment_name,table_name,column_name,geoid_column,census_table,'random_forest')
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
  cdb_predict_segment (
      segment_name TEXT,
      geoid_column TEXT DEFAULT 'geoid',
      census_table TEXT DEFAULT 'block_groups'
  )
RETURNS TABLE(geoid TEXT, prediction NUMERIC)
AS $$
  from crankshaft.segmentation import create_segemnt
  # TODO: use named parameters or a dictionary
  return create_segment('table')
$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION
  cdb_create_and_predict_segment (
      segment_name TEXT,
      table_name TEXT,
  	  column_name TEXT,
      geoid_column TEXT DEFAULT 'geoid',
      census_table TEXT DEFAULT 'block_groups'
  )
RETURNS TABLE (the_geom geometry, geoid text, prediction Numeric )
AS $$
  from crankshaft import segmentation
  # TODO: use named parameters or a dictionary
  return segmentation.create_and_predict_segment(segment_name,table_name,column_name,geoid_column,census_table,'random_forest')
$$ LANGUAGE plpythonu;
