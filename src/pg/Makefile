# Generation of a new development version 'dev' (with an alias 'current' for
# updating easily by upgrading to 'current', then 'dev')

# sudo make install -- generate the 'dev' version from current source
#                      and make it available to PostgreSQL
# PGUSER=postgres make installcheck -- test the 'dev' extension

EXTENSION    = crankshaft

DATA         = $(EXTENSION)--dev.sql \
	             $(EXTENSION)--current--dev.sql \
	             $(EXTENSION)--dev--current.sql

SOURCES_DATA_DIR = sql
SOURCES_DATA = $(wildcard $(SOURCES_DATA_DIR)/*.sql)

$(DATA): $(SOURCES_DATA)
	cat $(SOURCES_DATA_DIR)/*.sql > $@

TEST_DIR = test
REGRESS = $(notdir $(basename $(wildcard $(TEST_DIR)/sql/*test.sql)))
REGRESS_OPTS = --inputdir='$(TEST_DIR)' --outputdir='$(TEST_DIR)'

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# This seems to be needed at least for PG 9.3.11
all: $(DATA)

# WIP: goals for releasing the extension...

EXTVERSION   = $(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")

../release/$(EXTENSION).control: $(EXTENSION).control
	cp $< $@

release: ../release/$(EXTENSION).control
	cp $(EXTENSION)--dev.sql $(EXTENSION)--$(EXTVERSION).sql
	# pending: create upgrade/downgrade scripts,
	#          commit, push, tag....
