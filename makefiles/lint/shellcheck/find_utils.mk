# -*- makefile -*-
# -----------------------------------------------------------------------
# Intent:
#   o Construct a find command able to gather shell files for checking.
# -----------------------------------------------------------------------

## -----------------------------------------------------------------------
## Intent: Construct a string for invoking find \( excl-pattern \) -prune
# -----------------------------------------------------------------------
gen-shellcheck-find-excl = \
  $(strip \
	-name '__ignored__' \
	$(foreach dir,$($(1)),-o -name $(dir)) \
  )

## -----------------------------------------------------------------------
## Intent: Construct a find command to gather a list of python files
##         with exclusions.
## -----------------------------------------------------------------------
## Usage:
#	$(activate) & $(call gen-python-find-cmd) | $(args-n1) pylint
## -----------------------------------------------------------------------
gen-shellcheck-find-cmd = \
  $(strip \
    find . \
      \( $(call gen-shellcheck-find-excl,onf-excl-dirs) \) -prune \
      -o \( -iname '*.sh' \) \
      -print0 \
  )

# [EOF]
