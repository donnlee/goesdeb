#!/usr/bin/make -f

GO ?= go
empty :=
space := $(empty) $(empty)
indent := $(empty)   $(empty)
ifeq (,$(or $(DH_VERBOSE),$(V)))
  Q := @
  I := $(Q)echo "   "
else
  I := @:$(space)
endif

ifeq (,$(shell $(GO) version 2>/dev/null))
  ifneq (,$(wildcard /usr/lib/go-1.6))
    export GOROOT := /usr/lib/go-1.6
    export PATH := ${GOROOT}/bin:${PATH}
  else
    $(error no go)
  endif
endif

dryrun := $(filter n,$(MAKEFLAGS))

gitdescribe := $(shell git describe --tags 2>/dev/null)
gitref := $(shell git rev-parse --short HEAD)
kernelversion := $(shell make -C src/linux -s kernelversion)
kerneldebver := $(shell git --git-dir src/linux/.git describe --tags \
	| sed s:^v::)

define help
`all` builds:$(foreach target,$(all),
  $(target))

Cleaning targets:
  clean		aka. `git clean -X -d`
  clean-goes	aka. `git clean -X -d -- goes*`
  clean-DIR	aka. `git clean -X -d -- DIR/*`
  clean.SUFFIX	aka. `git clean -X -d -- *.SUFFIX`

Configuration targets:
  config-MACHINE
  menuconfig-MACHINE
  nconfig-MACHINE
  xconfig-MACHINE
  gconfig-MACHINE
	Update the given machine config utilising a line-oriented,
	menu, ncurses menu, Qt, or GTK+ based programs

Flags:
   V=1	verbose
   GOTAGS="test"
	enable test commands
   GCFLAGS="-N -l"
	disable optimization and inlines for daemon targets
   GO=$(GO)
	override go program

Debug targets:
  show-VARIABLE
	print value of $$(VARIABLE)

Machines:$(foreach machine,$(machines),
  $(machine)	- $($(subst -,_,$(machine))_help))

endef

linux_configs = config
linux_configs+= menuconfig
linux_configs+= nconfig
linux_configs+= xconfig
linux_configs+= gconfig

