# Install the package locally for development
install:
	virtualenv --system-site-packages dev
	./dev/bin/pip install -I ./crankshaft
	./dev/bin/pip install -I nose

# Test develpment install
testinstalled:
	./dev/bin/nosetests crankshaft/test/
