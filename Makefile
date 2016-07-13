#!/usr/bin/make -f

empty :=
space := $(empty) $(empty)
indent := $(empty)   $(empty)
ifeq (,$(or $(DH_VERBOSE),$(V)))
  Q := @
  I := $(Q)echo "   "
else
  I := @:$(space)
endif

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

goesversion := $(shell git --git-dir src/github.com/platinasystems/goes/.git \
	describe --tags)
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

Debug targets:
  show-VARIABLE
	print value of $$(VARIABLE)

Machines:$(foreach machine,$(machines),
  $(machine)	- $($(subst -,_,$(machine))_help))

U-boot images: (made with sudo and *not* included in "all")
	platina-mk1-bmc.u-boot.img
endef

machines = example
machines+= example-amd64
machines+= example-armhf
machines+= platina-mk1
machines+= platina-mk1-bmc

linux_configs = config
linux_configs+= menuconfig
linux_configs+= nconfig
linux_configs+= xconfig
linux_configs+= gconfig

example_help:= a daemon suitable for any debian system
define example_vars
$1: export GOARCH=amd64
$1: gotags=$(GOTAGS)
$1: machine=example
$1: main=github.com/platinasystems/goes/example
endef

$(eval $(call example_vars,goesd-example))

example_targets = goesd-example

all+= $(example_targets)

example_amd64_help:= suitable for qemu-goes
define example_amd64_vars
$1: arch=x86_64
$1: export GOARCH=amd64
$1: linux_config=kvmconfig
$1: machine=example-amd64
$1: main=github.com/platinasystems/goes/example
$1: vmlinuz=linux/example-amd64/arch/x86_64/boot/bzImage
endef

$(eval $(call example_amd64_vars,example-amd64.cpio.xz))
$(eval $(call example_amd64_vars,linux/example-amd64/.config))
$(eval $(call example_amd64_vars,linux/example-amd64/arch/x86_64/boot/bzImage))
$(eval $(call example_amd64_vars,example-amd64.vmlinuz))

$(foreach c,$(linux_configs),\
	$(eval $(call example_amd64_vars,$(c)-example-amd64)))

example_amd64_targets = example-amd64.cpio.xz
example_amd64_targets+= example-amd64.vmlinuz

all+= $(example_amd64_targets)

example_armhf_help:= suitable for qemu-goes
define example_armhf_vars
$1: arch=arm
$1: cross_compile=arm-linux-gnueabi-
$1: dtb=vexpress-v2p-ca9.dtb
$1: export GOARCH=arm
$1: export GOARM=7
$1: linux_config=olddefconfig
$1: machine=example-armhf
$1: main=github.com/platinasystems/goes/example
$1: stripper=arm-linux-gnueabi-strip
$1: vmlinuz=linux/example-armhf/arch/arm/boot/zImage
endef

$(eval $(call example_armhf_vars,example-armhf.cpio.xz))
$(eval $(call example_armhf_vars,linux/example-armhf/.config))
$(eval $(call example_armhf_vars,linux/example-armhf/arch/arm/boot/zImage))
$(eval $(call example_armhf_vars,example-armhf.vmlinuz))
$(eval $(call example_armhf_vars,example-armhf.dtb))

$(foreach c,$(linux_configs),\
	$(eval $(call example_armhf_vars,$(c)-example-armhf)))

example_armhf_targets = example-armhf.cpio.xz
example_armhf_targets+= example-armhf.vmlinuz
example_armhf_targets+= example-armhf.dtb

all+= $(example_armhf_targets)

platina_mk1_help := Platina Systems Mark 1 Platform(s)
define platina_mk1_vars
$1: arch=x86_64
$1: export GOARCH=amd64
$1: kernelrelease=$(kernelversion)-platina-mk1
$1: kdeb_pkgversion=$(kerneldebver)
$1: linux_config=olddefconfig
$1: machine=platina-mk1
$1: main=github.com/platinasystems/goes/platina/mk1
$1: vmlinuz=linux/platina-mk1/arch/x86_64/boot/bzImage
endef

platina_mk1_deb = linux/linux-image-$(kernelversion)-platina-mk1_$(kerneldebver)_amd64.deb

$(eval $(call platina_mk1_vars,goesd-platina-mk1))
$(eval $(call platina_mk1_vars,platina-mk1.cpio.xz))
$(eval $(call platina_mk1_vars,linux/platina-mk1/.config))
$(eval $(call platina_mk1_vars,linux/platina-mk1/arch/x86_64/boot/bzImage))
$(eval $(call platina_mk1_vars,platina-mk1.vmlinuz))
$(eval $(call platina_mk1_vars,$(platina_mk1_deb)))

$(foreach c,$(linux_configs),\
	$(eval $(call platina_mk1_vars,$(c)-platina-mk1)))

