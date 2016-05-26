#!/usr/bin/make -f

example := github.com/platinasystems/goes/example
bmc := github.com/platinasystems/goes/example/bmc

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
  I := $(Q)echo "   "
else
  I := @:
endif

gobuild_ =go build
gobuild_+=$(if $(filter netgo,$(GOTAGS)), -a)
gobuild_+=$(if $(GOTAGS), -tags "$(GOTAGS)")
gobuild_+=$(if $(goLdFlags), -ldflags '$(goLdFlags)')

define goBuild
$(I)go build $@
$(Q)$(gobuild_) -o $@ $($*)
endef

bin/goes-%-amd64-linux-gnu: GOTAGS+=netgo
bin/goes-%-amd64-linux-gnu: goLdFlags=-d

bin/goes-%-arm-linux-gnueabi: GOTAGS+=netgo
bin/goes-%-arm-linux-gnueabi: export GOARCH=arm

bin/goes-%-amd64-linux-gnu: ; $(goBuild)
bin/goes-%-arm-linux-gnueabi: ; $(goBuild)

.PRECIOUS: bin/goes-%-amd64-linux-gnu
.PRECIOUS: bin/goes-%-arm-linux-gnueabi

bin/goesd-%: ; $(goBuild)

initrd_build = $(subst .cpio.xz,-build,$@)

define mk
$(I)mk $@
$(Q)install -s$(if $(strip_program), --strip-program=$(strip_program))\
	-D bin/goes-$(subst .cpio.xz,,$(notdir $@))\
	$(initrd_build)/init
$(Q)install -d $(initrd_build)/bin
$(Q)ln -sf ../init $(initrd_build)/bin/goes
$(Q)cd $(initrd_build) && \
	find . | cpio --quiet -H newc -o --owner 0:0 \
		>../$(subst .xz,,$(notdir $@))
$(Q)rm -f $@
$(Q)xz --check=crc32 -9 $(subst .xz,,$@)
$(Q)rm -rf $(initrd_build)
endef

goes-initrd/%-arm-linux-gnueabi.cpio.xz: strip_program=arm-linux-gnueabi-strip

goes-initrd/%-amd64-linux-gnu.cpio.xz: bin/goes-%-amd64-linux-gnu
	$(mk)

goes-initrd/%-arm-linux-gnueabi.cpio.xz: bin/goes-%-arm-linux-gnueabi
	$(mk)

all := bin/goesd-example
all += goes-initrd/example-amd64-linux-gnu.cpio.xz
all += goes-initrd/bmc-arm-linux-gnueabi.cpio.xz

bin/goes-bmc-arm-linux-gnueabi: export GOARM=7

.PHONY: all
all : $(all)

.PHONY: clean
clean:
	@git clean -X -d$(if $(Q), --quiet)

.PHONY: show-%
show-%:
	@echo $($*)
