.DEFAULT_GOAL := default

SOURCE_FILES=lib/**/*.dart
TEST_FILES=test/**/*.dart

DOC_DIR=doc
COVERAGE_DIR=coverage
ADDLICENSE_CONFIG=addlicense_config.txt

# BEGIN: Primary tasks
default: prepare license_check format analyze test coverage doc
.PHONY: all

pre_commit: prepare format_check analyze license_check test
.PHONY: pre_commit

cicd: prepare format_check analyze license_check test
.PHONY: cicd

# END: Primary tasks

test:
	dart test
.PHONY: test

format:
	dart format lib/ test/ example/
.PHONY: format

## Check formatting without modifying files. Fails if any file is unformatted —
## used by the pre-commit hook so the commit is blocked (rather than silently
## reformatting already-staged files). Mirrors `format`'s scope exactly.
format_check:
	dart format --output=none --set-exit-if-changed lib test
.PHONY: format_check

analyze:
	dart analyze
.PHONY: analyze

coverage:
	dart run coverage:test_with_coverage --out $(COVERAGE_DIR)
	genhtml $(COVERAGE_DIR)/lcov.info -o $(COVERAGE_DIR)/html
.PHONY: coverage

license_check:
	@echo "Checking for license headers..."
	cat $(ADDLICENSE_CONFIG) | xargs addlicense --check

license_add:
	cat $(ADDLICENSE_CONFIG) | xargs addlicense

doc:
	dart doc --output=$(DOC_DIR) --validate-links .
.PHONY: doc

prepare:
	dart pub get

clean:
	rm -rf $(DOC_DIR)
	rm -rf $(COVERAGE_DIR)
.PHONY: clean
