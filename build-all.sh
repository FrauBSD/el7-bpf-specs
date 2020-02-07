#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to build bpftrace on CentOS 7.7+ $
# $Copyright: 2020 Devin Teske. All rights reserved. $
# $FrauBSD: el7-bpf-specs/build-all.sh 2020-02-06 18:01:24 -0800 freebsdfrau $
#
############################################################ GLOBALS

pgm="${0##*/}" # Program basename

#
# Global exit status
#
SUCCESS=0
FAILURE=1

############################################################ FUNCTIONS

eval2(){ printf "\033[32;1m==>\033[m %s\n" "$*"; eval "$@"; }
have(){ type "$@" > /dev/null 2>&1; }
quietly(){ "$@" > /dev/null 2>&1; }
usage(){ die "Usage: %s\n" "$pgm"; }

die()
{
	local fmt="$1"
	if [ "$fmt" ]; then
		shift 1 # fmt
		printf "$fmt\n" "$@" >&2
	fi
	exit $FAILURE
}

rpmfilenames()
{
	local OPTIND=1 OPTARG flag
	local exclude=
	local spec
	local sp="[[:space:]]*"
	local dist=

	while getopts x: flag; do
		case "$flag" in
		x) exclude="$OPTARG" ;;
		esac
	done
	shift $(( $OPTIND - 1 ))

	spec="$1"

	case "$( cat /etc/redhat-release )" in
	*" 7."*) dist=.el7 ;;
	esac

	awk -v name_regex="^$sp[Nn][Aa][Mm][Ee]:$sp" \
	    -v vers_regex="^$sp[Vv][Ee][Rr][Ss][Ii][Oo][Nn]:$sp" \
	    -v vrel_regex="^$sp[Rr][Ee][Ll][Ee][Aa][Ss][Ee]:$sp" \
	    -v arch_regex="^$sp[Bb][Uu][Ii][Ll][Dd][Aa][Rr][Cc][Hh]:$sp" \
	    -v dist="$dist" \
	    -v default_arch="$( uname -p )" \
	    -v exclude="$exclude" '
	################################################## BEGIN

	BEGIN {
		pkg = 0
		delete g # globals array
	}

	################################################## FUNCTIONS

	function show(name,        var, val, left, right)
	{
		gsub(/%\{\?dist\}/, dist, name)
		right = name
		while (1) {
			if (!match(right, /%{[^}]+}/)) break
			var = substr(right, RSTART + 2, RLENGTH - 3)
			val = var ~ /with_static/ ? "" : g[var]
			left = left substr(right, 1, RSTART - 1) val
			right = substr(right, RSTART + RLENGTH)
		}
		left = left right
		if (exclude != "" && left ~ exclude) return
		print left ".rpm"
		shown++
	}

	function dump()
	{
		if (pkgname == "") return
		show(sprintf("%s-%s-%s.%s", pkgname, vers, vrel,
			pkgarch == "" ? default_arch : pkgarch))
		pkgname = pkgarch = ""
	}

	################################################## MAIN

	$1 == "%global" { g[$2] = $3 }

	$1 == "%package" {
		dump()
		pkg = 1
		pkgname = $2 == "-n" ? $3 : name "-" $2
	}

	sub(name_regex, "") { name = g["name"] = $0 }
	sub(vers_regex, "") { vers = g["vers"] = $0 }
	sub(vrel_regex, "") { vrel = g["rel"] = $0 }

	sub(arch_regex, "") {
		if (pkg) pkgarch = $0; else arch = g["arch"] = $0
	}

	################################################## END

	END {
		dump()
		varch = arch == "" ? default_arch : arch
		if (name vers vrel != "")
			show(sprintf("%s-%s-%s.%s", name, vers, vrel, varch))
		if (shown == 0) exit 1
		show(sprintf("%s-debuginfo-%s-%s.%s", name, vers, vrel, varch))
	}
	' "$spec"
}

deps()
{
	local spec="$1"
	awk '/^BuildRequires:/{print $2}' "$spec"
}

