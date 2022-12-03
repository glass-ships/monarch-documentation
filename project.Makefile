## Add your own custom Makefile targets here

.INCLUDE : Makefile

genpython:
	$(RUN) gen-python $(SOURCE_SCHEMA_PATH) > $(PYMODEL)/monarch_technical_documentation.py

genindex:
	$(RUN) python scripts/generate_index.py

genrepodocs:
	$(RUN) python scripts/generate_repo_pages.py

genschemadoc: $(DOCDIR)
	$(RUN) gen-doc -d $(DOCDIR)/Documentation-Schema $(SOURCE_SCHEMA_PATH)

build-docs: genpython genschemadoc genindex genrepodocs gen-monarch-overview
	#@rm -f $(DOCDIR)/Documentation-Schema/about.md
	cp src/docs/registry.md docs/registry.md
	cp src/docs/about.md docs/about.md

############################################
### Provisional Monarch Asset Registry #####
############################################

src/docs/registry.md: src/monarch_technical_documentation/resources/monarch_resources.md.jinja2 src/data/resources.yaml
	$(RUN) j2 $^ > $@

src/docs/registry_2.md: $(SOURCE_SCHEMA_PATH) src/data/resources.yaml
	$(RUN) linkml-convert -f yaml -C ResourceRegistry -t ttl -s $^

validate-registry: $(SOURCE_SCHEMA_PATH) src/data/resources.yaml
	$(RUN) linkml-validate --target-class ResourceRegistry -s $^

gen-monarch-overview:
	$(MAKE) src/docs/registry.md
