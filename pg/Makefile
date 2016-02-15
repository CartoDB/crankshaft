EXTENSION    = crankshaft
EXTVERSION   = $(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")

DATA         = dist/$(EXTENSION)--$(EXTVERSION).sql

SOURCES_DATA_DIR = sql
SOURCES_DATA = $(wildcard sql/$(EXTVERSION)/*.sql)

dist/$(EXTENSION)--$(EXTVERSION).sql: $(SOURCES_DATA)
	rm -f $@
	cat $(SOURCES_DATA_DIR)/*.sql >> $@

dist/$(EXTENSION).control: $(EXTENSION).control
	cp $< $@

REGRESS = $(notdir $(basename $(wildcard test/sql/*test.sql)))
TEST_DIR = test
REGRESS_OPTS = --inputdir='$(TEST_DIR)' --outputdir='$(TEST_DIR)'

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
