import Foundation
import Testing
import Domain
@testable import Audio

/// Feasibility evidence for the existing raw periodic estimate, independent of stable-onset quality.
struct ExpressivePitchProbeTests {
    @Test func movingPitchWindowCenterProbe() throws {
        guard ProcessInfo.processInfo.environment["COACH_EXPRESSIVE_PROBE"] == "1" else { return }
        struct Measurement: Codable {
            let rate: Double; let base: Double; let shape: String; let harmonic: Bool
            let accepted: Int; let total: Int; let medianAbsoluteCents: Double; let p95AbsoluteCents: Double; let peakToPeakCents: Double
        }
        var measurements:[Measurement]=[]
        for rate in [44100.0,48000.0] { for base in [196.0,261.625565,440.0] {
            for shape in ["bend","release","vibrato2","vibrato4","slide"] { for harmonic in [false,true] {
                func cents(_ t:Double)->Double {
                    switch shape {
                    case "bend":return t<0.6 ? 0 : min(200,max(0,(t-0.6)/0.8*200))
                    case "release":return t<0.6 ? 0 : t<1.2 ? (t-0.6)/0.6*200 : t<1.8 ? 200 : max(0,200-(t-1.8)/0.6*200)
                    case "vibrato2":return t<0.6 ? 0 : 50*sin(2 * .pi * 2*(t-0.6))
                    case "vibrato4":return t<0.6 ? 0 : 50*sin(2 * .pi * 4*(t-0.6))
                    default:return t<0.6 ? 0 : min(400,max(0,(t-0.6)/0.4*400))
                    }
                }
                let analyzer=try MonophonicAnalyzer(sampleRate:rate)
                var phase=0.0, samples:[Float]=[]
                for sample in 0..<Int(rate*3) {
                    let t=Double(sample)/rate, frequency=base*pow(2,cents(t)/1200)
                    phase += 2 * .pi * frequency/rate
                    let tone=sin(phase)+(harmonic ? 0.6*sin(2*phase)+0.3*sin(3*phase) : 0)
                    samples.append(Float(0.15*tone*min(1,t/0.005)))
                }
                var errors:[Double]=[],observed:[Double]=[],total=0
                samples.withUnsafeBufferPointer { pcm in
                    analyzer.process(pcm) { observation in
                        let center=Double(observation.time.frame-Int64(PitchDetector.windowFrames/2))/rate
                        guard center>=0.6 && center<2.6 else {return};total+=1
                        guard let e=observation.periodEvidence,e.clarity>=0.9,!e.octaveAmbiguous,e.fundamentalFraction>=0.001 else{return}
                        let actual=1200*log2(e.frequency/base)
                        errors.append(abs(actual-cents(center)));observed.append(actual)
                    }
                }
                errors.sort()
                measurements.append(Measurement(rate:rate,base:base,shape:shape,harmonic:harmonic,accepted:errors.count,total:total,
                    medianAbsoluteCents:errors.isEmpty ? 999 : errors[errors.count/2],p95AbsoluteCents:errors.isEmpty ? 999 : errors[min(errors.count-1,Int(Double(errors.count)*0.95))],peakToPeakCents:(observed.max() ?? 0)-(observed.min() ?? 0)))
            } }
        } }
        let data=try JSONEncoder().encode(measurements)
        try data.write(to:URL(fileURLWithPath:"/tmp/expressive-pitch-probe.json"))
        #expect(measurements.count==60)
    }
}
