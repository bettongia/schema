.DEFAULT_GOAL := default

include site.mk

# BEGIN: Primary tasks

default: clean prepare license_check format analyze test coverage doc_site
.PHONY: default

pre_commit: format_check analyze license_check test
.PHONY: pre_commit

cicd: default
.PHONY: cicd

# END: Primary tasks

format:
	dart format lib/ test/ hook/ tool/
.PHONY: format

format_check:
	dart format --output=none --set-exit-if-changed lib/ test/ hook/ tool/
.PHONY: format_check

analyze:
	dart analyze
.PHONY: analyze

checks: coverage.log license_check
.PHONY: checks

test: test.log
.PHONY: test

test.log: lib/** test/**
	dart test  | tee test.log


license_check:
	cat addlicense_config.txt | xargs addlicense --check

license_add:
	cat addlicense_config.txt | xargs addlicense

coverage: coverage.log
.PHONY: coverage

coverage.log: lib/** test/**
	# flutter test --coverage
	dart test --coverage-path=coverage/lcov.info
	rm -rf site/coverage
	mkdir -p site/coverage
	genhtml coverage/lcov.info --legend -o site/coverage

prepare:
	dart pub global activate coverage
	dart pub get
.PHONY: prepare_dart

clean:
	rm -rf site dist coverage .dart_tool
	rm -f *.log
	dart pub get

.PHONY: clean
