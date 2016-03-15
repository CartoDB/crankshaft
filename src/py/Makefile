# Install the package locally for development
install:
	virtualenv --system-site-packages environment
	./environment/bin/pip install -I -U ./crankshaft
	./environment/bin/pip install -I nose

# Test develpment install
test:
	./environment/bin/nosetests crankshaft/test/
