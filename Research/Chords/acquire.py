#!/usr/bin/env python3
"""Fetch a fixed research subset; never read user audio or launch capture."""
import argparse, hashlib, json, time, urllib.request, urllib.error
from pathlib import Path

REVISION = '4aca25487bef5cb0d2c4ec146218f9145402a776'
ROWS = [0, 40, 60, 100, 120, 160, 180, 220, 240, 280, 300, 340]
EXCLUDED = {'04_BN3-154-E_comp', '04_Jazz1-200-B_comp', '02_Funk2-119-G_comp'}
def sha(data): return hashlib.sha256(data).hexdigest()
def fetch(url):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=30) as response: return response.read()
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2: raise
            time.sleep(1 + attempt)
def main():
    parser = argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=Path);args=parser.parse_args()
    args.directory.mkdir(parents=True,exist_ok=True)
    tracks=[]
    expected_path=Path(__file__).with_name('corpus.json')
    expected=json.loads(expected_path.read_text()) if expected_path.exists() else None
    for index in ROWS:
        url=f'https://datasets-server.huggingface.co/rows?dataset=jhartquist%2Fguitarset&config=default&split=train&offset={index}&length=1'
        response=json.loads(fetch(url));cell=response['rows'][0]
        if cell.get('truncated_cells'): raise ValueError('Truncated annotation row')
        row=cell['row'];track=row['track_id']
        if row['style']!='comp' or track in EXCLUDED: raise ValueError('Unexpected or excluded selected recording')
        source=row['audio_mono_pickup_mix'][0]['src']
        if f'/--/{REVISION}/--/' not in source: raise ValueError('Mirror revision changed; do not silently change corpus')
        audio=fetch(source)
        if audio[:4] not in (b'RIFF',b'RF64'):raise ValueError('Expected WAV data')
        target=args.directory/(track+'.wav');target.write_bytes(audio)
        notes=row['notes']
        if not notes or any(n['offset_s']<=n['onset_s'] for n in notes):raise ValueError('Invalid note annotations')
        entry={'id':track,'row':index,'player':row['player'],'split':'heldout' if row['player']>=4 else 'development',
               'file':target.name,'sha256':sha(audio),'durationSeconds':row['duration_s'],'notes':notes,
               'chords':row['chords'],'beatsSeconds':row['beats_s']}
        if expected:
            pinned=next(t for t in expected['tracks'] if t['row']==index)
            annotation_hash=sha(json.dumps(notes,sort_keys=True,separators=(',',':')).encode())
            if pinned['id']!=track or pinned['sha256']!=sha(audio) or pinned['annotationSHA256']!=annotation_hash:
                raise ValueError('Downloaded corpus differs from committed hashes')
        tracks.append(entry);print(track,len(audio),len(notes),flush=True)
    if sorted(t['player'] for t in tracks)!=[p for p in range(6) for _ in range(2)]:raise ValueError('Unexpected player split')
    manifest={'schemaVersion':1,'source':'GuitarSet 1.1.0 acoustic pickup mix','doi':'10.5281/zenodo.3371780',
              'mirror':'https://huggingface.co/datasets/jhartquist/guitarset','mirrorRevision':REVISION,
              'license':'CC-BY-4.0','sourceAnnotationCaveat':'Mirror-derived note labels; no independent human re-annotation. Upstream known-error tracks excluded.',
              'tracks':tracks}
    (args.directory/'manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
if __name__=='__main__':main()
