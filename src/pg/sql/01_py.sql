-- Use the crankshaft python module
CREATE OR REPLACE FUNCTION _cdb_crankshaft_activate_py()
RETURNS VOID
AS $$
    # activate virtualenv
    # TODO: parameterize with environment variables or something
    venv_path = '/home/ubuntu/crankshaft/src/py/dev'
    activate_path = venv_path + '/bin/activate_this.py'
    exec(open(activate_path).read(),
         dict(__file__=activate_path))

    # import something from virtualenv
    # from crankshaft import random_seeds

    # do some stuff
    # random_seeds.set_random_seeds(123)
    # plpy.notice('here we are')
$$ LANGUAGE plpythonu;
