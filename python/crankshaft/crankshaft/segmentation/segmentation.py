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

def create_segment(segment_name,table_name,column_name,geoid_column,census_table,method):
    """
    generate a segment with machine learning
    Stuart Lynn
    """
    data     = pd.DataFrame(join_with_census(table_name, column_name,geoid_column, census_table))
    features = data[data.columns.difference([column_name, 'geoid','the_geom'])]
    target, mean, std = normalize(data[column_name])
    model, accuracy = train_model(target,features, test_split=0.2)
    # save_model(segment_name, model, accuracy, table_name, column_name, census_table, geoid_column, method)
    # predict_segment
    return accuracy

def normalize(target):
    mean = np.mean(target)
    std  = np.std(target)
    plpy.notice('mean '+str(mean)+" std : "+str(std))
    return (target - mean)/std, mean, std

def denormalize(target, mean ,std):
    return target*std + mean

def train_model(target,features,test_split):
    plpy.notice('training the model')
    plpy.notice('dataframe shape '+ str(np.shape(features)))
    plpy.notice('dataframe columns '+ str(features.dtypes))
    features = features.dropna(axis =1, how='all').fillna(0)
    target = target.fillna(0)
    features_train, features_test, target_train, target_test = train_test_split(features, target, test_size=test_split)
    plpy.notice('training the model test train split')
    model = ExtraTreesRegressor(n_estimators = 40, max_features=len(features.columns))
    plpy.notice('training the model created tree')
    plpy.notice('features '+str(np.shape(features_train))+" "+str(np.shape(features_test)) )

    model.fit(features_train, target_train)
    plpy.notice('training the model fitting model')
    accuracy = calculate_model_accuracy(model,features,target)
    return model, accuracy

def calculate_model_accuracy(model,features,target):
    prediction = model.predict(features)
    return metrics.mean_squared_error(prediction,target)/np.std(target)

def join_with_census(table_name, column_name, geoid_column, census_table):
    columns          = plpy.execute('select * from {census_table} limit 1 '.format(**locals()))
    combined_columns = [ a for a in columns[0].keys() if a not in ['the_geom','cartodb_id','geoid']]
    feature_names    = ",".join([ " {census_table}.\"{a}\" as \"{a}\" ".format(**locals()) for a in combined_columns])
    plpy.notice('joining with census data')
    join_data     = plpy.execute('''

        SELECT {feature_names}, {table_name}.{column_name}
        FROM   {table_name}
        JOIN   {census_table}
        ON  {table_name}.{geoid_column}::numeric = {census_table}.geoid::numeric
    '''.format(**locals()))

    if len(join_data) == 0:
        plpy.notice('Failed to join with census data')

    return  query_to_dictionary(join_data)

def query_to_dictionary(result):
    return [ dict(zip(r.keys(), r.values())) for r in result ]

def predict_segment(model,features,geoid_column,census_table):
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


def create_model_table():
    """
    create the model table if requred
    """
    plpy.execute('''
        CREATE table IF NOT EXISTS _cdb_models(
            name TEXT,
            model TEXT,
            features TEXT[],
            accuracy NUMERIC,
            table_name TEXT,
            census_table_name TEXT,
            method TEXT
    )''')

def save_model(model_name,model,accuracy,table_name, column_name,census_table,geoid_column,method):
    """
    save a model to the model table for later use
    """
    create_model_table()

    plpy.execute('''
        DELETE FROM _cdb_models WHERE name = '{model_name}'
    '''.format(**locals()))
    model_pickle = pickle.dumps(model)
    plpy.execute("""
        INSERT INTO _cdb_models ('{model_name}','{model_pickle}',{accuracy}, '{table_name}', '{census_table}', '{method}')
    """.format(**locals()))
