
CREATE OR REPLACE FUNCTION
  CDB_CreateAndPredictSegment(
    target NUMERIC[],
    features NUMERIC[],
    target_features NUMERIC[],
    target_ids NUMERIC[],
    n_estimators INTEGER DEFAULT 1200,
    max_depth INTEGER DEFAULT 3,
    subsample DOUBLE PRECISION DEFAULT 0.5,
    learning_rate DOUBLE PRECISION DEFAULT 0.01,
    min_samples_leaf INTEGER DEFAULT 1)
RETURNS TABLE(cartodb_id NUMERIC, prediction NUMERIC, accuracy NUMERIC)
AS $$
    import numpy as np
    import plpy

    from crankshaft.segmentation import Segmentation
    seg = Segmentation()
    model_params = {'n_estimators': n_estimators,
                    'max_depth': max_depth,
                    'subsample': subsample,
                    'learning_rate': learning_rate,
                    'min_samples_leaf': min_samples_leaf}

    def unpack2D(data):
        dimension = data.pop(0)
        a = np.array(data, dtype=float)
        return a.reshape(len(a)/dimension, dimension)

    return seg.create_and_predict_segment_agg(np.array(target, dtype=float),
            unpack2D(features),
            unpack2D(target_features),
            target_ids,
            model_params)

$$ LANGUAGE plpythonu VOLATILE PARALLEL RESTRICTED;

CREATE OR REPLACE FUNCTION
  CDB_CreateAndPredictSegment (
      query TEXT,
      variable_name TEXT,
      target_table TEXT,
      n_estimators INTEGER DEFAULT 1200,
      max_depth INTEGER DEFAULT 3,
      subsample DOUBLE PRECISION DEFAULT 0.5,
      learning_rate DOUBLE PRECISION DEFAULT 0.01,
      min_samples_leaf INTEGER DEFAULT 1)
RETURNS TABLE (cartodb_id TEXT, prediction NUMERIC, accuracy NUMERIC)
AS $$
    from crankshaft.segmentation import Segmentation
    seg = Segmentation()
    model_params = {
        'n_estimators': n_estimators,
        'max_depth': max_depth,
        'subsample': subsample,
        'learning_rate': learning_rate,
        'min_samples_leaf': min_samples_leaf
    }
    return seg.create_and_predict_segment(
        query,
        variable_name,
        target_table,
        model_params
    )
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;

CREATE OR REPLACE FUNCTION
  CDB_CreateAndPredictSegment(
      query TEXT,
      variable TEXT,
      feature_columns TEXT[],
      target_query TEXT,
      n_estimators INTEGER DEFAULT 1200,
      max_depth INTEGER DEFAULT 3,
      subsample DOUBLE PRECISION DEFAULT 0.5,
      learning_rate DOUBLE PRECISION DEFAULT 0.01,
      min_samples_leaf INTEGER DEFAULT 1)
RETURNS TABLE (cartodb_id TEXT, prediction NUMERIC, accuracy NUMERIC)
AS $$
    from crankshaft.segmentation import Segmentation
    seg = Segmentation()
    model_params = {
        'n_estimators': n_estimators,
        'max_depth': max_depth,
        'subsample': subsample,
        'learning_rate': learning_rate,
        'min_samples_leaf': min_samples_leaf
    }
    return seg.create_and_predict_segment(
        query,
        variable,
        feature_columns,
        target_query,
        model_params
    )
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;
