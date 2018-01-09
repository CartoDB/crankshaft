CREATE OR REPLACE FUNCTION
    CDB_PyAggS(current_state Numeric[], current_row Numeric[]) 
    returns NUMERIC[] as $$
    BEGIN
        if array_upper(current_state,1) is null  then
            RAISE NOTICE 'setting state %',array_upper(current_row,1);
            current_state[1] = array_upper(current_row,1);
        end if;
        return array_cat(current_state,current_row) ;
    END
    $$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;

-- Create aggregate if it did not exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT *
        FROM pg_catalog.pg_proc p
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'cdb_crankshaft'
            AND p.proname = 'cdb_pyagg'
            AND p.proisagg)
    THEN
        CREATE AGGREGATE CDB_PyAgg(NUMERIC[]) (
            SFUNC = CDB_PyAggS,
            STYPE = Numeric[],
            PARALLEL = SAFE,
            INITCOND = "{}"
        );
    END IF;
END
$$ LANGUAGE plpgsql;
