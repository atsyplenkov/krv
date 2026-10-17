"""Release checks use only Python's standard library and Android SDK tools."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

CERTIFICATE = 'b813d691b1b988a2caf4c56dd17959df3ef7269f6a57f3cdc8cc5fec1302750c'

def run(*args):
    return subprocess.check_output(args, text=True, encoding='utf-8').strip()

def version(text):
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', text, re.M)
    if not match:
        raise ValueError('Expected a stable version x.y.z+build in pubspec.yaml')
    return match[1], int(match[2])

def validate_version():
    name, code = version(Path('pubspec.yaml').read_text(encoding='utf-8'))
    subprocess.run(['git', 'merge-base', '--is-ancestor', 'HEAD', 'origin/main'], check=True)
    if os.environ.get('GITHUB_REF_TYPE') == 'tag':
        tag = os.environ['GITHUB_REF_NAME']
        if tag != 'v' + name:
            raise ValueError('Tag and pubspec version must match')
        current = tuple(map(int, name.split('.')))
        for previous in run('git', 'tag', '--list', 'v*').splitlines():
            if previous == tag or not re.fullmatch(r'v\d+\.\d+\.\d+', previous):
                continue
            old_name, old_code = version(run('git', 'show', previous + ':pubspec.yaml'))
            if current <= tuple(map(int, old_name.split('.'))) or code <= old_code:
                raise ValueError('Version and Android build number must exceed previous releases')
    print(f'Validated {name}+{code} on main history')

def write_signing():
    names = ['KRV_KEYSTORE_BASE64', 'KRV_STORE_PASSWORD', 'KRV_KEY_PASSWORD', 'KRV_KEY_ALIAS']
    if any(not os.environ.get(name) for name in names):
        raise ValueError('Required GitHub signing secrets are missing')
    directory = Path(os.environ['RUNNER_TEMP']) / 'krv-signing'
    directory.mkdir(mode=0o700, exist_ok=False)
    key = directory / 'signing.p12'
    key.write_bytes(base64.b64decode(os.environ['KRV_KEYSTORE_BASE64'], validate=True))
    def escape(value):
        return value.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace(' ', '\\ ')
    values = {'storeFile': key.as_posix(), 'storePassword': os.environ['KRV_STORE_PASSWORD'], 'keyPassword': os.environ['KRV_KEY_PASSWORD'], 'keyAlias': os.environ['KRV_KEY_ALIAS']}
    (directory / 'signing.properties').write_text(''.join(f'{k}={escape(v)}\n' for k, v in values.items()), encoding='utf-8')

def verify_apk():
    name, code = version(Path('pubspec.yaml').read_text(encoding='utf-8'))
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
    candidates = [p for p in (sdk / 'build-tools').iterdir() if re.fullmatch(r'\d+\.\d+\.\d+', p.name)]
    build_tools = max(candidates, key=lambda p: tuple(map(int, p.name.split('.'))))
    apk = Path('build/app/outputs/flutter-apk/app-release.apk')
    certificate = run(str(build_tools / 'apksigner'), 'verify', '--verbose', '--print-certs', str(apk))
    fingerprints = re.findall(r'certificate SHA-256 digest: ([0-9a-f]+)', certificate)
    if fingerprints != [CERTIFICATE]:
        raise ValueError('APK signature does not match the preserved certificate')
    badging = run(str(build_tools / 'aapt'), 'dump', 'badging', str(apk))
    expected = f"package: name='krv.app' versionCode='{code}' versionName='{name}'"
    if not badging.startswith(expected) or 'application-debuggable' in badging:
        raise ValueError('APK package, version or debuggability is incorrect')
    output = Path('dist')
    output.mkdir(exist_ok=True)
    target = output / f'krv-{name}.apk'
    shutil.copyfile(apk, target)
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    (output / 'SHA256SUMS.txt').write_text(f'{digest}  {target.name}\n', encoding='utf-8')
    (output / 'build-info.json').write_text(json.dumps({'version': name, 'versionCode': code, 'applicationId': 'krv.app', 'commit': run('git', 'rev-parse', 'HEAD'), 'certificateSha256': CERTIFICATE, 'apkSha256': digest}, indent=2) + '\n', encoding='utf-8')
    print(f'Verified signed release APK: {target.name}; SHA-256 {digest}')

if __name__ == '__main__':
    {'version': validate_version, 'signing': write_signing, 'apk': verify_apk}[sys.argv[1]]()
