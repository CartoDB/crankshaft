SELECT cdb_crankshaft._cdb_random_seeds(1234);

-- Use regular user role
SET ROLE test_regular_user;

-- Add to the search path the schema
SET search_path TO public,cartodb,cdb_crankshaft;

-- Exercise public functions
SELECT ppoints.code, m.quads
  FROM ppoints
  JOIN cdb_moran_local('ppoints', 'value') m
    ON ppoints.cartodb_id = m.ids
  ORDER BY ppoints.code;
SELECT round(cdb_overlap_sum(
  '0106000020E61000000100000001030000000100000004000000FFFFFFFFFF3604C09A0B9ECEC42E444000000000C060FBBF30C7FD70E01D44400000000040AD02C06481F1C8CD034440FFFFFFFFFF3604C09A0B9ECEC42E4440'::geometry,
  'values', 'value'
), 2);
