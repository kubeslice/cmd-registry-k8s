FROM golang:1.18.2-buster as go
ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOBIN=/bin
RUN go install github.com/go-delve/delve/cmd/dlv@v1.8.2
ADD https://github.com/spiffe/spire/releases/download/v1.2.2/spire-1.2.2-linux-x86_64-glibc.tar.gz .
RUN tar xzvf spire-1.2.2-linux-x86_64-glibc.tar.gz -C /bin --strip=2 spire-1.2.2/bin/spire-server spire-1.2.2/bin/spire-agent

FROM go as build
WORKDIR /build
COPY go.mod go.sum ./
#COPY ./pkg/internal/imports ./pkg/internal/imports
#RUN go build ./pkg/internal/imports
ADD vendor vendor
COPY . .
RUN go env -w GOPRIVATE=github.com/kubeslice && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -mod=vendor -a -o /bin/cmd-registry-k8s .

FROM build as test
CMD go test -test.v ./...

FROM test as debug
CMD dlv -l :40000 --headless=true --api-version=2 test -test.v ./...

FROM alpine:3.16.2 as runtime
COPY --from=build /bin/cmd-registry-k8s /bin/cmd-registry-k8s
ENTRYPOINT ["/bin/cmd-registry-k8s"]
