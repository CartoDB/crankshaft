CREATE OR REPLACE FUNCTION
CDB_GRAVITY(subquery text, flows text, o_vars text[], d_vars text[],
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.gravity(subquery, flows, o_vars, d_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;
