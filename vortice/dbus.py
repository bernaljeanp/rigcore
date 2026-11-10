"""Llamadas a D-Bus con QtDBus (sin depender de busctl, que no existe en Flatpak).

QDBusConnection es seguro para llamadas bloqueantes desde hilos de trabajo.
"""

from __future__ import annotations

from PySide6.QtDBus import QDBus, QDBusConnection, QDBusMessage, QDBusVariant

PPD = ("net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles")
HELPER = ("io.github.vortice.Helper", "/io/github/vortice/Helper1", "io.github.vortice.Helper1")
TUNED = ("com.redhat.tuned", "/Tuned", "com.redhat.tuned.control")
PROPS = "org.freedesktop.DBus.Properties"
TIMEOUT_MS = 5000


def _unwrap(v):
    return v.variant() if isinstance(v, QDBusVariant) else v


def call(target: tuple[str, str, str], method: str, *args, bus: str = "system") -> tuple[bool, object]:
    """Devuelve (ok, primer valor devuelto | mensaje de error)."""
    service, path, iface = target
    conn = QDBusConnection.systemBus() if bus == "system" else QDBusConnection.sessionBus()
    if not conn.isConnected():
        return False, "sin conexión con D-Bus"
    msg = QDBusMessage.createMethodCall(service, path, iface, method)
    if args:
        msg.setArguments(list(args))
    reply = conn.call(msg, QDBus.CallMode.Block, TIMEOUT_MS)
    if reply.type() == QDBusMessage.MessageType.ErrorMessage:
        return False, reply.errorMessage() or reply.errorName()
    out = [_unwrap(a) for a in reply.arguments()]
    return True, (out[0] if len(out) == 1 else (out or None))


def get_property(target: tuple[str, str, str], name: str) -> object | None:
    service, path, iface = target
    ok, val = call((service, path, PROPS), "Get", iface, name)
    return val if ok else None


def set_property(target: tuple[str, str, str], name: str, value) -> bool:
    service, path, iface = target
    ok, _ = call((service, path, PROPS), "Set", iface, name, QDBusVariant(value))
    return ok
