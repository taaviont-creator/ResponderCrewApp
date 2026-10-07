"""Fail an APK handoff if resource shrinking removed/replaced the SAR sound.

Usage: python tool/verify_apk_alarm.py path/to/app-release.apk
Checks the packaged bytes, including builds with obfuscated resource paths.
"""
import hashlib
import json
import sys
import zipfile
from pathlib import Path


def verify(apk_path):
    source = Path(__file__).resolve().parents[1] / "android/app/src/main/res/raw/sar_alarm.wav"
    sound = source.read_bytes()
    expected = hashlib.sha256(sound).hexdigest()
    with zipfile.ZipFile(apk_path) as apk:
        matches = [
            entry.filename for entry in apk.infolist()
            if entry.filename.startswith("res/") and entry.file_size == len(sound)
            and hashlib.sha256(apk.read(entry)).hexdigest() == expected
        ]
        if not matches:
            raise SystemExit("FAIL: the APK does not contain the original SAR alarm sound")
        return {"apk": str(apk_path), "sarSoundVerified": True,
                "soundEntries": matches, "soundSha256": expected,
                "abis": [name.split('/')[1] for name in apk.namelist()
                         if name.startswith('lib/') and name.endswith('/libapp.so')]}


if __name__ == "__main__":
    print(json.dumps(verify(Path(sys.argv[1])), indent=2))
