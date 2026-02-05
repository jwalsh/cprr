.PHONY: test build clean

CPRR := ../../cprr

test: $(CPRR)
	@echo "==> Testing quickstart command"
	$(CPRR) quickstart --help || echo "FAIL: quickstart not implemented yet"

build:
	@echo "==> Building parent project"
	$(MAKE) -C ../.. build

$(CPRR):
	$(MAKE) build

clean:
	@echo "Nothing to clean"
