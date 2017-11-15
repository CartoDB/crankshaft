include ../../Makefile.global

# Development tasks:
#
# * install generates the control & script files into src/pg/
#   and installs then into the PostgreSQL extensions directory;
#   requires sudo. In additionof the current development version
#   named 'dev', an alias 'current' is generating for ease of
#   update (upgrade to 'current', then to 'dev').
# * test runs the tests for the currently generated Development
#   extension.

DATA = \
    $(EXTENSION)--dev.sql \
    $(EXTENSION)--current--dev.sql \
    $(EXTENSION)--dev--current.sql \
    $(EXTENSION)--$(RELEASE_VERSION)--dev.sql

SOURCES_DATA_DIR = sql
SOURCES_DATA = $(wildcard $(SOURCES_DATA_DIR)/*.sql)

REPLACEMENTS = -e 's/@@VERSION@@/$(EXTVERSION)/g'

$(DATA): $(SOURCES_DATA)
	$(SED) $(REPLACEMENTS) $(SOURCES_DATA_DIR)/*.sql > $@
ifeq ($(PG_PARALLEL), 0)
	$(eval TMPFILE := $(shell mktemp /tmp/$@.XXXXXXXXXX))
	$(SED) -e 's/PARALLEL \= [A-Z]*,/''/g' -e 's/PARALLEL [A-Z]*/''/g' $@ > $(TMPFILE);
	mv $(TMPFILE) $@
endif


TEST_DIR = test
REGRESS = $(sort $(notdir $(basename $(wildcard $(TEST_DIR)/sql/*test.sql))))
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

# If needed remove PARALLEL tags from the release files
release_remove_parallel_deploy:
ifeq ($(PG_PARALLEL), 0)
	for n in $(wildcard ../../release/*.sql); do \
		$(eval TMPFILE := $(shell mktemp /tmp/XXXXXXXXXX)) \
		$(SED) -e 's/PARALLEL \= [A-Z]*,/''/g' -e 's/PARALLEL [A-Z]*/''/g' $$n > $(TMPFILE); \
		mv $(TMPFILE) $$n; \
	done
endif

# Install the current release into the PostgreSQL extensions directory
deploy: release_remove_parallel_deploy
	$(INSTALL_DATA) ../../release/$(EXTENSION).control '$(DESTDIR)$(datadir)/extension/'
	$(INSTALL_DATA) ../../release/*.sql '$(DESTDIR)$(datadir)/extension/'

