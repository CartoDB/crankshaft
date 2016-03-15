# Development tasks:
#
# * install generates the control & script files into src/pg/
#   and installs then into the PostgreSQL extensions directory;
#   requires sudo. In additionof the current development version
#   named 'dev', an alias 'current' is generating for ease of
#   update (upgrade to 'current', then to 'dev').
#   the python module is installed in a virtualenv in envs/dev/
# * test runs the tests for the currently generated Development
#   extension.

SED = sed

EXTENSION    = crankshaft

DATA         = $(EXTENSION)--dev.sql \
	             $(EXTENSION)--current--dev.sql \
	             $(EXTENSION)--dev--current.sql

SOURCES_DATA_DIR = sql
SOURCES_DATA = $(wildcard $(SOURCES_DATA_DIR)/*.sql)

VIRTUALENV_PATH = $(realpath ../../envs)
ESC_VIRVIRTUALENV_PATH = $(subst /,\/,$(VIRTUALENV_PATH))

REPLACEMENTS = -e 's/@@VERSION@@/$(EXTVERSION)/g' \
               -e 's/@@VIRTUALENV_PATH@@/$(ESC_VIRVIRTUALENV_PATH)/g'

$(DATA): $(SOURCES_DATA)
	$(SED) $(REPLACEMENTS) $(SOURCES_DATA_DIR)/*.sql > $@

TEST_DIR = test
REGRESS = $(notdir $(basename $(wildcard $(TEST_DIR)/sql/*test.sql)))
REGRESS_OPTS = --inputdir='$(TEST_DIR)' --outputdir='$(TEST_DIR)'

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# This seems to be needed at least for PG 9.3.11
all: $(DATA)

test: export PGUSER=postgres
test: installcheck

# Release tasks

PACKAGE = crankshaft
EXTVERSION   = $(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")

../../release/$(EXTENSION).control: $(EXTENSION).control
	cp $< $@

# Prepare new release from the currently installed development version,
# for the current version X.Y.Z (defined in the control file)
# producing the extension script and control files in releases/
# and the python package in releases/python/X.Y.Z/crankshaft/
release: ../../release/$(EXTENSION).control
	cp $(EXTENSION)--dev.sql ../../release/$(EXTENSION)--$(EXTVERSION).sql
	mkdir -p ../../release/python/$(EXTVERSION)
	cp -r ../py/$(PACKAGE) ../../release/python/$(EXTVERSION)/
	$(SED) -i -r 's/version='"'"'[0-9]+\.[0-9]+\.[0-9]+'"'"'/version='"'"'$(EXTVERSION)'"'"'/g'  ../../release/python/$(EXTVERSION)/$(PACKAGE)/setup.py

# Install the current relese into the PostgreSQL extensions directory
# and the Python package in a virtual environment envs/X.Y.Z
deploy:
	$(INSTALL_DATA) ../../release/$(EXTENSION).control '$(DESTDIR)$(datadir)/extension/'
	$(INSTALL_DATA) ../../release/*.sql '$(DESTDIR)$(datadir)/extension/'
	# TODO: install also upgrade/downgrade files (manually generated)
	virtualenv --system-site-packages $(VIRTUALENV_PATH)/$(EXTVERSION)
	$(VIRTUALENV_PATH)/$(EXTVERSION)/bin/pip install -I -U ../../release/python/$(EXTVERSION)/$(PACKAGE)
	$(VIRTUALENV_PATH)/$(EXTVERSION)/bin/pip install -I nose

clean-dev:
	rm -f $(EXTENSION)--*.sql

clean-releases:
	rm -rf ../../release/python/*
	rm -f ../../release/$(EXTNAME)--*.sql
	rm -f ../../release/$(EXTNAME).control

clean-environments:
	rm -rf ../../envs/*

clean-all: clean-dev clean-releases clean-environments
