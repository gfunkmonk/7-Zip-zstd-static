[![build](https://github.com/spvkgn/7zip-static/actions/workflows/build.yml/badge.svg)](https://github.com/spvkgn/7zip-static/actions/workflows/build.yml)
# 7-Zip static build
* statically linked `7zz` built with musl libc
* applied patches from Debian:
	* Disable local echo display when in input passwords
	* Use system locale to select codepage for legacy zip archives
