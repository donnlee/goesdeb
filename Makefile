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

Flags:
   V=1	verbose
   FORCE=FORCE
	force build of goes targets
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

strip_program = $(if $(stripper),--strip-program=$(stripper))
cpio = cpio --quiet -H newc -o --owner 0:0
cpiofn = ../$(subst .xz,,$(notdir $@))

goes/%.cpio.xz: goes/%
	$(I)mk $@
	$(Q)install -s $(strip_program) -D $?  $(initrd_dir)/init
	$(Q)install -d $(initrd_dir)/bin
	$(Q)ln -sf ../init $(initrd_dir)/bin/goes
	$(Q)cd $(initrd_dir) && find . | $(cpio) >$(cpiofn)
	$(Q)rm -f $@
	$(Q)xz --check=crc32 -9 $(subst .xz,,$@)
	$(Q)rm -rf $(initrd_dir)

gorebuild_ = $(if $(filter netgo,$(GOTAGS)), -a)
gotags_ = $(if $(GOTAGS), -tags "$(GOTAGS)")
goldflags_ = $(if $(goLdFlags), -ldflags '$(goLdFlags)')

define gobuild
$(I)env GOARCH=$(GOARCH) go build -o $@ $(main)
$(Q)go build $(gorebuild_) $(gotags_) $(goldflags_) -o $@ $(main)
endef

example_main := github.com/platinasystems/goes/example

goesd-example: export GOARCH=amd64
goesd-example: main=$(example_main)

all += goesd-example

goes/example_amd64: export GOARCH=amd64
goes/example_amd64: GOTAGS=netgo
goes/example_amd64: goLdFlags=-d
goes/example_amd64: main=$(example_main)

all += goes/example_amd64.cpio.xz

goes/example_armhf: export GOARCH=arm
goes/example-armhf: export GOARM=7
goes/example_armhf: GOTAGS+=netgo
goes/example_armhf: goLdFlags=-d
goes/example_armhf: main=$(example_main)

all += goes/example_armhf.cpio.xz

goes/bmc_armhf: export GOARCH=arm
goes/bmc-armhf: export GOARM=7
goes/bmc_armhf: GOTAGS+=netgo
goes/bmc_armhf: goLdFlags=-d
goes/bmc_armhf: main=$(example_main)

all += goes/bmc_armhf.cpio.xz

# Replace all += <MACHINE_DEBARCH>.vmlinuz with these for linux debian
# packages instead of zImage/bzImage:
#
# <MACHINE_DEBARCH>_KDEB_PKGVERSION := $(kernelversion)-goes-<MACHINE>
# all += linux/linux-libc-dev_$(kernelversion)-goes-<MACHINE_DEBARCH>.deb

machines += example_amd64
example_amd64_help := suitable for qemu-goes
example_amd64_ARCH := x86_64
example_amd64_linux_config := kvmconfig

all += goes/example_amd64.vmlinuz

machines += example_armhf
example_armhf_help := suitable for qemu-goes
example_armhf_ARCH := arm
example_armhf_CROSS_COMPILE := arm-linux-gnueabi-
example_armhf_linux_config := olddefconfig

all += goes/example_armhf.vmlinuz

machines += bmc_armhf

bmc_armhf_help := Platina Systems Baseboard Management Controller
bmc_armhf_ARCH := arm
bmc_armhf_CROSS_COMPILE := arm-linux-gnueabi-
goes/bmc_armhf: main=github.com/platinasystems/goes/example/bmc
bmc_armhf_linux_config := olddefconfig

all += goes/bmc_armhf.vmlinuz

configs = $(foreach machine,$(machines),linux/$(machine)/.config)
.PRECIOUS: $(configs)

.PHONY: all
all : $(all); $(if $(dryrun),,@:)

goesd-example: $(FORCE); $(gobuild)
goes/example_amd64: $(FORCE); $(gobuild)
goes/example_armhf: $(FORCE); $(gobuild)
goes/bmc_armhf: $(FORCE); $(gobuild)

git_clean = git clean $(if $(dryrun),-n,-f) $(if $(Q),-q )-X -d

.PHONY: clean
clean: ; $(Q)$(git_clean)

.PHONY: clean-debian
clean-debian: ; $(Q)$(git_clean) -- debian/*

.PHONY: help
help: ; $(Q):$(info $(help))

.PHONY: show-%
show-%: ; $(Q):$(info $($*))

.PHONY: FORCE
