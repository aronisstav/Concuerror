REBAR3 ?= rebar3

all:
	$(REBAR3) escriptize
clean:
	$(REBAR3) clean
dev:
	$(REBAR3) as $@ escriptize
native:
	$(REBAR3) as $@ escriptize
pedantic:
	$(REBAR3) as $@ escriptize

.PHONY: tests
tests: all
	@$(RM) $@/thediff
	cd $@ && ./runtests.py

## the -j 1 below is so that the outputs of tests are not shown interleaved
.PHONY: tests-real
tests-real: all
	@$(RM) $@/thediff
	$(MAKE) -j 1 -C $@ \
		CONCUERROR=$(abspath bin/concuerror) \
		CONCUERROR_EBIN=$(abspath _build/default/lib/concuerror/ebin/) \
		DIFFER=$(abspath tests/differ) \
		DIFFPRINTER=$(abspath $@/thediff)

###-----------------------------------------------------------------------------
### Cover
###-----------------------------------------------------------------------------

.PHONY: cover
cover: cover/data
	$(RM) $</*
	export CONCUERROR_COVER=$(abspath cover/data); $(MAKE) tests tests-real
	if ! [ -z "$$TRAVIS_JOB_ID" ]; then $(REBAR3) as test coveralls send; fi

cover/data:
	mkdir -p $@
