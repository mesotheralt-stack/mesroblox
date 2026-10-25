#!/usr/bin/env python3
"""Compile every Luau source and test actual economy logic without Roblox Studio.

This runner uses Luau CLI and a Color3 shim for Config. It does not claim Roblox
rendering, multiplayer, or DataStore readiness; those require a Studio playtest.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau-dir', type=Path, help='Directory containing luau and luau-compile')
    args = parser.parse_args()
    def tool(name: str) -> str:
        executable = args.luau_dir / name if args.luau_dir else shutil.which(name)
        if not executable or not Path(executable).is_file():
            parser.error(f'{name} is missing; install Luau CLI or pass --luau-dir')
        return str(executable)

    compiler, runtime = tool('luau-compile'), tool('luau')
    sources = sorted((ROOT / 'src').rglob('*.luau'))
    if not sources:
        parser.error('No Luau sources found')
    subprocess.run([compiler, '--null', *map(str, sources)], check=True, cwd=ROOT)
    print(f'PASS Luau syntax compilation ({len(sources)} source files)', flush=True)
    config = (ROOT / 'src/shared/Config.luau').read_text()
    tests = (ROOT / 'tests/economy.luau').read_text()
    color_shim = 'local Color3 = {fromRGB = function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}\n'
    code = color_shim + 'local Config = (function()\n' + config + '\nend)()\n' + tests
    with tempfile.TemporaryDirectory(prefix='brainrot-tests-') as temporary:
        test_file = Path(temporary) / 'economy-run.luau'
        test_file.write_text(code)
        subprocess.run([runtime, str(test_file)], check=True, cwd=ROOT)
        server = ROOT / 'src/server/Main.server.luau'
        if not server.is_file():
            parser.error('Required src/server/Main.server.luau is missing')
        if server.exists():
            server_test = Path(temporary) / 'server-run.luau'
            server_test.write_text(color_shim + 'local Config = (function()\n' + config + '\nend)()\n' + (ROOT / 'tests/server_harness.luau').read_text() + '\n(function()\n' + server.read_text() + '\nend)()\n' + (ROOT / 'tests/server_actions.luau').read_text())
            subprocess.run([runtime, str(server_test)], check=True, cwd=ROOT)
            unpublished_test = Path(temporary) / 'unpublished-run.luau'
            unpublished_test.write_text(color_shim + 'local Config = (function()\n' + config + '\nend)()\n' + (ROOT / 'tests/server_harness.luau').read_text() + '\ndataStoreInitFailure=true\n(function()\n' + server.read_text() + '\nend)()\n' + (ROOT / 'tests/unpublished.luau').read_text())
            subprocess.run([runtime, str(unpublished_test)], check=True, cwd=ROOT)
    print('Studio playtest remains required for rendering, multiplayer and live persistence.', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
