#!/usr/bin/env python3
"""Régénère les illustrations de séances qui illustraient mal leur exercice
(diagnostic du 07/10/2026). Méthode de PROMPTS-VISUELS.md : 3 références de
style hétérogènes tirées de la série actuelle, un sujet littéral par séance,
2 variantes par image, puis on choisit.

  GEMINI_API_KEY=… python3 tool/regen_session_art.py generate [id …]
      → build/regen-art/<id>_a.png, <id>_b.png + planche build/regen-art/planche.jpg
  python3 tool/regen_session_art.py install express_7=a emo_sadness=b …
      → recadre à 96 %, 1024×1024, écrit Resources/Artwork/session-<id>.png
"""
import base64, json, os, sys, urllib.request
from io import BytesIO
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ARTWORK = ROOT / "ios/QuietoNative/Resources/Artwork"
OUT = ROOT / "build/regen-art"
MODEL = os.environ.get("GEMINI_IMAGE_MODEL", "gemini-3-pro-image-preview")
# Trio sans élément commun (piège n°9) : nature morte, paysage, personnage en intérieur.
REFERENCES = ["express_3", "sleep_2", "afternoon_fog"]

STYLE = """THE IMAGE CONTAINS ZERO TEXT. No title, no caption, no word, no letter, no number. This is a painting, not a poster.
Copy the painting style of the three reference images exactly: hand-painted gouache, flat opaque shapes, visible brush texture, matte, naive and calm. Same palette: deep ink blue night, muted greens, cream, a touch of warm light. Same woman when a person appears: dark hair in a loose bun, cream sweater, simple calm face.
Do NOT copy the CONTENT of the references: no bowl, no breakfast, no beach, no laptop unless described below.
Square 1:1. No white frame and no border, the paint touches all four edges. The subject is ENTIRELY INSIDE the frame and must not touch any edge. Leave the bottom third calm and nearly empty.
Never add: heart shapes, extra figures, any person or object not described in the scene, glow halos, photograph of a painting, text."""

SUBJECTS = {
    # Réveil en panique : l'angoisse du MATIN (l'ancienne image, réveil de nuit, va à middle_of_night).
    "express_7": "Early morning, first pale dawn light through the window, the sky turning from ink blue to warm dawn at the horizon, no moon. The woman sits up in bed, eyes open, gaze resting on one point of the room, one hand flat on her belly, breathing out slowly. Tense but steadying.",
    # Récupérer sans culpabiliser : repos assumé, pas le sommeil de nuit.
    "gentle_recovery": "The woman lies on a sofa under a thick green blanket, a cup of tea and a closed book on a low table beside her, a to-do notebook pushed far away and closed. Her face is relaxed, eyes half closed, fully allowing herself to rest. Cosy living room, plant, window.",
    # Tristesse : les bras serrés autour de soi, pas un lit.
    "emo_sadness": "The woman sits on the floor against the side of a sofa, knees drawn up, her arms wrapped gently around herself in a self-hug, head slightly tilted, sad but held. A few soft raindrops on the window behind her. Quiet, tender.",
    # S'asseoir avec moins de guidage : autonomie, silence, espace ouvert.
    "discover_open_sitting": "The woman seated cross-legged alone on a flat rock at the edge of a vast calm lake, seen from behind and slightly to the side, a lot of empty space and silence around her. Nothing else. Wide, open, autonomous.",
    # Descente vers le sommeil : un rythme qui ralentit (expiration de 4 à 8 s).
    "breath_sleep_descent": "A pale cream path descending a gentle green hillside toward a calm lake, made of long smooth steps whose length grows longer and longer as the path goes down, like a rhythm slowing. A low moon near the horizon. No person.",
    # Observer sans juger : nommer « pensée », « son », « sensation » puis revenir.
    "decouverte_2": "The woman seated cross-legged, eyes closed, seen in profile. Three small simple symbols drift past her at a distance, each inside its own small pale circle: a tiny spiral (a thought), three curved sound waves (a sound), a small leaf (a sensation). She does not follow them. Calm night lake behind.",
    # Expiration longue : distincte de la cohérence cardiaque (chemin sinueux).
    "new_long_exhale": "Close side view of the woman seated, one hand resting on her belly, breathing out through softly pursed lips a very long thin ribbon of pale mist that stretches far across the room and out of the open window toward the lake. Short in-breath, long out-breath.",
    # Après une dispute : main sur la poitrine, l'autre sur le ventre, le droit de ne pas répondre.
    "express_6": "The woman sits on the bottom step of a staircase at home, one hand on her chest and the other on her belly, eyes closed, breathing. Her phone lies face down on the step beside her. A door half closed in the background. Emotion settling after an argument.",
    # Respiration triangle : la forme doit se lire, comme la boucle de la respiration carrée.
    "breath_triangle": "A pale cream path drawn as a clear triangle with three equal sides on a green hilly landscape seen from slightly above, under a night sky with the moon over a lake. The triangle shape is obvious. No person.",
    # 4-7-8 : trois temps de longueurs différentes (monter, plateau, longue descente).
    "stress_2": "A pale cream path in three clear segments on a green hill: a short rise up, then a longer flat stretch along the ridge, then a very long gentle descent down to the lake. Night sky with the moon. No person.",
}


