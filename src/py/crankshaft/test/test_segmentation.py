import unittest
import numpy as np
from helper import plpy, fixture_file
import crankshaft.segmentation as segmentation
import json

class SegmentationTest(unittest.TestCase):
    """Testing class for Moran's I functions"""

    def setUp(self):
        plpy._reset()

    def generate_random_data(self,n_samples,random_state,  row_type=False):
        x1 = random_state.uniform(size=n_samples)
        x2 = random_state.uniform(size=n_samples)
        x3 = random_state.randint(0, 4, size=n_samples)

        y = x1+x2*x2+x3
        cartodb_id  = range(len(x1))

        if row_type:
            return [ {'features': vals} for vals in zip(x1,x2,x3)], y
        else:
            return  [dict( zip(['x1','x2','x3','target', 'cartodb_id'],[x1,x2,x3,y,cartodb_id]))]

    def test_replace_nan_with_mean(self):
        test_array = np.array([1.2, np.nan, 3.2, np.nan, np.nan])

    def test_create_and_predict_segment(self):
        n_samples = 1000

        random_state_train = np.random.RandomState(13)
        random_state_test = np.random.RandomState(134)
        training_data = self.generate_random_data(n_samples, random_state_train)
        test_data, test_y = self.generate_random_data(n_samples, random_state_test, row_type=True)


        ids =  [{'cartodb_ids': range(len(test_data))}]
        rows =  [{'x1': 0,'x2':0,'x3':0,'y':0,'cartodb_id':0}]

        plpy._define_result('select \* from  \(select \* from training\) a  limit 1',rows)
        plpy._define_result('.*from \(select \* from training\) as a' ,training_data)
        plpy._define_result('select array_agg\(cartodb\_id order by cartodb\_id\) as cartodb_ids from \(.*\) a',ids)
        plpy._define_result('.*select \* from test.*' ,test_data)

        model_parameters =  {'n_estimators': 1200,
                             'max_depth': 3,
                             'subsample' : 0.5,
                             'learning_rate': 0.01,
                             'min_samples_leaf': 1}

        result = segmentation.create_and_predict_segment(
                'select * from training',
                'target',
                'select * from test',
                model_parameters)

        prediction = [r[1] for r in result]

        accuracy =np.sqrt(np.mean( np.square( np.array(prediction) - np.array(test_y))))

        self.assertEqual(len(result),len(test_data))
        self.assertTrue( result[0][2] < 0.01)
        self.assertTrue( accuracy < 0.5*np.mean(test_y)  )
