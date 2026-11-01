OUT_DIR ?= out
.PHONY: all build verify test check-docs check-site
all: check-ci check-docs build verify test check-site
build:
	python3 scripts/build-schoolbell.py --out $(OUT_DIR)
verify:
	python3 scripts/verify-schoolbell.py $(OUT_DIR)
test:
	sh scripts/test-schoolbell.sh
	sh scripts/test-ui.sh
check-docs:
	python3 scripts/check-foundation.py

check-site:
	python3 scripts/build-site.py
	python3 scripts/test-site.py
	node scripts/test-site-demo.js
	node scripts/test-demo-storage.js
	node scripts/test-site-portable.js

.PHONY: check-ci test-runtime test-web
check-ci:
	python3 scripts/test-ci.py
test-runtime:
	sh scripts/test-schoolbell.sh
test-web:
	sh scripts/test-ui.sh
