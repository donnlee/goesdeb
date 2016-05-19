This repos contains control files for the following debian packages. Each
dependent, non-stdlib GO package is a submodule under the `src` directory that
is budled within the debian source tar ball.

`goesdeb` is the source package.

`goesd` is a binary package that includes the common `/etc/init.d` script and
man page.
   
`goesd-example` is an example sub-system that is run as a daemon within a
debian system.

`goes-initrd-example-amd64-linux-gnu` and
`goes-initrd-example-arm-linux-gnueabi` are the example configured to run as
standalone systems on the respective target.

Use this to build these packages,

```console
$ git-buildpackage -uc -us
```
