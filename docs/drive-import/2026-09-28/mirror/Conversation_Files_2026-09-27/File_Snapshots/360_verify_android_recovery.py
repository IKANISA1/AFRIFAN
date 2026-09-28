#!/usr/bin/env python3
"""Compile and run the PORTABLE Kotlin recovery core in a fresh temporary JAR.

Does not compile Android/Flutter host code, download SDKs, register a plugin, provision
keys, or deploy. Native device acceptance is a separate blocked gate even on success.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'packages/features/feat_membership/native/android'
KERNEL = ('RecoveryProtocol.kt', 'EncryptedRecoveryFile.kt', 'RecoveryStore.kt', 'RecoveryDispatcher.kt')
HOST = ('AndroidRecoveryHost.kt', 'NativeCheckoutRecoveryPlugin.kt')

def verify(results: Path) -> int:
    results.mkdir(parents=True, exist_ok=True)
    report = {'schemaVersion': 1, 'portableJvmCompiled': False, 'portableJvmTestsPassed': 0,
              'androidHostCompiled': False, 'androidKeystoreVerified': False, 'flutterBridgeVerified': False,
              'deviceStorageVerified': False, 'appsRegistered': 0, 'steps': [], 'sourceHashes': {}}
    def finish(status: str, reason: str, code: int) -> int:
        report.update(status=status, reason=reason)
        (results / 'android-recovery-verification.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report, indent=2))
        return code
    compiler, java = shutil.which('kotlinc'), shutil.which('java')
    if not compiler or not java:
        return finish('blocked', 'kotlinc and Java are required; missing tools are not passed tests', 2)
    folder = SOURCE / 'src/main/kotlin/com/africlub/recovery'
    files = [folder / name for name in KERNEL] + [SOURCE / 'tests/RecoveryContractHarness.kt']
    for path in files + [folder / name for name in HOST]:
        if not path.is_file() or path.is_symlink():
            return finish('failed', 'Missing or symlinked recovery source', 1)
        report['sourceHashes'][str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    try:
        for name, command in [('kotlin-version',[compiler,'-version']),('java-version',[java,'-version'])]:
            p = subprocess.run(command,text=True,capture_output=True,timeout=30,check=True)
            (results / (name+'.log')).write_text(p.stdout+p.stderr)
        with tempfile.TemporaryDirectory(prefix='africlub-jvm-recovery-') as directory:
            jar = Path(directory) / 'recovery-tests.jar'
            # Never reuse a stale JAR when compilation fails. The directory is new for every invocation.
            for name, command in [('compile',[compiler,*map(str,files),'-Werror','-include-runtime','-d',str(jar)]),
                                  ('contracts',[java,'-jar',str(jar)])]:
                p = subprocess.run(command,text=True,capture_output=True,timeout=120)
                output = p.stdout+p.stderr
                (results / (name+'.log')).write_text(output)
                report['steps'].append({'name':name,'exitCode':p.returncode})
                if p.returncode:
                    return finish('failed', 'Portable '+name+' failed; no native acceptance inferred', 1)
                if name=='compile':
                    if not jar.is_file():
                        return finish('failed', 'Compiler produced no JAR', 1)
                    report['portableJvmCompiled']=True
                else:
                    matches = re.findall(r'^SUMMARY passed=(\d+) failed=0 skipped=0$',output,re.M)
                    passed_lines = len(re.findall(r'^PASS ',output,re.M))
                    if len(matches)!=1 or int(matches[0])!=passed_lines or passed_lines==0:
                        return finish('failed', 'Missing or inconsistent complete harness result', 1)
                    report['portableJvmTestsPassed']=passed_lines
    except (OSError,subprocess.SubprocessError) as exc:
        return finish('failed', 'Verification unavailable: '+type(exc).__name__, 1)
    return finish('passed_portable_jvm_only', 'Android host, Keystore, Flutter/Dart and device tests are still required', 0)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--results',required=True,type=Path)
    sys.exit(verify(parser.parse_args().results.resolve()))
