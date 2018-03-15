
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
        a = np.array(data, dtype=np.float64)
        return a.reshape(int(len(a)/dimension), int(dimension))

    return seg.create_and_predict_segment_agg(
        np.array(target, dtype=np.float64),
        unpack2D(features),
        unpack2D(target_features),
        target_ids,
        model_params)

$$ LANGUAGE plpythonu VOLATILE PARALLEL RESTRICTED;

CREATE OR REPLACE FUNCTION
  CDB_CreateAndPredictSegment(
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
    feature_cols = set(plpy.execute('''
        select * from ({query}) as _w limit 0
    '''.format(query=query)).colnames()) -  set([variable_name, 'cartodb_id', ])
    return seg.create_and_predict_segment(
        query,
        variable_name,
        feature_cols,
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
