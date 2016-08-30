#!/usr/bin/make -f

machines+= example

example_help:= a daemon suitable for any debian system

example_targets = goesd-example

all+= $(example_targets)

define example_vars
$1: export GOARCH=amd64
$1: gotags=$(GOTAGS)
$1: machine=example
$1: main=github.com/platinasystems/goes/main/goes-example
endef

$(eval $(call example_vars,goesd-example))
