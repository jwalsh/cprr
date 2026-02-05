.PHONY: all build test clean lint lint-go lint-org lint-shell install help run tangle detangle worktrees worktrees-sync

GO ?= go
BINARY := cprr
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "none")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LDFLAGS := -ldflags "-s -w \
	-X main.Version=$(VERSION) \
	-X main.GitCommit=$(COMMIT) \
	-X main.BuildDate=$(BUILD_DATE)"

GO_FILES := $(shell find . -name '*.go' -type f)
ORG_FILES := $(wildcard *.org docs/*.org)
SHELL_FILES := $(shell find . -name '*.sh' -type f)

all: lint build test

# Build
build: $(BINARY)

$(BINARY): $(GO_FILES)
	$(GO) build $(LDFLAGS) -o $@ .

build-dev: $(GO_FILES)
	$(GO) build -o $(BINARY) .

build-release: $(GO_FILES)
	$(GO) build $(LDFLAGS) -o $(BINARY) .

# Cross-compilation targets
PLATFORMS := linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64

define build-platform
$(BINARY)-$(1): $(GO_FILES)
	GOOS=$(word 1,$(subst -, ,$(1))) GOARCH=$(word 2,$(subst -, ,$(1))) \
		$(GO) build $(LDFLAGS) -o $$@ .
endef

$(foreach p,$(PLATFORMS),$(eval $(call build-platform,$(p))))

$(BINARY)-windows-amd64.exe: $(GO_FILES)
	GOOS=windows GOARCH=amd64 $(GO) build $(LDFLAGS) -o $@ .

build-all: $(addprefix $(BINARY)-,$(PLATFORMS)) $(BINARY)-windows-amd64.exe

# Install
install: $(GO_FILES)
	$(GO) install $(LDFLAGS) .

# Run (development)
run: build-dev
	./$(BINARY)

# Test
test:
	$(GO) test -v ./...

test-cover:
	$(GO) test -cover ./...

test-race:
	$(GO) test -race ./...

test-cli: $(BINARY)
	@chmod +x docs/test-cli.sh 2>/dev/null || true
	@if [ -x docs/test-cli.sh ]; then \
		docs/test-cli.sh; \
	else \
		echo "Run: make tangle  # to generate test-cli.sh from docs/CLI-TESTING.org"; \
	fi

# Integration test
test-integration: $(BINARY)
	@echo "==> Integration test"
	rm -rf .cprr
	./$< --version
	./$< init --local --examples
	./$< list
	./$< show 1
	./$< next 1
	./$< evidence 1 "Test evidence 1"
	./$< evidence 1 "Test evidence 2"
	./$< next 1
	./$< list --status confirmed
	rm -rf .cprr
	@echo "==> Integration test passed"

# Lint
lint: lint-go lint-org lint-shell

lint-go:
	@echo "==> Go: vet"
	$(GO) vet ./...
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

# Environment setup
.env: .env.example
	cp $< $@
	@echo "Created $@ from $<"
	@echo "Edit $@ to customize, then run: direnv allow"

# Clean
clean:
	rm -f $(BINARY) $(BINARY)-*
	rm -rf .cprr dist/

# Git worktrees management
worktrees:
	@./scripts/worktrees.sh $(ARGS)

worktrees-sync:
	@./scripts/worktrees.sh sync

# Dev setup
dev-deps:
	@echo "Installing development dependencies..."
	$(GO) install honnef.co/go/tools/cmd/staticcheck@latest
	$(GO) install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo ""
	@echo "Optional (install via package manager):"
	@echo "  brew install shellcheck shfmt"
	@echo "  brew install emacs  # for org-lint"

# Quick validation
check: lint-go test
	@echo "==> Quick check passed"

# Show version info
version-info:
	@echo "VERSION:    $(VERSION)"
	@echo "COMMIT:     $(COMMIT)"
	@echo "BUILD_DATE: $(BUILD_DATE)"

# Org-mode tangle/detangle
tangle:
	@echo "==> Tangling org files"
	@if command -v emacs >/dev/null 2>&1; then \
		for f in $(ORG_FILES); do \
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
		for f in $(ORG_FILES); do \
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
	@echo "  make .env             Create .env from .env.example"
	@echo ""
	@echo "Org-mode:"
	@echo "  make tangle           Extract code from org files"
	@echo "  make detangle         Sync code changes back to org files"
	@echo ""
	@echo "Scripts (fallthrough):"
	@echo "  make <name>           Run ./scripts/<name>.sh if it exists"

# Directory creation pattern
%/:
	install -d $@

dist/$(BINARY)-%: $(GO_FILES) | dist/
	GOOS=$(word 1,$(subst -, ,$*)) GOARCH=$(word 2,$(subst -, ,$*)) \
		$(GO) build $(LDFLAGS) -o $@ .

# Fallthrough: run scripts from ./scripts/
%:
	@if [ -x ./scripts/$@.sh ]; then \
		./scripts/$@.sh; \
	else \
		echo "No rule to make target '$@'" >&2; \
		exit 1; \
	fi
