# include into engine Makefile: adds 'census' target
CENSUS ?= $(dir $(lastword $(MAKEFILE_LIST)))census.sh

census: plan.json
	@$(CENSUS) plan.json .
.PHONY: census
