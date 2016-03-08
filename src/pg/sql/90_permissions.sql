-- Make sure by default there are no permissions for publicuser
-- NOTE: this happens at extension creation time, as part of an implicit transaction.
-- REVOKE ALL PRIVILEGES ON SCHEMA cdb_crankshaft FROM PUBLIC, publicuser CASCADE;

-- Grant permissions on the schema to publicuser (but just the schema)
GRANT USAGE ON SCHEMA cdb_crankshaft TO publicuser;

-- Revoke execute permissions on all functions in the schema by default
-- REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA cdb_crankshaft FROM PUBLIC, publicuser;
