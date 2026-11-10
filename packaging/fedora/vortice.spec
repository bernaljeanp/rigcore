%global forgeurl https://github.com/bernaljeanp/vortice

Name:           vortice
Version:        0.1.0
Release:        1%{?dist}
Summary:        Centro de control para portátiles gaming en Linux

License:        GPL-3.0-only
URL:            %{forgeurl}
Source0:        %{forgeurl}/archive/v%{version}/%{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  python3-devel
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-setuptools
BuildRequires:  qt6-qtshadertools
BuildRequires:  systemd-rpm-macros
BuildRequires:  desktop-file-utils

Requires:       python3-pyside6
Requires:       qt6-qtdeclarative
Requires:       qt6-qtsvg
Requires:       python3-gobject
Requires:       systemd
Recommends:     (power-profiles-daemon or tuned-ppd)

%description
Vórtice reúne en una sola aplicación las temperaturas de CPU y GPU, el control
de ventiladores y sus curvas, los modos de rendimiento, el límite de carga de la
batería, las luces del teclado y los perfiles por juego, usando las interfaces
estándar del kernel. Incluye un servicio mínimo y aislado para las operaciones
que requieren privilegios.

%prep
%autosetup -n %{name}-%{version}

%generate_buildrequires
%pyproject_buildrequires

%build
# Shaders compilados con el Qt de la distro.
QSB=%{_libdir}/qt6/bin/qsb sh tools/build_shaders.sh
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files vortice
sh packaging/install-files.sh %{buildroot} %{_libexecdir}/vortice

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/vortice.desktop

%post
%systemd_post vortice-helper.service
%systemd_user_post vortice-agent.service
%{?udev_hwdb_update}

%preun
%systemd_preun vortice-helper.service
%systemd_user_preun vortice-agent.service

%postun
%systemd_postun_with_restart vortice-helper.service
%{?udev_hwdb_update}

%files -f %{pyproject_files}
%license LICENSE
%doc README.md
%{_bindir}/vortice
%{_bindir}/vortice-agent
%{_libexecdir}/vortice/
%{_unitdir}/vortice-helper.service
%{_userunitdir}/vortice-agent.service
%{_udevhwdbdir}/70-vortice-alienware.hwdb
%{_datadir}/dbus-1/system.d/io.github.vortice.Helper.conf
%{_datadir}/applications/vortice.desktop
%{_datadir}/icons/hicolor/scalable/apps/vortice.svg
%{_datadir}/icons/hicolor/scalable/status/vortice-symbolic.svg

%changelog
* Tue Nov 10 2026 bernaljeanp <316348178+bernaljeanp@users.noreply.github.com> - 0.1.0-1
- Primera versión empaquetada
