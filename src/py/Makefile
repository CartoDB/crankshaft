include ../../Makefile.global

# Install the package locally for development
install:
	echo "pip install ./crankshaft"

# Test develpment install
test:
	nosetests crankshaft/test/

release: ../../release/$(EXTENSION).control $(SOURCES_DATA)
	mkdir -p ../../release/python/$(EXTVERSION)
	cp -r ./$(PACKAGE) ../../release/python/$(EXTVERSION)/
	$(SED) -i -r 's/version='"'"'[0-9]+\.[0-9]+\.[0-9]+'"'"'/version='"'"'$(EXTVERSION)'"'"'/g'  ../../release/python/$(EXTVERSION)/$(PACKAGE)/setup.py

deploy: 
	pip install $(RUN_OPTIONS) --upgrade ../../release/python/$(RELEASE_VERSION)/$(PACKAGE)
