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

detail = Image.new("RGB", (960, 5 * 344), "#17202b")
detail_draw = ImageDraw.Draw(detail)
for slot, weapon in enumerate(("AR", "AWM", "SCAR", "MP40", "KRISS")):
    for index, pose in enumerate(("idle", "reload_38")):
        with Image.open(root / f"{slot:02d}-{pose}.png") as frame:
            frame.thumbnail((480, 320))
            detail.paste(frame, (index * 480, slot * 344 + 24))
        detail_draw.text((index * 480 + 5, slot * 344 + 5), f"{weapon} / {pose}", fill="white")
detail_path = root / "detail-sheet.jpg"
detail.save(detail_path, quality=92)
encoded = base64.b64encode(detail_path.read_bytes()).decode("ascii")
print("AURORA_DETAIL_SHEET_BEGIN")
for start in range(0, len(encoded), 1000):
    print(encoded[start:start + 1000])
print("AURORA_DETAIL_SHEET_END")
