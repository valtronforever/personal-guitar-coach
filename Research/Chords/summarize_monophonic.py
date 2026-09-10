#!/usr/bin/env python3
"""Compare production mono observations at the research frame centers; never infer chords."""
import argparse,bisect,collections,json
from pathlib import Path
from benchmark import match_attacks
p=argparse.ArgumentParser(description=__doc__);p.add_argument('polyphonic',type=Path);p.add_argument('monophonic',type=Path);p.add_argument('output',type=Path);args=p.parse_args()
poly=json.loads(args.polyphonic.read_text());mono=json.loads(args.monophonic.read_text());rows=[]
for record in mono['results']:
    reference=next(r for r in poly['tracks'] if r['id']==record['id'] and r['condition']==record['condition'])
    times=[f['seconds'] for f in record['frames']];comparisons=[]
    for frame in reference['frames']:
        index=bisect.bisect_right(times,frame['centerSeconds'])-1
        observation=record['frames'][index] if index>=0 and frame['centerSeconds']-times[index]<=.02 else None
        predicted=[] if observation is None or observation['quality']!='reliable' or observation.get('midi') is None else [observation['midi']]
        comparisons.append({'centerSeconds':frame['centerSeconds'],'referenceNotes':frame['referenceNotes'],'prediction':predicted,'quality':observation['quality'] if observation else 'unavailable'})
    rows.append({'id':record['id'],'split':record['split'],'condition':record['condition'],
        'frameQualityCounts':dict(collections.Counter(f['quality'] for f in record['frames'])),
        'attackQualityCounts':dict(collections.Counter(a['quality'] for a in record['attacks'])),
        'totalEvents':record['totalEvents'],'audioSeconds':record['audioSeconds'],'processingSeconds':record['processingSeconds'],'comparisons':comparisons})
summaries=[]
for split,condition in sorted({(r['split'],r['condition']) for r in rows}):
    group=[r for r in rows if r['split']==split and r['condition']==condition];frames=[f for r in group for f in r['comparisons']]
    tp=fp=fn=0
    for f in frames:
        expected=set(f['referenceNotes']);observed=set(f['prediction']);tp+=len(expected&observed);fp+=len(observed-expected);fn+=len(expected-observed)
    quality=collections.Counter();attacks=collections.Counter()
    for r in group:quality.update(r['frameQualityCounts']);attacks.update(r['attackQualityCounts'])
    summaries.append({'split':split,'condition':condition,'eligibleFrames':len(frames),'qualityCountsAllFrames':dict(quality),'attackQualityCounts':dict(attacks),
        'eligibleReliableFrames':sum(bool(f['prediction']) for f in frames),'pitchSetPrecision':tp/(tp+fp) if tp+fp else None,'pitchSetRecall':tp/(tp+fn) if tp+fn else None,
        'exactSetAccuracy':sum(set(f['referenceNotes'])==set(f['prediction']) for f in frames)/len(frames) if frames else None,
        'processingRealTimeFactor':sum(r['processingSeconds'] for r in group)/sum(r['audioSeconds'] for r in group)})
report={'schemaVersion':1,'algorithmVersion':mono['algorithmVersion'],'mode':mono['mode'],'chordAssessmentSupported':False,'hardwareMeasured':False,
    'comparison':'Last production observation <= frame center, age <=20 ms; mono can emit at most one pitch. Chord baseline uses a centered 186-ms window. Different window alignment is explicit; neither uses expected pitches.',
    'summaries':summaries,'tracks':rows}
args.output.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
print(json.dumps(summaries,indent=2))
