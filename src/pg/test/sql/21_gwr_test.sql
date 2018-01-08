-- test of Geographically Weighted Regression (GWR)
SET client_min_messages TO WARNING;
\set ECHO none
\pset format unaligned
\i test/fixtures/gwr_georgia.sql

SELECT 
    rowid,
    round((coeffs->>'pctrural')::numeric, 4) As coeff_pctrural,
    round((stand_errs->>'pctrural')::numeric, 4) As std_errs_pctrural,
    round((t_vals->>'pctrural')::numeric, 4) As t_vals_pctrural,
    round(predicted, 4) As predicted,
    round(residuals, 4) As residuals,
    round(r_squared, 4) As r_squared,
    bandwidth As bandwidth
FROM
cdb_crankshaft.CDB_GWR('SELECT * FROM g_utm_testing', 'pctbach', 
        Array['pctrural', 'pctpov', 'pctblack']::text[],
        90.0, 
        False,
        'bisquare', 
        'the_geom',
        'areakey')
WHERE rowid in (13001, 13027, 13039, 13231, 13321, 13293)
ORDER BY rowid ASC;


-- comparison data from known calculated values in 
--   https://github.com/TaylorOshan/pysal/blob/1d6af33bda46b1d623f70912c56155064463383f/pysal/examples/georgia/georgia_BS_NN_listwise.csv
-- Note: values output from this analysis were correct with 1% of the values in that table, possibly due to projection differences.

