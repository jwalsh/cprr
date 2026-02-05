# Alloy State Machine Verification

ALLOY_JAR ?= $(HOME)/bin/alloy.jar

.PHONY: check run clean

check: cprr.als
	@if [ -f "$(ALLOY_JAR)" ]; then \
		java -jar $(ALLOY_JAR) -c cprr.als; \
	else \
		echo "Alloy not found at $(ALLOY_JAR)"; \
		echo "Download from: https://alloytools.org/download.html"; \
	fi

run: cprr.als
	@if [ -f "$(ALLOY_JAR)" ]; then \
		java -jar $(ALLOY_JAR) cprr.als; \
	else \
		echo "Alloy not found at $(ALLOY_JAR)"; \
	fi

lint:
	@echo "Alloy files don't have a standard linter"
	@wc -l cprr.als

clean:
	rm -f *.cnf *.xml
