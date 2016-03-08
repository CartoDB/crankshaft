# Install the package locally for development
install:
	virtualenv dev
	./dev/bin/pip install ./crankshaft --upgrade
	./dev/bin/pip install nose

# Test develpment install
testinstalled:
	./dev/bin/nosetests crankshaft/test/
