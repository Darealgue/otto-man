#!/usr/bin/env python3
"""Placeholder WAV üretici — Godot yoksa: python tools/generate_audio_placeholders.py"""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"

SFX_STEMS = {
    "ui_click": {"hz": 920.0, "duration": 0.05, "volume": 0.22, "slide_hz": 0.0, "wave": "sine"},
    "ui_confirm": {"hz": 660.0, "duration": 0.07, "volume": 0.24, "slide_hz": 120.0, "wave": "sine"},
    "ui_cancel": {"hz": 340.0, "duration": 0.08, "volume": 0.2, "slide_hz": -80.0, "wave": "triangle"},
    "player_hurt": {"hz": 220.0, "duration": 0.11, "volume": 0.38, "slide_hz": -140.0, "wave": "triangle"},
    "player_death": {"hz": 130.0, "duration": 0.55, "volume": 0.42, "slide_hz": -90.0, "wave": "sine"},
    "door_open": {"hz": 280.0, "duration": 0.22, "volume": 0.32, "slide_hz": 420.0, "wave": "square"},
    "door_locked": {"hz": 160.0, "duration": 0.08, "volume": 0.28, "slide_hz": -60.0, "wave": "square"},
    "combat_swipe": {"hz": 540.0, "duration": 0.09, "volume": 0.3, "slide_hz": -220.0, "wave": "triangle"},
    "combat_hit_light": {"hz": 400.0, "duration": 0.06, "volume": 0.3, "slide_hz": -200.0, "wave": "square"},
    "combat_hit_heavy": {"hz": 210.0, "duration": 0.1, "volume": 0.38, "slide_hz": -80.0, "wave": "square"},
    "combat_whiff": {"hz": 310.0, "duration": 0.05, "volume": 0.14, "slide_hz": -90.0, "wave": "sine"},
    "combat_block": {"hz": 180.0, "duration": 0.09, "volume": 0.35, "slide_hz": 0.0, "wave": "triangle"},
    "pickup": {"hz": 780.0, "duration": 0.09, "volume": 0.26, "slide_hz": 200.0, "wave": "sine"},
    "build_complete": {"hz": 520.0, "duration": 0.18, "volume": 0.3, "slide_hz": 180.0, "wave": "sine"},
    "footstep_player": {"hz": 95.0, "duration": 0.04, "volume": 0.18, "slide_hz": -40.0, "wave": "triangle"},
    "player_jump": {"hz": 420.0, "duration": 0.07, "volume": 0.22, "slide_hz": 180.0, "wave": "sine"},
    "player_land": {"hz": 120.0, "duration": 0.05, "volume": 0.2, "slide_hz": -30.0, "wave": "triangle"},
    "player_land_heavy": {"hz": 85.0, "duration": 0.09, "volume": 0.28, "slide_hz": -20.0, "wave": "square"},
    "player_dash": {"hz": 640.0, "duration": 0.12, "volume": 0.24, "slide_hz": -280.0, "wave": "triangle"},
    "enemy_hurt": {"hz": 280.0, "duration": 0.07, "volume": 0.26, "slide_hz": -120.0, "wave": "square"},
    "enemy_death": {"hz": 150.0, "duration": 0.35, "volume": 0.32, "slide_hz": -60.0, "wave": "sine"},
    "enemy_alert": {"hz": 520.0, "duration": 0.14, "volume": 0.22, "slide_hz": 80.0, "wave": "triangle"},
    "enemy_attack_swing": {"hz": 380.0, "duration": 0.08, "volume": 0.22, "slide_hz": -150.0, "wave": "triangle"},
    "projectile_fire": {"hz": 720.0, "duration": 0.06, "volume": 0.2, "slide_hz": -200.0, "wave": "sine"},
    "projectile_hit": {"hz": 350.0, "duration": 0.05, "volume": 0.24, "slide_hz": -100.0, "wave": "square"},
}

MUSIC_STEMS = {
    "menu_ambient": {"hz": 110.0, "duration": 2.4, "volume": 0.08, "slide_hz": 8.0, "wave": "sine"},
    "village_ambient": {"hz": 165.0, "duration": 3.0, "volume": 0.07, "slide_hz": -12.0, "wave": "triangle"},
    "dungeon_ambient": {"hz": 90.0, "duration": 3.2, "volume": 0.09, "slide_hz": 5.0, "wave": "sine"},
}

SAMPLE_RATE = 22050


def sample_at(definition: dict, i: int, sample_count: int) -> float:
    t = i / SAMPLE_RATE
    progress = i / max(1, sample_count - 1)
    hz = definition["hz"] + definition["slide_hz"] * progress
    envelope = (1.0 - progress) * (1.0 - progress * 0.35)
    phase = 2.0 * math.pi * hz * t
    wave = definition["wave"]
    if wave == "square":
        value = 1.0 if (phase % (2.0 * math.pi)) < math.pi else -1.0
    elif wave == "triangle":
        p = (phase % (2.0 * math.pi)) / (2.0 * math.pi)
        value = 4.0 * abs(p - 0.5) - 1.0
    else:
        value = math.sin(phase)
    return value * envelope * definition["volume"]


def write_wav(path: Path, definition: dict) -> None:
    duration = max(0.03, float(definition["duration"]))
    sample_count = max(1, int(SAMPLE_RATE * duration))
    frames = []
    for i in range(sample_count):
        s = int(max(-32768, min(32767, sample_at(definition, i, sample_count) * 32767.0)))
        frames.append(struct.pack("<h", s))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(b"".join(frames))


def generate_folder(folder: Path, stems: dict) -> int:
    written = 0
    for stem, definition in stems.items():
        out = folder / f"{stem}.wav"
        if out.exists():
            print(f"[skip] {out.relative_to(ROOT)}")
            continue
        write_wav(out, definition)
        written += 1
        print(f"[write] {out.relative_to(ROOT)}")
    return written


def main() -> None:
    total = 0
    total += generate_folder(SFX_DIR, SFX_STEMS)
    total += generate_folder(MUSIC_DIR, MUSIC_STEMS)
    print(f"Done. {total} new wav file(s). Replace by filename anytime.")


if __name__ == "__main__":
    main()
