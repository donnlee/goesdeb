#!/usr/bin/make -f

machines+= example-amd64

example_amd64_help:= suitable for qemu-goes

example_amd64_targets = example-amd64.cpio.xz
example_amd64_targets+= example-amd64.vmlinuz

all+= $(example_amd64_targets)

define example_amd64_vars
$1: arch=x86_64
$1: export GOARCH=amd64
$1: linux_config=kvmconfig
$1: machine=example-amd64
$1: main=github.com/platinasystems/goes/main/goes-example
$1: vmlinuz=linux/example-amd64/arch/x86_64/boot/bzImage
$1: coreboot_defconfig=example-amd64_defconfig
$1: coreboot_crossgcc=crossgcc-i386
endef

$(eval $(call example_amd64_vars,example-amd64.cpio.xz))
$(eval $(call example_amd64_vars,linux/example-amd64/.config))
$(eval $(call example_amd64_vars,linux/example-amd64/arch/x86_64/boot/bzImage))
$(eval $(call example_amd64_vars,example-amd64.vmlinuz))
$(eval $(call example_amd64_vars,coreboot/example-amd64/.config))
$(eval $(call example_amd64_vars,coreboot-example-amd64.rom))

$(foreach c,$(linux_configs),\
	$(eval $(call example_amd64_vars,$(c)-example-amd64)))
