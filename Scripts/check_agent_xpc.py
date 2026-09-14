import argparse, pathlib, tempfile, shutil, plistlib, subprocess
parser = argparse.ArgumentParser(description="Signed sandbox-to-XPC check. Live mode sends only a synthetic sine fixture.")
parser.add_argument("--configuration", choices=["debug", "release"], default="debug")
parser.add_argument("--live-synthetic", choices=["codex", "claude"])
args = parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='coach-xpc-') as temp:
 app=pathlib.Path(temp)/'CoachProbe.app'
 shutil.copytree(root/'build'/args.configuration/'PersonalGuitarCoach.app',app)
 shutil.copy2(root/'.build'/args.configuration/'AgentServiceProbe',app/'Contents/MacOS/PersonalGuitarCoach')
 subprocess.run(['codesign','--force','--sign','-','--options','runtime','--entitlements',str(root/'App/PersonalGuitarCoach.entitlements'),str(app)],check=True)
 command = [str(app/'Contents/MacOS/PersonalGuitarCoach')]
 if args.live_synthetic:
  command += ['--live-synthetic', args.live_synthetic]
 subprocess.run(command,check=True,timeout=345 if args.live_synthetic else 25)
