import Domain

enum PracticeBarSelection {
    /// Include whole sustained events at either boundary. Two ordered scans also
    /// handle another event crossing a newly included barline without an unbounded loop.
    static func completeEvents(in exercise: Exercise, first: Int, last: Int) -> ClosedRange<Int> {
        let bar = exercise.timeSignature.ticksPerBar
        let count = Int((exercise.durationTicks - 1) / bar + 1)
        let first = max(1, min(first, count)), last = max(first, min(last, count))
        var lower = Int64(first - 1) * bar
        func endTick(_ last: Int) -> Int64 {
            let value = Int64(last).multipliedReportingOverflow(by: bar)
            return value.overflow ? exercise.durationTicks : min(exercise.durationTicks, value.partialValue)
        }
        var upper = endTick(last)
        for event in exercise.events.reversed() where event.startTick < lower && event.endTick > lower {
            lower = event.startTick / bar * bar
        }
        for event in exercise.events where event.startTick < upper && event.endTick > upper {
            upper = endTick(Int((event.endTick - 1) / bar + 1))
        }
        return (Int(lower / bar) + 1)...Int((upper - 1) / bar + 1)
    }
}
