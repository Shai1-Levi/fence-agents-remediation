# Build the manager binary
FROM quay.io/centos/centos:stream9 AS builder
RUN dnf install -y jq git \
    && dnf clean all -y

WORKDIR /workspace
# Copy the Go Modules manifests for detecting Go version
COPY go.mod go.mod
COPY go.sum go.sum

RUN \
    # Get Go version from mod file
    export GO_VERSION=$(grep -oE "go [[:digit:]]\.[[:digit:]][[:digit:]]" go.mod | awk '{print $2}') && \
    echo ${GO_VERSION} && \
    # Find filename for latest z version from Go download page
    export GO_FILENAME=$(curl -sL 'https://go.dev/dl/?mode=json&include=all' | jq -r "[.[] | select(.version | startswith(\"go${GO_VERSION}\"))][0].files[] | select(.os == \"linux\" and .arch == \"amd64\") | .filename") && \
    echo ${GO_FILENAME} && \
    # Download and unpack
    curl -sL -o go.tar.gz "https://golang.org/dl/${GO_FILENAME}" && \
    tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz

# Add Go directory to PATH
ENV PATH="${PATH}:/usr/local/go/bin"
RUN go version

# Copy the Go source
COPY main.go main.go
COPY api/ api/
COPY controllers/ controllers/
COPY hack/ hack/
COPY pkg/ pkg/
COPY version/ version/
COPY vendor/ vendor/

# for getting version info
COPY .git/ .git/

# Build
RUN ./hack/build.sh

FROM quay.io/centos/centos:stream9

WORKDIR /
COPY --from=builder /workspace/manager .

# Add Fence Agents and fence-agents-aws packages
RUN dnf install -y dnf-plugins-core \
    && dnf --enablerepo=highavailability install -y fence-agents-amt-ws fence-agents-apc-snmp fence-agents-cisco-mds fence-agents-cisco-ucs fence-agents-compute \
    fence-agents-eaton-snmp fence-agents-emerson fence-agents-eps fence-agents-heuristics-ping fence-agents-ibmblade fence-agents-ifmib fence-agents-ilo2 \
    fence-agents-intelmodular fence-agents-ipdu fence-agents-ipmilan fence-agents-kdump fence-agents-mpath fence-agents-redfish fence-agents-rhevm fence-agents-sbd \
    fence-agents-scsi fence-agents-vmware-rest fence-agents-vmware-soap \
    fence-agents-aws fence-agents-azure-arm fence-agents-gce \
    && dnf clean all -y

USER 65532:65532
ENTRYPOINT ["/manager"]
