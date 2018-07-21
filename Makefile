VERSION := $(shell git describe --tags | sed -e 's/^v//g' | awk -F "-" '{print $$1}')
ITERATION := $(shell git describe --tags --long | awk -F "-" '{print $$2}')
GO_VERSION=$(shell gobuild -v)
GO := $(or $(GOROOT),/usr/lib/go)/bin/go
PROCS := $(shell nproc)
cores:
	@echo "cores: $(PROCS)"
test:
	go test -v
bench:
	go test -bench .
bench-record:
	$(GO) test -bench . > "benchmarks/stun-go-$(GO_VERSION).txt"
fuzz-prepare-msg:
	go-fuzz-build -func FuzzMessage -o stun-msg-fuzz.zip github.com/gortc/stun
fuzz-prepare-typ:
	go-fuzz-build -func FuzzType -o stun-typ-fuzz.zip github.com/gortc/stun
fuzz-prepare-setters:
	go-fuzz-build -func FuzzSetters -o stun-setters-fuzz.zip github.com/gortc/stun
fuzz-msg:
	go-fuzz -bin=./stun-msg-fuzz.zip -workdir=examples/stun-msg
fuzz-typ:
	go-fuzz -bin=./stun-typ-fuzz.zip -workdir=examples/stun-typ
fuzz-setters:
	go-fuzz -bin=./stun-setters-fuzz.zip -workdir=examples/stun-setters
fuzz-test:
	go test -tags gofuzz -run TestFuzz -v .
fuzz-reset-setters:
	rm -f -v -r stun-setters-fuzz.zip examples/stun-setters
lint:
	@echo "linting on $(PROCS) cores"
	@gometalinter \
		--enable-all \
		-e "_test.go.+(gocyclo|errcheck|dupl)" \
		-e "attributes\.go.+credentials,.+,LOW.+\(gas\)" \
                -e "Message.+\(aligncheck\)" \
		-e "arg .+ for .+ verb %. of wrong type" \
		-e "error return value not checked \(fmt.Fprint\(h, k\)\) " \
		-e " parameter result 0 \(int\) is never used " \
		--enable="lll" --line-length=100 \
		--enable="gofmt" \
		--enable="goimports" \
		--enable="misspell" \
		--enable="unused" \
		--disable="gochecknoglobals" \
		--deadline=300s \
		-j $(PROCS)
	@echo "ok"
escape:
	@echo "Not escapes, except autogenerated:"
	@go build -gcflags '-m -l' 2>&1 \
	| grep -v "<autogenerated>" \
	| grep escapes
format:
	goimports -w .
bench-compare:
	go test -bench . > bench.go-16
	go-tip test -bench . > bench.go-tip
	@benchcmp bench.go-16 bench.go-tip
install:
	go get -u sourcegraph.com/sqs/goreturns
	go get -u github.com/alecthomas/gometalinter
	gometalinter --install --update
	go get -u github.com/dvyukov/go-fuzz/go-fuzz-build
	go get github.com/dvyukov/go-fuzz/go-fuzz
docker-build:
	docker build -t gortc/stun .
test-integration:
	cd integration-test && bash ./test.sh
prepush: test lint test-integration
