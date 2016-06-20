CREATE OR REPLACE FUNCTION cdb_crankshaft.cdb_crankshaft_version()
RETURNS text AS $$
  SELECT '0.0.2'::text;
$$ language 'sql' STABLE STRICT;

CREATE OR REPLACE FUNCTION cdb_crankshaft._cdb_crankshaft_internal_version()
RETURNS text AS $$
  SELECT installed_version FROM pg_available_extensions where name='crankshaft' and pg_available_extensions IS NOT NULL;
$$ language 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION cdb_crankshaft._cdb_crankshaft_virtualenvs_path()
RETURNS text
AS $$
  BEGIN
    RETURN '/home/ubuntu/crankshaft/envs';
  END;
$$ language plpgsql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION cdb_crankshaft._cdb_crankshaft_activate_py()
RETURNS VOID
AS $$
    import os
    # plpy.notice('%',str(os.environ))
    # activate virtualenv
    crankshaft_version = plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_internal_version()')[0]['_cdb_crankshaft_internal_version']
    base_path = plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_virtualenvs_path()')[0]['_cdb_crankshaft_virtualenvs_path']
    default_venv_path = os.path.join(base_path, crankshaft_version)
    venv_path =  os.environ.get('CRANKSHAFT_VENV', default_venv_path)
    activate_path = venv_path + '/bin/activate_this.py'
    exec(open(activate_path).read(), dict(__file__=activate_path))
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
cdb_crankshaft._cdb_random_seeds (seed_value INTEGER) RETURNS VOID
AS $$
  plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
  from crankshaft import random_seeds
  random_seeds.set_random_seeds(seed_value)
$$ LANGUAGE plpythonu;
-- Moran's I
CREATE OR REPLACE FUNCTION
cdb_crankshaft.cdb_moran_local (
      t TEXT,
  	  attr TEXT,
  	  significance float DEFAULT 0.05,
  	  num_ngbrs INT DEFAULT 5,
  	  permutations INT DEFAULT 99,
  	  geom_column TEXT DEFAULT 'the_geom',
  	  id_col TEXT DEFAULT 'cartodb_id',
      w_type TEXT DEFAULT 'knn')
RETURNS TABLE (moran FLOAT, quads TEXT, significance FLOAT, ids INT)
AS $$
  plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
  from crankshaft.clustering import moran_local
  # TODO: use named parameters or a dictionary
  return moran_local(t, attr, significance, num_ngbrs, permutations, geom_column, id_col, w_type)
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
cdb_crankshaft.cdb_moran_local_rate(t TEXT,
		 numerator TEXT,
		 denominator TEXT,
		 significance FLOAT DEFAULT 0.05,
		 num_ngbrs INT DEFAULT 5,
		 permutations INT DEFAULT 99,
		 geom_column TEXT DEFAULT 'the_geom',
		 id_col TEXT DEFAULT 'cartodb_id',
		 w_type TEXT DEFAULT 'knn')
RETURNS TABLE(moran FLOAT, quads TEXT, significance FLOAT, ids INT, y numeric)
AS $$
  plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
  from crankshaft.clustering import moran_local_rate
  # TODO: use named parameters or a dictionary
  return moran_local_rate(t, numerator, denominator, significance, num_ngbrs, permutations, geom_column, id_col, w_type)
$$ LANGUAGE plpythonu;
