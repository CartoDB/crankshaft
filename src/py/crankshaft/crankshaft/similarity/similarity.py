from sklearn.neighbors import BallTree
import  scipy.stats as stats
import numpy as np
import plpy

def query_to_dictionary(result):
    return [ dict(zip(r.keys(), r.values())) for r in result ]

def drop_all_nan_columns(data):
    return data[ ~np.isnan(data).all(axis=0)]
    
def fill_missing_na(data,val=None):
    inds = np.where(np.isnan(data))
    if val==None:
        col_mean = stats.nanmean(data,axis=0)
        data[inds]=np.take(col_mean,inds[1])
    else:
        data[inds]=np.take(val, inds[1])
    return data
    
def similarity_rank(target_cartodb_id, query):
    data = query_to_dictionary(plpy.execute(query))  
    
    features, target = extract_features_target(data,target_cartodb_id)
    features = fill_missing_na(drop_all_nan_columns(features))
    
    normed_features, normed_target  = normalize_features(features,target)
    tree = train(normed_features)
    dist, ind  = tree.query(normed_target, k=len(features))
    cartodb_ids  = [data[index]['cartodb_id'] for index in ind[0]]
    return zip(cartodb_ids, dist[0])

def most_similar(matches,query):
    data = plpy.execute(query)    
    features, _ = extract_features_target(data)
    tree = train(features)
    results = []
    for i in features:
        target = features
        dist,ind = tree.query(target, k=matches)
        cartodb_ids  = [ dist[ind]['cartodb_id'] for index in ind ]
        results.append(cartodb_ids)
    return cartodb_ids, results
    
    
def train(features):
    tree = BallTree(features, leaf_size=2)
    return tree
    
def normalize_features(features, target):
    maxes = features.max(axis=0)
    mins  = features.min(axis=0)
    return (features - mins)/(maxes-mins), (target-mins)/(maxes-mins)
    
def extract_features_target(data, target_cartodb_id=None):
    target = None
    features = []
    for row in data:
        values = [ val for key, val in row.iteritems() if key not in ['the_geom', 'the_geom_webmercator','cartodb_id']]
        if row['cartodb_id'] == target_cartodb_id:
            target = values
        features.append(values)

    return np.array(features, dtype=float), np.array(target, dtype=float)
    
