CREATE OR REPLACE FUNCTION _cdb_crankshaft_virtualenv_path()
RETURNS text
AS $$
  BEGIN
    -- RETURN '/opt/virtualenvs/crankshaft';
    RETURN '@@VIRTUALENV_PATH@@';
  END;
$$ language plpgsql IMMUTABLE STRICT;

-- Use the crankshaft python module
CREATE OR REPLACE FUNCTION _cdb_crankshaft_activate_py()
RETURNS VOID
AS $$
    import os
    # plpy.notice('%',str(os.environ))
    # activate virtualenv
    default_venv_path = plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_virtualenv_path()')[0]['_cdb_crankshaft_virtualenv_path']
    venv_path =  os.environ.get('CRANKSHAFT_VENV', default_venv_path)
    activate_path = venv_path + '/bin/activate_this.py'
    exec(open(activate_path).read(), dict(__file__=activate_path))
$$ LANGUAGE plpythonu;
