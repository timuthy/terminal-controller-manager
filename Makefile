
# Image URL to use all building/pushing image targets
IMG ?= controller:latest
# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true"

all: manager

# Run tests
test: generate fmt vet manifests
	go test ./api/... ./controllers/... -coverprofile cover.out

# Build manager binary
manager: generate fmt vet
	go build -o bin/manager main.go

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet
	go run ./main.go

# Install CRDs into a cluster
install: manifests
	kubectl apply -f config/crd/bases

# Install resources into a dev cluster
bootstrap-dev: install
	kubectl apply -f config/samples/bootstrap/01_namespaces.yaml
	kubectl apply -f config/samples/bootstrap/02_rbac.yaml

# Multi-cluster use case: Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy-rt: manifests
	kustomize build config/overlay/multi-cluster/runtime | kubectl apply -f -

# Multi-cluster use case: Deploy crd, admission configurations etc. in the configured Kubernetes cluster
deploy-virtual: manifests
	kustomize build config/overlay/multi-cluster/virtual-garden | kubectl apply -f -

# Single-cluster use case: Deploy crd, admission configurations, controller etc. in the configured Kubernetes cluster
deploy-singlecluster: manifests
	kustomize build config/overlay/single-cluster | kubectl apply -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests: controller-gen
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

# Run go fmt against code
fmt:
	go fmt ./...

# Run go vet against code
vet:
	go vet ./...

# Generate code
generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile=./hack/boilerplate.go.txt paths=./api/...

# Build the docker image
docker-build: test
	docker build . -t ${IMG}
	@echo "updating kustomize image patch file for manager resource"
	sed -i'' -e 's@image: .*@image: '"${IMG}"'@' ./config/default/manager_image_patch.yaml

# Push the docker image
docker-push:
	docker push ${IMG}

# find or download controller-gen
# download controller-gen if necessary
controller-gen:
ifeq (, $(shell which controller-gen))
	go get sigs.k8s.io/controller-tools/cmd/controller-gen@v0.2.0-beta.2
CONTROLLER_GEN=$(shell go env GOPATH)/bin/controller-gen
else
CONTROLLER_GEN=$(shell which controller-gen)
endif