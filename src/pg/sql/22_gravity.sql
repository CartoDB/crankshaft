CREATE OR REPLACE FUNCTION
CDB_GWR(subquery text, flows text, o_vars text[], d_vars text[],
       cost text, cost_func text default 'pow', Quasi boolean default False)
RETURNS table(v1 numeric, v2 numeric, v3 numeric, v4 numeric, v5 numeric, v6 numeric, rowid bigint)
AS $$

from crankshaft.regression import gwr_cs

return spint_cs.gravity(subquery, flows, o_vars, d_vars, cost, cost_func, Quasi)

$$ LANGUAGE plpythonu;
