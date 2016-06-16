#!/usr/bin/make -f

export GOPATH := ${CURDIR}

ifeq (,$(shell go version 2>/dev/null))
  ifneq (,$(wildcard /usr/lib/go-1.6))
    export GOROOT := /usr/lib/go-1.6
    export PATH := ${GOROOT}/bin:${PATH}
  else
    $(error no go)
  endif
endif

dryrun := $(filter n,$(MAKEFLAGS))

define help
Cleaning targets:
  clean		aka. `git clean -X -d`
  clean-debian	aka. `git clean -X -d -- debian/*`

Configuration targets:
  config-MACHINE
  menuconfig-MACHINE
  nconfig-MACHINE
  xconfig-MACHINE
  gconfig-MACHINE
  	Update the given machine config utilising a line-oriented,
	menu, ncurses menu, Qt, or GTK+ based programs

Machines:$(foreach machine,$(machines),
  $(machine)	- $($(machine)_help))

`all` builds:$(foreach target,$(all),
  $(target))
endef

empty :=
space := $(empty) $(empty)
ifeq (,$(or $(DH_VERBOSE),$(V)))
  Q := @
  I := $(Q)echo "   "
else
  I := @:$(space)
endif

kernelversion := $(shell make -C src/linux -s kernelversion)

configured = $(wildcard linux/$*/.config)

mklinux = $(if $(dryrun),$(if $(configured),+,:),+)$(MAKE) --no-print-directory
mklinux+=-C $(CURDIR)/src/linux
mklinux+=$(if $Q,,V=1 )O=$(CURDIR)/linux/$*
mklinux+=$(if $($*_CROSS_COMPILE),CROSS_COMPILE=$($*_CROSS_COMPILE))
mklinux+=$(if $($*_ARCH),ARCH=$($*_ARCH))
mklinux+=$(if $($*_KDEB_PKGVERSION),KDEB_PKGVERSION=$($*_KDEB_PKGVERSION))

goes/%_amd64.vmlinuz: linux/%_amd64/arch/x86_64/boot/bzImage
	$(Q)mkdir -p goes
	$(Q)cp $? $@
	$(Q)chmod -x $@

goes/%_armhf.vmlinuz: linux/%_armhf/arch/arm/boot/zImage
	$(Q)mkdir -p goes
	$(Q)cp $? $@
	$(Q)chmod -x $@

linux/%/arch/x86_64/boot/bzImage: linux/%/.config
	$(Q)$(mklinux) bzImage

linux/%/arch/arm/boot/zImage: linux/%/.config
	$(Q)$(mklinux) zImage

linux/linux-libc-dev_$(kernelversion)-goes-%.deb: linux/%/.config
	$(Q)$(mklinux) bindeb-pkg

config-%: linux_config=config
menuconfig-%: linux_config=menuconfig
nconfig-%: linux_config=nconfig
xconfig-%: linux_config=xconfig
qconfig-%: linux_config=qconfig

linux/%/.config \
config-% \
menuconfig-% \
nconfig-% \
xconfig-% \
qconfig-%:
	$(Q)mkdir -p linux/$*
	$(Q)test -L linux/$*/.config || \
		ln -s ../../configs/$*.defconfig linux/$*/.config
	$(Q)$(mklinux) $(if $(linux_config),$(linux_config),$($*_linux_config))

goes/%_armhf.cpio.xz: stripper=arm-linux-gnueabi-strip

initrd_dir = $(subst .cpio.xz,.tmp,$@)

goes/%.cpio.xz: goes/%
	$(I)mk $@
	$(Q)install -s$(if $(stripper), --strip-program=$(stripper))\
		-D $?  $(initrd_dir)/init
	$(Q)install -d $(initrd_dir)/bin
	$(Q)ln -sf ../init $(initrd_dir)/bin/goes
	$(Q)cd $(initrd_dir) && \
		find . | cpio --quiet -H newc -o --owner 0:0 \
			>../$(subst .xz,,$(notdir $@))
	$(Q)rm -f $@
	$(Q)xz --check=crc32 -9 $(subst .xz,,$@)
	$(Q)rm -rf $(initrd_dir)

gobuild  = go build
gobuild += $(if $(filter netgo,$(GOTAGS)), -a)
gobuild += $(if $(GOTAGS), -tags "$(GOTAGS)")
gobuild += $(if $(goLdFlags), -ldflags '$(goLdFlags)')

goes/%_amd64: export GOARCH=amd64
goes/%_amd64: GOTAGS+=netgo
goes/%_amd64: goLdFlags=-d

goes/%_armhf: export GOARCH=arm
goes/%_armhf: GOTAGS+=netgo
goes/%_armhf: goLdFlags=-d

goesd-% goes/%_amd64 goes/%_armhf:
	$(I)env GOARCH=$(GOARCH) go build $(main)
	$(Q)$(gobuild) -o $@ $(main)

example_main := github.com/platinasystems/goes/example
all += goesd-example

# Replace all += <MACHINE_DEBARCH>.vmlinuz with these for linux debian
# packages instead of zImage/bzImage:
#
# <MACHINE_DEBARCH>_KDEB_PKGVERSION := $(kernelversion)-goes-<MACHINE>
# all += linux/linux-libc-dev_$(kernelversion)-goes-<MACHINE_DEBARCH>.deb

machines += example_amd64
example_amd64_help := suitable for qemu-goes
example_amd64_ARCH := x86_64
goes/example_amd64: main=github.com/platinasystems/goes/example
example_amd64_linux_config := kvmconfig
all += goes/example_amd64
all += goes/example_amd64.cpio.xz
all += goes/example_amd64.vmlinuz

machines += example_armhf
example_armhf_help := suitable for qemu-goes
example_armhf_ARCH := arm
example_armhf_CROSS_COMPILE := arm-linux-gnueabi-
goes/example_armhf: main=github.com/platinasystems/goes/example
example_armhf_linux_config := olddefconfig
all += goes/example_armhf
all += goes/example_armhf.cpio.xz
all += goes/example_armhf.vmlinuz

goes/example-armhf: export GOARM=7

machines += bmc_armhf
bmc_armhf_help := Platina Systems Baseboard Management Controller
bmc_armhf_ARCH := arm
bmc_armhf_CROSS_COMPILE := arm-linux-gnueabi-
goes/bmc_armhf: main=github.com/platinasystems/goes/example/bmc
bmc_armhf_linux_config := olddefconfig
all += goes/bmc_armhf
all += goes/bmc_armhf.cpio.xz
all += goes/bmc_armhf.vmlinuz

goes/bmc-armhf: export GOARM=7

configs = $(foreach machine,$(machines),linux/$(machine)/.config)
.PRECIOUS: $(configs)

.PHONY: all
all : $(all); $(if $(dryrun),,@:)

git_clean = git clean $(if $(dryrun),-n,-f) $(if $(Q),-q )-X -d

.PHONY: clean
clean: ; $(Q)$(git_clean)

.PHONY: clean-debian
clean-debian: ; $(Q)$(git_clean) -- debian/*

.PHONY: help
help: ; $(Q):$(info $(help))

.PHONY: show-%
show-%: ; $(Q):$(info $($*))
