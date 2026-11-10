"""Idioma de la interfaz.

Los textos fuente están en español. Si el idioma elegido no es español, se carga
la traducción al inglés (vortice/i18n/vortice_en.qm), que llega a más gente.

Elección del idioma, por orden: variable VORTICE_LANG, ajuste guardado en
~/.config/vortice/settings.json ("lang": "system" | "es" | "en"), idioma del sistema.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from PySide6.QtCore import QCoreApplication, QLocale, QTranslator

HERE = Path(__file__).resolve().parent
SETTINGS = Path(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))) / "vortice" / "settings.json"
CONTEXT = "Vortice"
_translator: QTranslator | None = None


def tr(text: str) -> str:
    """Traduce un texto del código Python (contexto "Vortice")."""
    return QCoreApplication.translate(CONTEXT, text)


def saved_lang() -> str:
    try:
        return json.loads(SETTINGS.read_text()).get("lang", "system")
    except (OSError, ValueError, AttributeError):
        return "system"


def save_lang(lang: str) -> None:
    try:
        data = json.loads(SETTINGS.read_text())
    except (OSError, ValueError):
        data = {}
    data["lang"] = lang
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    SETTINGS.write_text(json.dumps(data))


def effective_lang() -> str:
    lang = os.environ.get("VORTICE_LANG") or saved_lang()
    if lang in ("es", "en"):
        return lang
    return "es" if QLocale.system().language() == QLocale.Language.Spanish else "en"


def install(app) -> str:
    """Carga la traducción si hace falta. Devuelve el idioma aplicado."""
    global _translator
    lang = effective_lang()
    if lang != "es":
        t = QTranslator(app)
        if t.load(str(HERE / "i18n" / f"vortice_{lang}.qm")):
            app.installTranslator(t)
            _translator = t
        else:
            lang = "es"
    return lang
