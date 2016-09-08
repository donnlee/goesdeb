This repos contains control files for the following debian packages. Each
dependent, non-stdlib GO package is a submodule under the `src` directory that
is budled within the debian source tar ball. Also included with `src` is the
linux kernel used to build qemu, BMC, and other machine kernels.

`goesdeb` is the source package.

`goesd` is a binary package that includes the common `/etc/init.d` script and
man page.
   
`goesd-example` is an example sub-system that is run as a daemon within a
debian system.

`qemu-goes-example-amd64` and `qemu-goes-example-armhf` are the example
configured to run as an initrd for qemu evaluation of the respective target.
The kernel and initrd are installed in `/usr/share/goes/example_ARCH.vmlinuz`
and `/usr/share/goes/example_ARCH.cpio.xz`. These may be run with the
`qemu-goes` script contained in the so named package like this,

```console
$ cd /usr/share/goes
$ ./qemu-goes -q example_amd64.vmlinuz example_amd64.cpio.xz
```

`goes-bmc-armhf` contains the `vmlinuz` and `initrd` for the Platina Systems' 
Baseboard Management Controller.

Run this to build the source and all binary packages,

```console
$ debuild -e GOPATH -uc -us
```

or skip the source package,

```console
$ debuild -e GOPATH -b -uc -us
```
