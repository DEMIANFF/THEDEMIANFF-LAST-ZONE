"""Stage user-supplied audio locally and cut single footfalls with Blender's audio decoder."""
import argparse
import hashlib
from pathlib import Path
import shutil
import sys
import wave

import aud
import numpy as np


FILES = {
    "AURORA_GRANADA_EXPLOSION.ogg": ("grenade.ogg", "f6a973a97bf366db7491283e13e1c63a9eb6a5830d014cb51972fc1c3cf49e0f"),
    "AURORA_AVION_SOBREVUELO_TRANSICION.ogg": ("aircraft.ogg", "875bc4e8f50dcd00d9fd7e93e586e60bf2e2914a8bdf53eb8d6fa5a0a6065aa9"),
    "AURORA_LOBBY_MUSICA_LOOP_GODOT.ogg": ("aurora_lobby_loop.ogg", "9a8e3d5e3bd385cd8682a4789621d0fe74d1af87a4d0d65471cb759e01fe10f2"),
}
FOOTSTEPS = (
    ("freesound_community-walking-46245.mp3", "8bd34b2e6a38829e728eb3f65821dc1516992bd353db2781588c61c4c3b5b571", "walk", (.66, 1.79, 2.94)),
    ("freeeverythingxx-running-on-concrete-268478.mp3", "3ac5acd848e0c34808122b087a5f000893d100fc685122413279d67edd41fffe", "run", (1.73, 2.29, 4.48)),
)
OUTPUT_RATE = 22050


def verify(path, digest):
    with path.open("rb") as stream:
        actual = hashlib.file_digest(stream, "sha256").hexdigest()
    if actual != digest:
        raise ValueError(f"SHA-256 incorrecto para {path.name}: {actual}")


def write_footsteps(source, output, name, peaks):
    sound = aud.Sound.file(str(source))
    rate = int(sound.specs[0])
    mono = sound.data().mean(axis=1)
    for index, peak in enumerate(peaks):
        # Include the initial attack and stop before the following step.
        start = round((peak - .045) * rate)
        samples = mono[start:start + round(.185 * rate)]
        times = np.arange(round(.185 * OUTPUT_RATE)) * rate / OUTPUT_RATE
        pcm = np.interp(times, np.arange(len(samples)), samples)
        pcm *= .64 / max(.001, np.abs(pcm).max())
        pcm[:132] *= np.linspace(0., 1., 132)
        pcm[-770:] *= np.linspace(1., 0., 770)
        with wave.open(str(output / f"{name}_{index}.wav"), "wb") as stream:
            stream.setparams((1, 2, OUTPUT_RATE, 0, "NONE", "not compressed"))
            stream.writeframes((pcm * 32767).astype("<i2").tobytes())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("addendum", type=Path, help="Unpacked audio and footsteps ZIP files")
    parser.add_argument("lobby_ogg", type=Path)
    arguments = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    project = Path(__file__).resolve().parents[1]
    output = project / "assets/audio/aurora_v3_addendum"
    entries = [(arguments.lobby_ogg if destination == "aurora_lobby_loop.ogg" else
                arguments.addendum / source, destination, digest)
               for source, (destination, digest) in FILES.items()]
    for path, _, digest in entries:
        verify(path, digest)
    for file, digest, _, _ in FOOTSTEPS:
        verify(arguments.addendum / file, digest)
    output.mkdir(parents=True, exist_ok=True)
    for path, destination, _ in entries:
        shutil.copyfile(path, output / destination)
    for file, _, name, peaks in FOOTSTEPS:
        write_footsteps(arguments.addendum / file, output, name, peaks)
    print(f"9 recursos locales verificados y preparados en {output}")


if __name__ == "__main__":
    main()
