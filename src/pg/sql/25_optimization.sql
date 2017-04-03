CREATE OR REPLACE FUNCTION 
CDB_OptimAssignments(drain text,
                     source text,
                     drain_capacity text,
                     source_production text,
                     marginal_cost text,
                     waste_per_person numeric DEFAULT 0.01,
                     recycle_rate numeric DEFAULT 0.0,
                     dist_rate numeric DEFAULT 0.15,
                     dist_threshold numeric DEFAULT null)
RETURNS table(drain_id bigint, source_id int, cost numeric) AS $$

from crankshaft.optimization import Optim

def cast_val(val):
    return float(val) if val is not None else None

params = {'waste_per_person': cast_val(waste_per_person),
          'recycle_rate': cast_val(recycle_rate), 
          'dist_rate': cast_val(dist_rate),
          'dist_threshold': cast_val(dist_threshold)}

optim = Optim(drain, source, drain_capacity, source_production, marginal_cost,
              **params)
x = optim.output()

return x
$$ LANGUAGE plpythonu;
