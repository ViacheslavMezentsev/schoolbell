OUT_DIR ?= out
.PHONY: all build verify test check-docs
all: check-docs build verify test
build:
	python3 scripts/build-schoolbell.py --out $(OUT_DIR)
verify:
	python3 scripts/verify-schoolbell.py $(OUT_DIR)
test:
	sh scripts/test-schoolbell.sh
	sh scripts/test-ui.sh
check-docs:
	python3 scripts/check-foundation.py
