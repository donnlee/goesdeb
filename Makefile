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

STRIP ?= strip

goes_static = $(addprefix goes-,$(addsuffix -static,$(notdir $@)))
initrd_build = $(subst .cpio.xz,-build,$@)

goBuild := go build$(if $(GOTAGS), -tags )$(GOTAGS)
goLdflags := -linkmode external$(if $(GOLDFLAGS), )$(GOLDFLAGS)
goLdflags += -extldflags
goLdflags += "-static$(if $(GOEXTLDFLAGS), )$(GOEXTLDFLAGS)"
goStaticBuild := $(goBuild) -ldflags '$(goLdflags)'

define mkimg
$(Q)$(echo) go build $@
$(Q)$(goStaticBuild) -o bin/$(goes_static) $(pkg_$(pkg))
$(Q)install -s --strip-program=$(STRIP) -D bin/$(goes_static)\
	$(initrd_build)/init
$(Q)install -d $(initrd_build)/bin
$(Q)ln -sf ../init $(initrd_build)/bin/goes
$(Q)cd $(initrd_build)  && find . |\
	cpio --quiet -H newc -o --owner 0:0 >../$(subst .xz,,$(notdir $@))
$(Q)rm -f $@
$(Q)xz --check=crc32 -9 $(subst .xz,,$@)
$(Q)rm -rf $(initrd_build)
endef

bin/goesd-%:
	$(Q)$(echo) go build $@
	$(Q)$(goBuild) -o $@ $(pkg_$(*))

goes-initrd/%-arm-linux-gnueabi.cpio.xz: export GOARCH=arm
goes-initrd/%-arm-linux-gnueabi.cpio.xz: export CGO_ENABLED=1
goes-initrd/%-arm-linux-gnueabi.cpio.xz: export CC=arm-linux-gnueabi-gcc
goes-initrd/%-arm-linux-gnueabi.cpio.xz: export LD=arm-linux-gnueabi-ld
goes-initrd/%-arm-linux-gnueabi.cpio.xz: export STRIP=arm-linux-gnueabi-strip
goes-initrd/%-arm-linux-gnueabi.cpio.xz: pkg=$*

goes-initrd/%-arm-linux-gnueabi.cpio.xz:
	$(call mkimg)

goes-initrd/%-amd64-linux-gnu.cpio.xz: pkg=$*

goes-initrd/%-amd64-linux-gnu.cpio.xz:
	$(call mkimg)

all := bin/goesd-example
all += goes-initrd/example-amd64-linux-gnu.cpio.xz
all += goes-initrd/example-arm-linux-gnueabi.cpio.xz

.PHONY: all
all : $(all)

.PHONY: clean
clean:
	@git clean -X -d$(if $(Q), --quiet)

show-%:
	@echo $($*)
