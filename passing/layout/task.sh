#!/bin/sh
set -xeu

check_mimic() {
	# Depending on the destination of the bind mount, we have different expected source.
	case "$BIND_TO" in
	/etc/*)
		cat <<__INFO__
When layouts bind to /etc or below, then they act on top of a view of the
host's /etc.  As such the mimic is not faithful in relation to the base snap.
__INFO__
		mimic_source=/var/lib/snapd/hostfs/etc
		;;
	/usr/share/doc/*)
		cat <<__INFO__
When layouts bind to /usr/share/doc or below, then they act on top of a view of
the host's /usr/share/doc.  As such the mimic is not faithful in relation to
the base snap.
__INFO__
		mimic_source=/var/lib/snapd/hostfs/usr/share/doc
		;;
	*)
		cat <<__INFO__
 Since layouts create new entries in an otherwise read-only file system, they
 are im
 tmpfs, and populated with bind mounts to the original location.  Ensure that
 all such entries are present.
__INFO__
		mimic_source=/snap/core24/current
		;;
	esac

	parent_dir="$(dirname "$BIND_TO")"

	find "${mimic_source}${parent_dir}" -maxdepth 1 -printf '%P\n' | while read -r f; do
		# Some directories are special.
		case "$parent_dir/$f" in
		"$parent_dir/")
			echo "The top-level directory itself is not the same, as we have created a mimic at $parent_dir."
			# shellcheck disable=SC2016
			if nsenter -m/run/snapd/ns/test-snapd-layout.mnt bash -c "test \"${mimic_source}${parent_dir}\" -ef \"$parent_dir\""; then
				exit 1
			fi
			;;
		/var/lib/snapd)
			if nsenter -m/run/snapd/ns/test-snapd-layout.mnt bash -c 'test /var/lib/snapd/hostfs/var/lib/snap" -ef /var/lib/snap'; then
				exit 1
			fi
			;;
		/usr/lib/snapd)
			echo "The /var/lib/snapd directory is always provided from the host."
			if nsenter -m/run/snapd/ns/test-snapd-layout.mnt bash -c 'test /var/lib/snapd/hostfs/usr/lib/snapd" -ef /usr/lib/snapd'; then
				exit 1
			fi
			;;
		/usr/src)
			echo "The directory /usr/src is shared from the host, so that snaps can access kernel source code."
			if nsenter -m/run/snapd/ns/test-snapd-layout.mnt bash -c 'test /var/lib/snapd/hostfs/usr/src" -ef /usr/src'; then
				exit 1
			fi
			;;
		/usr/lib/firmware)
			echo "The directory /usr/lib/firmware is shared from the host, so that snaps can trigger kernel to load firmware and, do so from the snap mount namespace."
			if nsenter -m/run/snapd/ns/test-snapd-layout.mnt bash -c 'test /var/lib/snapd/hostfs/usr/lib/firmware" -ef /usr/lib/firmware'; then
				exit 1
			fi
			;;
		/usr/lib/modules)
			echo "The directory /usr/lib/modules is shared from the host, so that snaps can trigger kernel to load modules, and do so from the snap mount namespace."
			if nsenter -m/run/snapd/ns/test-snapd-layout.mnt bash -c 'test /var/lib/snapd/hostfs/usr/lib/modules" -ef /usr/lib/modules'; then
				exit 1
			fi
			;;
		*)
			# shellcheck disable=SC2016
			if ! nsenter -m/run/snapd/ns/test-snapd-layout.mnt bash -c "set -x; test \"${mimic_source}${parent_dir}/$f\" -ef \"${parent_dir}/$f\""; then
				nsenter -m/run/snapd/ns/test-snapd-layout.mnt stat "${mimic_source}${parent_dir}/$f" >&2
				nsenter -m/run/snapd/ns/test-snapd-layout.mnt stat "${parent_dir}/$f" >&2
				echo "Error: ${mimic_source}${parent_dir}/$f is not the same file as ${parent_dir}/$f" >&2
				exit 1
			fi
			;;
		esac
	done
}

check_canary() {
	cat <<__INFO__
    Check that the canary.txt file is the same file inside the snap and in the
    layout directory. Check that it has the expected text.
__INFO__
	# shellcheck disable=SC2016
	snap run test-snapd-layout.sh -c 'test -f "$SNAP"/foo/canary.txt'
	# shellcheck disable=SC2016
	snap run test-snapd-layout.sh -c 'test -f "$BIND_TO"/canary.txt'
	# shellcheck disable=SC2016
	snap run test-snapd-layout.sh -c 'cat "$BIND_TO"/canary.txt' | GREP 'This is a canary file'
	# shellcheck disable=SC2016
	snap run test-snapd-layout.bash -c 'test "$BIND_TO"/canary.txt -ef "$SNAP"/foo/canary.txt'
}

case "$1" in
prepare)
	sed -e "s,@BIND_TO@,$BIND_TO,g" test-snapd-layout/meta/snap.yaml.in >test-snapd-layout/meta/snap.yaml
	snap pack test-snapd-layout
	;;
execute)
	sudo snap remove --purge test-snapd-layout
	# The number of revisions here is more than the retention period, guaranteeing that the oldest loop devices are reused.
	for r in x1 x2 x3 x4 x5; do
		sudo snap install --dangerous ./test-snapd-layout_a_all.snap
		# shellcheck disable=SC2016
		snap run test-snapd-layout.sh -c 'echo "$SNAP_REVISION"' | GREP -F "$r"
		check_canary
		check_mimic
	done
	;;
restore)
	sudo snap remove --purge test-snapd-layout
	rm -f test-snapd-layout_a_all.snap
	;;
debug)
	set +e # Debug instructions may be fragile, but we want them.
	echo "The snap.yaml file we used was saved to snap.yaml.txt"
	cat test-snapd-layout/meta/snap.yaml >snap.yaml.txt
	echo "The mount table of the snap was saved to mountinfo.txt"
	nsenter -m/run/snapd/ns/test-snapd-layout.mnt cat /proc/self/mountinfo >mountinfo.txt
	;;
*)
	echo "Unknown task command $1" >&2
	exit 1
	;;
esac
