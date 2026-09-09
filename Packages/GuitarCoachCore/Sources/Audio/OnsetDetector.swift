import Accelerate
import Foundation

/// Causal positive spectral flux plus energy rise. Pitch changes alone never create an attack.
final class OnsetDetector {
    static let size = 2048
    private let setup: vDSP_DFT_Setup
    private var real = [Float](repeating: 0, count: size)
    private var imaginary = [Float](repeating: 0, count: size)
    private var outputReal = [Float](repeating: 0, count: size)
    private var outputImaginary = [Float](repeating: 0, count: size)
    private var previous = [Float](repeating: 0, count: size / 2)
    private let window: [Float]
    private var recentFlux = [Double](repeating: 0, count: 8)
    private var fluxIndex = 0
    private var previousRMS = 0.0
    private var lastOnset: Int64?
    private let sampleRate: Double

    init(sampleRate: Double) throws {
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.size), .FORWARD) else {
            throw AudioBackendError.allocationFailed
        }
        self.setup = setup; self.sampleRate = sampleRate
        window = (0..<Self.size).map { Float(0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(Self.size - 1))) }
    }
    deinit { vDSP_DFT_DestroySetup(setup) }

    func process(frame: [Float], endFrame: Int64, hop: Int, rms: Double, noiseFloor: Double) -> Int64? {
        let start = frame.count - Self.size
        var energy = 0.0
        for i in 0..<Self.size {
            real[i] = frame[start + i] * window[i]
            energy += Double(frame[start + i]) * Double(frame[start + i])
        }
        let smoothRMS = (energy / Double(Self.size)).squareRoot()
        vDSP_DFT_Execute(setup, real, imaginary, &outputReal, &outputImaginary)
        var increase = 0.0, magnitudeSum = 0.0
        for i in 1..<Self.size / 2 {
            let magnitude = (outputReal[i] * outputReal[i] + outputImaginary[i] * outputImaginary[i]).squareRoot()
            increase += Double(max(0, magnitude - previous[i])); magnitudeSum += Double(magnitude)
            previous[i] = magnitude
        }
        let flux = increase / max(1e-8, magnitudeSum)
        let baseline = recentFlux.sorted()[recentFlux.count / 2]
        recentFlux[fluxIndex] = flux; fluxIndex = (fluxIndex + 1) % recentFlux.count
        let energyRise = smoothRMS > max(0.0015, previousRMS * 1.8)
        previousRMS = max(smoothRMS, previousRMS * 0.75)
        guard endFrame >= max(Self.size, hop * recentFlux.count), smoothRMS > max(0.0015, noiseFloor * 3),
              energyRise || (flux > max(0.16, baseline * 3 + 0.06) && rms >= smoothRMS * 0.7),
              lastOnset == nil || endFrame - lastOnset! >= Int64(sampleRate * 0.08) else { return nil }
        let onset = max(0, endFrame - Int64(energyRise ? hop : Self.size / 2))
        lastOnset = endFrame
        return onset
    }
}
