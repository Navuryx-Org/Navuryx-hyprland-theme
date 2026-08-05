# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Navuryx Python Dependencies"
HOMEPAGE=""

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~x86"

DEPEND=""
RDEPEND="
	dev-python/clang
	dev-python/uv
	gui-libs/gtk
	gui-libs/libadwaita
	net-libs/libsoup
	dev-libs/libportal
	dev-libs/gobject-introspection
"
