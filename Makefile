.DEFAULT_GOAL := default

# BEGIN: Primary tasks

default: clean prepare license_check format analyze test coverage site
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
	# flutter analyze
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
	genhtml coverage/lcov.info -o site/coverage

# BEGIN: Documentation site tasks
site/:
	mkdir -p site

site: styles site/index.html site/spec.html site/roadmap.html site/api/index.html coverage | site/
.PHONY: site

styles: site/styles/styles.css
.PHONY: styles

site/index.html:  docs/index.md docs/.pandoc docs/template/header.html | site/
	pandoc --defaults="docs/.pandoc" docs/index.md README.md -o "site/index.html";

site/spec.html:  docs/spec/*.md docs/template/header.html | site/
	pandoc --defaults="docs/spec/.pandoc" --mathml docs/spec/*.md -o "site/spec.html";

site/roadmap.html: docs/roadmap/*.md docs/.pandoc docs/template/header.html | site/
	pandoc --defaults="docs/.pandoc" docs/roadmap/v*.md -o "site/roadmap.html";

site/styles/styles.css: docs/styles/styles.css | site/
	mkdir -p site/styles/
	cp docs/styles/styles.css site/styles/styles.css

site/api/index.html:
	dart doc -o site/api/index.html

# END: Documentation site tasks

prepare:
	dart pub global activate coverage
	dart pub get
.PHONY: prepare_dart

clean:
	rm -rf site dist coverage .dart_tool
	rm -f *.log
	dart pub get

.PHONY: clean
