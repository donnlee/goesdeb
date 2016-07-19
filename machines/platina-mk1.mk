#!/usr/bin/make -f

machines+= platina-mk1

platina_mk1_help := Platina Systems Mark 1 Platform(s)

platina_mk1_deb = linux/linux-image-$(kernelversion)-platina-mk1_$(kerneldebver)_amd64.deb

platina_mk1_targets = goesd-platina-mk1
platina_mk1_targets+= platina-mk1.cpio.xz
platina_mk1_targets+= $(platina_mk1_deb)

all+= $(platina_mk1_targets)

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

$(eval $(call platina_mk1_vars,goesd-platina-mk1))
$(eval $(call platina_mk1_vars,platina-mk1.cpio.xz))
$(eval $(call platina_mk1_vars,linux/platina-mk1/.config))
$(eval $(call platina_mk1_vars,linux/platina-mk1/arch/x86_64/boot/bzImage))
$(eval $(call platina_mk1_vars,platina-mk1.vmlinuz))
$(eval $(call platina_mk1_vars,$(platina_mk1_deb)))

$(foreach c,$(linux_configs),\
	$(eval $(call platina_mk1_vars,$(c)-platina-mk1)))