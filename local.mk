# Buildroot package source overrides for local development.
# See: https://buildroot.org/downloads/manual/manual.html#_using_buildroot_during_development
#
# offlinelab-framework now lives in ./framework/ and uses SITE_METHOD = local,
# so no override is needed. Add overrides here only for packages that still
# fetch from external git repos (e.g. offlinelab-disco).

# OFFLINELAB_DISCO_OVERRIDE_SRCDIR = /path/to/disco