include machines/*.mk

.PHONY: all
all : $(all); $(if $(dryrun),,@:)

define phony_machine
.PHONY: $1
$1: $($(subst -,_,$(1))_targets)
endef

$(foreach machine,$(machines),$(eval $(call phony_machine,$(machine))))

.PHONY: clean
clean: ; $(Q)$(git_clean)

.PHONY: clean-goes
clean-goes: ; $(Q)$(git_clean) -- goes*

.PHONY: clean-%
clean-%: ; $(Q)$(git_clean) -- $*

.PHONY: clean.%
clean.%: ; $(Q)$(git_clean) -- *.$*

.PHONY: help
help: ; $(Q):$(info $(help))

.PHONY: show-%
show-%: ; $(Q):$(info $($(subst -,_,$*)))

.PHONY: FORCE

xV = $(if $Q,,V=1)
xARCH = $(if $(arch), ARCH=$(arch))
xCROSS_COMPILE = $(if $(cross_compile), CROSS_COMPILE=$(cross_compile))
xDTB = $(if $(dtb), DTB=$(dtb))
xGOES = $(if $(goes), GOES=$(goes))
xIMAGE_FILE = $(if $(IMAGE_FILE), IMAGE_FILE=$(IMAGE_FILE))
xIMAGE_SIZE = $(if $(IMAGE_SIZE), IMAGE_SIZE=$(IMAGE_SIZE))
xKDEB_PKGVERSION = $(if $(kdeb_pkgversion), KDEB_PKGVERSION=$(kdeb_pkgversion))
xKERNELRELEASE = $(if $(kernelrelease), KERNELRELEASE=$(kernelrelease))
xMACHINE = $(if $(machine), MACHINE=$(machine))
xUBOOT_ENV= $(if $(uboot_env), UBOOT_ENV="$(uboot_env)")
xUBOOT_ENV_OFFSET = $(if $(uboot_env_offset),\
		    UBOOT_ENV_OFFSET=$(uboot_env_offset))
xUBOOT_ENV_SIZE = $(if $(uboot_env_size), UBOOT_ENV_SIZE=$(uboot_env_size))
xUBOOT_IMAGE = $(if $(uboot_image), UBOOT_IMAGE=$(uboot_image))
xUBOOT_IMAGE_OFFSET = $(if $(uboot_image_offset),\
		      UBOOT_IMAGE_OFFSET=$(uboot_image_offset))
xVMLINUZ=$(if $(vmlinuz), VMLINUZ=$(vmlinuz))
xVERSION=$(if $(gitdescribe), VERSION=$(gitdescribe), VERSION=$(gitref))

linux_configured = $(wildcard linux/$(machine)/.config)
uboot_configured = $(wildcard u-boot/$(machine)/.config)
coreboot_configured = $(wildcard coreboot/$(machine)/.config)

linux_defconfigs := $(wildcard configs/*.defconfig)
uboot_defconfigs := $(wildcard configs/*.u-boot_defconfig)

git_clean = git clean $(if $(dryrun),-n,-f) $(if $(Q),-q )-X -d

mkinfo = $(Q)$(info $(indent)mk $@)
fixme = : $(info FIXME$(space))

gobuild = $(gobuild_)$(GO) build -o $@
gobuild_= $(if $(dryrun),: ,$(mkinfo))

gcflags = $(if $(GCFLAGS),-gcflags="$(GCFLAGS)" )

goesd-%:
	$(gobuild) $(gcflags)$(if $(GOTAGS),-tags "$(GOTAGS)" )$(main)

goes-%:
	$(gobuild) -tags "netgo$(if $(GOTAGS), $(GOTAGS))" -ldflags "-d" $(main)

strip_program = $(if $(stripper),--strip-program=$(stripper))
cpio := cpio --quiet -H newc -o --owner 0:0
cpiofn = $(subst .xz,,$(notdir $@))
cpiotmp = $(subst .cpio.xz,.tmp,$@)

%.cpio.xz: goes-%
	$(Q)install -s $(strip_program) -D $?  $(cpiotmp)/init
	$(Q)install -d $(cpiotmp)/bin
	$(Q)ln -sf ../init $(cpiotmp)/bin/goes
	$(Q)mkdir $(cpiotmp)/etc
	$(Q)echo "nameserver 8.8.8.8" > $(cpiotmp)/etc/resolv.conf
	$(Q)rm -f $(@:%.xz=%) $@
	$(Q)cd $(cpiotmp) && find . | $(cpio) >../$(cpiofn)
	$(Q)xz --check=crc32 -9 $(cpiofn)
	$(Q)rm -rf $(cpiotmp)

uboot_mkimage = $(uboot_mkimage_)u-boot/$(machine)/tools/mkimage
uboot_mkimage+= -A $(arch)
uboot_mkimage+= -O linux
uboot_mkimage+= -T ramdisk
uboot_mkimage_= $(if $(dryrun),: ,$(mkinfo))

%.cpio.xz.u-boot: %.cpio.xz u-boot/%/tools/mkimage
	$(uboot_mkimage) -d $*.cpio.xz $@ >/dev/null

goes_linux_n_cpus := $(shell grep '^processor' /proc/cpuinfo | wc -l)

# Flags to pass to sub-makes to enable parallel builds
goes_make_parallel = -j $(shell				\
	if [ -f /proc/cpuinfo ] ; then			\
		expr 2 '*' $(goes_linux_n_cpus) ;	\
	else						\
		echo 1 ;				\
	fi)

mklinux = $(mklinux_)$(MAKE)
mklinux+= --no-print-directory
mklinux+= -C $(CURDIR)/src/linux
mklinux+= $(goes_make_parallel)
mklinux+= O=$(CURDIR)/linux/$(machine)
mklinux+= $(xV)$(xARCH)$(xCROSS_COMPILE)$(xKDEB_PKGVERSION)$(xKERNELRELEASE)
mklinux_= $(if $(dryrun),$(if $(linux_configured),+,: ),$(mkinfo)+)

%.vmlinuz: linux/%/.config
	$(mklinux) $(notdir $(vmlinuz))
	$(Q)install $(vmlinuz) $@

linux/linux-image-$(kernelversion)-%_$(kerneldebver)_amd64.deb: linux/%/.config
	$(mklinux) bindeb-pkg

%.dtb: %.vmlinuz
	$(mklinux) dtbs
	$(Q)cp linux/$(machine)/arch/arm/boot/dts/$(dtb) $@

mkuboot = $(mkuboot_)$(MAKE)
mkuboot+= --no-print-directory
mkuboot+= -C src/u-boot
mkuboot+= O=$(CURDIR)/u-boot/$(machine)
mkuboot+= $(xV)$(xARCH)$(xV)$(xCROSS_COMPILE)
mkuboot_= $(if $(dryrun),$(if $(uboot_configured),+,: ),$(mkinfo)+)

mk_u_boot_img = $(mk_u_boot_img_)sudo scripts/mk-u-boot-img
mk_u_boot_img+= $(xMACHINE)
mk_u_boot_img+= $(xDTB)
mk_u_boot_img+= $(xGOES)
mk_u_boot_img+= $(xIMAGE_FILE)
mk_u_boot_img+= $(xIMAGE_SIZE)
mk_u_boot_img+= $(xUBOOT_ENV)
mk_u_boot_img+= $(xUBOOT_ENV_OFFSET)
mk_u_boot_img+= $(xUBOOT_ENV_SIZE)
mk_u_boot_img+= $(xUBOOT_IMAGE)
mk_u_boot_img+= $(xUBOOT_IMAGE_OFFSET)
mk_u_boot_img+= $(xVERSION)
mk_u_boot_img+= $(xVMLINUZ)
mk_u_boot_img_= $(if $(dryrun),: ,$(mkinfo))

u-boot/%/tools/mkimage u-boot/%/u-boot u-boot/%/u-boot.imx: u-boot/%/.config
	$(mkuboot)

u-boot/%/.config:
	$(Q)mkdir -p u-boot/$*
	$(mkuboot) $(uboot_defconfig)

%.u-boot.img: goes-% %.vmlinuz %.dtb u-boot/%/u-boot.imx
	$(mk_u_boot_img)

mkcoreboot = $(mkcoreboot_)$(MAKE)
mkcoreboot+= --no-print-directory
mkcoreboot+= -C src/coreboot
mkcoreboot+= O=$(CURDIR)/coreboot/$(machine)
mkcoreboot_= $(if $(dryrun),$(if $(coreboot_configured),+,: ),$(mkinfo)+)

coreboot/%/.config:
	$(Q)mkdir -p coreboot/$*
	$(mkcoreboot) $(coreboot_crossgcc)
	$(mkcoreboot) $(coreboot_defconfig)

coreboot-%.rom: coreboot/%/.config %.vmlinuz %.cpio.xz
	$(mkcoreboot)
	$(Q)cp coreboot/$*/coreboot.rom $@

config-%: linux_config=config
menuconfig-%: linux_config=menuconfig
nconfig-%: linux_config=nconfig
xconfig-%: linux_config=xconfig
gconfig-%: linux_config=gconfig

linux/%/.config:
	$(Q)mkdir -p linux/$(machine)
	$(Q)cp configs/$(machine).defconfig linux/$(machine)/.config
	$(mklinux) $(linux_config)
	$(Q)cp linux/$(machine)/.config configs/$(machine).defconfig

config-% menuconfig-% nconfig-% xconfig-% gconfig-%:
	$(Q)mkdir -p linux/$(machine)
	$(Q)cp configs/$(machine).defconfig linux/$(machine)/.config
	$(mklinux) $(subst -$*,,$@)
	$(Q)cp linux/$(machine)/.config configs/$(machine).defconfig

.PRECIOUS: $(foreach machine,$(machines),\
	linux/$(machine)/.config\
	linux/$(machine)/arch/x86_64/boot/bzImage\
	linux/$(machine)/arch/arm/boot/zImage\
	u-boot/$(machine)/.config)
