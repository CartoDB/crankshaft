-- Set the seeds of the RNGs (Random Number Generators)
-- used internally.
CREATE OR REPLACE FUNCTION
cdb_random_seeds (seed_value INTEGER) RETURNS VOID
AS $$
  from crankshaft import random_seeds
  random_seeds.set_random_seeds(seed_value)
$$ LANGUAGE plpythonu;
