## Regression

### Predictive geographically weighted regression (GWR)

-- add description here

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

### Descriptive geographically weighted regression

-- add description here

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


## Advanced reading

*   Fotheringham, A. Stewart, Chris Brunsdon, and Martin Charlton. 2002. Geographically Weighted Regression: The Analysis of Spatially Varying Relationships. John Wiley & Sons. <http://www.wiley.com/WileyCDA/WileyTitle/productCd-0471496162.html>

*   Brunsdon, Chris, A. Stewart Fotheringham, and Martin E. Charlton. 1996. "Geographically Weighted Regression: A Method for Exploring Spatial Nonstationarity." Geographical Analysis 28 (4): 281–98. <http://onlinelibrary.wiley.com/doi/10.1111/j.1538-4632.1996.tb00936.x/abstract>

*   Brunsdon, Chris, Stewart Fotheringham, and Martin Charlton. 1998. "Geographically Weighted Regression." Journal of the Royal Statistical Society: Series D (The Statistician) 47 (3): 431–43. <http://onlinelibrary.wiley.com/doi/10.1111/1467-9884.00145/abstract>

*   Fotheringham, A. S., M. E. Charlton, and C. Brunsdon. 1998. "Geographically Weighted Regression: A Natural Evolution of the Expansion Method for Spatial Data Analysis." Environment and Planning A 30 (11): 1905–27. doi:10.1068/a301905. <https://www.researchgate.net/publication/23538637_Geographically_Weighted_Regression_A_Natural_Evolution_Of_The_Expansion_Method_for_Spatial_Data_Analysis>

### GWR for prediction

*   Harris, P., A. S. Fotheringham, R. Crespo, and M. Charlton. 2010. "The Use of Geographically Weighted Regression for Spatial Prediction: An Evaluation of Models Using Simulated Data Sets." Mathematical Geosciences 42 (6): 657–80. doi:10.1007/s11004-010-9284-7. <https://www.researchgate.net/publication/225757830_The_Use_of_Geographically_Weighted_Regression_for_Spatial_Prediction_An_Evaluation_of_Models_Using_Simulated_Data_Sets>

### GWR in application

*   Cahill, Meagan, and Gordon Mulligan. 2007. "Using Geographically Weighted Regression to Explore Local Crime Patterns." Social Science Computer Review 25 (2): 174–93. doi:10.1177/0894439307298925. <http://isites.harvard.edu/fs/docs/icb.topic923297.files/174.pdf>

*   Gilbert, Angela, and Jayajit Chakraborty. 2011. "Using Geographically Weighted Regression for Environmental Justice Analysis: Cumulative Cancer Risks from Air Toxics in Florida." Social Science Research 40 (1): 273–86. doi:10.1016/j.ssresearch.2010.08.006. <http://scholarcommons.usf.edu/cgi/viewcontent.cgi?article=2985&context=etd>

*   Ali, Kamar, Mark D. Partridge, and M. Rose Olfert. 2007. "Can Geographically Weighted Regressions Improve Regional Analysis and Policy Making?" International Regional Science Review 30 (3): 300–329. doi:10.1177/0160017607301609. <https://www.researchgate.net/publication/249682503_Can_Geographically_Weighted_Regressions_Improve_Regional_Analysis_and_Policy_Making>

*   Lu, Binbin, Martin Charlton, and A. Stewart Fotheringhama. 2011. "Geographically Weighted Regression Using a Non-Euclidean Distance Metric with a Study on London House Price Data." Procedia Environmental Sciences, Spatial Statistics 2011: Mapping Global Change, 7: 92–97. doi:10.1016/j.proenv.2011.07.017. <https://www.researchgate.net/publication/261960122_Geographically_weighted_regression_with_a_non-Euclidean_distance_metric_A_case_study_using_hedonic_house_price_data>
