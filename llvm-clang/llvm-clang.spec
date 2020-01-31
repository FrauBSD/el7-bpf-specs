%global maj_ver 8
%global min_ver 0
%global patch_ver 0
%define _unpackaged_files_terminate_build 0

Name:     ebpftoolsbuilder-llvm-clang
Version:	%{maj_ver}.%{min_ver}.%{patch_ver}
Release:  0%{?dist}
Summary:	The Low Level Virtual Machine
License:	NCSA
URL:		  http://llvm.org
Source0:	http://llvm.org/releases/%{version}/llvm-%{version}.src.tar.xz
Source1:	http://llvm.org/releases/%{version}/cfe-%{version}.src.tar.xz

ExclusiveArch:  x86_64

BuildRequires:	zlib-devel
BuildRequires:	ncurses-devel
BuildRequires:  bison
BuildRequires:  cmake3
BuildRequires:  flex
BuildRequires:  make
BuildRequires:  libxml2-devel
BuildRequires:  elfutils-libelf-devel
BuildRequires:  devtoolset-8-runtime

%description
A build of LLVM and Clang to make bpftrace and BCC possible on
RH7. Don't use this as your daily compiler!

%package libs
Summary: Libs required for running the dynamically linked version of bpftrace

%description libs
Libs required for running the dynamically linked version of bpftrace

%prep

%setup -n llvm-8.0.0.src -q
%setup -T -D -a 1 -n llvm-8.0.0.src -q
mv cfe-8.0.0.src tools/clang
mkdir build

%build

. /opt/rh/devtoolset-8/enable
cd build

cmake3 .. \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLIBCLANG_BUILD_STATIC=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
	-DLLVM_LIBDIR_SUFFIX=64 \
  -DCLANG_BUILD_EXAMPLES=OFF \
  -DCLANG_INCLUDE_DOCS=OFF \
  -DCLANG_INCLUDE_TESTS=OFF \
  -DLLVM_APPEND_VC_REV=OFF \
  -DLLVM_BUILD_DOCS=OFF \
  -DLLVM_BUILD_EXAMPLES=OFF \
  -DLLVM_BUILD_TESTS=OFF \
  -DLLVM_BUILD_TOOLS=ON \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_CXX1Y=ON \
  -DLLVM_ENABLE_EH=ON \
  -DLLVM_ENABLE_LIBCXX=OFF \
  -DLLVM_ENABLE_PIC=ON \
  -DLLVM_ENABLE_RTTI=ON \
  -DLLVM_ENABLE_SPHINX=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_GO_TESTS=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_TOOLS=ON \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DLLVM_TARGETS_TO_BUILD="host;BPF"

%make_build

%install

cd build
%make_install

# Need libclang for static linking
find . -name 'libclang.a' -exec cp {} %{buildroot}%{_libdir} \;
# Links to libclang.so for some reason which makes libclang.so a
# package dependency
rm %{buildroot}%{_bindir}/c-index-test

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
/usr/libexec/c++-analyzer
/usr/libexec/ccc-analyzer
/usr/share/clang/bash-autocomplete.sh
/usr/share/clang/clang-format-bbedit.applescript
/usr/share/clang/clang-format-diff.py
/usr/share/clang/clang-format-diff.pyc
/usr/share/clang/clang-format-diff.pyo
/usr/share/clang/clang-format-sublime.py
/usr/share/clang/clang-format-sublime.pyc
/usr/share/clang/clang-format-sublime.pyo
/usr/share/clang/clang-format.el
/usr/share/clang/clang-format.py
/usr/share/clang/clang-format.pyc
/usr/share/clang/clang-format.pyo
/usr/share/clang/clang-rename.el
/usr/share/clang/clang-rename.py
/usr/share/clang/clang-rename.pyc
/usr/share/clang/clang-rename.pyo
/usr/share/man/man1/scan-build.1.gz
/usr/share/opt-viewer/opt-diff.py
/usr/share/opt-viewer/opt-diff.pyc
/usr/share/opt-viewer/opt-diff.pyo
/usr/share/opt-viewer/opt-stats.py
/usr/share/opt-viewer/opt-stats.pyc
/usr/share/opt-viewer/opt-stats.pyo
/usr/share/opt-viewer/opt-viewer.py
/usr/share/opt-viewer/opt-viewer.pyc
/usr/share/opt-viewer/opt-viewer.pyo
/usr/share/opt-viewer/optpmap.py
/usr/share/opt-viewer/optpmap.pyc
/usr/share/opt-viewer/optpmap.pyo
/usr/share/opt-viewer/optrecord.py
/usr/share/opt-viewer/optrecord.pyc
/usr/share/opt-viewer/optrecord.pyo
/usr/share/opt-viewer/style.css
/usr/share/scan-build/scanview.css
/usr/share/scan-build/sorttable.js
/usr/share/scan-view/FileRadar.scpt
/usr/share/scan-view/GetRadarVersion.scpt
/usr/share/scan-view/Reporter.py
/usr/share/scan-view/Reporter.pyc
/usr/share/scan-view/Reporter.pyo
/usr/share/scan-view/ScanView.py
/usr/share/scan-view/ScanView.pyc
/usr/share/scan-view/ScanView.pyo
/usr/share/scan-view/bugcatcher.ico
/usr/share/scan-view/startfile.py
/usr/share/scan-view/startfile.pyc
/usr/share/scan-view/startfile.pyo
%{_bindir}/*
%{_libdir}/*.a
%{_includedir}/llvm
%{_includedir}/llvm-c
%{_includedir}/clang
%{_includedir}/clang-c
%{_libdir}/clang/%{version}
%{_libdir}/cmake/
%{_libdir}/lib*.so
%{_libdir}/lib*.so.%{maj_ver}

%files libs
%{_libdir}/libLLVM*.so
%{_libdir}/libclang.so*

%changelog
* Sun Jun 30 2019 bas smit - 0.9.1
- Initial version
