import time
import plpy
import pickle
from petname import generate

def create_model_table():
    q = '''
        create table if not exists model_storage(
            description text,
            name text unique,
            model bytea,
            feature_names text[],
            date_created timestamptz,
            id serial primary key);
        '''
    plpy.notice(q)
    plan = plpy.prepare(q)
    resp = plpy.execute(plan)
    plpy.notice('Model table successfully created')
    plpy.notice(str(resp))

def get_model(model_name):
    """retrieve model if it exists"""
    try:
        plan = plpy.prepare('''
            SELECT model FROM model_storage
            WHERE name = $1;
        ''', ['text', ])
        model_encoded = plpy.execute(plan, [model_name, ])
        if len(model_encoded) == 1:
            model = pickle.loads(
                model_encoded[0]['model']
            )
            plpy.notice('Model successfully loaded')
        else:
            plpy.notice('Model not found, or too many models '
                        '({})'.format(len(model_encoded)))
            model = None
    except plpy.SPIError as err:
        plpy.error('ERROR: {}'.format(err))

    return model

def set_model(model, model_name, feature_names):
    """stores the model in the table model_storage"""
    if model_name is None:
	model_name = generate(words=2, separator='_', letters=8)
	existing_names = plpy.execute('''
	    SELECT array_agg(name) as name
	    FROM model_storage
	''')
        plpy.notice('nrows: {}'.format(existing_names.nrows()))
	plpy.notice('MODEL NAME: {}'.format(model_name))
        plpy.notice('LEN of ms: {}'.format(len(existing_names)))
        plpy.notice('existing_names: {}'.format(str(existing_names)))
        plpy.notice('existing_names: {}'.format(str(existing_names[0]['name'])))
        plpy.notice('type existing_names: {}'.format(type(existing_names[0]['name'])))
        if existing_names[0]['name'] is not None:
            while model_name in existing_names[0]['name']:
                model_name = generate(words=2, separator='_', letters=10)
                plpy.notice(model_name)

    # store model
    try:
	plan = plpy.prepare('''
	    INSERT INTO model_storage(description, name, model, feature_names, date_created)
	    VALUES (
	      $1,
	      $2,
	      $3,
              $4::text[],
	      to_timestamp($5));
	''', ['text', 'text', 'bytea', 'text', 'numeric'])
        plpy.notice('{%s}' % ','.join(feature_names))
        plpy.notice(feature_names)
	plpy.execute(
	    plan,
	    [' '.join(m.strip() for m in model.__repr__().split('\n')),
	     model_name,
	     pickle.dumps(model),
             '{%s}' % ','.join(feature_names),
	     time.time()]
	)
	plpy.notice('model successfully stored as {}'.format(model_name))
    except plpy.SPIError as err:
	plpy.notice('ERROR: {}\nt: {}'.format(err, time.time()))
