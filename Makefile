MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:
.SECONDARY:

RUN = uv run
# get values from about.yaml file
SCHEMA_NAME = $(shell ./utils/get-value.sh name)
SOURCE_SCHEMA_PATH = $(shell ./utils/get-value.sh source_schema_path)
SOURCE_SCHEMA_DIR = $(dir $(SOURCE_SCHEMA_PATH))
SRC = src
DEST = project
PYMODEL = $(SRC)/$(SCHEMA_NAME)/datamodel
DOCDIR = docs
EXAMPLEDIR = examples
SHEET_MODULE = personinfo_enums
SHEET_ID = $(shell ./utils/get-value.sh google_sheet_id)
SHEET_TABS = $(shell ./utils/get-value.sh google_sheet_tabs)
SHEET_MODULE_PATH = $(SOURCE_SCHEMA_DIR)/$(SHEET_MODULE).yaml

# basename of a YAML file in model/
.PHONY: all clean

# note: "help" MUST be the first target in the file,
# when the user types "make" they should get help info
help: status
	@echo ""
	@echo "make setup -- initial setup (run this first)"
	@echo "make site -- makes site locally"
	@echo "make install -- install dependencies"
	@echo "make test -- runs tests"
	@echo "make lint -- perfom linting"
	@echo "make testdoc -- builds docs and runs local test server"
	@echo "make deploy -- deploys site"
	@echo "make update -- updates linkml version"
	@echo "make help -- show this help"
	@echo ""

status: check-config
	@echo "Project: $(SCHEMA_NAME)"
	@echo "Source: $(SOURCE_SCHEMA_PATH)"

# generate products and add everything to github
setup: install gen-project gen-examples gendoc git-init-add

# install any dependencies required for building
.PHONY: install
install:
	uv venv --allow-existing
	uv pip install -e .[dev]

# ---
# Project Syncronization
# ---
#
# check we are up to date
check: cruft-check
cruft-check:
	cruft check
cruft-diff:
	cruft diff

update: update-template update-linkml
update-template:
	cruft update

# todo: consider pinning to template
update-linkml:
	uv add -D linkml@latest

# EXPERIMENTAL
create-data-harmonizer:
	npm init data-harmonizer $(SOURCE_SCHEMA_PATH)

all: site
site: gen-project gendoc
%.yaml: gen-project
deploy: all mkd-gh-deploy

compile-sheets:
	$(RUN) sheets2linkml --gsheet-id $(SHEET_ID) $(SHEET_TABS) > $(SHEET_MODULE_PATH).tmp && mv $(SHEET_MODULE_PATH).tmp $(SHEET_MODULE_PATH)

# In future this will be done by conversion
gen-examples:
	cp src/data/examples/* $(EXAMPLEDIR)

# generates all project files

gen-project: $(PYMODEL)
	$(RUN) gen-project -d $(DEST) $(SOURCE_SCHEMA_PATH) && mv $(DEST)/*.py $(PYMODEL)


test: test-schema test-python
test-schema:
	$(RUN) gen-project -d tmp $(SOURCE_SCHEMA_PATH) 

test-python:
	$(RUN) python -m unittest discover

lint:
	$(RUN) linkml-lint $(SOURCE_SCHEMA_PATH) 

check-config:
	@(grep my-datamodel about.yaml > /dev/null && printf "\n**Project not configured**:\n\n  - Remember to edit 'about.yaml'\n\n" || exit 0)

convert-examples-to-%:
	$(patsubst %, $(RUN) linkml-convert  % -s $(SOURCE_SCHEMA_PATH) -C Person, $(shell find src/data/examples -name "*.yaml")) 

examples/%.yaml: src/data/examples/%.yaml
	$(RUN) linkml-convert -s $(SOURCE_SCHEMA_PATH) -C Person $< -o $@
examples/%.json: src/data/examples/%.yaml
	$(RUN) linkml-convert -s $(SOURCE_SCHEMA_PATH) -C Person $< -o $@
examples/%.ttl: src/data/examples/%.yaml
	$(RUN) linkml-convert -P EXAMPLE=http://example.org/ -s $(SOURCE_SCHEMA_PATH) -C Person $< -o $@

# Test documentation locally
serve: mkd-serve

# Python datamodel
$(PYMODEL):
	mkdir -p $@


$(DOCDIR):
	mkdir -p $@

gendoc: $(DOCDIR)
	cp $(SRC)/docs/*.md $(DOCDIR)
	$(RUN) gen-doc -d $(DOCDIR) $(SOURCE_SCHEMA_PATH)

testdoc: gendoc serve

MKDOCS = $(RUN) mkdocs
mkd-%:
	$(MKDOCS) $*

PROJECT_FOLDERS = sqlschema shex shacl protobuf prefixmap owl jsonschema jsonld graphql excel
git-init-add: git-init git-add git-commit git-status
git-init:
	git init
git-add: .cruft.json
	git add .gitignore .github .cruft.json Makefile LICENSE *.md examples utils about.yaml mkdocs.yml uv.lock project.Makefile pyproject.toml src/monarch_documentation/schema/*yaml src/*/datamodel/*py src/data src/docs tests
	git add $(patsubst %, project/%, $(PROJECT_FOLDERS))
git-commit:
	git commit -m 'Initial commit' -a
git-status:
	git status

# only necessary if setting up via cookiecutter
.cruft.json:
	echo "creating a stub for .cruft.json. IMPORTANT: setup via cruft not cookiecutter recommended!" ; \
	touch $@

clean:
	rm -rf $(DEST)
	rm -rf tmp

include project.Makefile
