-- Internal function.
-- Set the seeds of the RNGs (Random Number Generators)
-- used internally.
CREATE OR REPLACE FUNCTION
_cdb_random_seeds (seed_value INTEGER) RETURNS VOID
AS $$
  plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
  from crankshaft import random_seeds
  random_seeds.set_random_seeds(seed_value)
$$ LANGUAGE plpythonu;
