#!/usr/bin/env python3
"""Stage preview-only Aurora audio from verified user sources; NEVER auto-publish.

Audio licenses are not established by an intact SHA-256. Output stays outside
Godot's resource directory until permissions and on-device QA are approved.
"""
import argparse
from array import array
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

SLICES = {
    'ar_fire': ('freesound_community-ak47-sfx-102801.mp3', 1.55, .30),
    'awm_fire': ('freesound_community-039259_sniper-shots-dod-56706-amp-dod-146324flac-75998.mp3', 1.01, .72),
    'mp40_fire': ('dennish18-machine-gun-129929.mp3', .0, .14),
    'kriss_fire': ('ribhavagrawal-gun-shots-230534.mp3', .04, .16),
    'distant_fire': ('freesound_community-distant-gunshot-2-mono-80285.mp3', .07, .55),
    'impact': ('u_68csiaifb5-bulletimpact2-442718.mp3', 0.0, .72),
    'eliminated': ('universfield-game-over-deep-male-voice-clip-352695.mp3', 0.0, 2.11),
    'reload': ('dragon-studio-gun-reload-511309.mp3', 0.0, 1.50),
}
STEPS = {
    'walk': ('freesound_community-walking-46245.mp3', '8bd34b2e6a38829e728eb3f65821dc1516992bd353db2781588c61c4c3b5b571', (.66, 1.79, 2.94)),
    'run': ('freeeverythingxx-running-on-concrete-268478.mp3', '3ac5acd848e0c34808122b087a5f000893d100fc685122413279d67edd41fffe', (1.73, 2.29, 4.48)),
}
ADENDA = {
    'AURORA_GRANADA_EXPLOSION.ogg': ('grenade.ogg', 'f6a973a97bf366db7491283e13e1c63a9eb6a5830d014cb51972fc1c3cf49e0f'),
    'AURORA_AVION_SOBREVUELO_TRANSICION.ogg': ('aircraft.ogg', '875bc4e8f50dcd00d9fd7e93e586e60bf2e2914a8bdf53eb8d6fa5a0a6065aa9'),
}


def digest(p: Path) -> str:
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def ffmpeg(source: Path, target: Path, start: float, duration: float, wav=False) -> None:
    command = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostdin', '-y',
               '-ss', str(max(0., start)), '-i', str(source), '-t', str(duration),
               '-vn', '-ac', '1', '-ar', '22050']
    if wav:
        command += ['-af', 'afade=t=in:st=0:d=0.005,afade=t=out:st=0.135:d=0.045',
                    '-c:a', 'pcm_s16le']
    else:
        command += ['-af', 'afade=t=in:st=0:d=0.007,afade=t=out:st=%.4f:d=0.06' % max(0., duration-.065),
                    '-c:a', 'libvorbis', '-q:a', '4']
    subprocess.run(command + [str(target)], check=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-i', str(target), '-f', 'null', '-'],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def normalize_ogg(path: Path, max_peak: float = .82) -> None:
    # Vorbis decoded peaks may exceed encoded PCM peaks: iterate safely.
    for iteration in range(4):
        decoded = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path),
                                  '-ac', '1', '-ar', '22050', '-f', 'f32le', '-'],
                                 check=True, stdout=subprocess.PIPE).stdout
        floats = array('f')
        floats.frombytes(decoded)
        peak = max((abs(v) for v in floats), default=0.)
        if peak <= max_peak:
            return
        temp = path.with_name(path.stem + '.normalized.ogg')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(path),
                        '-af', 'volume=%.8f' % (max_peak / peak * .86),
                        '-c:a', 'libvorbis', '-q:a', '4', str(temp)], check=True)
        temp.replace(path)
    raise ValueError('Audio remains above safe decoded peak: ' + path.name)


def normalize_wav(path: Path, target_peak: float = .47) -> None:
    import wave
    with wave.open(str(path), 'rb') as stream:
        params = stream.getparams()
        if params.nchannels != 1 or params.sampwidth != 2:
            raise ValueError('Expected mono 16-bit step clip')
        samples = array('h')
        samples.frombytes(stream.readframes(params.nframes))
    peak = max((abs(v) for v in samples), default=0)
    if peak:
        factor = target_peak * 32767. / peak
        scaled = array('h', (max(-32767, min(32767, round(v * factor)))
                             for v in samples))
        with wave.open(str(path), 'wb') as stream:
            stream.setparams(params)
            stream.writeframes(scaled.tobytes())


def stage(originals: Path, inventory: Path, extra: Path, destination: Path) -> dict:
    if destination.exists():
        raise FileExistsError('Refusing to overwrite staged audio: ' + str(destination))
    if shutil.which('ffmpeg') is None:
        raise RuntimeError('ffmpeg required')
    definitions = json.loads(inventory.read_text(encoding='utf-8'))['files']
    sources = {f['name']: f for f in definitions}
    base = destination / 'native-godot/assets/audio/aurora_v3_addendum'
    weapons = base / 'weapons'
    weapons.mkdir(parents=True)
    records = []
    for event, (name, start, duration) in SLICES.items():
        source = originals / name
        if digest(source) != sources[name]['sha256']:
            raise ValueError('Unverified audio source: ' + name)
        target = weapons / (event + '.ogg')
        ffmpeg(source, target, start, duration)
        normalize_ogg(target)
        records.append({'event': event, 'source': name, 'source_sha256': sources[name]['sha256'],
                        'cut_start_seconds': start, 'cut_length_seconds': duration,
                        'output_sha256': digest(target), 'license_approved': False})
    for event, (name, sha, peaks) in STEPS.items():
        source = extra / name
        if digest(source) != sha:
            raise ValueError('Unverified footstep source: ' + name)
        for index, peak in enumerate(peaks):
            output = base / (event + '_' + str(index) + '.wav')
            ffmpeg(source, output, peak - .045, .185, wav=True)
            normalize_wav(output)
            records.append({'event': event+'_'+str(index), 'source': name,
                            'output_sha256': digest(output), 'license_approved': False})
    for name, (output, expected) in ADENDA.items():
        source = extra / name
        if digest(source) != expected:
            raise ValueError('Unverified addendum: ' + name)
        shutil.copyfile(source, base / output)
        records.append({'event': output, 'source': name,
                        'output_sha256': expected, 'license_approved': False})
    report = {'scope': 'private_test_only_not_redistributable', 'clips': len(records),
              'gameplay_or_license_approval_implied': False, 'records': records}
    (destination / 'PRIVATE_SOURCE_AUDIO_REPORT.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--originals', type=Path, required=True)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--extra-audio', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--private-preview-only', action='store_true')
    args = parser.parse_args()
    if not args.private_preview_only:
        parser.error('Audio permissions are unverified: require --private-preview-only')
    report = stage(args.originals, args.inventory, args.extra_audio, args.output)
    print('PRIVATE_AUDIO_CLIPS_STAGED', report['clips'])
    print('DO_NOT_COMMIT_UNCLEARED_SOUNDS_TO_PUBLIC_REPO')


if __name__ == '__main__':
    main()