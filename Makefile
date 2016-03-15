EXT_DIR = src/pg
PYP_DIR = src/py

.PHONY: install
.PHONY: run_tests

install:
	$(MAKE) -C $(PYP_DIR) install
	$(MAKE) -C $(EXT_DIR) install

test:
	$(MAKE) -C $(PYP_DIR) test
	$(MAKE) -C $(EXT_DIR) test

release: install
	$(MAKE) -C $(EXT_DIR) release

deploy:
	 echo 'not yet implemented'
