import SwiftUI
import Domain

struct PitchTransitionMarker: Equatable {
    let tick: Int64
    let position: FretPosition
    let durationTicks: Int64
    let continuation: Bool
}

struct PitchTechniqueLink {
    let startTick: Int64
    let endTick: Int64
    let mark: String
    var slide = false
    var ascending = true
}

enum PitchTransitionPresentation {
    static func links(_ event: MusicalEvent) -> [PitchTechniqueLink] {
        if let transition = event.pitchTransition {
            return [.init(startTick: event.startTick + (transition.kind == .slide ? transition.startTick : 0),
                endTick: event.startTick + transition.endTick, mark: mark(transition), slide: transition.kind == .slide, ascending: transition.semitones > 0)]
        }
        guard let chain = event.legatoChain else { return [] }
        return chain.targets.enumerated().map { index, target in
            .init(startTick: event.startTick + chain.boundaryTicks[index], endTick: event.startTick + target.startTick,
                mark: target.kind == .hammerOn ? "h" : target.kind == .pullOff ? "p" : "t")
        }
    }
    static func mark(_ transition: PitchTransition) -> String {
        switch transition.kind { case .slide: transition.semitones > 0 ? "/" : "\\"; case .hammerOn: "h"; case .pullOff: "p" }
    }
    static func markers(_ segment: TimelineSegment) -> [PitchTransitionMarker] {
        let event = segment.resolved.event
        let phases: [(Int64, Int64, FretPosition)]
        if let chain = event.legatoChain {
            let boundaries = chain.boundaryTicks + [event.durationTicks]
            phases = event.techniquePositions.enumerated().map { (event.startTick + boundaries[$0.offset], event.startTick + boundaries[$0.offset + 1], $0.element) }
        } else if let transition = event.pitchTransition, let base = event.positions.first,
                  let target = try? transition.targetPosition(from: base) {
            let targetTick = event.startTick + transition.endTick
            phases = [(event.startTick, targetTick, base), (targetTick, event.endTick, target)]
        } else { return [] }
        var markers: [PitchTransitionMarker] = []
        for (start, end, position) in phases {
            let low = max(start, segment.startTick), high = min(end, segment.endTick)
            if low < high { markers.append(PitchTransitionMarker(tick: low, position: position, durationTicks: segment.triplet == nil ? end - start : (end - start) / 2 * 3, continuation: low > start)) }
        }
        return markers
    }
    static func spoken(event: ResolvedEvent, pulseTicks: Int64, tuning: TuningProfile, locale: Locale, localized: (String) -> String) -> String {
        if let chain = event.event.legatoChain {
            return chain.targets.enumerated().map { index, target in
                let position = event.event.techniquePositions[index + 1]
                let pitch = (try? tuning.pitch(at: position).name(spelling: tuning.preferredSpelling)) ?? ""
                let beat = (Double(target.startTick) / Double(pulseTicks) + 1).formatted(.number.precision(.fractionLength(0...2)).locale(locale))
                let kindKey = "legato.kind." + target.kind.rawValue
                return String(format: localized("legato.spoken %@ %@ %lld %@"), locale: locale,
                    localized(kindKey), beat, Int64(position.fret), pitch)
            }.joined(separator: "; ")
        }
        guard let transition = event.event.pitchTransition, let target = event.transitionTargetPitch,
              let position = event.event.techniquePositions.last else { return "" }
        let start = (Double(transition.startTick) / Double(pulseTicks) + 1).formatted(.number.precision(.fractionLength(0...2)).locale(locale))
        let arrival = (Double(transition.endTick) / Double(pulseTicks) + 1).formatted(.number.precision(.fractionLength(0...2)).locale(locale))
        let kindKey = "transition.kind." + transition.kind.rawValue
        return String(format: localized("transition.spoken %@ %@ %@ %lld %@"), locale: locale,
            localized(kindKey), start, arrival, Int64(position.fret), target.name(spelling: tuning.preferredSpelling))
    }
}

/// One selectable authored event; the second fret has its own musical-time coordinate, not a new pick attack.
struct PitchTransitionTabContent: View {
    let segment: TimelineSegment
    let width: Double
    let gridTop: Double
    let stringSpacing: Double
    let anchorX: Double
    let zoom: Double
    let compact: Bool
    private func x(_ tick: Int64) -> Double {
        let raw = Double(tick - segment.startTick) / Double(segment.endTick - segment.startTick) * width + anchorX
        return min(max(anchorX, width - anchorX), max(anchorX, raw))
    }
    var body: some View {
        if segment.resolved.event.pitchTransition != nil || segment.resolved.event.legatoChain != nil {
            let event = segment.resolved.event, markers = PitchTransitionPresentation.markers(segment)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    guard let position = event.positions.first else { return }
                    for link in PitchTransitionPresentation.links(event) {
                    let start = link.startTick, arrival = link.endTick
                    let low = max(start, segment.startTick), high = min(arrival, segment.endTick)
                    guard low < high else { continue }
                    let a = low == segment.startTick && low > start ? 0 : x(low) + 10 * zoom
                    let b = high == segment.endTick && high < arrival ? width : x(high) - 10 * zoom
                    let y = gridTop + (Double(position.string) - 0.5) * stringSpacing - 3 * zoom
                    var path = Path(); path.move(to: CGPoint(x: a, y: y))
                    if link.slide { path.addLine(to: CGPoint(x: max(a, b), y: y - 6 * zoom)) }
                    else { path.addQuadCurve(to: CGPoint(x: max(a, b), y: y), control: CGPoint(x: (a + b) / 2, y: y - 15 * zoom)) }
                    context.stroke(path, with: .color(.primary), lineWidth: 1.5)
                    context.draw(Text(verbatim: link.mark).font(.system(size: 11 * zoom, weight: .bold)),
                        at: CGPoint(x: (a + b) / 2, y: y - 12 * zoom))
                    }
                }
                ForEach(markers, id: \.tick) { marker in
                    Text(verbatim: (marker.continuation ? "↳" : "") + TimelineModel.durationLabel(marker.durationTicks))
                        .font(.system(size: (compact ? 8 : 11) * zoom).monospacedDigit())
                        .position(x: x(marker.tick), y: (compact ? 28 : 34) * zoom)
                    Text(verbatim: String(marker.position.fret))
                        .font(.system(size: (compact ? 12 : 14) * zoom, weight: .bold, design: .monospaced))
                        .frame(minWidth: (compact ? 15 : 24) * zoom, minHeight: (compact ? 16 : 24) * zoom)
                        .background(.background, in: RoundedRectangle(cornerRadius: 3))
                        .position(x: x(marker.tick), y: gridTop + (Double(marker.position.string) - 0.5) * stringSpacing)
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}
