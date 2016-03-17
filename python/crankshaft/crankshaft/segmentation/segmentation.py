"""
Segmentation creation and prediction
"""

import sklearn
import numpy as np
import pandas as pd
import cPickle
import plpy
import sys
from sklearn.ensemble import ExtraTreesRegressor
from sklearn import metrics
from sklearn.externals import joblib
from sklearn.cross_validation import train_test_split
import StringIO
import gzip

# High level interface ---------------------------------------

def create_segment(segment_name,table_name,column_name,geoid_column,census_table,method):
    """
    generate a segment with machine learning
    Stuart Lynn
    """
    data     = pd.DataFrame(join_with_census(table_name, column_name,geoid_column, census_table))
    features = data[data.columns.difference([column_name, 'geoid','the_geom', 'the_geom_webmercator'])]
    target, mean, std = normalize(data[column_name])
    model, accuracy = train_model(target,features, test_split=0.2)
    save_model(segment_name, model, accuracy, table_name, column_name, census_table, geoid_column, method)
    # predict_segment
    return accuracy

def create_and_predict_segment(segment_name,query,geoid_column,census_table,target_table,method):
    """
    generate a segment with machine learning
    Stuart Lynn
    """
    data     = pd.DataFrame(join_with_census(query,geoid_column, census_table))
    features = data[data.columns.difference(['target', 'the_geom_webmercator', 'geoid','the_geom'])]
    target, mean, std = normalize(data['target'])

    normed_target,target_mean, target_std = normalize(target)
    plpy.notice('mean ', target_mean, " std ", target_std)
    model, accuracy, used_features = train_model(target,features, test_split=0.2)
    # save_model(segment_name, model, accuracy, table_name, column_name, census_table, geoid_column, method)
    geoms, geoids, result = predict_segment(model,used_features,geoid_column,target_table)
    return zip(geoms,geoids, [denormalize(t,target_mean, target_std) for t in result] )


def normalize(target):
    mean = np.mean(target)
    std  = np.std(target)
    plpy.notice('mean '+str(mean)+" std : "+str(std))
    return (target - mean)/std, mean, std

def denormalize(target, mean ,std):
    return target*std + mean

def train_model(target,features,test_split):
    plpy.notice('training the model')
    plpy.notice('before ', str(np.shape(features)))
    features = features.dropna(axis =1, how='all').fillna(0)
    plpy.notice('after ', str(np.shape(features)))
    target = target.fillna(0)
    features_train, features_test, target_train, target_test = train_test_split(features, target, test_size=test_split)
    model = ExtraTreesRegressor(n_estimators = 200, max_features=len(features.columns))
    plpy.notice('training the model: fitting to data')
    model.fit(features_train, target_train)
    plpy.notice('training the model: fitting one')
    accuracy = calculate_model_accuracy(model,features,target)
    return model, accuracy, features.columns

def calculate_model_accuracy(model,features,target):
    prediction = model.predict(features)
    return metrics.mean_squared_error(prediction,target)/np.std(target)

def join_with_census(query, geoid_column, census_table):
    columns          = plpy.execute('select * from  {census_table}  limit 1  '.format(**locals()))
    combined_columns = [ a for a in columns[0].keys() if a not in ['target','the_geom','cartodb_id','geoid','the_geom_webmercator']]
    plpy.notice(combined_columns)
    feature_names    = ",".join([ " {census_table}.\"{a}\"::Numeric as \"{a}\" ".format(**locals()) for a in combined_columns])
    plpy.notice(feature_names)

    plpy.notice('joining with census data')
    join_data     = plpy.execute('''

        SELECT {feature_names}, a.target
        FROM   ({query}) a
        JOIN   {census_table}
        ON  a.{geoid_column}::numeric = {census_table}.geoid::numeric
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
    # data     = fetch_model(segment_name)
    # model    = data['model']
    # features = ",".join(features)

    joined_features  = ','.join(['\"'+a+'\"::numeric' for a in features])
    targets  = pd.DataFrame(query_to_dictionary(plpy.execute('select {joined_features} from {census_table}'.format(**locals()))))
    plpy.notice('predicting:' + str(len(features)) + ' '+str(np.shape(targets)))
    plpy.notice(joined_features)
    targets = targets.dropna(axis =1, how='all').fillna(0)
    plpy.notice('predicting:' + str(len(features)) + ' '+str(np.shape(targets)))
    geo_ids  = plpy.execute('select geoid from {census_table}'.format(**locals()))
    geoms  = plpy.execute('select the_geom from {census_table}'.format(**locals()))

    plpy.notice('predicting: predicting data')

    prediction   = model.predict(targets)
    de_norm_prediciton = []
    plpy.notice('predicting: predicted')

    return  [a['the_geom'] for a in geoms], [a['geoid'] for a in geo_ids],prediction


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

    # stringio = StringIO.StringIO()
    # gzip_file = gzip.GzipFile(fileobj=stringio, mode='w')
    # gzip_file.write()
    # gzip_file.close()

    model_pickle = cPickle.dumps(model) #stringio.getvalue()


    # stringio.close()

    plpy.notice(type(model_pickle))
    plpy.notice(len(model_pickle))
    plpy.notice(sys.getsizeof(model_pickle))
    model_pickle  =plpy.quote_literal(model_pickle)
    plpy.execute("""
        INSERT INTO _cdb_models VALUES ('{model_name}',$${model_pickle}$$, Array['test1', 'test2'],{accuracy}, '{table_name}', '{census_table}', '{method}')
    """.format(**locals()))
