# Snapd mount tests

Snapd uses an elaborate mount namespace system for running snap applications.
One consequence of the design, is that the mount namespace of a given snap,
once created, is persisted until the snap is removed, the system is rebooted or
until one of the conditions that necessitate its re-construction occurs.

A persisted mount namespace may be updated due to snap refreshes or snap
interface connection changes. Over time we've found countless bugs in this
design as the behavior of a mount namespace is highly complex, with propagation
events and propagation control. Many bugs have since been fixed and some of the
logic behind the mount namespace construction and update have been revised to
behave in a more robust manner but more bugs are known and need to be fixed.

As a part of preparation for the third iteration of the implementation, a
number of tests exploring curious properties of the snapd mount namespace
system are provided. Tests are split into two main groups - failing and passing.
Failing tests indicate behaviors that are known to misbehave.

The project explicitly does not build snapd, instead testing either snapd from
the archive, from the snap store or one built locally and provided to the test
system.

Tests are implemented in spread (https://github.com/snapcore/spread) and
executed on top of Debian unstable, as Ubuntu autopkgtest images failed to
build for me for reasons I was unable to debug further and it doesn't really
matter from the point of view of the mount algorithm.

One needs to build and install spread locally. Stock spread should work
although testing was peformed with a locally built for of spread, with several
bug fixes and improvements.

## Usage

Run this once to cache large snaps and reuse them offline (especially locally in qemu).
```sh
make fetch-snaps
```

This runs all the checks:
```sh
make check
```
