# Copyright 2017 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.
FROM debian:jessie
LABEL maintainer "golang-dev@googlegroups.com"

ENV GOPATH /go
ENV PATH /usr/local/go/bin:$GOPATH/bin:$PATH
ENV GOROOT_BOOTSTRAP /usr/local/gobootstrap
ENV GO_VERSION 1.10
ENV DEPS 'ca-certificates'
ENV BUILD_DEPS 'curl bzip2 git gcc patch libc6-dev'

# Fake time
COPY enable-fake-time.patch /usr/local/playground/
# Fake file system
COPY fake_fs.lst /usr/local/playground/

RUN set -x && \
    apt-get update && apt-get install -y ${BUILD_DEPS} ${DEPS} --no-install-recommends && rm -rf /var/lib/apt/lists/*

RUN curl -s https://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/49.0.2623.87/naclsdk_linux.tar.bz2 | tar -xj -C /usr/local/bin --strip-components=2 pepper_49/tools/sel_ldr_x86_64

# Get the Go binary.
RUN curl -sSL https://dl.google.com/go/go$GO_VERSION.linux-amd64.tar.gz -o /tmp/go.tar.gz && \
    curl -sSL https://dl.google.com/go/go$GO_VERSION.linux-amd64.tar.gz.sha256 -o /tmp/go.tar.gz.sha256 && \
    echo "$(cat /tmp/go.tar.gz.sha256) /tmp/go.tar.gz" | sha256sum -c - && \
    tar -C /usr/local/ -vxzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz /tmp/go.tar.gz.sha256 && \
    # Make a copy for GOROOT_BOOTSTRAP, because we rebuild the toolchain and make.bash removes bin/go as its first step.
    cp -R /usr/local/go $GOROOT_BOOTSTRAP && \
    # Apply the fake time and fake filesystem patches.
    patch /usr/local/go/src/runtime/rt0_nacl_amd64p32.s /usr/local/playground/enable-fake-time.patch && \
    cd /usr/local/go && go run misc/nacl/mkzip.go -p syscall /usr/local/playground/fake_fs.lst src/syscall/fstest_nacl.go && \
    # Re-build the Go toolchain.
    cd /usr/local/go/src && GOOS=nacl GOARCH=amd64p32 ./make.bash --no-clean && \
    # Clean up.
    rm -rf $GOROOT_BOOTSTRAP

# Add and compile tour packages
RUN GOOS=nacl GOARCH=amd64p32 go get \
    golang.org/x/tour/pic \
    golang.org/x/tour/reader \
    golang.org/x/tour/tree \
    golang.org/x/tour/wc \
    golang.org/x/talks/2016/applicative/google && \
    rm -rf $GOPATH/src/golang.org/x/tour/.git && \
    rm -rf $GOPATH/src/golang.org/x/talks/.git

# Add tour packages under their old import paths (so old snippets still work)
RUN mkdir -p $GOPATH/src/code.google.com/p/go-tour && \
    cp -R $GOPATH/src/golang.org/x/tour/* $GOPATH/src/code.google.com/p/go-tour/ && \
    sed -i 's_// import_// public import_' $(find $GOPATH/src/code.google.com/p/go-tour/ -name *.go) && \
    go install \
    code.google.com/p/go-tour/pic \
    code.google.com/p/go-tour/reader \
    code.google.com/p/go-tour/tree \
    code.google.com/p/go-tour/wc

# BEGIN deps (run `make update-deps` to update)

# Repo cloud.google.com/go at a083a92 (2018-03-16)
ENV REV=a083a92838d54ab12461596770ce37d9e18972e4
RUN go get -d cloud.google.com/go/compute/metadata `#and 7 other pkgs` &&\
    (cd /go/src/cloud.google.com/go && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo github.com/blaskovicz/go-swarmed at fe5b653 (2018-04-08)
ENV REV=fe5b653281f364aeb279513cc3daffd56972d755
RUN go get -d github.com/blaskovicz/go-swarmed &&\
    (cd /go/src/github.com/blaskovicz/go-swarmed && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo github.com/bradfitz/gomemcache at 1952afa (2017-02-08)
ENV REV=1952afaa557dc08e8e0d89eafab110fb501c1a2b
RUN go get -d github.com/bradfitz/gomemcache/memcache &&\
    (cd /go/src/github.com/bradfitz/gomemcache && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo github.com/go-redis/redis at fdafb11 (2017-09-11)
ENV REV=fdafb11e5fa5d52d965e12073c8a58468c98ebe2
RUN go get -d github.com/go-redis/redis `#and 6 other pkgs` &&\
    (cd /go/src/github.com/go-redis/redis && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo github.com/golang/protobuf at bbd03ef (2018-02-02)
ENV REV=bbd03ef6da3a115852eaf24c8a1c46aeb39aa175
RUN go get -d github.com/golang/protobuf/proto `#and 8 other pkgs` &&\
    (cd /go/src/github.com/golang/protobuf && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo github.com/googleapis/gax-go at 317e000 (2017-09-15)
ENV REV=317e0006254c44a0ac427cc52a0e083ff0b9622f
RUN go get -d github.com/googleapis/gax-go &&\
    (cd /go/src/github.com/googleapis/gax-go && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo go.opencensus.io at 2869e62 (2018-03-18)
ENV REV=2869e622b5122aa78b20e7f3d62ffd1f6545ea3d
RUN go get -d go.opencensus.io/internal `#and 9 other pkgs` &&\
    (cd /go/src/go.opencensus.io && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo golang.org/x/net at 0744d00 (2017-09-22)
ENV REV=0744d001aa8470aaa53df28d32e5ceeb8af9bd70
RUN go get -d golang.org/x/net/context `#and 8 other pkgs` &&\
    (cd /go/src/golang.org/x/net && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo golang.org/x/oauth2 at fdc9e63 (2018-03-14)
ENV REV=fdc9e635145ae97e6c2cb777c48305600cf515cb
RUN go get -d golang.org/x/oauth2 `#and 5 other pkgs` &&\
    (cd /go/src/golang.org/x/oauth2 && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo golang.org/x/text at 1cbadb4 (2017-09-15)
ENV REV=1cbadb444a806fd9430d14ad08967ed91da4fa0a
RUN go get -d golang.org/x/text/secure/bidirule `#and 4 other pkgs` &&\
    (cd /go/src/golang.org/x/text && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo golang.org/x/tools at 0444735 (2017-11-30)
ENV REV=04447353bc504b9a5c02eb227b9ecd252e64ea20
RUN go get -d golang.org/x/tools/go/ast/astutil `#and 3 other pkgs` &&\
    (cd /go/src/golang.org/x/tools && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo google.golang.org/api at c24aa0e (2018-03-13)
ENV REV=c24aa0e5ed34558ea50c016e4fb92c5e9aa69f2c
RUN go get -d google.golang.org/api/googleapi `#and 6 other pkgs` &&\
    (cd /go/src/google.golang.org/api && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo google.golang.org/genproto at f8c8703 (2018-03-16)
ENV REV=f8c8703595236ae70fdf8789ecb656ea0bcdcf46
RUN go get -d google.golang.org/genproto/googleapis/api/annotations `#and 5 other pkgs` &&\
    (cd /go/src/google.golang.org/genproto && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Repo google.golang.org/grpc at fa28bef (2018-03-16)
ENV REV=fa28bef9392c6c3e28e75389d8be8a6797561f57
RUN go get -d google.golang.org/grpc `#and 24 other pkgs` &&\
    (cd /go/src/google.golang.org/grpc && (git cat-file -t $REV 2>/dev/null || git fetch -q origin $REV) && git reset --hard $REV)

# Optimization to speed up iterative development, not necessary for correctness:
RUN go install cloud.google.com/go/compute/metadata \
	cloud.google.com/go/datastore \
	cloud.google.com/go/internal \
	cloud.google.com/go/internal/atomiccache \
	cloud.google.com/go/internal/fields \
	cloud.google.com/go/internal/trace \
	cloud.google.com/go/internal/version \
	github.com/blaskovicz/go-swarmed \
	github.com/bradfitz/gomemcache/memcache \
	github.com/go-redis/redis \
	github.com/go-redis/redis/internal \
	github.com/go-redis/redis/internal/consistenthash \
	github.com/go-redis/redis/internal/hashtag \
	github.com/go-redis/redis/internal/pool \
	github.com/go-redis/redis/internal/proto \
	github.com/golang/protobuf/proto \
	github.com/golang/protobuf/protoc-gen-go/descriptor \
	github.com/golang/protobuf/ptypes \
	github.com/golang/protobuf/ptypes/any \
	github.com/golang/protobuf/ptypes/duration \
	github.com/golang/protobuf/ptypes/struct \
	github.com/golang/protobuf/ptypes/timestamp \
	github.com/golang/protobuf/ptypes/wrappers \
	github.com/googleapis/gax-go \
	go.opencensus.io/internal \
	go.opencensus.io/internal/tagencoding \
	go.opencensus.io/plugin/ocgrpc \
	go.opencensus.io/stats \
	go.opencensus.io/stats/internal \
	go.opencensus.io/stats/view \
	go.opencensus.io/tag \
	go.opencensus.io/trace \
	go.opencensus.io/trace/propagation \
	golang.org/x/net/context \
	golang.org/x/net/context/ctxhttp \
	golang.org/x/net/http2 \
	golang.org/x/net/http2/hpack \
	golang.org/x/net/idna \
	golang.org/x/net/internal/timeseries \
	golang.org/x/net/lex/httplex \
	golang.org/x/net/trace \
	golang.org/x/oauth2 \
	golang.org/x/oauth2/google \
	golang.org/x/oauth2/internal \
	golang.org/x/oauth2/jws \
	golang.org/x/oauth2/jwt \
	golang.org/x/text/secure/bidirule \
	golang.org/x/text/transform \
	golang.org/x/text/unicode/bidi \
	golang.org/x/text/unicode/norm \
	golang.org/x/tools/go/ast/astutil \
	golang.org/x/tools/godoc/static \
	golang.org/x/tools/imports \
	google.golang.org/api/googleapi \
	google.golang.org/api/googleapi/internal/uritemplates \
	google.golang.org/api/internal \
	google.golang.org/api/iterator \
	google.golang.org/api/option \
	google.golang.org/api/transport/grpc \
	google.golang.org/genproto/googleapis/api/annotations \
	google.golang.org/genproto/googleapis/datastore/v1 \
	google.golang.org/genproto/googleapis/rpc/code \
	google.golang.org/genproto/googleapis/rpc/status \
	google.golang.org/genproto/googleapis/type/latlng \
	google.golang.org/grpc \
	google.golang.org/grpc/balancer \
	google.golang.org/grpc/balancer/base \
	google.golang.org/grpc/balancer/roundrobin \
	google.golang.org/grpc/codes \
	google.golang.org/grpc/connectivity \
	google.golang.org/grpc/credentials \
	google.golang.org/grpc/credentials/oauth \
	google.golang.org/grpc/encoding \
	google.golang.org/grpc/encoding/proto \
	google.golang.org/grpc/grpclb/grpc_lb_v1/messages \
	google.golang.org/grpc/grpclog \
	google.golang.org/grpc/internal \
	google.golang.org/grpc/keepalive \
	google.golang.org/grpc/metadata \
	google.golang.org/grpc/naming \
	google.golang.org/grpc/peer \
	google.golang.org/grpc/resolver \
	google.golang.org/grpc/resolver/dns \
	google.golang.org/grpc/resolver/passthrough \
	google.golang.org/grpc/stats \
	google.golang.org/grpc/status \
	google.golang.org/grpc/tap \
	google.golang.org/grpc/transport
# END deps

RUN apt-get purge -y --auto-remove ${BUILD_DEPS}

# Add and compile playground daemon
COPY . /go/src/playground/
RUN go install playground

RUN mkdir /app

COPY edit.html /app
COPY static /app/static

WORKDIR /app

# Run tests
RUN /go/bin/playground test

EXPOSE 8080
ENTRYPOINT ["/go/bin/playground"]
