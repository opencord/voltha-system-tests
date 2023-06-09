# Howto create a python 3.10+ patch

1) Checkout voltha-docs
2) cd voltha-docs
3) make venv
4) make patch-init
5) modify the file to be patched beneath staging/${relative_path_to_patch}
6) make patch-create PATCH_PATH=${relative_path_to_patch}
    o This will create patches/${relative_path_to_patch}/patch
7) Verify
    o make sterile
    o make venv

# Howto apply python 3.10+ patches

See repo:voltha-docs for a working example.

1) Modify Makefile
2) Add target

# [EOF]