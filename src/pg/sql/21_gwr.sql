CREATE OR REPLACE FUNCTION
CDB_GWR(subquery text, dep_var text, ind_vars text[],
       fixed boolean default False, kernel text default 'bisquare')
RETURNS table(v1 numeric, v2 numeric, v3 numeric, v4 numeric, v5 numeric, v6 numeric, rowid bigint)
AS $$

from crankshaft.regression import gwr

return gwr(subquery, dep_var, ind_vars, fixed, kernel)

$$ LANGUAGE plpythonu;
