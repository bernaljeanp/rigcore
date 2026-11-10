# Empaquetado de Vórtice

| Vía | Archivos | Para |
|---|---|---|
| AUR (`vortice-git`) | `arch/PKGBUILD`, `arch/vortice.install` | Arch, CachyOS, EndeavourOS, Garuda… |
| COPR | `fedora/vortice.spec` | Fedora Workstation (y Bazzite/Silverblue por capas) |
| Instalador universal | `../install.sh` | Cualquier distro, incluidas las inmutables |

Los dos paquetes compilan los shaders con el Qt de la distro (`qsb`) y colocan los
archivos de sistema con `install-files.sh`: servicio, política D-Bus (grupo `wheel`),
regla `hwdb`, unidad de usuario del agente, entrada de menú e iconos.

Tras instalar un paquete, el servicio de hardware se activa con:

```sh
sudo systemctl enable --now vortice-helper
```

## Publicar en AUR

Requisitos: cuenta en <https://aur.archlinux.org> con tu clave SSH pública añadida.

```sh
git clone ssh://aur@aur.archlinux.org/vortice-git.git aur-vortice
cp packaging/arch/PKGBUILD packaging/arch/vortice.install aur-vortice/
cd aur-vortice
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD vortice.install .SRCINFO
git commit -m "vortice-git: primera versión"
git push
```

## Publicar en COPR

Requisitos: cuenta de Fedora (FAS) y el token de <https://copr.fedorainfracloud.org/api/>
guardado en `~/.config/copr`.

1. Crear una versión etiquetada en GitHub (el `.spec` descarga
   `.../archive/v0.1.0/vortice-0.1.0.tar.gz`):

   ```sh
   git tag v0.1.0 && git push origin v0.1.0
   ```

2. Construir el paquete fuente (SRPM) y subirlo a COPR, que lo compila para cada
   versión de Fedora (es la vía probada; ver *Probar los paquetes localmente*):

   ```sh
   rpmbuild -bs packaging/fedora/vortice.spec      # con el tarball en ~/rpmbuild/SOURCES
   copr-cli create vortice --chroot fedora-rawhide-x86_64 --chroot fedora-45-x86_64 \
       --description "Centro de control para portátiles gaming en Linux"
   copr-cli build vortice ~/rpmbuild/SRPMS/vortice-0.1.0-1.*.src.rpm
   ```

3. Los usuarios lo instalan con:

   ```sh
   sudo dnf copr enable bernaljeanp/vortice
   sudo dnf install vortice
   sudo systemctl enable --now vortice-helper
   ```

   En Bazzite/Silverblue: añadir el repositorio de COPR y `rpm-ostree install vortice`,
   o usar el instalador universal (`./install.sh`), que no necesita capas.

## Probar los paquetes localmente

- **Fedora:** `rpmbuild -ba packaging/fedora/vortice.spec` en un contenedor Fedora con
  `rpm-build pyproject-rpm-macros python3-devel qt6-qtshadertools systemd-rpm-macros desktop-file-utils`
  y el tarball de `git archive --prefix=vortice-0.1.0/` en `SOURCES/`.
- **Arch:** `makepkg -f` en un contenedor Arch con las dependencias del `PKGBUILD`,
  cambiando `source` por `git+file:///ruta/al/repo#branch=main`.
