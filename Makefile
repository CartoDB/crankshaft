EXT_DIR = src/pg
PYP_DIR = src/py

.PHONY: install
.PHONY: run_tests

install:
	$(MAKE) -C $(PYP_DIR) install
	$(MAKE) -C $(EXT_DIR) install

testinstalled:
	$(MAKE) -C $(PYP_DIR) testinstalled
	$(MAKE) -C $(EXT_DIR) installcheck
