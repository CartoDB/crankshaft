include ../../Makefile.global

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

DATA         = $(EXTENSION)--dev.sql \
	             $(EXTENSION)--current--dev.sql \
	             $(EXTENSION)--dev--current.sql

SOURCES_DATA_DIR = sql
SOURCES_DATA = $(wildcard $(SOURCES_DATA_DIR)/*.sql)

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

../../release/$(EXTENSION).control: $(EXTENSION).control
	cp $< $@

# Prepare new release from the currently installed development version,
# for the current version X.Y.Z (defined in the control file)
# producing the extension script and control files in releases/
# and the python package in releases/python/X.Y.Z/crankshaft/
release: ../../release/$(EXTENSION).control $(SOURCES_DATA)
	$(SED) $(REPLACEMENTS) $(SOURCES_DATA_DIR)/*.sql > ../../release/$(EXTENSION)--$(EXTVERSION).sql

# Install the current relese into the PostgreSQL extensions directory
# and the Python package in a virtual environment envs/X.Y.Z
deploy:
	$(INSTALL_DATA) ../../release/$(EXTENSION).control '$(DESTDIR)$(datadir)/extension/'
	$(INSTALL_DATA) ../../release/*.sql '$(DESTDIR)$(datadir)/extension/'
