.PHONY: help lint test test-install test-syntax clean

help:
	@echo "determinagents — local dev tasks"
	@echo ""
	@echo "  make lint           shellcheck install.sh + bin/determinagents"
	@echo "  make test-syntax    sh -n on shell scripts (no deps required)"
	@echo "  make test-install   end-to-end install test in Docker"
	@echo "  make test           lint + syntax + install (full suite)"
	@echo "  make clean          remove the test Docker image"

lint:
	@command -v shellcheck >/dev/null 2>&1 || { \
	  echo "shellcheck not installed; install with: brew install shellcheck"; exit 1; }
	shellcheck install.sh bin/determinagents

test-syntax:
	@sh -n install.sh && echo "install.sh: OK"
	@sh -n bin/determinagents && echo "bin/determinagents: OK"

test-install:
	docker build -f tests/Dockerfile.install -t det-install-test .
	docker run --rm det-install-test

test: lint test-syntax test-install

clean:
	-docker image rm det-install-test 2>/dev/null || true
