SHELL := $(shell which bash)
TEST_LOG_FILE := test.log

APP_VSN ?= `grep 'version:' mix.exs | cut -d '"' -f2`
APP_NAME ?=unified-chat-gateway
BUILD ?= `git rev-parse --short HEAD`

.PHONY: compile deps_compile deps_get clean distclean apps

compile: deps_get
	@mix compile --ignore-module-conflict

clean:
	@mix clean

apps:
	@mix compile --no-deps-check

distclean: clean clean-deps
	@mix clean --deps

deps_compile: deps_get
	@mix deps.compile

deps_get:
	@mix deps.get

.PHONY: clean-deps
clean-deps:
	@mix deps.clean --all


.PHONY: tests clean-tests
clean-tests:
	@rm -f $(TEST_LOG_FILE)

# This allows us to run _all_ of the tests and be notified
# of all failures at the end.
# For test reruns following may be convenient
# OPTS="--no-compile --no-deps-check"
tests: clean-tests
	@mix test $(OPTS) --cover --no-start 2>test.failures | tee $(TEST_LOG_FILE); \
	  status=$${PIPESTATUS[0]} \
	    && cat test.failures | tee -a $(TEST_LOG_FILE) \
	    && rm test.failures \
	    && exit $$status


# Dialyzer

.PHONY: dialyzer

dialyzer:
	@echo "-*- mode: compilation-minor; eval: (auto-revert-mode 1) -*-" > .dialyzer_result
	mix dialyzer | tee -a .dialyzer_result
	mv .dialyzer_result dialyzer_result

# Releases

.PHONY: rel
rel:
	docker build --build-arg APP_NAME=$(APP_NAME) \
		--no-cache \
		--build-arg APP_VSN=$(APP_VSN) \
		-t $(APP_NAME):$(APP_VSN)-$(BUILD) \
		-t $(APP_NAME):latest .

format:
	([[ -n $$(git diff --name-only) ]] && git diff --name-only || \
	 [[ -n $$(git diff --cached --name-only) ]] && git diff --cached --name-only || \
	 git show --format= --name-only) | \
	 grep -E '\.exs?$$' | xargs -r mix format --check-equivalent
