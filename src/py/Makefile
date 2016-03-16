include ../../Makefile.global

# Install the package locally for development
install:
	virtualenv --system-site-packages ../../envs/dev
	# source ../../envs/dev/bin/activate
	../../envs/dev/bin/pip install -I ./crankshaft
	../../envs/dev/bin/pip install -I nose

# Test develpment install
test:
	../../envs/dev/bin/nosetests crankshaft/test/

release: ../../release/$(EXTENSION).control $(SOURCES_DATA)
	mkdir -p ../../release/python/$(EXTVERSION)
	cp -r ./$(PACKAGE) ../../release/python/$(EXTVERSION)/
	$(SED) -i -r 's/version='"'"'[0-9]+\.[0-9]+\.[0-9]+'"'"'/version='"'"'$(EXTVERSION)'"'"'/g'  ../../release/python/$(EXTVERSION)/$(PACKAGE)/setup.py

deploy:
	virtualenv --system-site-packages $(VIRTUALENV_PATH)/$(RELEASE_VERSION)
	$(VIRTUALENV_PATH)/$(RELEASE_VERSION)/bin/pip install -I -U ../../release/python/$(RELEASE_VERSION)/$(PACKAGE)
	$(VIRTUALENV_PATH)/$(RELEASE_VERSION)/bin/pip install -I nose
