Name:          fpman
Version:       1.2.0
Release:       3
Summary:       manpages for Free Pascal
License:       zlib with acknowledgement
URL:           http://svgames.pl
Source0:       %{name}-%{version}.zip
BuildRequires: fpc, sqlite-devel
Requires:      sqlite, man

%description
fpman provides manpages for Free Pascal by converting HTML files generated by
fpdoc to troff files and storing them in a library inside the user's home directory.

%prep
%setup

%build
make release

%install
install -m 755 -d %{buildroot}/%{_bindir}/
install -m 755 -d %{buildroot}/%{_mandir}/man6/

install -m 755 %{_builddir}/%{name}-%{version}/%{name} %{buildroot}/%{_bindir}/%{name}
install -m 644 %{_builddir}/%{name}-%{version}/%{name}.man %{buildroot}/%{_mandir}/man1/%{name}.1

%files
%{_bindir}/%{name}
%{_mandir}/man1/%{name}.1.gz
