# Empaquetado de Rigcore

| Vía | Archivos | Para |
|---|---|---|
| AUR (`rigcore`, `rigcore-git`) | `arch/rigcore/`, `arch/rigcore-git/` (PKGBUILD, rigcore.install, .SRCINFO) | Arch, CachyOS, EndeavourOS, Garuda… |
| COPR | `fedora/rigcore.spec` | Fedora Workstation (y Bazzite/Silverblue por capas) |
| Instalador universal | `../install.sh` | Cualquier distro, incluidas las inmutables |
| Flatpak | `flatpak/io.github.bernaljeanp.Rigcore.yml` | Flathub (y con ello Bazaar en Bazzite). Edición con sandbox: sin perfiles por juego ni teclas globales; el servicio se instala aparte |
| AppImage | `appimage/build.sh` | Un archivo para cualquier distro, con todas las funciones |

Los dos paquetes compilan los shaders con el Qt de la distro (`qsb`) y colocan los
archivos de sistema con `install-files.sh`: servicio, política D-Bus (grupo `wheel`),
regla `hwdb`, unidad de usuario del agente, entrada de menú e iconos.

Tras instalar un paquete, el servicio de hardware se activa con:

```sh
sudo systemctl enable --now rigcore-helper
```

## Publicar en AUR

Hay dos paquetes: `rigcore` (versión etiquetada, recomendado) y `rigcore-git`
(último commit). Requisitos: cuenta en <https://aur.archlinux.org> con tu clave
SSH pública añadida (el host `aur.archlinux.org` usa `~/.ssh/aur`, ver `~/.ssh/config`).

```sh
for p in rigcore rigcore-git; do
  git clone ssh://aur@aur.archlinux.org/$p.git /tmp/aur-$p
  cp packaging/arch/$p/PKGBUILD packaging/arch/$p/rigcore.install packaging/arch/$p/.SRCINFO /tmp/aur-$p/
  git -C /tmp/aur-$p add PKGBUILD rigcore.install .SRCINFO
  git -C /tmp/aur-$p commit -m "$p 0.1.1"
  git -C /tmp/aur-$p push origin HEAD:master
done
```

Nueva versión de `rigcore`: subir `pkgver`, poner `pkgrel=1`, actualizar
`sha256sums` (del tarball de la etiqueta) y regenerar `.SRCINFO` con
`makepkg --printsrcinfo > .SRCINFO` (en un contenedor de Arch si no usas Arch).

## Publicar en COPR

Requisitos: cuenta de Fedora (FAS) y el token de <https://copr.fedorainfracloud.org/api/>
guardado en `~/.config/copr`.

1. Crear una versión etiquetada en GitHub (el `.spec` descarga
   `.../archive/v0.1.0/rigcore-0.1.0.tar.gz`):

   ```sh
   git tag v0.1.0 && git push origin v0.1.0
   ```

2. Construir el paquete fuente (SRPM) y subirlo a COPR, que lo compila para cada
   versión de Fedora (es la vía probada; ver *Probar los paquetes localmente*):

   ```sh
   rpmbuild -bs packaging/fedora/rigcore.spec      # con el tarball en ~/rpmbuild/SOURCES
   copr-cli create rigcore --chroot fedora-rawhide-x86_64 --chroot fedora-45-x86_64 \
       --description "Centro de control para portátiles gaming en Linux"
   copr-cli build rigcore ~/rpmbuild/SRPMS/rigcore-0.1.0-1.*.src.rpm
   ```

3. Los usuarios lo instalan con:

   ```sh
   sudo dnf copr enable bernaljeanp/rigcore
   sudo dnf install rigcore
   sudo systemctl enable --now rigcore-helper
   ```

   En Bazzite/Silverblue: añadir el repositorio de COPR y `rpm-ostree install rigcore`,
   o usar el instalador universal (`./install.sh`), que no necesita capas.

## Probar los paquetes localmente

- **Fedora:** `rpmbuild -ba packaging/fedora/rigcore.spec` en un contenedor Fedora con
  `rpm-build pyproject-rpm-macros python3-devel qt6-qtshadertools systemd-rpm-macros desktop-file-utils`
  y el tarball de `git archive --prefix=rigcore-0.1.0/` en `SOURCES/`.
- **Arch:** `makepkg -f` en un contenedor Arch con las dependencias del `PKGBUILD`,
  cambiando `source` por `git+file:///ruta/al/repo#branch=main`.

## Flatpak

Construir e instalar localmente (necesita `org.flatpak.Builder` de Flathub):

```sh
flatpak run --filesystem=$PWD org.flatpak.Builder --user --install-deps-from=flathub \
    --force-clean --install build/flatpak/build-dir packaging/flatpak/io.github.bernaljeanp.Rigcore.yml
flatpak run io.github.bernaljeanp.Rigcore
```

Para Flathub: abrir un *pull request* en <https://github.com/flathub/flathub> con el
manifiesto, cambiando la fuente `type: dir` por `type: git` con la URL del repositorio
y el `tag`/`commit` de la versión. El AppStream (`.metainfo.xml`) ya pasa `appstreamcli validate`.

## AppImage

```sh
packaging/appimage/build.sh      # -> build/appimage/Rigcore-x86_64.AppImage
```

Descarga un Python portable (python-build-standalone) y `appimagetool`. El AppImage
incluye el servicio: se instala desde *Ajustes → Instalar servicio*.
