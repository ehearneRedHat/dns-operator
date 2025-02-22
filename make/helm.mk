##@ Helm Charts

# TODO: If this is found useful, consider adding it to the main Makefile
# Semantic versioning (i.e. Major.Minor.Patch)
is_semantic_version = $(shell [[ $(1) =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.+)?$$ ]] && echo "true")


# OPERATOR_IMG defines the dns-operator image with version tag.
# If the version is not semantic, will use the default one
bundle_is_semantic := $(call is_semantic_version,$(VERSION))
ifeq (0.0.0,$(VERSION))
OPERATOR_IMG = $(IMAGE_TAG_BASE):latest
else ifeq ($(bundle_is_semantic),true)
OPERATOR_IMG = $(IMAGE_TAG_BASE):v$(VERSION)
else
OPERATOR_IMG ?= $(DEFAULT_IMAGE_TAG)
endif

.PHONY: helm-build
helm-build: yq manifests kustomize operator-sdk ## Build the helm chart from kustomize manifests
	# Replace the controller image
	cd config/manager && $(KUSTOMIZE) edit set image controller=$(OPERATOR_IMG)
	# Build the helm chart templates from kustomize manifests
	$(KUSTOMIZE) build config/helm > charts/dns-operator/templates/manifests.yaml
	V="$(VERSION)" $(YQ) eval '.version = strenv(V)' -i charts/dns-operator/Chart.yaml

.PHONY: helm-install
helm-install: $(HELM) ## Install the helm chart
	# Install the helm chart in the cluster
	$(HELM) install dns-operator charts/dns-operator

.PHONY: helm-uninstall
helm-uninstall: $(HELM) ## Uninstall the helm chart
	# Uninstall the helm chart from the cluster
	$(HELM) uninstall dns-operator

.PHONY: helm-upgrade
helm-upgrade: $(HELM) ## Upgrade the helm chart
	# Upgrade the helm chart in the cluster
	$(HELM) upgrade dns-operator charts/dns-operator

.PHONY: helm-package
helm-package: $(HELM) ## Package the helm chart
	# Package the helm chart
	$(HELM) package charts/dns-operator

# GitHub Token with permissions to upload to the release assets
HELM_WORKFLOWS_TOKEN ?= <YOUR-TOKEN>
# GitHub Release Asset Browser Download URL, it can be find in the output of the uploaded asset
BROWSER_DOWNLOAD_URL ?= <BROWSER-DOWNLOAD-URL>
# Github repo name for the helm charts repository
HELM_REPO_NAME ?= helm-charts
ifeq (0.0.0,$(VERSION))
CHART_VERSION = $(VERSION)-dev
else
CHART_VERSION = $(VERSION)
endif

.PHONY: helm-sync-package-created
helm-sync-package-created: ## Sync the helm chart package to the helm-charts repo
	curl -L \
	  -X POST \
	  -H "Accept: application/vnd.github+json" \
	  -H "Authorization: Bearer $(HELM_WORKFLOWS_TOKEN)" \
	  -H "X-GitHub-Api-Version: 2022-11-28" \
	  https://api.github.com/repos/$(ORG)/$(HELM_REPO_NAME)/dispatches \
	  -d '{"event_type":"chart-created","client_payload":{"chart":"$(REPO_NAME)","version":"$(CHART_VERSION)", "browser_download_url": "$(BROWSER_DOWNLOAD_URL)"}}'

.PHONY: helm-sync-package-deleted
helm-sync-package-deleted: ## Sync the deleted helm chart package to the helm-charts repo
	curl -L \
	  -X POST \
	  -H "Accept: application/vnd.github+json" \
	  -H "Authorization: Bearer $(HELM_WORKFLOWS_TOKEN)" \
	  -H "X-GitHub-Api-Version: 2022-11-28" \
	  https://api.github.com/repos/$(ORG)/$(HELM_REPO_NAME)/dispatches \
	  -d '{"event_type":"chart-deleted","client_payload":{"chart":"$(REPO_NAME)","version":"$(CHART_VERSION)"}}'
