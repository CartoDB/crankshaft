CREATE OR REPLACE FUNCTION
  CDB_CreateAndPredictSegment (
      query TEXT,
      variable_name TEXT,
      target_table TEXT,
      n_estimators INTEGER DEFAULT 1200,
      max_depth INTEGER DEFAULT 3,
      subsample DOUBLE PRECISION DEFAULT 0.5,
      learning_rate DOUBLE PRECISION DEFAULT 0.01,
      min_samples_leaf INTEGER DEFAULT 1

  )
RETURNS TABLE (cartodb_id text, prediction Numeric,accuracy Numeric )
AS $$
  from crankshaft.segmentation import create_and_predict_segment
  model_params = {'n_estimators': n_estimators, 'max_depth':max_depth, 'subsample' : subsample, 'learning_rate': learning_rate, 'min_samples_leaf' : min_samples_leaf} 
  return create_and_predict_segment(query,variable_name,target_table, model_params)
$$ LANGUAGE plpythonu;

