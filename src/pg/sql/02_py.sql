CREATE OR REPLACE FUNCTION _cdb_crankshaft_virtualenvs_path()
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
    crankshaft_version = plpy.execute('SELECT cdb_crankshaft.cdb_crankshaft_internal_version()')[0]['cdb_crankshaft_internal_version']
    base_path = plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_virtualenvs_path()')[0]['_cdb_crankshaft_virtualenvs_path']
    default_venv_path = os.path.join(base_path, crankshaft_version)
    venv_path =  os.environ.get('CRANKSHAFT_VENV', default_venv_path)
    activate_path = venv_path + '/bin/activate_this.py'
    exec(open(activate_path).read(), dict(__file__=activate_path))
$$ LANGUAGE plpythonu;
