# Generation of a new development version 'dev' (with an alias 'current' for
# updating easily by upgrading to 'current', then 'dev')

# sudo make install -- generate the 'dev' version from current source
#                      and make it available to PostgreSQL
# PGUSER=postgres make installcheck -- test the 'dev' extension

SED = sed

EXTENSION    = crankshaft

DATA         = $(EXTENSION)--dev.sql \
	             $(EXTENSION)--current--dev.sql \
	             $(EXTENSION)--dev--current.sql

SOURCES_DATA_DIR = sql
SOURCES_DATA = $(wildcard $(SOURCES_DATA_DIR)/*.sql)

VIRTUALENV_PATH = $(realpath ../py/environment)
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


# WIP: goals for releasing the extension...

EXTVERSION   = $(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")

RELEASED_PACKAGE = crankshaft_$(subst .,_,$(EXTVERSION))

RELEASE_REPLACEMENTS = -e 's/import\scrankshaft/import $(RELEASED_PACKAGE)/g' \
                       -e 's/from\scrankshaft/from $(RELEASED_PACKAGE)/g'

../../release/$(EXTENSION).control: $(EXTENSION).control
	cp $< $@

release: ../../release/$(EXTENSION).control
	# ALTERNATIVE: use release virtualenv; copy here files from src replacing VIRTUALENV_PATH
	$(SED) $(RELEASE_REPLACEMENTS) $(EXTENSION)--dev.sql > ../../release/$(EXTENSION)--$(EXTVERSION).sql
	cp -r ../py/crankshaft ../../release/$(RELEASED_PACKAGE)
	$(SED) -i -e 's/name='"'"'crankshaft'"'"'/name='"'"'$(RELEASED_PACKAGE)'"'"'/g'  ../../release/$(RELEASED_PACKAGE)/setup.py

install_release:
	$(INSTALL_DATA) ../../release/$(EXTENSION).control '$(DESTDIR)$(datadir)/extension/'
	$(INSTALL_DATA) ../../release/*.sql '$(DESTDIR)$(datadir)/extension/'
	# virtualenv --system-site-packages ../py/dev
	../py/environment/bin/pip install -I -U ../../release/$(RELEASED_PACKAGE)
	../py/environment/bin/pip install -I nose

test: export PGUSER=postgres
test: installcheck
