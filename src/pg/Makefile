include ../../Makefile.global

# Development tasks:
#
# * install generates the control & script files into src/pg/
#   and installs then into the PostgreSQL extensions directory;
#   requires sudo. In addition of the current development version
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
ifneq ($(PYTHON3), true)
	REPLACEMENTS = -e 's/@@VERSION@@/$(EXTVERSION)/g' -e 's/plpython3u/plpythonu/g'
endif

$(DATA): $(SOURCES_DATA)
	$(SED) $(REPLACEMENTS) $(SOURCES_DATA_DIR)/*.sql > $@
ifneq ($(PG_PARALLEL), true)
	$(eval TMPFILE := $(shell mktemp /tmp/$@.XXXXXXXXXX))
	$(SED) -e 's/PARALLEL \= [A-Z]*,/''/g' -e 's/PARALLEL [A-Z]*/''/g' $@ > $(TMPFILE);
	mv $(TMPFILE) $@
endif
ifneq ($(PYTHON3), true)
	$(eval TMPFILE := $(shell mktemp /tmp/$@.XXXXXXXXXX))
	$(SED) -e 's/plpython3u/plpythonu/g' $$n > $(TMPFILE);
	mv $(TMPFILE) $@
endif

TEST_DIR = test
REGRESS = $(sort $(notdir $(basename $(wildcard $(TEST_DIR)/sql/*test.sql))))
REGRESS_OPTS = --inputdir='$(TEST_DIR)' --outputdir='$(TEST_DIR)'

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# This seems to be needed at least for PG 9.3.11
all: $(DATA)

test: export PGUSER=postgres
test: installcheck

# Release tasks
.PHONY ../../release/$(EXTENSION).control: $(EXTENSION).control
	cp $< $@

# Prepare new release from the currently installed development version,
# for the current version X.Y.Z (defined in the control file)
# producing the extension script and control files in releases/
# and the python package in releases/python/X.Y.Z/crankshaft/
release: ../../release/$(EXTENSION).control $(SOURCES_DATA)
	$(SED) $(REPLACEMENTS) $(SOURCES_DATA_DIR)/*.sql > ../../release/$(EXTENSION)--$(EXTVERSION).sql

# If needed remove PARALLEL tags from the release files
release_remove_parallel_deploy:
ifneq ($(PG_PARALLEL), true)
	for n in $(wildcard ../../release/*.sql); do \
		$(eval TMPFILE := $(shell mktemp /tmp/XXXXXXXXXX)) \
		$(SED) -e 's/PARALLEL \= [A-Z]*,/''/g' -e 's/PARALLEL [A-Z]*/''/g' $$n > $(TMPFILE); \
		mv $(TMPFILE) $$n; \
	done
endif

release_adapt_plpython:
ifneq ($(PYTHON3), true)
	for n in $(wildcard ../../release/*.sql); do \
		$(eval TMPFILE := $(shell mktemp /tmp/XXXXXXXXXX)) \
		$(SED) -e 's/plpython3u/plpythonu/g' $$n > $(TMPFILE); \
		mv $(TMPFILE) $$n; \
	done
endif

# Install the current release into the PostgreSQL extensions directory
# We execute these 3 tasks to modify release files in place so they are compatible with
# the PG and python releases available during deployment, and not release
deploy: release_remove_parallel_deploy release_adapt_plpython ../../release/$(EXTENSION).control
	$(INSTALL_DATA) ../../release/$(EXTENSION).control '$(DESTDIR)$(datadir)/extension/'
	$(INSTALL_DATA) ../../release/*.sql '$(DESTDIR)$(datadir)/extension/'

