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
  clean-DIR	aka. `git clean -X -d -- DIR/*`

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
  platina-mk1-linux-image
	builds $(platina_mk1_linux_image)

U-boot images: (made with sudo and *not* included with "all")
	platina-mk1-bmc.u-boot.img
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

machine_ = $(subst -,_,$*)
xV = $(if $Q,,V=1)
xARCH = $(if $($(machine_)_ARCH),\
	ARCH=$($(machine_)_ARCH))
xCROSS_COMPILE = $(if $($(machine_)_CROSS_COMPILE),\
		 CROSS_COMPILE=$($(machine_)_CROSS_COMPILE))
xKDEB_PKGVERSION = $(if $($(machine_)_KDEB_PKGVERSION),\
		   KDEB_PKGVERSION=$($(machine_)_KDEB_PKGVERSION))
xKERNELRELEASE = $(if $($(machine_)_KERNELRELEASE),\
		 KERNELRELEASE=$($(machine_)_KERNELRELEASE))

platina_mk1_linux_image = linux/linux-image-$(kernelversion)-platina-mk1_$(kerneldebver)_amd64.deb

linux_configured = $(wildcard linux/$*/.config)
uboot_configured = $(wildcard u-boot/$*/.config)

mklinux = $(if $(dryrun),$(if $(linux_configured),+,:),+)$(MAKE)
mklinux+= --no-print-directory -C $(CURDIR)/src/linux O=$(CURDIR)/linux/$*
mklinux+= $(xV)$(xARCH)$(xCROSS_COMPILE)$(xKDEB_PKGVERSION)$(xKERNELRELEASE)

mkuboot = $(if $(dryrun),$(if $(uboot_configured),+,:),+)$(MAKE)
mkuboot+= --no-print-directory  -C src/u-boot O=$(CURDIR)/u-boot/$*
mkuboot+= $(xV)$(xCROSS_COMPILE)

mk_u_boot_img = scripts/mk-u-boot O=$@
mk_u_boot_img+= INITRD=$*.cpio.xz.u-boot
mk_u_boot_img+= VMLINUZ=$*.vmlinuz
mk_u_boot_img+= DTB=$*.dtb

linux/%/arch/x86_64/boot/bzImage: linux/%/.config
	$(I)mk $@
	$(Q)$(mklinux) bzImage

linux/%/arch/arm/boot/zImage: linux/%/.config
	$(I)mk $@
	$(Q)$(mklinux) zImage

linux/linux-image-$(kernelversion)-%_$(kerneldebver)_amd64.deb: linux/%/.config
	$(I)mk $@
	$(Q)$(mklinux) bindeb-pkg

%.dtb: linux/%/.config
	$(I)mk $@
	$(Q)$(mklinux) dtbs
	$(Q)install linux/$*/arch/arm/boot/dts/$(dtb) $@

u-boot/%/tools/mkimage u-boot/%/u-boot: u-boot/%/.config
	$(I)mk $@
	$(Q)$(mkuboot)

u-boot/%/.config: configs/%.u-boot_defconfig
	$(I)mk $@
	$(Q)mkdir -p u-boot/$*
	$(Q)install $< u-boot/$*/.config
	$(Q)$(mkuboot) olddefconfig

%.u-boot.img: %.cpio.xz.u-boot %.vmlinuz %.dtb u-boot/%/u-boot
	$(I)FIXME sudo $(mk_u_boot_img)
	$(Q)touch $@

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
	$(I)mk linux/$*/.config
	$(Q)mkdir -p linux/$*
	$(Q)install configs/$*.defconfig linux/$*/.config
	$(Q)$(mklinux) $(if $(linux_config),$(linux_config),$($*_linux_config))
	$(Q)install linux/$*/.config configs/$*.defconfig

tmp_dir = $(subst .cpio.xz,.tmp,$@)
strip_program = $(if $(stripper),--strip-program=$(stripper))
cpio = cpio --quiet -H newc -o --owner 0:0
cpiofn = ../$(subst .xz,,$(notdir $@))

%.cpio.xz: goes-%
	$(I)mk $@
	$(Q)install -s $(strip_program) -D $?  $(tmp_dir)/init
	$(Q)install -d $(tmp_dir)/bin
	$(Q)ln -sf ../init $(tmp_dir)/bin/goes
	$(Q)cd $(tmp_dir) && find . | $(cpio) >$(cpiofn)
	$(Q)rm -f $@
	$(Q)xz --check=crc32 -9 $(subst .xz,,$@)
	$(Q)rm -rf $(tmp_dir)

%.cpio.xz.u-boot: %.cpio.xz u-boot/%/tools/mkimage
	$(I)mk $@
	$(Q)u-boot/$*/tools/mkimage -A $($(machine_)_ARCH) -O linux\
		-T ramdisk -d $*.cpio.xz $@ >/dev/null

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

goes-example-amd64: export GOARCH=amd64
goes-example-amd64: gotags=$(GOTAGS_)netgo
goes-example-amd64: goLdFlags=-d
goes-example-amd64: main=$(example_main)

