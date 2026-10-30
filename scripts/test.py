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
    color_shim = 'local function fakeColor(r,g,b) return {R=r,G=g,B=b,Lerp=function(self,other,t) return fakeColor(self.R+(other.R-self.R)*t,self.G+(other.G-self.G)*t,self.B+(other.B-self.B)*t) end} end\nlocal Color3 = {new=fakeColor,fromRGB = function(r,g,b) return fakeColor(r/255,g/255,b/255) end}\n'
    garden_module = '\nActualGardenService = (function()\n' + (ROOT / 'src/server/GardenService.luau').read_text() + '\nend)();\n'
    world_modules = ''.join('\nActual' + name + ' = (function()\n'
        + (ROOT / f'src/server/{name}.luau').read_text() + '\nend)();\n'
        for name in ('PortalFactory', 'StationKeeper'))
    harness = (ROOT / 'tests/server_harness.luau').read_text()
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
            server_test.write_text(color_shim + 'local Config = (function()\n' + config + '\nend)()\n' + harness + garden_module + '\n(function()\n' + server.read_text() + '\nend)()\n' + (ROOT / 'tests/server_actions.luau').read_text())
            subprocess.run([runtime, str(server_test)], check=True, cwd=ROOT)
            unpublished_test = Path(temporary) / 'unpublished-run.luau'
            unpublished_test.write_text(color_shim + 'local Config = (function()\n' + config + '\nend)()\n' + harness + garden_module + '\ndataStoreInitFailure=true\n(function()\n' + server.read_text() + '\nend)()\n' + (ROOT / 'tests/unpublished.luau').read_text())
            subprocess.run([runtime, str(unpublished_test)], check=True, cwd=ROOT)
        world_test = Path(temporary) / 'world-run.luau'
        world_test.write_text(color_shim + 'local Config = (function()\n' + config + '\nend)()\n' + harness + '\n' + (ROOT / 'tests/world_startup.luau').read_text() + garden_module + world_modules
            + (ROOT / 'tests/station_keepers.luau').read_text() + '\nverifyStationKeepers(ActualStationKeeper)\n'
            + '\nlocal WorldUnderTest = (function()\n' + (ROOT / 'src/server/World.luau').read_text() + '\nend)()\nverifyWorld(WorldUnderTest)\n')
        subprocess.run([runtime, str(world_test)], check=True, cwd=ROOT)
        model_test = Path(temporary) / 'models-run.luau'
        scene_prefix = color_shim + 'local Config = (function()\n' + config + '\nend)()\n' + (ROOT / 'tests/server_harness.luau').read_text() + '\n' + (ROOT / 'tests/world_startup.luau').read_text() + '\n' + (ROOT / 'tests/model_details.luau').read_text() + '\nConfig = (function()\n' + config + '\nend)()\n'
        model_test.write_text(scene_prefix + '\nlocal FactoryUnderTest = (function()\n' + (ROOT / 'src/shared/CreatureFactory.luau').read_text() + '\nend)()\nverifyModels(FactoryUnderTest, Config)\n')
        subprocess.run([runtime, str(model_test)], check=True, cwd=ROOT)
        detector_test = Path(temporary) / 'detectors-run.luau'
        detector_test.write_text(scene_prefix + '\nlocal DetectorUnderTest = (function()\n'
            + (ROOT / 'src/server/DetectorTool.luau').read_text() + '\nend)()\n'
            + (ROOT / 'tests/detector_tools.luau').read_text() + '\nverifyDetectorTools(DetectorUnderTest,Config)\n')
        subprocess.run([runtime, str(detector_test)], check=True, cwd=ROOT)
        client_test = Path(temporary) / 'client-run.luau'
        client_test.write_text(scene_prefix + '\n' + (ROOT / 'tests/client_ui.luau').read_text() + '\n(function()\n' + (ROOT / 'src/client/Main.client.luau').read_text() + '\nend)()\ncheckClient()\n')
        subprocess.run([runtime, str(client_test)], check=True, cwd=ROOT)
        sprint_test = Path(temporary) / 'sprint-run.luau'
        sprint_test.write_text((ROOT / 'tests/sprint.luau').read_text()
            + '\n;(function()\n' + (ROOT / 'src/server/Sprint.server.luau').read_text()
            + '\nend)()\nverifySprintServer()\n;(function()\n'
            + (ROOT / 'src/client/Sprint.client.luau').read_text()
            + '\nend)()\nverifySprintClient()\n')
        subprocess.run([runtime, str(sprint_test)], check=True, cwd=ROOT)
        portal_test = Path(temporary) / 'portal-effects-run.luau'
        portal_test.write_text((ROOT / 'tests/portal_effects.luau').read_text()
            + '\n;(function()\n' + (ROOT / 'src/client/PortalEffects.client.luau').read_text()
            + '\nend)()\nverifyPortalEffects()\n')
        subprocess.run([runtime, str(portal_test)], check=True, cwd=ROOT)
    print('Studio playtest remains required for rendering, multiplayer and live persistence.', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
