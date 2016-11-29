CREATE OR REPLACE FUNCTION
CDB_GWR(subquery text, dep_var text, ind_vars text[],
       bw numeric default null, fixed boolean default False, kernel text default 'bisquare')
RETURNS table(coeffs JSON, stand_errs JSON, t_vals JSON, predicted numeric, residuals numeric, r_squared numeric, rowid bigint, bandwidth numeric)
AS $$

from crankshaft.regression import gwr_cs

return gwr_cs.gwr(subquery, dep_var, ind_vars, bw, fixed, kernel)

$$ LANGUAGE plpythonu;
