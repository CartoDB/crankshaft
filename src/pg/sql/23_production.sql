CREATE OR REPLACE FUNCTION
CDB_PRODUCTION(subquery text, flows text, origins text, d_vars text[],
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.production(subquery, flows, origins, d_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;
