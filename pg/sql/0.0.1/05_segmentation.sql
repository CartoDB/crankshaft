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
  cdb_correlated_variables(
    query text,
    geoid_column text DEFAULT 'geoid',
    census_table text DEFAULT 'ml_learning_block_groups_clipped'
  )
RETURNS TABLE(feature text, importance NUMERIC, std NUMERIC)
AS $$
  from crankshaft.segmentation import correlated_variables
  return correlated_variables(query,geoid_column,census_table)
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
      query TEXT,
      target_table TEXT,
      geoid_column TEXT DEFAULT 'geoid',
      census_table TEXT DEFAULT 'block_groups'
  )
RETURNS TABLE (the_geom geometry, geoid text, prediction Numeric )
AS $$
  from crankshaft import segmentation
  # TODO: use named parameters or a dictionary
  return segmentation.create_and_predict_segment(segment_name,query,geoid_column,census_table,target_table,'random_forest')
$$ LANGUAGE plpythonu;
