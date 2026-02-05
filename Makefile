.PHONY: all build test clean lint lint-go lint-org lint-shell install help run tangle detangle

BINARY := cprr
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "none")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LDFLAGS := -ldflags "-s -w \
	-X main.Version=$(VERSION) \
	-X main.GitCommit=$(COMMIT) \
	-X main.BuildDate=$(BUILD_DATE)"

GO_FILES := $(shell find . -name '*.go' -type f)
ORG_FILES := $(shell find . -name '*.org' -type f)
SHELL_FILES := $(shell find . -name '*.sh' -type f)

all: lint build test

# Build
build: $(BINARY)

$(BINARY): $(GO_FILES)
	go build $(LDFLAGS) -o $(BINARY) .

build-dev:
	go build -o $(BINARY) .

build-release:
	go build $(LDFLAGS) -o $(BINARY) .

# Cross-compilation
build-all:
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BINARY)-linux-amd64 .
	GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o $(BINARY)-linux-arm64 .
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(BINARY)-darwin-amd64 .
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(BINARY)-darwin-arm64 .
	GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o $(BINARY)-windows-amd64.exe .

# Install
install:
	go install $(LDFLAGS) .

# Run (development)
run: build-dev
	./$(BINARY)

# Test
test:
	go test -v ./...

test-cover:
	go test -cover ./...

test-race:
	go test -race ./...

# Integration test (manual testing flow)
test-integration: build
	@echo "==> Integration test"
	rm -rf .cprr
	./$(BINARY) --version
	./$(BINARY) init --local --examples
	./$(BINARY) list
	./$(BINARY) show 1
	./$(BINARY) next 1
	./$(BINARY) evidence 1 "Test evidence 1"
	./$(BINARY) evidence 1 "Test evidence 2"
	./$(BINARY) next 1
	./$(BINARY) list --status confirmed
	rm -rf .cprr
	@echo "==> Integration test passed"

# Lint
lint: lint-go lint-org lint-shell

lint-go:
	@echo "==> Go: vet"
	go vet ./...
	@echo "==> Go: fmt check"
	@gofmt -l $(GO_FILES) | tee /dev/stderr | (! read)
	@if command -v staticcheck >/dev/null 2>&1; then \
		echo "==> Go: staticcheck"; \
		staticcheck ./...; \
	fi
	@if command -v golangci-lint >/dev/null 2>&1; then \
		echo "==> Go: golangci-lint"; \
		golangci-lint run; \
	fi

lint-org:
	@echo "==> Org: checking files"
	@for f in $(ORG_FILES); do \
		echo "  $$f"; \
		if ! head -1 "$$f" | grep -q '^#+TITLE:'; then \
			echo "    WARN: missing #+TITLE header"; \
		fi; \
	done
	@if command -v emacs >/dev/null 2>&1; then \
		echo "==> Org: emacs lint"; \
		for f in $(ORG_FILES); do \
			emacs --batch -l org "$$f" \
				--eval "(org-lint)" \
				--eval "(message \"Checked: %s\" buffer-file-name)" \
				2>&1 | grep -v "^Loading\|^For information"; \
		done; \
	fi

lint-shell:
	@echo "==> Shell: checking files"
	@if [ -z "$(SHELL_FILES)" ]; then \
		echo "  No shell files found"; \
	else \
		if command -v shellcheck >/dev/null 2>&1; then \
			echo "==> Shell: shellcheck"; \
			shellcheck $(SHELL_FILES); \
		else \
			echo "  SKIP: shellcheck not installed"; \
		fi; \
		if command -v shfmt >/dev/null 2>&1; then \
			echo "==> Shell: shfmt check"; \
			shfmt -d $(SHELL_FILES); \
		fi; \
	fi

# Format
fmt:
	gofmt -w $(GO_FILES)
	@if command -v shfmt >/dev/null 2>&1 && [ -n "$(SHELL_FILES)" ]; then \
		shfmt -w $(SHELL_FILES); \
	fi

# Clean
clean:
	rm -f $(BINARY) $(BINARY)-*
	rm -rf .cprr dist/

# Dev setup
dev-deps:
	@echo "Installing development dependencies..."
	go install honnef.co/go/tools/cmd/staticcheck@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo ""
	@echo "Optional (install via package manager):"
	@echo "  brew install shellcheck shfmt"
	@echo "  brew install emacs  # for org-lint"

# Quick validation
check: lint-go test
	@echo "==> Quick check passed"

# Show version info that will be embedded
version-info:
	@echo "VERSION:    $(VERSION)"
	@echo "COMMIT:     $(COMMIT)"
	@echo "BUILD_DATE: $(BUILD_DATE)"

# Org-mode tangle/detangle
TANGLE_FILES := $(wildcard *.org docs/*.org)

tangle:
	@echo "==> Tangling org files"
	@if command -v emacs >/dev/null 2>&1; then \
		for f in $(TANGLE_FILES); do \
			echo "  Tangling: $$f"; \
			emacs --batch -l org "$$f" \
				--eval "(org-babel-tangle)" \
				2>&1 | grep -v "^Loading\|^For information\|^Tangled"; \
		done; \
	else \
		echo "  SKIP: emacs not installed"; \
	fi

detangle:
	@echo "==> Detangling to org files"
	@if command -v emacs >/dev/null 2>&1; then \
		for f in $(TANGLE_FILES); do \
			echo "  Detangling: $$f"; \
			emacs --batch -l org "$$f" \
				--eval "(org-babel-detangle)" \
				2>&1 | grep -v "^Loading\|^For information"; \
		done; \
	else \
		echo "  SKIP: emacs not installed"; \
	fi

# Help
help:
	@echo "cprr Makefile"
	@echo ""
	@echo "Build:"
	@echo "  make build            Build binary with version info"
	@echo "  make build-dev        Build binary (fast, no version)"
	@echo "  make build-release    Build optimized binary"
	@echo "  make build-all        Cross-compile for all platforms"
	@echo "  make install          Install to GOPATH/bin"
	@echo "  make run              Build and run"
	@echo ""
	@echo "Test:"
	@echo "  make test             Run unit tests"
	@echo "  make test-cover       Run tests with coverage"
	@echo "  make test-race        Run tests with race detector"
	@echo "  make test-integration Run integration test flow"
	@echo ""
	@echo "Lint:"
	@echo "  make lint             Run all linters"
	@echo "  make lint-go          Go: vet, fmt, staticcheck, golangci-lint"
	@echo "  make lint-org         Org: header check, emacs org-lint"
	@echo "  make lint-shell       Shell: shellcheck, shfmt"
	@echo ""
	@echo "Other:"
	@echo "  make fmt              Auto-format Go and shell files"
	@echo "  make clean            Remove build artifacts"
	@echo "  make dev-deps         Install linter tools"
	@echo "  make check            Quick lint + test"
	@echo "  make version-info     Show embedded version info"
	@echo ""
	@echo "Org-mode:"
	@echo "  make tangle           Extract code from org files"
	@echo "  make detangle         Sync code changes back to org files"
