# Spatial Interaction Models (aka Gravity models)

## Tradiational Gravity (unconstrained)

### CDB_SpIntGravity(subquery text, flows_var text, origin_vars text[], destin_vars text[], cost text)

Unconstrained (traditional gravity) gravity-type spatial interaction model. This model builds up a description of the flow into and out of a geography to or from other geographies. The model is inspired by Newton's Universal Law of Gravitation, but modified to allow for attraction and repulsion. The cost is a measure of the 'difficulty' of moving from geography `i` to geography `j`. It is often based on distance and time.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | text | SQL query to expose data used for analysis |
| flows | text | Column name of observed flow between origin and destination. This is the quantity that will be described by `origin_vars` and `destin_vars`. |
| origin_vars | text[] | Text array of column names for each origin of n flows |
| destin_vars | text[] | attributes for each destination of n flows |
| cost | text | column name of cost to overcome separation between each origin and destination associated with a flow. This value is typically distance or time-based. |
| cost_func (optional) | text | Name of cost function. One of 'exp' or 'pow' |
| quasi (optional) | boolean | True (default) to estimate QuasiPoisson model; should result in same parameters as Poisson but with altered covariance. |


#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| coeffs | JSON | JSON object with model coefficient values for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the parameter estimate. The model's intercept is accessible with the key `'intercept'`. |
| stand_errs | JSON | Standard errors for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the respective standard errors. The standard error for the model's intercept is accessible with the key `'intercept'`. |
| t_vals | JSON | T-values for each of the dependent variables. The keys of the JSON object are the dependent variable names, with values corresponding to the respective t-value. The t-value for the model's intercept is accessible with the key `'intercept'`. |
| predicted | NUMERIC | Prediction of the flows for this geometry given the model coefficients `coeffs`. |
| r_squared | NUMERIC | R-squared for the parameter fit |
| aic | NUMERIC | [Akaike information criterion](https://en.wikipedia.org/wiki/Akaike_information_criterion) to describe the model quality. |

#### Sample usage

```sql
SELECT
  a.cartodb_id,
  a.the_geom,
  a.the_geom_webmercator,
  origin_i,
  (spint.coeffs->>'origin_i')::numeric As coeff_origin_i,
  (spint.coeffs->>'destination_j')::numeric As coeff_destination_j,
  (spint.coeffs->>'intercept')::numeric As coeff_intercept,
  spint.r_squared,
  spint.aic
FROM cdb_crankshaft.CDB_SpIntGravity('select * from austria_migration',   
  'flow_data',
  Array['origin_i'],
  Array['destination_j'],
  'dij') As spint
JOIN austria_migration As a
on a.cartodb_id = spint.rowid
```

## Production-constrained

### CDB_SpIntProduction(subquery text, flows_var text, origins text, destin_vars text[], cost text)

This model is similar to the traditional gravity model, but with additional knowledge about how flows originate that can be used to constrain the the model.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | text | SQL query to expose data used for analysis |
| flows | text | Column name of observed flow between origin and destination. This is the quantity that will be described by `origin_vars` and `destin_vars`. |
| origins | text | Column name of the origin regions used as a constraint. |
| destin_vars | text[] | attributes for each destination of n flows |
| cost | text | column name of cost to overcome separation between each origin and destination associated with a flow. This value is typically distance or time-based. |
| cost_func (optional) | text | Name of cost function. One of 'exp' or 'pow' |
| quasi (optional) | boolean | True (default) to estimate QuasiPoisson model; should result in same parameters as Poisson but with altered covariance. |


#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| coeffs | JSON | JSON object with model coefficient values for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the parameter estimate. The model's intercept is accessible with the key `'intercept'`. |
| stand_errs | JSON | Standard errors for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the respective standard errors. The standard error for the model's intercept is accessible with the key `'intercept'`. |
| t_vals | JSON | T-values for each of the dependent variables. The keys of the JSON object are the dependent variable names, with values corresponding to the respective t-value. The t-value for the model's intercept is accessible with the key `'intercept'`. |
| predicted | NUMERIC | Prediction of the flows for this geometry given the model coefficients `coeffs`. |
| r_squared | NUMERIC | R-squared for the parameter fit |
| aic | NUMERIC | [Akaike information criterion](https://en.wikipedia.org/wiki/Akaike_information_criterion) to describe the model quality. |

#### Sample usage

```sql
SELECT
  a.cartodb_id,
  a.the_geom,
  a.the_geom_webmercator,
  a.origin_i,
  (spint.coeffs->>'origin_4016')::numeric As coeff_origin_4016,
  (spint.coeffs->>'destination_j')::numeric As coeff_destination_j,
  (spint.coeffs->>'intercept')::numeric As coeff_intercept,
  spint.r_squared,
  spint.aic
FROM cdb_crankshaft.CDB_SpIntProduction('select * from austria_migration',   
  'flow_data',
  'origin_i',
  Array['destination_j'],
  'dij') As spint
JOIN austria_migration As a
on a.cartodb_id = spint.rowid
```

## Attraction-constrained

### CDB_SpIntAttraction(subquery text, flows_var text, destinations text, origin_vars text[], cost text)

This model is similar to the traditional gravity model, but with additional knowledge about how flows terminate that can be used to constrain the the model.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | text | SQL query to expose data used for analysis |
| flows | text | Column name of observed flow between origin and destination. This is the quantity that will be described by `origin_vars` and `destin_vars`. |
| destinations | text | Column name for the destination constraint. |
| origin_vars | text[] | Text array of column names for each origin of n flows |
| cost | text | column name of cost to overcome separation between each origin and destination associated with a flow. This value is typically distance or time-based. |
| cost_func (optional) | text | Name of cost function. One of 'exp' or 'pow' |
| quasi (optional) | boolean | True (default) to estimate QuasiPoisson model; should result in same parameters as Poisson but with altered covariance. |


#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| coeffs | JSON | JSON object with model coefficient values for each of the dependent variables. The keys of the JSON object are the specific dependent destinations, with values corresponding to the parameter estimate. |
| stand_errs | JSON | Standard errors for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the respective standard errors. The standard error for the model's intercept is accessible with the key `'intercept'`. |
| t_vals | JSON | T-values for each of the dependent variables. The keys of the JSON object are the dependent variable names, with values corresponding to the respective t-value. The t-value for the model's intercept is accessible with the key `'intercept'`. |
| predicted | NUMERIC | Prediction of the flows for this geometry given the model coefficients `coeffs`. |
| r_squared | NUMERIC | R-squared for the parameter fit |
| aic | NUMERIC | [Akaike information criterion](https://en.wikipedia.org/wiki/Akaike_information_criterion) to describe the model quality. |

Note: the JSON objects have keys defined by the inputs for the origin variables, destination, and costs. They can be accessed using [PostgreSQL JSON operators](https://www.postgresql.org/docs/9.5/static/functions-json.html).

A typical response of `coeffs` (as well as `stand_errs` and `t_vals`), is as follows:

```json
{
  "dest_AT34": -1.020,
  "dest_AT22": 0.569,
  "dest_AT21": -0.217,
  "origin_i": 1.237,
  "intercept": -5.143,
  "dij": 0.009
}
```

Based on inputs:

*   column `destination` which has row values of ('AT22', 'AT34', 'AT21') from
*   origin_vars set to `Array['origin_i']`
*   cost set to `dij`

#### Sample usage

```sql
SELECT
  a.cartodb_id,
  a.the_geom,
  a.the_geom_webmercator,
  a.destination_j,
  (spint.coeffs->>'origin_i')::numeric As coeff_origin_i,
  (spint.coeffs->>'dest_AT34')::numeric As coeff_dest_at34,
  (spint.coeffs->>'intercept')::numeric As coeff_intercept,
  (spint.coeffs->>'dij')::numeric As coeff_cost,
  spint.r_squared,
  spint.aic
FROM cdb_crankshaft.CDB_SpIntAttraction('select * from austria_migration',   
  'flow_data',
  'destination',
  Array['origin_i'],
  'dij') As spint
JOIN austria_migration As a
on a.cartodb_id = spint.rowid
```

## Doubly-constrained

### CDB_SpIntDoubly(subquery text, flows_var text, origins text, destinations text, cost text)

This model is similar to the traditional gravity model, but with additional knowledge about how flows originate and terminate that can be used to constrain the the model.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | text | SQL query to expose data used for analysis |
| flows | text | Column name of observed flow between origin and destination. This is the quantity that will be described by `origin_vars` and `destin_vars`. |
| origins | text | Column name of the origin regions used as a constraint. |
| destinations | text | Column name for the destination constraint. |
| cost | text | column name of cost to overcome separation between each origin and destination associated with a flow. This value is typically distance or time-based. |
| cost_func (optional) | text | Name of cost function. One of 'exp' or 'pow' |
| quasi (optional) | boolean | True (default) to estimate QuasiPoisson model; should result in same parameters as Poisson but with altered covariance. |


#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| coeffs | JSON | JSON object with model coefficient values for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the parameter estimate. The model's intercept is accessible with the key `'intercept'`. |
| stand_errs | JSON | Standard errors for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the respective standard errors. The standard error for the model's intercept is accessible with the key `'intercept'`. |
| t_vals | JSON | T-values for each of the dependent variables. The keys of the JSON object are the dependent variable names, with values corresponding to the respective t-value. The t-value for the model's intercept is accessible with the key `'intercept'`. |
| predicted | NUMERIC | Prediction of the flows for this geometry given the model coefficients `coeffs`. |
| r_squared | NUMERIC | R-squared for the parameter fit |
| aic | NUMERIC | [Akaike information criterion](https://en.wikipedia.org/wiki/Akaike_information_criterion) to describe the model quality. |

Note: the JSON objects have keys defined by the inputs for the origin variables, destination, and costs. They can be accessed using [PostgreSQL JSON operators](https://www.postgresql.org/docs/9.5/static/functions-json.html).

A typical response of `coeffs` (as well as `stand_errs` and `t_vals`), is as follows:

```json
{
  "dest_8634": 1.580,
  "dest_8193": 1.548,
  "origin_4016": 0.651,
  "origin_4341": 0.708,
  "dest_3952": 0.749,
  "origin_29142": 3.066,
  "intercept": 3.530,
  "dij": 0.009,
}
```

Based on inputs:

*   column `destination` which has row values of ('8634', '8193', '3952') from
*   column `origin` which as row values of ('4016', '4341', '29142')
*   cost set to `dij`

#### Sample usage

```sql
SELECT
  a.cartodb_id,
  a.the_geom,
  a.the_geom_webmercator,
  a.origin_i,
  a.destination_j,
  (spint.coeffs->>'dest_8634')::numeric As coeff_dest_8634,
  (spint.coeffs->>'origin_4341')::numeric As coeff_origin_4341,
  (spint.coeffs->>'intercept')::numeric As coeff_intercept,
  (spint.coeffs->>'dij')::numeric As coeff_cost,
  spint.r_squared,
  spint.aic
FROM cdb_crankshaft.CDB_SpIntDoubly('select * from austria_migration',   
  'flow_data',
  'origin_i',
  'destination_j',
  'dij') As spint
JOIN austria_migration As a
on a.cartodb_id = spint.rowid
```


## Local Production

### CDB_SpIntLocalProduction(subquery text, flows_var text, origins text, destin_vars text[], cost text)

Description

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | text | SQL query to expose data used for analysis |
| flows | text | Column name of observed flow between origin and destination. This is the quantity that will be described by `origin_vars` and `destin_vars`. |
| origins | text | Column name of the origin regions used as a constraint. |
| destin_vars | text[] | attributes for each destination of n flows |
| cost | text | column name of cost to overcome separation between each origin and destination associated with a flow. This value is typically distance or time-based. |
| cost_func (optional) | text | Name of cost function. One of 'exp' or 'pow' |
| quasi (optional) | boolean | True (default) to estimate QuasiPoisson model; should result in same parameters as Poisson but with altered covariance. |


#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| coeffs | JSON | JSON object with model coefficient values for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the parameter estimate. The model's intercept is accessible with the key `'intercept'`. |
| stand_errs | JSON | Standard errors for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the respective standard errors. The standard error for the model's intercept is accessible with the key `'intercept'`. |
| t_vals | JSON | T-values for each of the dependent variables. The keys of the JSON object are the dependent variable names, with values corresponding to the respective t-value. The t-value for the model's intercept is accessible with the key `'intercept'`. |
| predicted | NUMERIC | Prediction of the flows for this geometry given the model coefficients `coeffs`. |
| r_squared | NUMERIC | R-squared for the parameter fit |
| aic | NUMERIC | [Akaike information criterion](https://en.wikipedia.org/wiki/Akaike_information_criterion) to describe the model quality. |

Note: the JSON objects have keys defined by the inputs for the origin variables, destination, and costs. They can be accessed using [PostgreSQL JSON operators](https://www.postgresql.org/docs/9.5/static/functions-json.html).

A typical response of `coeffs` (as well as `stand_errs` and `t_vals`), is as follows:

```json
{
  "dest_AT34": -1.020,
  "dest_AT22": 0.569,
  "dest_AT21": -0.217,
  "origin_i": 1.237,
  "intercept": -5.143,
  "dij": 0.009
}
```

Based on inputs:

*   column `destination` which has row values of ('AT22', 'AT34', 'AT21') from
*   origin_vars set to `Array['origin_i']`
*   cost set to `dij`

#### Sample usage

```sql
SELECT
  a.cartodb_id,
  a.the_geom,
  a.the_geom_webmercator,
  a.origin_i,
  spint.coeffs,
  spint.r_squared,
  spint.aic
FROM cdb_crankshaft.CDB_SpIntLocalProduction('select * from austria_migration',   
  'flow_data',
  'origin',
  Array['destination_j'],
  'dij') As spint
JOIN austria_migration As a
on a.cartodb_id = spint.rowid
```


## Local Attraction

### CDB_SpIntLocalAttraction(subquery text, flows_var text, origin_vars text[], destin_vars text[], cost text)

Description

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | text | SQL query to expose data used for analysis |
| flows | text | Column name of observed flow between origin and destination. This is the quantity that will be described by `origin_vars` and `destin_vars`. |
| origin_vars | text[] | Text array of column names for each origin of n flows |
| destin_vars | text[] | attributes for each destination of n flows |
| cost | text | column name of cost to overcome separation between each origin and destination associated with a flow. This value is typically distance or time-based. |
| cost_func (optional) | text | Name of cost function. One of 'exp' or 'pow' |
| quasi (optional) | boolean | True (default) to estimate QuasiPoisson model; should result in same parameters as Poisson but with altered covariance. |


#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| coeffs | JSON | JSON object with model coefficient values for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the parameter estimate. The model's intercept is accessible with the key `'intercept'`. |
| stand_errs | JSON | Standard errors for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the respective standard errors. The standard error for the model's intercept is accessible with the key `'intercept'`. |
| t_vals | JSON | T-values for each of the dependent variables. The keys of the JSON object are the dependent variable names, with values corresponding to the respective t-value. The t-value for the model's intercept is accessible with the key `'intercept'`. |
| predicted | NUMERIC | Prediction of the flows for this geometry given the model coefficients `coeffs`. |
| r_squared | NUMERIC | R-squared for the parameter fit |
| aic | NUMERIC | [Akaike information criterion](https://en.wikipedia.org/wiki/Akaike_information_criterion) to describe the model quality. |

Note: the JSON objects have keys defined by the inputs for the origin variables, destination, and costs. They can be accessed using [PostgreSQL JSON operators](https://www.postgresql.org/docs/9.5/static/functions-json.html).

A typical response of `coeffs` (as well as `stand_errs` and `t_vals`), is as follows:

```json
{
  "dest_AT34": -1.020,
  "dest_AT22": 0.569,
  "dest_AT21": -0.217,
  "origin_i": 1.237,
  "intercept": -5.143,
  "dij": 0.009
}
```

Based on inputs:

*   column `destination` which has row values of ('AT22', 'AT34', 'AT21') from
*   origin_vars set to `Array['origin_i']`
*   cost set to `dij`

#### Sample usage

```sql
SELECT
  a.cartodb_id,
  a.the_geom,
  a.the_geom_webmercator,
  origin_i,
  (spint.coeffs->>'origin_i')::numeric As coeff_origin_i,
  (spint.coeffs->>'destination_j')::numeric As coeff_destination_j,
  (spint.coeffs->>'intercept')::numeric As coeff_intercept,
  spint.r_squared,
  spint.aic
FROM cdb_crankshaft.CDB_SpIntLocalAttraction('select * from austria_migration',   
  'flow_data',
  Array['origin_i'],
  Array['destination_j'],
  'dij') As spint
JOIN austria_migration As a
on a.cartodb_id = spint.rowid
```
