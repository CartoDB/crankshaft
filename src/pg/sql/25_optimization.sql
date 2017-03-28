CREATE OR REPLACE FUNCTION 
CDB_OptimAssignments(drain text,
                     source text,
                     drain_capacity text,
                     source_production text,
                     marginal_cost text)
RETURNS setof int AS $$

from crankshaft.optimization import Optim

optim = Optim(drain, source, drain_capacity, source_production, marginal_cost)
x = optim.optim()
print(x)

return x
$$ LANGUAGE plpythonu;
