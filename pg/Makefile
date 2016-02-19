# Makefile to generate the extension out of separate sql source files.
# Once a version is released, it is not meant to be changed. E.g: once version 0.0.1 is out, it SHALL NOT be changed.

EXTENSION    = crankshaft
EXTVERSION   = $(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")

# The new version to be generated from templates
NEW_EXTENSION_ARTIFACT = $(EXTENSION)--$(EXTVERSION).sql

# DATA is a special variable used by postgres build infrastructure
# These are the files to be installed in the server shared dir,
# for installation from scratch, upgrades and downgrades.
# @see http://www.postgresql.org/docs/current/static/extend-pgxs.html
DATA =  $(NEW_EXTENSION_ARTIFACT)

SOURCES_DATA_DIR = sql/$(EXTVERSION)
SOURCES_DATA = $(wildcard sql/$(EXTVERSION)/*.sql)

# The extension installation artifacts are stored in the base subdirectory
$(NEW_EXTENSION_ARTIFACT): $(SOURCES_DATA)
	rm -f $@
	cat $(SOURCES_DATA_DIR)/*.sql >> $@

REGRESS = $(notdir $(basename $(wildcard test/$(EXTVERSION)/sql/*test.sql)))
TEST_DIR = test/$(EXTVERSION)
REGRESS_OPTS = --inputdir='$(TEST_DIR)' --outputdir='$(TEST_DIR)'

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
