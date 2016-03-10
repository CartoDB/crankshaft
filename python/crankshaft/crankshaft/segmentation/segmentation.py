"""
Segmentation creation and prediction
"""

import sklearn
import numpy as np
import pandas as pd
import pickle
import plpy
from sklearn.ensemble import ExtraTreesRegressor
from sklearn import metrics
from sklearn.cross_validation import train_test_split

# High level interface ---------------------------------------

def cdb_create_segment(segment_name,table_name,column_name,geoid_column,census_table,method):
    """
    generate a segment with machine learning
    Stuart Lynn
    """
    data     = pd.DataFrame(join_with_census(table_name, column_name,geoid_column, census_table,))
    features = data[data.columns.difference([column_name, 'geoid'])]
    target, mean, std = normalize(data[column_name])
    model, accuracy = train_model(target,features, test_split=0.2)
    save_model(segment_name, model, accuracy, table_name, column_name, census_table, geoid_column, method)
    return accuracy

def normalize(target):
    mean = np.mean(target)
    std  = no.std(target)
    return (target - mean)/std, mean, std

def denormalize(target, mean ,std):
    return target*std + mean

def train_model(target,features,test_split):
    features_train, features_test, target_train, target_test = train_test_split(features, target, test_size=test_split)
    model = ExtraTreesRegressor(n_estimators = 40, max_features=len(features.columns))
    model.fit(features_train, target_train)
    accuracy = calculate_model_accuracy(model,features,target)
    return model, accuracy

def calculate_model_accuracy(model,features,target):
    prediction = self.model.predict(features)
    return metrics.mean_squared_error(prediction,target)/np.std(target)

def join_with_census(table_name, column_name, geoid_column, census_table):
    coulmns        = plpy.execute('select {census_table}.* limit 1 ')
    feature_names  = ",".join(columns.keys.difference(['the_geom','cartodb_id']))
    join_data     = plpy.execute('''
        WITH region_extent AS (
            SELECT ST_Extent(the_geom) as table_extent FROM {table_name};
        )
        SELECT {features_names}, {table_name}.{column_name}
        FROM   {table_name} ,region_extent
        JOIN   {census_table}
        ON  {table_name}.{geoid_column} = {census_table}.geoid
        WHERE {census_table}.the_geom && region_extent.table_extent
    '''.format(**locals()))

    if len(join_data) == 0:
        plpy.notice('Failed to join with census data')

    return join_data

def cdb_predict_segment(segment_name,geoid_column,census_table):
    """
    predict a segment with machine learning
    Stuart Lynn
    """
    data     = fetch_model(segment_name)
    model    = data['model']
    features = ",".join(data['features'])
    targets  = plpy.execute('select {features} from {census_table}')
    geo_ids  = plpy.execute('select geoid from {census_table}')
    result   = model.predict(targets)
    return zip(geo_ids,prediction)


def fetch_model(model_name):
    """
    fetch a model from storage
    """
    data = plpy.execute('select * from models where name={model_name}')
    if len(data)==0:
        plpy.notice('model not found')
    data = data[0]
    data['model'] = pickle.load(data['model'])
    return data


def create_model_table(model_name):
    """
    create the model table if requred
    """
    plpy.execute('''
        CREATE table IF NOT EXISTS _cdb_models(
            name TEXT,
            model BLOB,
            features TEXT[],
            accuracy NUMERIC,
            table_name TEXT,
    )''')

def save_model(model_name,model,accuracy,table_name, column_name,census_table,geoid_column,method):
    """
    save a model to the model table for later use
    """

    plpy.execute('''
        DELETE FROM _cdb_models WHERE model_name = {model_name}
    '''.format(**locals()))

    plpy.execute("""
        INSERT INTO _cdb_models ({model_name},{model_pickle},{accuracy})
    """)

def
