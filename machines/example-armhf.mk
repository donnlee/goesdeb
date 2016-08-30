#!/usr/bin/make -f

machines+= example-armhf

example_armhf_help:= suitable for qemu-goes

example_armhf_targets = example-armhf.cpio.xz
example_armhf_targets+= example-armhf.vmlinuz
example_armhf_targets+= example-armhf.dtb

all+= $(example_armhf_targets)

define example_armhf_vars
$1: arch=arm
$1: cross_compile=arm-linux-gnueabi-
$1: dtb=vexpress-v2p-ca9.dtb
$1: export GOARCH=arm
$1: export GOARM=7
$1: linux_config=olddefconfig
$1: machine=example-armhf
$1: main=github.com/platinasystems/goes/main/goes-example
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
