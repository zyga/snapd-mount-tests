shell_files=$(shell find . -path .git -prune -o -type f -a -name '*.sh' -print) bin/GREP
yaml_files=$(shell find . -path .git -prune -o -type f -a -name '*.yaml' -print)

.PHONY: all clean
all:
	echo "There's nothing to build here"
clean:
	false # TODO: implement this

.PHONY: check check-sh check-spread
check: check-sh check-spread

.PHONY: fmt fmt-sh fmt-yaml
fmt: fmt-sh fmt-yaml

fmt-sh: SHFMT ?= $(or $(shell command -v shfmt),$(error shfmt is required to format shell scripts))
fmt-sh: $(shell_files)
	shfmt --write $^
fmt-yaml: YAMLFMT ?= $(or $(shell command -v yamlfmt),$(error yamlfmt from github.com/google/yamlfmt is required to format yaml files))
fmt-yaml: $(yaml_files)
	$(YAMLFMT) $^

check-sh: SHELLCHECK ?= $(or $(shell command -v shellcheck),$(error shellcheck is required for static analysis of shell scripts))
check-sh: $(shell_files)
	$(SHELLCHECK) -x $^

# In CI systems, the CI variable is set to a non-empty value. Use it to disable SPREAD_QEMU_GUI, control -debug, -reuse and -resend.
check-spread: SPREAD ?= $(or $(shell command -v spread),$(error spread is required for integration tests))
check-spread: SPREAD_REUSE_ARG ?= $(if $(value CI),,-reuse)
check-spread: SPREAD_DEBUG_ARG ?= $(if $(value CI),,-debug)
check-spread: SPREAD_RESEND_ARG ?= $(if $(value CI),,-resend)
check-spread: export SPREAD_QEMU_GUI ?= $(if $(value CI),0,1)
check-spread: SPREAD_SYSTEM ?=
check-spread: SPREAD_TASK ?= passing/
check-spread: spread.yaml $(shell find passing/ -name task.yaml) $(shell find failing -name task.yaml)
check-spread: | $(if $(value SPREAD_SYSTEM),$(HOME)/.spread/qemu/$(SPREAD_SYSTEM).img,$(foreach img,$(foreach r,12 13 sid,debian-$r.img) $(foreach r,20.04 22.04 24.04,ubuntu-$r.img),$(HOME)/.spread/qemu/$(img)))
check-spread: | $(HOME)/.spread/qemu/bios/uefi.img
	$(strip $(SPREAD) -v $(SPREAD_DEBUG_ARG) $(SPREAD_RESEND_ARG) $(SPREAD_REUSE_ARG) $(SPREAD_SYSTEM):$(SPREAD_TASK))
	# Nothing there yet, skip it for now. Later on this should probably list tests and run one-by-one ensuring it fails.
	# $(strip ! $(SPREAD) -v $(SPREAD_REUSE_ARG) $(SPREAD_SYSTEM):failing/)

# Spread requires all the images to live in ~/.spread/qemu, with bios in ~/.spread/qemu/bios/uefi.img
$(HOME)/.spread:
		mkdir $@
$(HOME)/.spread/qemu: | $(HOME)/.spread
		mkdir $@
$(HOME)/.spread/qemu/bios: | $(HOME)/.spread/qemu
		mkdir $@
$(HOME)/.spread/qemu/%.img: %.img | $(HOME)/.spread/qemu
		ln -sf $(CURDIR)/$< $@
$(HOME)/.spread/qemu/bios/uefi.img: /usr/share/ovmf/OVMF.fd | $(HOME)/.spread/qemu/bios
		cp $< $@

# Ubuntu images are built using autopkgtest-buildvm-ubuntu-cloud.
ubuntu-%.img: AUTOPKGTEST_BUILDVM_UBUNTU_CLOUD ?= $(or $(shell command -v autopkgtest-buildvm-ubuntu-cloud),$(error autopkgtest-buildvm-ubuntu-cloud is required for building ubuntu images))
ubuntu-%.img: codename_24.04=noble
ubuntu-%.img: codename_22.04=jammy
ubuntu-%.img: codename_20.04=focal
ubuntu-20.04.img ubuntu-22.04.img ubuntu-24.04.img: ubuntu-%.img:
	# There's no way to control the name of the image so rename it explicitly.
	$(AUTOPKGTEST_BUILDVM_UBUNTU_CLOUD) \
		--release $(codename_$*) \
		--arch amd64 \
		--ram-size 2048 \
		--cpus 4 \
		--verbose
	mv autopkgtest-$(codename_$*)-amd64.img $@

# Debian images are built using autopkgtest-build-qemu.
debian-%.img: AUTOPKGTEST_BUILD_QEMU ?= $(or $(shell command -v autopkgtest-build-qemu),$(error autopkgtest-build-qemu is required for building debian images))
debian-%.img: codename_12=bookworm
debian-%.img: codename_13=trixie
debian-%.img: codename_sid=sid
debian-12.img debian-13.img debian-sid.img: debian-%.img: prepare-debian-qemu.sh
	# Using fakemachine is unreliable, use sudo instead.
	sudo $(AUTOPKGTEST_BUILD_QEMU) \
		--boot efi \
		--init systemd \
		--architecture amd64 \
		--script $< \
		$(codename_$*) $@
	sudo chown `id -u`:`id -g` $@

# NOTE: spread doesn't boot images the same way.
.PHONY: shell
shell: SPREAD_SYSTEM ?= $(error Set SPREAD_SYSTEM to the name of the image to boot)
shell: QEMU_SYSTEM_X86_64 ?= $(or $(shell command -v qemu-system-x86_64),$(error qemu-system-x86_64 is required for interactive shell in test virtual machine))
shell: $(SPREAD_SYSTEM).img
	$(QEMU_SYSTEM_X86_64) \
	-snapshot \
	-bios /usr/share/ovmf/OVMF.fd \
	-accel kvm \
	-m 2048 \
	-smp 4 \
	-device virtio-net-pci,netdev=net0 \
	-netdev user,id=net0 \
	-object rng-random,filename=/dev/urandom,id=rng0 \
	-nographic \
	$<

.PHONY: fetch-snaps
fetch-snaps:
	. ./snap-revs.$(shell uname -m).sh && $(MAKE) -f spread.mk $@
