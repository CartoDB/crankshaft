include ../../Makefile.global

# Install the package locally for development
install:
	$(PIP) install --upgrade ./crankshaft

# Test develpment install
test:
	$(NOSETESTS) crankshaft/test/

release: ../../release/$(EXTENSION).control $(SOURCES_DATA)
	mkdir -p ../../release/python/$(EXTVERSION)
	cp -r ./$(PACKAGE) ../../release/python/$(EXTVERSION)/
	$(SED) -i -r 's/version='"'"'[0-9]+\.[0-9]+\.[0-9]+'"'"'/version='"'"'$(EXTVERSION)'"'"'/g'  ../../release/python/$(EXTVERSION)/$(PACKAGE)/setup.py

deploy: 
	$(PIP) install $(RUN_OPTIONS) --upgrade ../../release/python/$(RELEASE_VERSION)/$(PACKAGE)
