from sklearn.neighbors import NearestNeighbors
import  scipy.stats as stats
import numpy as np
import plpy
import time
import cPickle


def query_to_dictionary(result):
    return [ dict(zip(r.keys(), r.values())) for r in result ]

def drop_all_nan_columns(data):
    return data[ :, ~np.isnan(data).all(axis=0)]
    
def fill_missing_na(data,val=None):
    inds = np.where(np.isnan(data))
    if val==None:
        col_mean = stats.nanmean(data,axis=0)
        data[inds]=np.take(col_mean,inds[1])
    else:
        data[inds]=np.take(val, inds[1])
    return data
    
def similarity_rank(target_cartodb_id, query):
    start_time  = time.time() 
    #plpy.notice('converting to dictionary ', start_time) 
    #data = query_to_dictionary(plpy.execute(query))  
    plpy.notice('coverted , running query ', time.time() - start_time) 
    
    data = plpy.execute(query_only_values(query))
    plpy.notice('run query  , getting cartodb_idsi', time.time() - start_time)
    cartodb_ids = plpy.execute(query_cartodb_id(query))[0]['a']
    target_id  = cartodb_ids.index(target_cartodb_id)
    plpy.notice('run query  , extracting ', time.time() - start_time)
    features, target = extract_features_target(data,target_id)
    plpy.notice('extracted  , cleaning ', time.time() - start_time)
    features = fill_missing_na(drop_all_nan_columns(features))
    plpy.notice('cleaned , normalizing', start_time - time.time())
    
    normed_features, normed_target  = normalize_features(features,target)
    plpy.notice('normalized , training ', time.time() - start_time )
    tree = train(normed_features)
    plpy.notice('normalized , pickling ', time.time() - start_time )
    #plpy.notice('tree_dump ',  len(cPickle.dumps(tree, protocol=cPickle.HIGHEST_PROTOCOL)))
    plpy.notice('pickles, querying ', time.time() - start_time)
    dist, ind  = tree.kneighbors(normed_target)
    plpy.notice('queried , rectifying', time.time() - start_time)
    return zip(cartodb_ids, dist[0])

def query_cartodb_id(query):
    return 'select array_agg(cartodb_id) a from ({0}) b'.format(query)

def query_only_values(query):
    first_row = plpy.execute('select * from ({query}) a limit 1'.format(query=query))
    just_values = ','.join([ key for key in  first_row[0].keys()  if key not in ['the_geom', 'the_geom_webmercator','cartodb_id']])
    return 'select Array[{0}] a from ({1}) b '.format(just_values, query)


def most_similar(matches,query):
    data = plpy.execute(query)    
    features, _ = extract_features_target(data)
    results = []
    for i in features:
        target = features
        dist,ind = tree.query(target, k=matches)
        cartodb_ids  = [ dist[ind]['cartodb_id'] for index in ind ]
        results.append(cartodb_ids)
    return cartodb_ids, results
    
    
def train(features):
    tree = NearestNeighbors( n_neighbors=len(features), algorithm='auto').fit(features)
    return tree
    
def normalize_features(features, target):
    maxes = features.max(axis=0)
    mins  = features.min(axis=0)
    return (features - mins)/(maxes-mins), (target-mins)/(maxes-mins)
 
def extract_row(row):
    keys = row.keys()
    values = row.values()
    del values[ keys.index('cartodb_id')]
    return values

def extract_features_target(data, target_index=None):
    target   = None
    features = [row['a'] for row in data]
    target   = features[target_index]
    return np.array(features, dtype=float), np.array(target, dtype=float)
    