def generate(ids):
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        sys.exit("GEMINI_API_KEY manquante.")
    OUT.mkdir(parents=True, exist_ok=True)
    refs = [{"inlineData": {"mimeType": "image/png",
                            "data": base64.b64encode((ARTWORK / f"session-{r}.png").read_bytes()).decode()}}
            for r in REFERENCES]
    for sid in ids:
        prompt = f"{STYLE}\n\nScene: {SUBJECTS[sid]}"
        for variant in "ab":
            body = {"contents": [{"parts": refs + [{"text": prompt}]}],
                    "generationConfig": {"responseModalities": ["IMAGE"]}}
            req = urllib.request.Request(
                f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
                data=json.dumps(body).encode(),
                headers={"Content-Type": "application/json", "x-goog-api-key": key})
            with urllib.request.urlopen(req, timeout=180) as r:
                parts = json.load(r)["candidates"][0]["content"]["parts"]
            data = next(p["inlineData"]["data"] for p in parts if "inlineData" in p)
            # L'API renvoie souvent du JPEG : on repasse par PIL, quel que soit le format.
            Image.open(BytesIO(base64.b64decode(data))).convert("RGB").save(OUT / f"{sid}_{variant}.png")
            print(f"{sid}_{variant}")
    sheet(ids)


def sheet(ids):
    t = 360
    img = Image.new("RGB", (2 * t, len(ids) * (t + 30)), "white")
    d = ImageDraw.Draw(img)
    for row, sid in enumerate(ids):
        for col, v in enumerate("ab"):
            p = OUT / f"{sid}_{v}.png"
            if p.exists():
                img.paste(Image.open(p).resize((t - 6, t - 6)), (col * t + 3, row * (t + 30) + 3))
            d.text((col * t + 6, row * (t + 30) + t), f"{sid}={v}", fill="black")
    img.save(OUT / "planche.jpg", quality=80)
    print(OUT / "planche.jpg")


def install(choices):
    for choice in choices:
        sid, variant = choice.split("=")
        im = Image.open(OUT / f"{sid}_{variant}.png").convert("RGB")
        w, h = im.size
        cw, ch = int(w * 0.96), int(h * 0.96)
        im = im.crop(((w - cw) // 2, (h - ch) // 2, (w + cw) // 2, (h + ch) // 2)).resize((1024, 1024), Image.LANCZOS)
        im.save(ARTWORK / f"session-{sid}.png")
        print(f"session-{sid}.png")


if __name__ == "__main__":
    cmd, args = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 1 else ("", [])
    if cmd == "generate":
        generate(args or list(SUBJECTS))
    elif cmd == "install":
        install(args)
    else:
        sys.exit(__doc__)
