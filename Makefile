EXT_DIR = src/pg
PYP_DIR = src/py

.PHONY: install
.PHONY: run_tests
.PHONY: release
.PHONY: deploy


# Generate and install developmet versions of the extension
# and python package.
# The extension is named 'dev' with a 'current' alias for easily upgrading.
# The Python package is installed in a virtual environment envs/dev/
# Requires sudo.
install:
	$(MAKE) -C $(PYP_DIR) install
	$(MAKE) -C $(EXT_DIR) install

# Run the tests for the installed development extension and
# python package
test:
	$(MAKE) -C $(PYP_DIR) test
	$(MAKE) -C $(EXT_DIR) test

# Generate a new release into release
release:
	$(MAKE) -C $(EXT_DIR) release

# Install the current release.
# The Python package is installed in a virtual environment envs/X.Y.Z/
# Requires sudo.
deploy:
	$(MAKE) -C $(EXT_DIR) deploy
