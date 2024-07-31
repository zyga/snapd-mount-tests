# This makefile is also used inside the test environment.
TEST_CORE24_REV_A ?= $(error spread.yaml should have set TEST_CORE24_REV_A)
TEST_CORE24_REV_B ?= $(error spread.yaml should have set TEST_CORE24_REV_B)

SNAP ?= $(or $(shell command -v snap),$(error Managing snaps requires snapd to be installed))

.PHONY: install-snaps
install-snaps: snapd_$(TEST_SNAPD_REV).snap snapd_$(TEST_SNAPD_REV).assert
install-snaps: core24_$(TEST_CORE24_REV_A).snap core24_$(TEST_CORE24_REV_A).assert
install-snaps: core24_$(TEST_CORE24_REV_B).snap core24_$(TEST_CORE24_REV_B).assert
install-snaps:
	$(foreach f,$(filter %.assert,$^),$(SNAP) ack ./$f;)
	$(foreach f,$(sort $(filter %.snap,$^)),$(SNAP) install ./$f;)

.PHONY: remove-snaps
remove-snaps:
	$(SNAP) remove --purge core24
	$(SNAP) remove --purge snapd

.PHONY: fetch-snaps
fetch-snaps: snapd_$(TEST_SNAPD_REV).snap snapd_$(TEST_SNAPD_REV).assert
fetch-snaps: core24_$(TEST_CORE24_REV_A).snap core24_$(TEST_CORE24_REV_A).assert
fetch-snaps: core24_$(TEST_CORE24_REV_B).snap core24_$(TEST_CORE24_REV_B).assert

# TODO: use conditional logic to use grouped targets when supported by make.
# XXX: $(.FEATURES) seems to contain grouped-targets on make 4.3 when this doesn't really work?
# https://www.gnu.org/software/make/manual/html_node/Multiple-Targets.html
core24_%.snap core24_%.assert:
	$(SNAP) download core24 --revision=$*
snapd_%.snap snapd_%.assert:
	$(SNAP) download snapd --revision=$*
