CREATE OR REPLACE FUNCTION
CDB_OptimAssignments(source text,
                     drain text,
                     drain_capacity text,
                     source_production text,
                     marginal_cost text,
                     dist_matrix_query text,
                     dist_rate numeric DEFAULT 0.15,
                     dist_threshold numeric DEFAULT null)
RETURNS table(drain_id bigint, source_id int, cost numeric) AS $$

from crankshaft.optimization import Optim

def cast_val(val):
    return float(val) if val is not None else None

params = {'dist_rate': cast_val(dist_rate),
          'dist_threshold': cast_val(dist_threshold)}


optim = Optim(source, drain, dist_matrix_query, drain_capacity,
              source_production, marginal_cost, **params)
x = optim.output()

return x
$$ LANGUAGE plpythonu;
