"""Arrange unmodified Godot screenshots for review; never synthesize gameplay."""
import base64
from pathlib import Path
from PIL import Image, ImageDraw

root = Path("native-godot/out/aurora-v3-weapons")
poses = ("idle", "fire", "reload_15", "reload_38", "reload_64", "reload_85", "reload_99", "ready", "holster")
sheet = Image.new("RGB", (9 * 240, 5 * 184), "#17202b")
draw = ImageDraw.Draw(sheet)
for slot, weapon in enumerate(("AR", "AWM", "SCAR", "MP40", "KRISS")):
    for index, pose in enumerate(poses):
        source = root / f"{slot:02d}-{pose}.png"
        with Image.open(source) as frame:
            frame.thumbnail((240, 160))
            sheet.paste(frame, (index * 240, slot * 184 + 24))
        draw.text((index * 240 + 4, slot * 184 + 4), f"{weapon} / {pose}", fill="white")
target = root / "contact-sheet.jpg"
sheet.save(target, quality=88)
# Only rendered public-repository game imagery, no files or credentials.
# Chunking avoids GitHub's per-line truncation. Allows remote visual review
# when a local execution environment cannot download/unpack the artifact.
encoded = base64.b64encode(target.read_bytes()).decode("ascii")
print("AURORA_CONTACT_SHEET_BEGIN")
for start in range(0, len(encoded), 1000):
    print(encoded[start:start + 1000])
print("AURORA_CONTACT_SHEET_END")
