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
  $(machine)	- $($(subst -,_,$(machine))_help))

`all` builds:$(foreach target,$(all),
  $(target))

Flags:
   V=1	verbose
   FORCE=FORCE
	force build of goes targets

Debug targets:
  show-VARIABLE
	print value of $$(VARIABLE)

Phony targets:
  linux-image-platina-mk1
	builds $(linux_image_platina_mk1)
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
kerneldebver := $(shell git --git-dir src/linux/.git describe --tags --dirty \
	| sed s:^v::)

linux_image_platina_mk1 = linux/linux-image-$(kernelversion)-platina-mk1_$(kerneldebver)_amd64.deb

configured = $(wildcard linux/$*/.config)

mklinux = $(if $(dryrun),$(if $(configured),+,:),+)$(MAKE) --no-print-directory
mklinux+=-C $(CURDIR)/src/linux
mklinux+=$(if $Q,,V=1 )O=$(CURDIR)/linux/$*
mklinux+=$(if $($(subst -,_,$*)_CROSS_COMPILE),CROSS_COMPILE=$($(subst -,_,$*)_CROSS_COMPILE))
mklinux+=$(if $($(subst -,_,$*)_ARCH),ARCH=$($(subst -,_,$*)_ARCH))
mklinux+=$(if $($(subst -,_,$*)_KDEB_PKGVERSION),KDEB_PKGVERSION=$($(subst -,_,$*)_KDEB_PKGVERSION))
mklinux+=$(if $($(subst -,_,$*)_KERNELRELEASE),KERNELRELEASE=$($(subst -,_,$*)_KERNELRELEASE))

mkuboot = $(MAKE) --no-print-directory
mkuboot+= -C src/u-boot
mkuboot+=$(if $Q,,V=1 )O=$(CURDIR)/u-boot/$*
mkuboot+=$(if $($(subst -,_,$*)_CROSS_COMPILE),CROSS_COMPILE=$($(subst -,_,$*)_CROSS_COMPILE))

linux/%/arch/x86_64/boot/bzImage: linux/%/.config
	$(Q)$(mklinux) bzImage

linux/%/arch/arm/boot/zImage: linux/%/.config
	$(Q)$(mklinux) zImage

linux/linux-image-$(kernelversion)-%_$(kerneldebver)_amd64.deb: linux/%/.config
	$(Q)$(mklinux) bindeb-pkg

goes/%.dtb: linux/%/.config
	$(Q)$(mklinux) dtbs
	$(Q)mkdir -p goes
	$(Q)cp linux/$*/arch/arm/boot/dts/$($*_dtb) $@

goes/%.u-boot: configs/%.u-boot_defconfig goes/%.cpio.xz
	$(I)mk $@
	$(Q)mkdir -p u-boot/$*
	$(Q)cp $< u-boot/$*/.config
	$(Q)$(mkuboot) olddefconfig
	$(Q)$(mkuboot)
	$(Q)u-boot/$*/tools/mkimage -A $($(subst -,_,$*)_ARCH) -O linux\
		-T ramdisk -d goes/$*.cpio.xz $@ >/dev/null

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
	$(Q)cp configs/$*.defconfig linux/$*/.config
	$(Q)$(mklinux) $(if $(linux_config),$(linux_config),$($*_linux_config))
	$(Q)cp linux/$*/.config configs/$*.defconfig

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

GOTAGS_ = $(if $(GOTAGS),$(GOTAGS) )
gorebuild_ = $(if $(filter netgo,$(gotags)),-a )
gotags_ = $(if $(gotags),-tags "$(gotags)" )
goldflags_ = $(if $(goLdFlags),-ldflags '$(goLdFlags)' )

define gobuild
$(I)env GOARCH=$(GOARCH) go build -o $@ $(main)
$(Q)go build $(gorebuild_)$(gotags_)$(goldflags_)-o $@ $(main)
endef

example_main := github.com/platinasystems/goes/example

goesd-example: export GOARCH=amd64
goesd-example: gotags=$(GOTAGS)
goesd-example: main=$(example_main)

