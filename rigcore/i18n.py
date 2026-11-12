"""Idioma de la interfaz.

Los textos fuente están en español. Si el idioma elegido no es español, se carga
la traducción al inglés (rigcore/i18n/rigcore_en.qm), que llega a más gente.

Elección del idioma, por orden: variable RIGCORE_LANG, ajuste guardado en
~/.config/rigcore/settings.json ("lang": "system" | "es" | "en"), idioma del sistema.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from PySide6.QtCore import QCoreApplication, QLocale, QTranslator

HERE = Path(__file__).resolve().parent
SETTINGS = Path(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))) / "rigcore" / "settings.json"
CONTEXT = "Rigcore"
_translator: QTranslator | None = None


def tr(text: str) -> str:
    """Traduce un texto del código Python (contexto "Rigcore")."""
    return QCoreApplication.translate(CONTEXT, text)


def get_setting(key: str, default: str) -> str:
    try:
        return json.loads(SETTINGS.read_text()).get(key, default)
    except (OSError, ValueError, AttributeError):
        return default


def set_setting(key: str, value: str) -> None:
    try:
        data = json.loads(SETTINGS.read_text())
    except (OSError, ValueError):
        data = {}
    data[key] = value
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    SETTINGS.write_text(json.dumps(data))


def saved_lang() -> str:
    return get_setting("lang", "system")


def save_lang(lang: str) -> None:
    set_setting("lang", lang)


def effective_lang() -> str:
    lang = os.environ.get("RIGCORE_LANG") or saved_lang()
    if lang in ("es", "en"):
        return lang
    return "es" if QLocale.system().language() == QLocale.Language.Spanish else "en"


def install(app) -> str:
    """Carga la traducción si hace falta. Devuelve el idioma aplicado."""
    global _translator
    lang = effective_lang()
    if lang != "es":
        t = QTranslator(app)
        if t.load(str(HERE / "i18n" / f"rigcore_{lang}.qm")):
            app.installTranslator(t)
            _translator = t
        else:
            lang = "es"
    return lang
