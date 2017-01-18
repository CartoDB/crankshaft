CREATE OR REPLACE FUNCTION
CDB_Gravity(subquery text, flows text, o_vars text[], d_vars text[],
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.gravity(subquery, flows, o_vars, d_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
CDB_Production(subquery text, flows text, origins text, d_vars text[],
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.production(subquery, flows, origins, d_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION
CDB_Attraction(subquery text, flows text, destinations text, o_vars text[],
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.attraction(subquery, flows, destinations, o_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION
CDB_Doubly(subquery text, flows text, origins text, destinations text,
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.doubly(subquery, flows, origins, destinations, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION
CDB_LocalProduction(subquery text, flows text, origins text, d_vars text[], cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.local_production(subquery, flows, origins, d_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION
CDB_LocalAttraction(subquery text, flows text, destinations text, o_vars text[],
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.local_attraction(subquery, flows, destinations, o_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
CDB_LocalGravity(subquery text, flows text, o_vars text[], d_vars text[], locs text,
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, r_squared numeric, aic numeric, rowid varchar)
AS $$

from crankshaft.regression import spint_gravity

return spint_gravity.local_gravity(subquery, flows, o_vars, d_vars, locs, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;
