CREATE OR REPLACE FUNCTION
CDB_ATTRACTION(subquery text, flows text, destinations text, o_vars text[],
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.attraction(subquery, flows, destinations, o_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;
