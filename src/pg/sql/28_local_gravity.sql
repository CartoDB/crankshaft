CREATE OR REPLACE FUNCTION
CDB_LOCAL_GRAVITY(subquery text, flows text, o_vars text[], d_vars text[], locs text,
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.local_gravity(subquery, flows, o_vars, d_vars, locs, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;
