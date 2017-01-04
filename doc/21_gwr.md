## Regression

### Geographically weighted regression

Can currently estimate Gaussian, Poisson, and logistic models (built on a GLM framework). GWR object prepares model input. Fit method performs estimation and returns a GWR Results object.

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| subquery | text | SQL query that expose the data to be analyzed (e.g., `SELECT * FROM regression_inputs`). This query must have the geometry column name (see the optional `geom_col` for default), the id column name (see `id_col`), dependent and independent column names. |
| dep_var | text | name of the dependent variable in the regression model |
| ind_vars | text[] | Text array of independent used in the model to describe the dependent variable |
| bw (optional) | numeric | bandwidth value consisting of either a distance or N nearest neighbors. Defaults to calculate an optimal bandwidth. |
| fixed (optional) | boolean | True for distance based kernel function and False for adaptive (nearest neighbor) kernel function (default). Defaults to false. |
| kernel | text | Type of kernel function used to weight observations. One of gaussian, bisquare (default), or exponential. |


#### Returns

| Column Name | Type | Description |
|-------------|------|-------------|
| coeffs | JSON | JSON object with parameter estimates for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the parameter estimate. |
| stand_errs | JSON | Standard errors for each of the dependent variables. The keys of the JSON object are the dependent variables, with values corresponding to the respective standard errors. |
| t_vals | JSON | T-values for each of the dependent variables. The keys of the JSON object are the dependent variable names, with values corresponding to the respective t-value. |
| predicted | numeric | predicted value of y |
| residuals | numeric | residuals of the response |
| r_squared | numeric | R-squared for the parameter fit |
| bandwidth | numeric | bandwidth value consisting of either a distance or N nearest neighbors |
| rowid | int | row id of the original row |


#### Example Usage

```sql
SELECT
  g.cartodb_id,
  g.the_geom,
  g.the_geom_webmercator,
  (gwr.coeffs->>'pctblack')::numeric as coeff_pctblack,
  (gwr.coeffs->>'pctrural')::numeric as coeff_pctrural,
  (gwr.coeffs->>'pcteld')::numeric as coeff_pcteld,
  (gwr.coeffs->>'pctpov')::numeric as coeff_pctpov,
  gwr.residuals
FROM cdb_crankshaft.CDB_GWR('select * from g_utm'::text, 'pctbach'::text, Array['pctblack', 'pctrural', 'pcteld', 'pctpov']) As gwr
JOIN g_utm as g
on g.cartodb_id = gwr.rowid
```

Note: See [PostgreSQL syntax for parsing JSON objects](https://www.postgresql.org/docs/9.5/static/functions-json.html).
