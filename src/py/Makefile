# Install the package locally for development
install:
	virtualenv --system-site-packages ../../envs/dev
	# source ../../envs/dev/bin/activate
	../../envs/dev/bin/pip install -I ./crankshaft
	../../envs/dev/bin/pip install -I nose

# Test develpment install
test:
	../../envs/dev/bin/nosetests crankshaft/test/
