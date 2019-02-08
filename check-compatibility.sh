#!/bin/bash

export PGUSER=postgres

DBNAME=crankshaft_compatcheck

function die {
    echo $1
    exit -1
}

# Create fresh DB
psql -c "CREATE DATABASE $DBNAME;" || die "Could not create DB"

# Hook for cleanup
function cleanup {
    psql -c "DROP DATABASE IF EXISTS crankshaft_compatcheck;"
}
trap cleanup EXIT

# Deploy previous release
(cd src/py && sudo make deploy RUN_OPTIONS="--no-deps") || die "Could not deploy python extension"
(cd src/pg && sudo make deploy) || die " Could not deploy last release"
psql -c "SELECT * FROM pg_available_extension_versions WHERE name LIKE 'crankshaft';"

# Install in the fresh DB
psql $DBNAME <<'EOF'
-- Install dependencies
CREATE EXTENSION plpythonu;
CREATE EXTENSION postgis;

-- Create role publicuser if it does not exist
DO
$$
BEGIN
   IF NOT EXISTS (
      SELECT *
      FROM   pg_catalog.pg_user
      WHERE  usename = 'publicuser') THEN

      CREATE ROLE publicuser LOGIN;
   END IF;
END
$$ LANGUAGE plpgsql;

-- Install the default version
CREATE EXTENSION crankshaft;
\dx
EOF


# Check PG version
PG_VERSION=`psql -q -t -c "SELECT current_setting('server_version_num')"`

# Save public function signatures
if [[ "$PG_VERSION" -lt 110000 ]]; then
    psql $DBNAME -c "
    CREATE TABLE release_function_signatures AS
    SELECT
        p.proname as name,
        pg_catalog.pg_get_function_result(p.oid) as result_type,
        pg_catalog.pg_get_function_arguments(p.oid) as arguments,
    CASE
        WHEN p.proisagg THEN 'agg'
        WHEN p.proiswindow THEN 'window'
        WHEN p.prorettype = 'pg_catalog.trigger'::pg_catalog.regtype THEN 'trigger'
        ELSE 'normal'
    END as type
    FROM pg_catalog.pg_proc p
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE
        n.nspname = 'cdb_crankshaft'
        AND p.proname LIKE 'cdb_%'
    ORDER BY 1, 2, 4;"
else
    psql $DBNAME -c "
    CREATE TABLE release_function_signatures AS
    SELECT
        p.proname as name,
        pg_catalog.pg_get_function_result(p.oid) as result_type,
        pg_catalog.pg_get_function_arguments(p.oid) as arguments,
    CASE    WHEN p.prokind = 'a' THEN 'agg'
            WHEN p.prokind = 'w' THEN 'window'
            WHEN p.prorettype = 'pg_catalog.trigger'::pg_catalog.regtype THEN 'trigger'
            ELSE 'normal'
    END as type
    FROM pg_catalog.pg_proc p
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE
        n.nspname = 'cdb_crankshaft'
        AND p.proname LIKE 'cdb_%'
    ORDER BY 1, 2, 4;"
fi

# Deploy current dev branch
make clean-dev || die "Could not clean dev files"
sudo make install || die "Could not deploy current dev branch"

# Check it can be upgraded
psql $DBNAME -c "ALTER EXTENSION crankshaft update to 'dev';" || die "Cannot upgrade to dev version"

if [[ $PG_VERSION -lt 110000 ]]; then
    psql $DBNAME -c "
    CREATE TABLE dev_function_signatures AS
        SELECT  p.proname as name,
                pg_catalog.pg_get_function_result(p.oid) as result_type,
                pg_catalog.pg_get_function_arguments(p.oid) as arguments,
                CASE    WHEN p.proisagg     THEN 'agg'
                        WHEN p.proiswindow  THEN 'window'
                        WHEN p.prorettype = 'pg_catalog.trigger'::pg_catalog.regtype THEN 'trigger'
                        ELSE 'normal'
                END as type
        FROM pg_catalog.pg_proc p
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE
            n.nspname = 'cdb_crankshaft'
            AND p.proname LIKE 'cdb_%'
        ORDER BY 1, 2, 4;"
else
    psql $DBNAME -c "
    CREATE TABLE dev_function_signatures AS
        SELECT  p.proname as name,
                pg_catalog.pg_get_function_result(p.oid) as result_type,
                pg_catalog.pg_get_function_arguments(p.oid) as arguments,
                CASE    WHEN p.prokind = 'a' THEN 'agg'
                        WHEN p.prokind = 'w' THEN 'window'
                        WHEN p.prorettype = 'pg_catalog.trigger'::pg_catalog.regtype THEN 'trigger'
                        ELSE 'normal'
                END as type
        FROM pg_catalog.pg_proc p
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE
            n.nspname = 'cdb_crankshaft'
            AND p.proname LIKE 'cdb_%'
        ORDER BY 1, 2, 4;"
fi


echo "Functions in development not in latest release (ok):"
psql $DBNAME -c "SELECT * FROM dev_function_signatures EXCEPT SELECT * FROM release_function_signatures;"

echo "Functions in latest release not in development (compat issue):"
psql $DBNAME -c "SELECT * FROM release_function_signatures EXCEPT SELECT * FROM dev_function_signatures;"

# Fail if there's a signature mismatch / missing functions
psql $DBNAME -c "SELECT * FROM release_function_signatures EXCEPT SELECT * FROM dev_function_signatures;" | fgrep '(0 rows)' \
    || die "Function signatures changed"
