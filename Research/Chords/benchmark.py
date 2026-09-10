#!/usr/bin/env python3
"""Offline chord feasibility; no product grading and no expected-chord conditioning."""
import argparse, collections, hashlib, json, platform, resource, time
from pathlib import Path
import numpy as np
import scipy
from scipy.io import wavfile
from scipy.optimize import nnls
from scipy.signal import find_peaks, resample_poly

RATE=22050; WINDOW=4096; MIDIS=np.arange(36,89); VERSION='chord-feasibility-1'
TEMPLATES={f'{r}:{q}': {(r+i)%12 for i in intervals} for r in range(12) for q,intervals in [('maj',(0,4,7)),('min',(0,3,7))]}

def exact_chord(notes):
    pcs={int(n)%12 for n in notes}
    return next((key for key,value in TEMPLATES.items() if value==pcs),'unknown')

def dictionary():
    bins=np.arange(WINDOW//2+1);columns=[]
    for midi in MIDIS:
        f=440*2**((int(midi)-69)/12);column=np.zeros_like(bins,dtype=float)
        for harmonic in range(1,9):
            center=f*harmonic*WINDOW/RATE
            if center>=len(bins):break
            column+=np.exp(-0.5*((bins-center)/0.85)**2)/harmonic
        columns.append(column/np.linalg.norm(column))
    return np.stack(columns,axis=1)
D=dictionary(); HANN=np.hanning(WINDOW)

def estimate(signal):
    spectrum=abs(np.fft.rfft(signal*HANN));rms=float(np.sqrt(np.mean(signal**2)))
    if rms<0.0001:return {'chroma':'unknown','harmonic':'unknown','notes':[],'residual':None}
    peaks,_=find_peaks(spectrum,height=max(spectrum)*0.03,distance=2)
    chroma=np.zeros(12)
    for peak in peaks:
        frequency=peak*RATE/WINDOW
        if frequency<55 or frequency>4000:continue
        midi=int(round(69+12*np.log2(frequency/440)))
        chroma[midi%12]+=spectrum[peak]
    norm=np.linalg.norm(chroma)
    scores=sorted(((sum(chroma[list(pcs)])/max(norm*np.sqrt(3),1e-12),key) for key,pcs in TEMPLATES.items()),reverse=True)
    identity=scores[0][1] if scores[0][0]>=0.8 and scores[0][0]-scores[1][0]>=0.08 else 'unknown'
    coefficients,residual=nnls(D,spectrum,maxiter=500)
    relative=float(residual/max(np.linalg.norm(spectrum),1e-12))
    notes=MIDIS[coefficients>=max(coefficients)*0.2].tolist() if max(coefficients)>0 else []
    if relative>0.45 or len(notes)>6:notes=[]
    return {'chroma':identity,'harmonic':exact_chord(notes),'notes':notes,'residual':relative}

def distort(signal):
    peak=max(np.max(abs(signal)),1e-12)
    return np.tanh(4*signal/peak)*0.5

def load_audio(path, condition="clean"):
    rate,signal=wavfile.read(path)
    if signal.ndim!=1:raise ValueError('Expected explicit mono pickup mix')
    if np.issubdtype(signal.dtype,np.integer):signal=signal.astype(float)/max(abs(np.iinfo(signal.dtype).min),np.iinfo(signal.dtype).max)
    else:signal=signal.astype(float)
    if not np.isfinite(signal).all():raise ValueError('Nonfinite audio')
    if condition == "derived-distortion": signal = distort(signal)
    from math import gcd
    divisor=gcd(rate,RATE)
    return resample_poly(signal,RATE//divisor,rate//divisor)

def attacks_from_notes(notes):
    groups=[]
    for onset in sorted(n['onset_s'] for n in notes):
        if not groups or onset-groups[-1]>0.06:groups.append(onset)
    return groups

def detect_attacks(signal):
    size=1024;hop=220;previous=None;flux=[];times=[]
    for end in range(size,len(signal)+1,hop):
        magnitude=abs(np.fft.rfft(signal[end-size:end]*np.hanning(size)))
        flux.append(0 if previous is None else float(np.maximum(magnitude-previous,0).sum()))
        times.append((end-size/2)/RATE);previous=magnitude
    if not flux:return []
    values=np.array(flux);threshold=max(np.median(values)*3,np.max(values)*0.06)
    peaks,_=find_peaks(values,height=threshold,distance=6,prominence=np.max(values)*0.025)
    return [times[p] for p in peaks]

def match_attacks(expected,observed):
    # Small monotonic DP maximizes match count, then minimizes absolute error.
    n=len(expected);m=len(observed);dp=[[None]*(m+1) for _ in range(n+1)];dp[0][0]=(0,0,[])
    for i in range(n+1):
        for j in range(m+1):
            if i==j==0:continue
            candidates=[]
            if i:candidates.append(dp[i-1][j])
            if j:candidates.append(dp[i][j-1])
            if i and j and abs(expected[i-1]-observed[j-1])<=0.05:
                count,cost,errors=dp[i-1][j-1];error=abs(expected[i-1]-observed[j-1]);candidates.append((count+1,cost+error,errors+[error*1000]))
            dp[i][j]=max(candidates,key=lambda value:(value[0],-value[1]))
    matched,_,errors=dp[n][m]
    return {'expected':n,'detected':m,'matched':matched,'errorsMs':errors}

def pitch_metrics(frames):
    tp=fp=fn=exact=octave=0
    for f in frames:
        reference=set(f['referenceNotes']);prediction=set(f['notes']);tp+=len(reference&prediction);fp+=len(prediction-reference);fn+=len(reference-prediction);exact+=reference==prediction
        octave+=sum(any(n!=r and n%12==r%12 for r in reference) for n in prediction-reference)
    return {'frames':len(frames),'tp':tp,'fp':fp,'fn':fn,'precision':tp/(tp+fp) if tp+fp else None,'recall':tp/(tp+fn) if tp+fn else None,'f1':2*tp/(2*tp+fp+fn) if 2*tp+fp+fn else None,'exactAccuracy':exact/len(frames) if frames else None,'octaveExtras':octave}

def summarize(rows):
    summaries=[]
    for split,condition in sorted({(r['split'],r['condition']) for r in rows}):
        subset=[r for r in rows if r['split']==split and r['condition']==condition]
        frames=[f for r in subset for f in r['frames']]
        identities={}
        for method in ['chroma','harmonic']:
            known=[f for f in frames if f['referenceChord']!='unknown'];unknown=[f for f in frames if f['referenceChord']=='unknown']
            accepted=[f for f in frames if f[method]!='unknown'];correct=sum(f[method]==f['referenceChord'] for f in accepted)
            identities[method]={'knownFrames':len(known),'unknownFrames':len(unknown),'accepted':len(accepted),'correct':correct,
                'precision':correct/len(accepted) if accepted else None,'recall':correct/len(known) if known else None,
                'coverage':len(accepted)/len(frames) if frames else None,
                'unknownFalseAcceptance':sum(f[method]!='unknown' for f in unknown)/len(unknown) if unknown else None,
                'confusion':dict(sorted(collections.Counter(f["referenceChord"]+' -> '+f[method] for f in frames).items()))}
        errors=[e for r in subset for e in r['rhythm']['errorsMs']]
        expected=sum(r['rhythm']['expected'] for r in subset);detected=sum(r['rhythm']['detected'] for r in subset);matched=sum(r['rhythm']['matched'] for r in subset)
        summaries.append({'split':split,'condition':condition,'tracks':len(subset),'frames':len(frames),'identity':identities,
            'pitchSet':pitch_metrics(frames),'polyphonicPitchSet':pitch_metrics([f for f in frames if len(f['referenceNotes'])>=2]),
            'rhythmProxy':{'expected':expected,'detected':detected,'matched':matched,'precision':matched/detected if detected else None,'recall':matched/expected if expected else None,'errorMedianMs':float(np.median(errors)) if errors else None,'errorP95Ms':float(np.percentile(errors,95)) if errors else None},
            'analysisWallSeconds':sum(r['analysisWallSeconds'] for r in subset),'audioSeconds':sum(r['audioSeconds'] for r in subset),
            'voicings':len({tuple(f['referenceNotes']) for f in frames}),'referenceClassFrames':dict(sorted(collections.Counter(f['referenceChord'] for f in frames).items()))})
    return summaries

def synthetic_cases():
    values=[]
    for root in [40,45,48,50,55,60]:
        for kind,intervals in [('major',[0,4,7]),('minor',[0,3,7]),('power',[0,7]),('single',[0]),('cluster',[0,1,6]),('extra',[0,4,7,10])]:
            notes=[root+i for i in intervals];t=np.arange(WINDOW)/RATE;signal=np.zeros(WINDOW)
            for note in notes:
                frequency=440*2**((note-69)/12)
                for harmonic in range(1,9):signal+=np.sin(2*np.pi*frequency*harmonic*t+harmonic*0.37)/(harmonic*len(notes))*0.15
            for condition,audio in [('clean',signal),('derived-distortion',distort(signal))]:
                values.append({'id':f'{root}-{kind}-{condition}','referenceNotes':notes,'referenceChord':exact_chord(notes),**estimate(audio)})
    for name,signal in [('silence',np.zeros(WINDOW)),('noise',np.random.default_rng(21).normal(0,0.1,WINDOW))]:
        values.append({'id':name,'referenceNotes':[],'referenceChord':'unknown',**estimate(signal)})
    return values

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);p.add_argument('output',type=Path);p.add_argument('--synthetic-only',action='store_true');args=p.parse_args()
    start=time.perf_counter();rows=[];manifest=None
    if not args.synthetic_only:
        manifest=json.loads((args.directory/'manifest.json').read_text())
        for track in manifest['tracks']:
            path=args.directory/track['file']
            if hashlib.sha256(path.read_bytes()).hexdigest()!=track['sha256']:raise ValueError('Audio hash mismatch')
            notes=track['notes']
            for condition in ['clean','derived-distortion']:
                audio=load_audio(path,condition)
                begin=time.perf_counter();frames=[]
                for center in np.arange(0.25,len(audio)/RATE-0.125,0.25):
                    end=int(round(center*RATE))+WINDOW//2;lower=(end-WINDOW)/RATE;upper=end/RATE
                    active=[n for n in notes if n['onset_s']<=center<n['offset_s']]
                    if not active or any(lower<n['onset_s']<upper or lower<n['offset_s']<upper for n in notes):continue
                    reference=sorted({int(round(n['midi'])) for n in active})
                    frame={'centerSeconds':float(center),'referenceNotes':reference,'referenceChord':exact_chord(reference),**estimate(audio[end-WINDOW:end])};frames.append(frame)
                rhythm=match_attacks(attacks_from_notes(notes),detect_attacks(audio))
                rows.append({'id':track['id'],'player':track['player'],'split':track['split'],'condition':condition,'frames':frames,'rhythm':rhythm,
                             'analysisWallSeconds':time.perf_counter()-begin,'audioSeconds':len(audio)/RATE})
                print(track['id'],condition,len(frames),'frames',flush=True)
    controls=synthetic_cases();usage=resource.getrusage(resource.RUSAGE_SELF)
    report={'schemaVersion':1,'algorithmVersion':VERSION,'protocolSHA256':hashlib.sha256(Path(__file__).with_name('PROTOCOL.md').read_bytes()).hexdigest(),
            'implementationSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'platform':platform.platform(),'python':platform.python_version(),'numpy':np.__version__,'scipy':scipy.__version__,'inputSampleRate':RATE,'windowSamples':WINDOW,'windowMilliseconds':WINDOW/RATE*1000,
            'hardwareMeasured':False,'syntheticDistortionIsRealAmplifier':False,'mirrorRevision':manifest['mirrorRevision'] if manifest else None,
            'totalWallSeconds':time.perf_counter()-start,'processCPUSeconds':usage.ru_utime+usage.ru_stime,'processPeakRSS':usage.ru_maxrss,
            'rssUnit':'bytes on macOS; KiB on Linux','summaries':summarize(rows),'tracks':rows,'syntheticControls':controls}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
if __name__=='__main__':main()
