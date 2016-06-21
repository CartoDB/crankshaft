CREATE OR REPLACE FUNCTION
  CDB_CreateAndPredictSegment (
      query TEXT,
      variable_name TEXT,
      target_table TEXT
  )
RETURNS TABLE (cartodb_id text, prediction Numeric )
AS $$
  from crankshaft.segmentation import create_and_predict_segment
  # TODO: use named parameters or a dictionary
  return create_and_predict_segment(query,variable_name,target_table)
$$ LANGUAGE plpythonu;