all += example-amd64.cpio.xz

goes-example-armhf: export GOARCH=arm
goes-example-armhf: export GOARM=7
goes-example-armhf: gotags=$(GOTAGS_)netgo
goes-example-armhf: goLdFlags=-d
goes-example-armhf: main=$(example_main)

example-armhf.cpio.xz: stripper=arm-linux-gnueabi-strip

all += example-armhf.cpio.xz

platina_mk1_main := github.com/platinasystems/goes/platina/mk1

goesd-platina-mk1: export GOARCH=amd64
goesd-platina-mk1: gotags=$(GOTAGS)
goesd-platina-mk1: main=$(platina_mk1_main)

all += goesd-platina-mk1

goes-platina-mk1: export GOARCH=amd64
goes-platina-mk1: gotags=$(GOTAGS_)netgo
goes-platina-mk1: goLdFlags=-d
goes-platina-mk1: main=$(platina_mk1_main)

all += platina-mk1.cpio.xz

goes-platina-mk1-bmc: export GOARCH=arm
goes-platina-mk1-bmc: export GOARM=7
goes-platina-mk1-bmc: gotags=$(GOTAGS_)netgo
goes-platina-mk1-bmc: goLdFlags=-d
goes-platina-mk1-bmc: main=github.com/platinasystems/goes/platina/mk1/bmc

platina-mk1-bmc.cpio.xz: stripper=arm-linux-gnueabi-strip

all += platina-mk1-bmc.cpio.xz

machines += example-amd64
example_amd64_help := suitable for qemu-goes
example_amd64_ARCH := x86_64
example_amd64_linux_config := kvmconfig

all += example-amd64.vmlinuz

machines += example-armhf
example_armhf_help := suitable for qemu-goes
example_armhf_ARCH := arm
example_armhf_CROSS_COMPILE := arm-linux-gnueabi-
example_armhf_linux_config := olddefconfig

all += example-armhf.vmlinuz

example-armhf.dtb: dtb=vexpress-v2p-ca9.dtb

all += example-armhf.dtb

machines += platina-mk1
platina_mk1_help := Platina Systems Mark 1 Platform(s)
platina_mk1_ARCH := x86_64
platina_mk1_KERNELRELEASE := $(kernelversion)-platina-mk1
platina_mk1_KDEB_PKGVERSION := $(kerneldebver)
platina_mk1_linux_config := olddefconfig

all += $(linux_image_platina_mk1)

machines += platina-mk1-bmc
uboot_machines += platina-mk1-bmc
platina_mk1_bmc_help := Platina Systems Mark 1 Baseboard Management Controller
platina_mk1_bmc_ARCH := arm
platina_mk1_bmc_CROSS_COMPILE := arm-linux-gnueabi-
platina_mk1_bmc_linux_config := olddefconfig

all += platina-mk1-bmc.vmlinuz

# FIXME
platina-mk1-bmc.dtb: dtb=platina-bugatti-mm.dtb

all += platina-mk1-bmc.dtb

configs = $(foreach machine,$(machines),linux/$(machine)/.config)
configs+=  $(foreach machine,$(uboot_machines),u-boot/$(machine)/.config)
.PRECIOUS: $(configs)

.PHONY: all
all : $(all); $(if $(dryrun),,@:)

goesd-example: $(FORCE); $(gobuild)
goes-example-amd64: $(FORCE); $(gobuild)
goes-example-armhf: $(FORCE); $(gobuild)
goesd-platina-mk1: $(FORCE); $(gobuild)
goes-platina-mk1: $(FORCE); $(gobuild)
goes-platina-mk1-bmc: $(FORCE); $(gobuild)

example-amd64.vmlinuz: linux/example-amd64/arch/x86_64/boot/bzImage
	$(Q)install -D $? $@

example-armhf.vmlinuz: linux/example-armhf/arch/arm/boot/zImage
	$(Q)install -D $? $@

platina-mk1-bmc.vmlinuz: linux/platina-mk1-bmc/arch/arm/boot/zImage
	$(Q)install -D $? $@

.PHONY: platina-mk1-linux-image
platina-mk1-linux-image: $(platina_mk1_linux_image)

git_clean = git clean $(if $(dryrun),-n,-f) $(if $(Q),-q )-X -d

.PHONY: clean
clean: ; $(Q)$(git_clean)

.PHONY: clean-debian
clean-debian: ; $(Q)$(git_clean) -- debian/*

.PHONY: clean-dtb
clean-dtb: ; $(Q)$(git_clean) -- *.dtb

.PHONY: clean-goes
clean-goes: ; $(Q)$(git_clean) -- goes* *.cpio.xz

.PHONY: clean-linux
clean-linux: ; $(Q)$(git_clean) -- linux/*

.PHONY: clean-u-boot
clean-u-boot: ; $(Q)$(git_clean) -- u-boot/* *.u-boot

.PHONY: help
help: ; $(Q):$(info $(help))

.PHONY: show-%
show-%: ; $(Q):$(info $($*))

.PHONY: FORCE
