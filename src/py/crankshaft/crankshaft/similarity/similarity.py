from sklearn.neighbors import BallTree
import numpy as np
import plpy

def similarity_rank(target_cartodb_id, query):
    data = plpy.execute(query)    
    features, target = extract_features_target(data,target_cartodb_id)
    tree = train(features)
    dist, ind  = tree.query(target, k=len(data))
    cartodb_ids  = [ dist[ind]['cartodb_id'] for index in ind ]
    return cartodb_ids, dist

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
    normed_features  = normalize_features(featuers)
    normed_target    = normalize_features([target])
    tree = BallTree(normed_features, leaf_size=2)
    return tree
    
def normalize_features(features):
    maxes = features.max(axis=0)
    mins  = features.min(axis=0)
    return (features - mins)/(maxes-mins)
    
def extract_features_target:(data, target_cartodb_id=None):
    target = None
    for row in data:
        data.keys().difference(['the_geom', 'the_geom_webmercator','cartodb_id'])
        if data['cartodb_id'] == target_cartodb_id
            target = data.values()
    return np.array(data), np.array(target)
    
