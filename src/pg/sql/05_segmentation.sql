
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
      model_name text DEFAULT NULL,
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
    all_cols = list(plpy.execute('''
        select * from ({query}) as _w limit 0
    '''.format(query=query)).colnames())
    feature_cols = [a for a in all_cols
                    if a not in [variable_name, 'cartodb_id', ]]
    return seg.create_and_predict_segment(
        query,
        variable_name,
        feature_cols,
        target_table,
        model_params,
        model_name=model_name
    )
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;

CREATE OR REPLACE FUNCTION
  CDB_RetrieveModelParams(
    model_name text,
    param_name text
  )
RETURNS TABLE(param numeric, feature_name text) AS $$

import pickle
from collections import Iterable

plan = plpy.prepare('''
    SELECT model, feature_names FROM model_storage
    WHERE name = $1;
''', ['text', ])

try:
    model_encoded = plpy.execute(plan, [model_name, ])
except plpy.SPIError as err:
    plpy.error('ERROR: {}'.format(err))
plpy.notice(model_encoded[0]['feature_names'])
model = pickle.loads(
    model_encoded[0]['model']
)

res = getattr(model, param_name) 
if not isinstance(res, Iterable):
    raise Exception('Cannot return `{}` as a table'.format(param_name))
return zip(res, model_encoded[0]['feature_names'])

$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;

CREATE OR REPLACE FUNCTION
  CDB_CreateAndPredictSegment(
      query TEXT,
      variable TEXT,
      feature_columns TEXT[],
      target_query TEXT,
      model_name TEXT DEFAULT NULL,
      n_estimators INTEGER DEFAULT 1200,
      max_depth INTEGER DEFAULT 3,
      subsample DOUBLE PRECISION DEFAULT 0.5,
      learning_rate DOUBLE PRECISION DEFAULT 0.01,
      min_samples_leaf INTEGER DEFAULT 1)
RETURNS TABLE (cartodb_id TEXT, prediction NUMERIC, accuracy NUMERIC)
AS $$

# get stored features if they exist to validate whether
# model matches input data
if model_name:
    try:
        stored_features = plpy.execute('''
            select feature_names
            from model_storage
            where name = \'{}\'
            '''.format(model_name)
        )[0]['feature_names']
    except plpy.SPIError:
        stored_features = []
else:
    stored_features = []

if set(feature_columns) == set(stored_features):
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
        model_params,
        model_name=model_name
    )
else:
    raise plpy.SPIError(
        'Feature columns for stored model `{0}` does not match features '
        'passed in this function.\n'
            'Stored model: {1}\n'
            'New model: {2}\n'
            'Pick a new model name or adjust features.'.format(
                model_name,
                ', '.join(sorted(feature_columns)),
                ', '.join(sorted(stored_features))
                    ))
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;
