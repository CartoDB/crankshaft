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
echo "[rtorre] is it even getting here???"
#psql -c "SELECT * FROM pg_available_extension_versions WHERE name LIKE 'crankshaft';"

echo "[rtorre] so far so good"

# Install in the fresh DB
psql $DBNAME -f ci/create-default-extension.sql

echo "[rtorre] is it creating the extension?"

# TODO save public functions and signatures

# Deploy current dev branch
make clean-dev || die "Could not clean dev files"
sudo make install || die "Could not deploy current dev branch"

# Check it can be upgraded
psql $DBNAME -c "ALTER EXTENSION crankshaft update to 'dev';" || die "Cannot upgrade to dev version"



# TODO check against saved public functions and signatures
