SET client_min_messages TO WARNING;
\set ECHO none
\set VERBOSITY TERSE
\pset format unaligned

--
-- postgres=# select round(avg(i), 3) as avg,
--                   round(stddev(i), 3) as stddev,
--                   round(avg(i) + stddev(i), 3) as one_stddev,
--                   round(avg(i) + 2 * stddev(i), 3) As two_stddev
--            from unnest(ARRAY[1,3,2,3,5,1,2,32,12,3,57,2,1,4,2,100]) As x(i);
--   avg   | stddev | one_stddev | two_stddev
-- --------+--------+------------+------------
--  14.375 | 27.322 |     41.697 |     69.020


-- With an threshold of 1.0 standard deviation, ids 11, 16, and 17 are outliers
WITH a AS (
    SELECT
      ARRAY[1,3,2,3,5,1,2,32,12, 3,57, 2, 1, 4, 2,100,-100]::numeric[] As vals, ARRAY[1,2,3,4,5,6,7, 8, 9,10,11,12,13,14,15, 16,  17]::int[] As ids
), b As (
  SELECT
    (cdb_crankshaft.cdb_StdDevOutlier(vals, 1.0, ids)).*
  FROM a
  ORDER BY ids)
SELECT *
FROM b
WHERE is_outlier IS TRUE;

-- With a threshold of 2.0 standard deviations, id 16 is the only outlier
WITH a AS (
    SELECT
      ARRAY[1,3,2,3,5,1,2,32,12, 3,57, 2, 1, 4, 2,100,-100]::numeric[] As vals,
      ARRAY[1,2,3,4,5,6,7, 8, 9,10,11,12,13,14,15, 16,  17]::int[] As ids
), b As (
  SELECT
    (cdb_crankshaft.CDB_StdDevOutlier(vals, 2.0, ids)).*
  FROM a
  ORDER BY ids)
SELECT *
FROM b
WHERE is_outlier IS TRUE;

-- With a Stddev of zero, should throw back error
-- With a threshold of 2.0 standard deviations, id 16 is the only outlier
WITH a AS (
    SELECT
      ARRAY[5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5]::numeric[] As vals,
      ARRAY[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]::int[] As ids
), b As (
  SELECT
    (cdb_crankshaft.CDB_StdDevOutlier(vals, 1.0, ids)).*
  FROM a
  ORDER BY ids)
SELECT *
FROM b
WHERE is_outlier IS TRUE;

-- With a ratio threshold of 2.0 threshold (100% above or below the mean)
--  which is greater than ~21, which are values
WITH a AS (
    SELECT
      ARRAY[1,3,2,3,5,1,2,32,12, 3,57, 2, 1, 4, 2,100,-100]::numeric[] As vals,
      ARRAY[1,2,3,4,5,6,7, 8, 9,10,11,12,13,14,15, 16,  17]::int[] As ids
), b As (
  SELECT
    (cdb_crankshaft.CDB_PercentOutlier(vals, 2.0, ids)).*
  FROM a
  ORDER BY ids)
SELECT *
  FROM b
 WHERE is_outlier IS TRUE;

-- With a static threshold of 11, what are the outliers
WITH a AS (
     SELECT
       ARRAY[1,3,2,3,5,1,2,32,12, 3,57, 2, 1, 4, 2,100,-100]::numeric[] As vals,
       ARRAY[1,2,3,4,5,6,7, 8, 9,10,11,12,13,14,15, 16,  17]::int[] As ids
 ), b As (
   SELECT unnest(vals) As v, unnest(ids) as i
     FROM a
 )
SELECT cdb_crankshaft.CDB_StaticOutlier(v, 11.0) As is_outlier, i As rowid
  FROM b
WHERE cdb_crankshaft.CDB_StaticOutlier(v, 11.0) is True
ORDER BY i;
