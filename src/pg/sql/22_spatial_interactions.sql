CREATE OR REPLACE FUNCTION
CDB_SpIntGravity(subquery text, flows_var text, origin_vars text[], destin_vars text[],
       cost text, cost_func text default 'pow', quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid bigint)
AS $$

from crankshaft.regression import SpInt
spint = SpInt()
return spint.gravity(subquery, flows_var, origin_vars, destin_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
CDB_SpIntProduction(subquery text, flows_var text, origins text, d_vars text[],
       cost text, cost_func text default 'pow', quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid bigint)
AS $$

from crankshaft.regression import SpInt
spint = SpInt()
return spint.production(subquery, flows_var, origins, d_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION
CDB_SpIntAttraction(subquery text, flows_var text, destinations text, o_vars text[],
       cost text, cost_func text default 'pow', quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid bigint)
AS $$

from crankshaft.regression import SpInt
spint = SpInt()
return spint.attraction(subquery, flows_var, destinations, o_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION
CDB_SpIntDoubly(subquery text, flows_var text, origins text, destinations text,
       cost text, cost_func text default 'pow', quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, r_squared numeric, aic numeric, rowid bigint)
AS $$

from crankshaft.regression import SpInt
spint = SpInt()
return spint.doubly(subquery, flows_var, origins, destinations, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION
CDB_SpIntLocalProduction(subquery text, flows_var text, origins text, d_vars text[], cost text, cost_func text default 'pow', quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, r_squared numeric, aic numeric, rowid bigint)
AS $$

from crankshaft.regression import SpInt
spint = SpInt()
return spint.local_production(subquery, flows_var, origins, d_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION
CDB_SpIntLocalAttraction(subquery text, flows_var text, destinations text, o_vars text[],
       cost text, cost_func text default 'pow', quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, r_squared numeric, aic numeric, rowid bigint)
AS $$

from crankshaft.regression import SpInt
spint = SpInt()
return spint.local_attraction(subquery, flows_var, destinations, o_vars, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION
CDB_SpIntLocalGravity(subquery text, flows_var text, o_vars text[], d_vars text[], locs text,
       cost text, cost_func text default 'pow', quasi boolean default False)
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, r_squared numeric, aic numeric, rowid bigint)
AS $$

from crankshaft.regression import SpInt
spint = SpInt()
return spint.local_gravity(subquery, flows_var, o_vars, d_vars, locs, cost, cost_func, quasi)

$$ LANGUAGE plpythonu;
