CREATE OR REPLACE FUNCTION cdb_poc_xyz()
RETURNS Text AS $$
    from crankshaft.poc import xyz
    return xyz()
$$ LANGUAGE plpythonu;