build()
{
	local OPTIND=1 OPTARG flag
	local exclude=
	local tool

	while getopts x: flag; do
		case "$flag" in
		x) exclude="$OPTARG" ;;
		esac
	done
	shift $(( $OPTIND - 1 ))

	tool="$1"

	if have figlet; then
		printf "\033[36m%s\033[m\n" "$( figlet "$tool" )"
	else
		printf "\033[36m#\n# Building %s\n#\033m\n" "$tool"
	fi

	local file name
	local exists=1
	for file in $( rpmfiles ${exclude:+-x"$exclude"} $tool/$tool.spec ); do
		name="${file##*/}"
		if [ -e "$file" ]; then
			echo "$name exists"
			continue
		fi
		echo "$file does not exist"
		exists=
	done
	if [ "$exists" ]; then
		echo "All RPMS exist (skipping $tool)"
		return
	fi

	eval2 cd $tool || die

	eval2 mkdir -p ~/rpmbuild/SOURCES || die
	for p in *.patch; do
		[ -e "$p" ] || continue
		eval2 cp $p ~/rpmbuild/SOURCES/ || die
	done

	eval2 spectool -g -R $tool.spec || die
	local needed dep to_install=
	needed=$( deps $tool.spec ) || die
	for dep in $needed; do
		if quietly rpm -q $dep; then
			echo "$dep installed"
			continue
		fi
		to_install="$to_install $dep"
	done
	[ ! "$to_install" ] || eval2 sudo yum install -y $to_install | die
	eval2 rpmbuild -bb $tool.spec "$@" || die

	eval2 cd -
}

rpmfiles()
{
	rpmfilenames "$@" | awk -v p="$HOME/rpmbuild/RPMS/" '
		BEGIN { sub("/$", "", p) }
		/-debuginfo-/ { next }
		{
			arch = $0
			sub(/\.rpm$/, "", arch)
			sub(/.*\./, "", arch)
			printf "%s/%s/%s\n", p, arch, $0
		}
	' # END-QUOTE
}

############################################################ MAIN

#
# Process command-line options
#
while getopts h flag; do
	case "$flag" in
	*) usage # NOTREACHED
	esac
done
shift $(( $OPTIND - 1 ))

#
# Check system dependencies
#
needed=
quietly rpm -q gcc || needed="$needed gcc"
[ -e /opt/rh/devtoolset-8/enable ] || needed="$needed devtoolset-8-runtime"
[ ! "$needed" ] || eval2 sudo yum install -y $needed || die

#
# Software dependencies
#
build bpftool
if ! quietly rpm -q ebpftoolsbuilder-llvm-clang; then
	build llvm-clang
	conflicts="clang clang-devel llvm llvm-devel"
	to_uninstall=
	for conflict in $conflicts; do
		quietly rpm -q $conflict || continue
		to_uninstall="$to_uninstall $conflict"
	done
	if [ "$to_uninstall" ]; then
		eval2 sudo rpm -e $to_uninstall \|\| : errors ignored
		exists=
		for conflict in $conflicts; do
			quietly rpm -q $conflict || continue
			exists=1
			echo "$name still installed"
		done
		[ ! "$exists" ] || die "Failed update llvm-clang"
	fi
	to_install=
	for file in $( rpmfiles llvm-clang/llvm-clang.spec ); do
		name=${file##*/}
		name=${name%%-[0-9]*}
		rpm -q $name && continue
		to_install="$to_install $file"
	done
	eval2 sudo rpm -ivh $to_install || die
fi
build -x lua bcc

#
# Install dependencies
#
files=$( rpmfiles -x lua bcc/bcc.spec ) # with lua = false
to_uninstall=
for file in $files; do
	name="${file%%-[0-9]*}"
	installed=$( rpm -q $name 2> /dev/null ) || continue
	[ "$installed" != "${file%.rpm}" ] || continue
	to_uninstall="$to_uninstall $name"
done
if [ "$to_uninstall" ]; then
	eval2 sudo rpm -e $to_uninstall \|\| : errors ignored
	exists=
	for file in $files; do
		name="${file%%-[0-9]*}"
		quietly rpm -q $name || continue
		exists=1
		echo "$name still installed"
	done
	[ ! "$exists" ] || die "Failed to update bcc"
fi
to_install=
for file in $files; do
	name="${file%.rpm}"
	quietly rpm -q $file || continue
	to_install="$to_install $file"
done
if [ "$to_install" ]; then
	eval2 sudo rpm -ivh $( rpmfiles -x lua bcc/bcc.spec ) || die
fi
needed= # for bpftrace compile below
for name in ncurses-static binutils-devel; do
	quietly rpm -q $name || needed="$needed $name"
done
[ ! "$needed" ] || eval2 sudo yum install -y $needed || die

#
# Build software
#
build bpftrace
#build bpftrace --with static
#build bpftrace --with git
#build bpftrace --with git --with static

################################################################################
# END
################################################################################