platina_mk1_targets = goesd-platina-mk1
platina_mk1_targets+= platina-mk1.cpio.xz
platina_mk1_targets+= $(platina_mk1_deb)

all+= $(platina_mk1_targets)

platina_mk1_bmc_uboot_env+='fdt_high=0xffffffff'
platina_mk1_bmc_uboot_env+='bootdelay=1'
platina_mk1_bmc_uboot_env+='bootargs=console=ttymxc0,115200 quiet root=/dev/mmcblk0p1 rootfstype=ext4 rootwait rw init=/init'
platina_mk1_bmc_uboot_env+='bootcmd=ext2load mmc 0:1 0x82000000 /boot/zImage; ext2load mmc 0:1 0x88000000 /boot/${boot_dtb}; bootz 0x82000000 - 0x88000000'

platina_mk1_bmc_help := Platina Systems Mark 1 Baseboard Management Controller
define platina_mk1_bmc_vars
$1: arch=arm
$1: cross_compile=arm-linux-gnueabi-
$1: dtb=platina-mk1-bmc.dtb
$1: export GOARCH=arm
$1: export GOARM=7
$1: linux_config=olddefconfig
$1: machine=platina-mk1-bmc
$1: main=github.com/platinasystems/goes/platina/mk1/bmc
$1: stripper=arm-linux-gnueabi-strip
$1: vmlinuz=linux/platina-mk1-bmc/arch/arm/boot/zImage
$1: uboot_env=$(platina_mk1_bmc_uboot_env)
endef

$(eval $(call platina_mk1_bmc_vars,goes-platina-mk1-bmc))
$(eval $(call platina_mk1_bmc_vars,linux/platina-mk1-bmc/arch/arm/boot/zImage))
$(eval $(call platina_mk1_bmc_vars,platina-mk1-bmc.vmlinuz))
$(eval $(call platina_mk1_bmc_vars,platina-mk1-bmc.dtb))
$(eval $(call platina_mk1_bmc_vars,u-boot/platina-mk1-bmc/.config))
$(eval $(call platina_mk1_bmc_vars,u-boot/platina-mk1-bmc/tools/mkimage))
$(eval $(call platina_mk1_bmc_vars,u-boot/platina-mk1-bmc/u-boot.imx))
$(eval $(call platina_mk1_bmc_vars,platina-mk1-bmc.u-boot.img))

$(foreach c,$(linux_configs),\
	$(eval $(call platina_mk1_bmc_vars,$(c)-platina-mk1-bmc)))

platina_mk1_bmc_targets = goes-platina-mk1-bmc
platina_mk1_bmc_targets+= platina-mk1-bmc.vmlinuz
platina_mk1_bmc_targets+= platina-mk1-bmc.dtb
platina_mk1_bmc_targets+= platina-mk1-bmc.u-boot.img

# NOTE don't build platina-mk1-bmc.u-boot.img w/ all b/c it needs sudo
all+= $(filter-out %.u-boot.img,$(platina_mk1_bmc_targets))

.PHONY: all
all : $(all); $(if $(dryrun),,@:)

.PHONY: example
example: $(example_targets)

.PHONY: example-amd64
example-amd64: $(example_amd64_targets)

.PHONY: example-armhf
example-armhf: $(example_armhf_targets)

.PHONY: platina-mk1
platina-mk1: $(platina_mk1_targets)

.PHONY: platina-mk1-bmc
platina-mk1-bmc: $(platina_mk1_bmc_targets)

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
xIMAGE_FILE = $(if $(image_file), IMAGE_FILE-$(image_file))
xIMAGE_SIZE = $(if $(image_size), IMAGE_SIZE-$(image_size))
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
xVERSION=$(if $(goesversion), VERSION=$(goesversion))

linux_configured = $(wildcard linux/$(machine)/.config)
uboot_configured = $(wildcard u-boot/$(machine)/.config)

linux_defconfigs := $(wildcard configs/*.defconfig)
uboot_defconfigs := $(wildcard configs/*.u-boot_defconfig)

git_clean = git clean $(if $(dryrun),-n,-f) $(if $(Q),-q )-X -d

mkinfo = $(Q)$(info $(indent)mk $@)
fixme = : $(info FIXME$(space))

gobuild = $(gobuild_)go build -o $@
gobuild_= $(if $(dryrun),: ,$(mkinfo))

goesd-%:
	$(gobuild) $(if $(GOTAGS),-tags "$(GOTAGS)" )$(main)

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

u-boot/%/.config: configs/%.u-boot_defconfig
	$(Q)mkdir -p u-boot/$*
	$(Q)cp $< u-boot/$*/.config
	$(mkuboot) olddefconfig

%.u-boot.img: goes-% %.vmlinuz %.dtb u-boot/%/u-boot.imx
	$(mk_u_boot_img)

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