all += goesd-example

goes/example_amd64: export GOARCH=amd64
goes/example_amd64: gotags=$(GOTAGS_)netgo
goes/example_amd64: goLdFlags=-d
goes/example_amd64: main=$(example_main)

all += goes/example_amd64.cpio.xz

goes/example_armhf: export GOARCH=arm
goes/example-armhf: export GOARM=7
goes/example_armhf: gotags=$(GOTAGS_)netgo
goes/example_armhf: goLdFlags=-d
goes/example_armhf: main=$(example_main)
goes/example_armhf.cpio.xz: stripper=arm-linux-gnueabi-strip

all += goes/example_armhf.cpio.xz

goes/platina-mk1: export GOARCH=amd64
goes/platina-mk1: gotags=$(GOTAGS_)netgo
goes/platina-mk1: goLdFlags=-d
goes/platina-mk1: main=github.com/platinasystems/goes/platina/mk1

all += goes/platina-mk1.cpio.xz

goes/platina-mk1-bmc: export GOARCH=arm
goes/platina-mk1-bmc: export GOARM=7
goes/platina-mk1-bmc: gotags=$(GOTAGS_)netgo
goes/platina-mk1-bmc: goLdFlags=-d
goes/platina-mk1-bmc: main=github.com/platinasystems/goes/platina/mk1/bmc
goes/platina-mk1-bmc.cpio.xz: stripper=arm-linux-gnueabi-strip

all += goes/platina-mk1-bmc.cpio.xz

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
example_armhf_dtb := vexpress-v2p-ca9.dtb

all += goes/example_armhf.vmlinuz
all += goes/example_armhf.dtb

machines += platina-mk1
platina_mk1_help := Platina Systems Mark 1 Platform(s)
platina_mk1_ARCH := x86_64
platina_mk1_KERNELRELEASE := $(kernelversion)-platina-mk1
platina_mk1_KDEB_PKGVERSION := $(kerneldebver)
platina_mk1_linux_config := olddefconfig

all += $(linux_image_platina_mk1)

machines += platina-mk1-bmc
platina_mk1_bmc_help := Platina Systems Mark 1 Baseboard Management Controller
platina_mk1_bmc_ARCH := arm
platina_mk1_bmc_CROSS_COMPILE := arm-linux-gnueabi-
platina_mk1_bmc_linux_config := olddefconfig

all += goes/platina-mk1-bmc.vmlinuz
all += goes/platina-mk1-bmc.u-boot

configs = $(foreach machine,$(machines),linux/$(machine)/.config)
.PRECIOUS: $(configs)

.PHONY: all
all : $(all); $(if $(dryrun),,@:)

goesd-example: $(FORCE); $(gobuild)
goes/example_amd64: $(FORCE); $(gobuild)
goes/example_armhf: $(FORCE); $(gobuild)
goes/platina-mk1: $(FORCE); $(gobuild)
goes/platina-mk1-bmc: $(FORCE); $(gobuild)

goes/example_amd64.vmlinuz: linux/example_amd64/arch/x86_64/boot/bzImage
	$(Q)install -D $? $@

goes/example_armhf.vmlinuz: linux/example_armhf/arch/arm/boot/zImage
	$(Q)install -D $? $@

goes/platina-mk1-bmc.vmlinuz: linux/platina-mk1-bmc/arch/arm/boot/zImage
	$(Q)install -D $? $@

git_clean = git clean $(if $(dryrun),-n,-f) $(if $(Q),-q )-X -d

.PHONY: linux-image-platina-mk1
linux-image-platina-mk1: $(linux_image_platina_mk1)

.PHONY: clean
clean: ; $(Q)$(git_clean)

.PHONY: clean-debian
clean-debian: ; $(Q)$(git_clean) -- debian/*

.PHONY: clean-u-boot
clean-u-boot: ; $(Q)$(git_clean) -- u-boot/*

.PHONY: help
help: ; $(Q):$(info $(help))

.PHONY: show-%
show-%: ; $(Q):$(info $($*))

.PHONY: FORCE
