#!/usr/bin/make -f

pkg_example := github.com/platinasystems/goes/example

export GOPATH := ${CURDIR}

ifeq (,$(shell go version 2>/dev/null))
  ifneq (,$(wildcard /usr/lib/go-1.6))
    export GOROOT := /usr/lib/go-1.6
    export PATH := ${GOROOT}/bin:${PATH}
  else
    $(error no go)
  endif
endif

ifeq (,$(or $(DH_VERBOSE),$(V)))
  Q := @
  echo := echo "  "
else
  echo := @:
endif

cpio := cpio --quiet -H newc -o --owner 0:0
STRIP ?= strip

goBuild := go build$(if $(GOTAGS), -tags )$(GOTAGS)
goLdflags := -linkmode external$(if $(GOLDFLAGS), )$(GOLDFLAGS)
goLdflags += -extldflags
goLdflags += "-static$(if $(GOEXTLDFLAGS), )$(GOEXTLDFLAGS)"
goStaticBuild := $(goBuild) -ldflags '$(goLdflags)'

define mkimg
$(Q)$(echo) go build $@
$(Q)$(goStaticBuild) -o $@-init $(pkg_$(pkg))
$(Q)install -s --strip-program=$(STRIP) -D $@-init $@-build/init
$(Q)install -d $@-build/bin
$(Q)ln -sf ../init $@-build/bin/goes
$(Q)cd $@-build  && find . | $(cpio) >../$@.cpio
$(Q)rm -f $@.cpio.xz
$(Q)xz --check=crc32 -9 $@.cpio
$(Q)mv $@.cpio.xz $@
$(Q)rm -rf $@-build
endef

goesd-%:
	$(Q)$(echo) go build $@
	$(Q)$(goBuild) -o $@ $(pkg_$(*))

arm-linux-gnueabi-initrd-%: export GOARCH=arm
arm-linux-gnueabi-initrd-%: export CGO_ENABLED=1
arm-linux-gnueabi-initrd-%: export CC=arm-linux-gnueabi-gcc
arm-linux-gnueabi-initrd-%: export LD=arm-linux-gnueabi-ld
arm-linux-gnueabi-initrd-%: export STRIP=arm-linux-gnueabi-strip
arm-linux-gnueabi-initrd-%: pkg=$*

arm-linux-gnueabi-initrd-%:
	$(call mkimg)

x86_64-linux-gnu-initrd-%: pkg=$*

x86_64-linux-gnu-initrd-%:
	$(call mkimg)

all := goesd-example
all += x86_64-linux-gnu-initrd-example
all += arm-linux-gnueabi-initrd-example

.PHONY: all
all : $(all)

.PHONY: clean
clean:
	@git clean -X -d$(if $(Q), --quiet)

show-%:
	@echo $($*)
