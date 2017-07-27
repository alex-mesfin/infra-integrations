PACKAGE_TYPES     ?= deb rpm
PROJECT_NAME       = newrelic-infra-integrations
BINS_PREFIX        = nr
BINS_DIR           = $(TARGET_DIR)/bin/linux_amd64
SOURCE_DIR         = $(TARGET_DIR)/source
PACKAGE_DIR        = $(TARGET_DIR)/package
DEB_FILENAME      := $(PROJECT_NAME)_$(VERSION)_amd64.deb
RPM_FILENAME      := $(PROJECT_NAME)-$(subst -,_,$(VERSION))-1.x86_64.rpm
LICENSE            = "https://newrelic.com/terms (also see LICENSE.txt installed with this package)"
VENDOR             = "New Relic, Inc."
PACKAGER           = "New Relic Infrastructure Team <infrastructure-eng@newrelic.com>"
PACKAGE_URL        = "https://www.newrelic.com/infrastructure"
SUMMARY            = "New Relic Infrastructure Integrations"
DESCRIPTION        = "New Relic Infrastructure Integrations extend the core New Relic\nInfrastructure agent's capabilities to allow you to collect metric and\nlive state data from your infrastructure components such as MySQL,\nNGINX and Cassandra."
FPM_COMMON_OPTIONS = --verbose -C $(SOURCE_DIR) -s dir -n $(PROJECT_NAME) -v $(VERSION) --prefix "" --iteration 1 --license $(LICENSE) --vendor $(VENDOR) -m $(PACKAGER) --url $(PACKAGE_URL) --config-files /etc/newrelic-infra/ --description "$$(printf $(DESCRIPTION))" --depends "nrjmx" --depends "newrelic-infra >= 1.0.726"
FPM_DEB_OPTIONS    = -t deb -p $(PACKAGE_DIR)/deb/$(DEB_FILENAME)
FPM_RPM_OPTIONS    = -t rpm -p $(PACKAGE_DIR)/rpm/$(RPM_FILENAME) --epoch 0 --rpm-summary $(SUMMARY)

package: create-bins prep-pkg-env $(PACKAGE_TYPES)

create-bins:
	@for I in $(INTS); do \
		if [ $$I != "example" ]; then \
			PACKAGE=$$(go list ./integrations/$$I/... 2>&1) ;\
			if echo $$PACKAGE | grep -Eq ".*matched\ no\ packages$$"; then \
				echo "=== Main === [ create-bins ]: no Go files found for $$I. Skipping." ;\
			else \
				echo "=== Main === [ create-bins ]: creating binary for $$I..." ;\
				go build -v -ldflags '-X main.buildVersion=$(VERSION)' -o $(BINS_DIR)/$(BINS_PREFIX)-$$I $$PACKAGE || exit 1 ;\
			fi ;\
		fi ;\
	done
	@echo ""

prep-pkg-env:
	@if [ ! -d $(BINS_DIR) ]; then \
		echo "=== Main === [ prep-pkg-env ]: no built binaries found. Run 'make create-bins'" ;\
		exit 1 ;\
	fi
	@echo "=== Main === [ prep-pkg-env ]: preparing a clean packaging environment..."
	@rm -rf $(SOURCE_DIR)
	@mkdir -p $(SOURCE_DIR)/var/db/newrelic-infra/newrelic-integrations/bin $(SOURCE_DIR)/etc/newrelic-infra/integrations.d
	@echo "=== Main === [ prep-pkg-env ]: adding built binaries and configuration and definition files..."
	@for BIN in $$(ls $(BINS_DIR)); do \
		cp $(BINS_DIR)/$$BIN $(SOURCE_DIR)/var/db/newrelic-infra/newrelic-integrations/bin ;\
		chmod 755 $(SOURCE_DIR)/var/db/newrelic-infra/newrelic-integrations/bin/* ;\
		cp $(INTEGRATIONS_DIR)/$${BIN#$(BINS_PREFIX)-}/*.yml $(SOURCE_DIR)/var/db/newrelic-infra/newrelic-integrations/ ;\
		chmod 644 $(SOURCE_DIR)/var/db/newrelic-infra/newrelic-integrations/*.yml ;\
		cp $(INTEGRATIONS_DIR)/$${BIN#$(BINS_PREFIX)-}/*.sample $(SOURCE_DIR)/etc/newrelic-infra/integrations.d/ ;\
		chmod 644 $(SOURCE_DIR)/etc/newrelic-infra/integrations.d/*.sample ;\
	done
	@echo ""

deb: prep-pkg-env
	@echo "=== Main === [ deb ]: building DEB package..."
	@mkdir -p $(PACKAGE_DIR)/deb
	@fpm $(FPM_COMMON_OPTIONS) $(FPM_DEB_OPTIONS) .

rpm: prep-pkg-env
	@echo "=== Main === [ rpm ]: building RPM package..."
	@mkdir -p $(PACKAGE_DIR)/rpm
	@fpm $(FPM_COMMON_OPTIONS) $(FPM_RPM_OPTIONS) .

.PHONY: package create-bins prep-pkg-env deb rpm
