#!/usr/bin/env python3
"""Fabrique les ambiances de l'app (Resources/Ambiences/ambience-<id>.m4a).

- Bruits blanc, rose et brun : générés ici, en stéréo décorrélée.
- Enregistrements : sources/<id>.<ext> (téléchargés depuis l'URL de ambiences.json),
  découpés (start/length), bouclés sans couture par un fondu enchaîné de 4 s,
  ramenés au même niveau sonore puis encodés en AAC stéréo 160 kbit/s.

Usage : python3 Scripts/ambiences/build_ambiences.py [id ...]   (depuis app/ios/QuietoNative)
Nécessite numpy, scipy et afconvert (macOS).
"""
import json, subprocess, sys, tempfile, wave
from pathlib import Path
import numpy as np
from scipy.signal import lfilter

HERE = Path(__file__).resolve().parent
OUT = HERE.parent.parent / "Resources" / "Ambiences"
RATE = 44100
CROSSFADE = 4.0
TARGET_RMS_DB = -26.0

def read_wav(path):
    with wave.open(str(path)) as w:
        frames = w.readframes(w.getnframes())
        data = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768
        return data.reshape(-1, w.getnchannels())

def write_wav(path, samples):
    pcm = (np.clip(samples, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(pcm.tobytes())

def decode(source, tmp):
    wav = Path(tmp) / "decoded.wav"
    subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}", "-c", "2", str(source), str(wav)], check=True)
    return read_wav(wav)

def seamless(samples, seconds, crossfade=CROSSFADE):
    """Garde `seconds` de son ; la fin se fond dans le début pour une boucle sans saut."""
    n, x = int(seconds * RATE), int(crossfade * RATE)
    if len(samples) < n + x:
        n = len(samples) - x
    body = samples[:n].copy()
    t = np.linspace(0, np.pi / 2, x)[:, None]
    body[:x] = samples[:x] * np.sin(t) + samples[n:n + x] * np.cos(t)
    return body

def normalize(samples):
    rms = np.sqrt(np.mean(samples ** 2))
    gain = 10 ** (TARGET_RMS_DB / 20) / max(rms, 1e-6)
    peak = np.max(np.abs(samples)) * gain
    if peak > 0.89:  # -1 dBFS
        gain *= 0.89 / peak
    return samples * gain

def noise(kind, seconds=30):
    rng = np.random.default_rng({"white": 1, "pink": 2, "brown": 3}[kind])
    n = int((seconds + CROSSFADE) * RATE)
    white = rng.standard_normal((n, 2)).astype(np.float32)
    if kind == "white":
        out = white
    elif kind == "brown":
        # Intégrateur à fuite (-6 dB/octave).
        out = lfilter([0.02], [1, -0.98], white, axis=0).astype(np.float32)
    else:
        # Filtre de Paul Kellet (-3 dB/octave).
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        out = lfilter(b, a, white, axis=0).astype(np.float32)
    out -= out.mean(axis=0)
    return seamless(out, seconds)

def encode(samples, ident):
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "out.wav"
        write_wav(wav, samples)
        target = OUT / f"ambience-{ident}.m4a"
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "160000", str(wav), str(target)], check=True)
    legacy = OUT / f"ambience-{ident}.mp3"
    if legacy.exists():
        legacy.unlink()  # l'ancienne boucle synthétique de 30 s est remplacée
    print(f"✓ {ident} : {len(samples) / RATE:.0f} s → {target.name}")

def main():
    config = {k: v for k, v in json.loads((HERE / "ambiences.json").read_text()).items() if not k.startswith("_")}
    wanted = sys.argv[1:] or list(config)
    missing = []
    for ident in wanted:
        entry = config[ident]
        if "generated" in entry:
            encode(normalize(noise(entry["generated"])), ident)
            continue
        sources = sorted((HERE / "sources").glob(f"{ident}.*"))
        if not sources:
            missing.append(ident)
            continue
        with tempfile.TemporaryDirectory() as tmp:
            samples = decode(sources[0], tmp)
        start = int(entry.get("start", 0) * RATE)
        encode(normalize(seamless(samples[start:], entry.get("length", 30), entry.get("crossfade", CROSSFADE))), ident)
    if missing:
        print("\nÀ télécharger dans Scripts/ambiences/sources/ :")
        for ident in missing:
            print(f"  {ident}.<ext>  ←  {config[ident]['url']}")

if __name__ == "__main__":
    main()
