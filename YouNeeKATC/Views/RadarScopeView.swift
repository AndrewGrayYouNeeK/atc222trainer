import SwiftUI

/// Colour set for the scope. A high-contrast alternative is swapped in for
/// colour-blind players (green/amber/red → blue/white/magenta).
struct RadarPalette {
    let traffic: Color
    let selected: Color
    let conflict: Color
    let emergency: Color
    let grid: Color

    static let standard = RadarPalette(
        traffic: ATC.phosphor, selected: ATC.selected,
        conflict: ATC.conflict, emergency: ATC.emergency, grid: ATC.grid
    )
    static let colorBlind = RadarPalette(
        traffic: Color(red: 0.40, green: 0.85, blue: 1.0),
        selected: Color.white,
        conflict: Color(red: 1.0, green: 0.45, blue: 0.95),
        emergency: Color(red: 1.0, green: 0.30, blue: 0.85),
        grid: Color(red: 0.35, green: 0.6, blue: 0.95).opacity(0.25)
    )
}

/// The live tactical display: range rings, runway, fixes and traffic. Drives the
/// engine each frame and turns taps/drags into selection and heading vectors.
struct RadarScopeView: View {
    @Bindable var engine: GameEngine
    var palette: RadarPalette = .standard
    var showDataBlocks = true
    var reduceMotion = false

    /// In-progress heading drag from an aircraft.
    @State private var dragOrigin: UUID?
    @State private var dragHeading: Double?
    @State private var dragPoint: CGPoint?

    private let displayRange: Double = 42  // NM radius of outer ring

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 * 0.95
            let scale = radius / CGFloat(displayRange)

            TimelineView(.animation) { timeline in
                let sweep = reduceMotion ? nil : sweepAngle(for: timeline.date)
                Canvas { context, _ in
                    draw(in: context, center: center, radius: radius, scale: scale, sweep: sweep)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(center: center, scale: scale))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Radar scope")
            .accessibilityValue(accessibilitySummary)
        }
    }

    // MARK: Coordinate mapping

    private func screenPoint(_ nm: CGPoint, center: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: center.x + nm.x * scale, y: center.y - nm.y * scale)
    }

    // MARK: Gestures

    private func dragGesture(center: CGPoint, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragOrigin == nil {
                    guard let id = nearestAircraft(to: value.startLocation, center: center, scale: scale) else { return }
                    dragOrigin = id
                    engine.select(id)
                }
                guard let id = dragOrigin, let ac = engine.aircraft.first(where: { $0.id == id }) else { return }
                let from = screenPoint(ac.position, center: center, scale: scale)
                let dx = value.location.x - from.x
                let dy = value.location.y - from.y
                if hypot(dx, dy) > 18 {
                    dragHeading = Nav.normalize(atan2(Double(dx), Double(-dy)) * 180 / .pi)
                    dragPoint = value.location
                }
            }
            .onEnded { value in
                defer { dragOrigin = nil; dragHeading = nil; dragPoint = nil }
                if let heading = dragHeading {
                    engine.setHeading(heading)
                } else {
                    // Treat as a tap: (re)select nearest within tolerance.
                    if let id = nearestAircraft(to: value.location, center: center, scale: scale, tolerance: 46) {
                        engine.select(id)
                    }
                }
            }
    }

    private func nearestAircraft(to point: CGPoint, center: CGPoint, scale: CGFloat, tolerance: CGFloat = 60) -> UUID? {
        var best: (id: UUID, dist: CGFloat)?
        for ac in engine.aircraft {
            let p = screenPoint(ac.position, center: center, scale: scale)
            let d = hypot(p.x - point.x, p.y - point.y)
            if best == nil || d < best!.dist { best = (ac.id, d) }
        }
        if let best, best.dist <= tolerance { return best.id }
        return nil
    }

    // MARK: Drawing

    private func sweepAngle(for date: Date) -> Double {
        (date.timeIntervalSinceReferenceDate * 60).truncatingRemainder(dividingBy: 360)
    }

    private func draw(in context: GraphicsContext, center: CGPoint, radius: CGFloat, scale: CGFloat, sweep: Double?) {
        drawGrid(context, center: center, radius: radius)
        if let sweep { drawSweep(context, center: center, radius: radius, angle: sweep) }
        drawRunway(context, center: center, scale: scale)
        drawFixes(context, center: center, scale: scale)
        for ac in engine.aircraft { drawAircraft(context, ac, center: center, scale: scale) }
        drawDragVector(context, center: center, scale: scale)
    }

    private func drawGrid(_ context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        for fraction in stride(from: 0.25, through: 1.0, by: 0.25) {
            let r = radius * fraction
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            context.stroke(Circle().path(in: rect), with: .color(palette.grid), lineWidth: 1)
        }
        for deg in stride(from: 0, to: 360, by: 30) {
            let rad = Double(deg) * .pi / 180
            let outer = CGPoint(x: center.x + CGFloat(sin(rad)) * radius,
                                y: center.y - CGFloat(cos(rad)) * radius)
            var path = Path()
            path.move(to: center); path.addLine(to: outer)
            context.stroke(path, with: .color(palette.grid.opacity(0.4)), lineWidth: 0.5)
            let label = String(format: "%02d", deg == 0 ? 36 : deg / 10)
            let lp = CGPoint(x: center.x + CGFloat(sin(rad)) * (radius - 12),
                             y: center.y - CGFloat(cos(rad)) * (radius - 12))
            context.draw(Text(label).font(ATC.mono(8)).foregroundColor(ATC.hudDim), at: lp)
        }
    }

    private func drawSweep(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double) {
        let trailing = 48
        for i in 0..<trailing {
            let a = (angle - Double(i)) * .pi / 180
            let opacity = (1.0 - Double(i) / Double(trailing)) * 0.20
            let outer = CGPoint(x: center.x + CGFloat(sin(a)) * radius,
                                y: center.y - CGFloat(cos(a)) * radius)
            var path = Path(); path.move(to: center); path.addLine(to: outer)
            context.stroke(path, with: .color(palette.traffic.opacity(opacity)), lineWidth: 2)
        }
        let a = angle * .pi / 180
        let edge = CGPoint(x: center.x + CGFloat(sin(a)) * radius,
                           y: center.y - CGFloat(cos(a)) * radius)
        var line = Path(); line.move(to: center); line.addLine(to: edge)
        context.stroke(line, with: .color(palette.traffic.opacity(0.85)), lineWidth: 2)
    }

    private func drawRunway(_ context: GraphicsContext, center: CGPoint, scale: CGFloat) {
        let rwy = engine.activeRunway
        let dir = Nav.vector(forHeading: rwy.heading)
        let halfLen = CGFloat(rwy.length / 2) * scale
        let t = screenPoint(rwy.threshold, center: center, scale: scale)
        let p1 = CGPoint(x: t.x - dir.x * halfLen, y: t.y + dir.y * halfLen)
        let p2 = CGPoint(x: t.x + dir.x * halfLen, y: t.y - dir.y * halfLen)
        var strip = Path(); strip.move(to: p1); strip.addLine(to: p2)
        context.stroke(strip, with: .color(ATC.hud), lineWidth: 3)

        // Extended centerline (final approach course) as a dashed feather.
        let farMiles: CGFloat = 14
        let far = CGPoint(x: t.x - dir.x * farMiles * scale, y: t.y + dir.y * farMiles * scale)
        var centerLine = Path(); centerLine.move(to: t); centerLine.addLine(to: far)
        context.stroke(centerLine, with: .color(palette.grid.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
        context.draw(Text(rwy.name).font(ATC.mono(9, weight: .bold)).foregroundColor(ATC.hud),
                     at: CGPoint(x: t.x, y: t.y - 14))
    }

    private func drawFixes(_ context: GraphicsContext, center: CGPoint, scale: CGFloat) {
        for fix in engine.airport.fixes {
            let p = screenPoint(fix.position, center: center, scale: scale)
            let r: CGFloat = 4
            var tri = Path()
            tri.move(to: CGPoint(x: p.x, y: p.y - r))
            tri.addLine(to: CGPoint(x: p.x - r, y: p.y + r))
            tri.addLine(to: CGPoint(x: p.x + r, y: p.y + r))
            tri.closeSubpath()
            let color = fix.isArrival ? palette.grid.opacity(0.9) : ATC.hudDim
            context.stroke(tri, with: .color(color), lineWidth: 1)
            context.draw(Text(fix.name).font(ATC.mono(8, weight: .semibold)).foregroundColor(ATC.hudDim),
                         at: CGPoint(x: p.x, y: p.y + 14))
        }
    }

    private func drawAircraft(_ context: GraphicsContext, _ ac: Aircraft, center: CGPoint, scale: CGFloat) {
        let p = screenPoint(ac.position, center: center, scale: scale)
        let isSelected = ac.id == engine.selectedID
        let tint: Color = {
            if ac.emergency != nil { return palette.emergency }
            if ac.conflict { return palette.conflict }
            if isSelected { return palette.selected }
            return palette.traffic
        }()

        // Trail.
        for (i, t) in ac.trail.enumerated() {
            let tp = screenPoint(t, center: center, scale: scale)
            let op = Double(i) / Double(max(ac.trail.count, 1)) * 0.5
            let dot = CGRect(x: tp.x - 1.2, y: tp.y - 1.2, width: 2.4, height: 2.4)
            context.fill(Circle().path(in: dot), with: .color(tint.opacity(op)))
        }

        // Velocity leader (length scales with speed).
        let v = Nav.vector(forHeading: ac.heading)
        let leadLen = CGFloat(12 + ac.speed / 16)
        let lead = CGPoint(x: p.x + v.x * leadLen, y: p.y - v.y * leadLen)
        var leadPath = Path(); leadPath.move(to: p); leadPath.addLine(to: lead)
        context.stroke(leadPath, with: .color(tint), lineWidth: 1.5)

        // Conflict halo.
        if ac.conflict || ac.emergency != nil {
            let ring = CGRect(x: p.x - 14, y: p.y - 14, width: 28, height: 28)
            context.stroke(Circle().path(in: ring), with: .color(tint.opacity(0.8)), lineWidth: 1.5)
        }

        // Blip (square for landing, diamond for departures, dot otherwise).
        let blip = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
        context.fill(Circle().path(in: blip), with: .color(tint))
        if isSelected {
            let box = CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)
            context.stroke(RoundedRectangle(cornerRadius: 3).path(in: box), with: .color(tint), lineWidth: 1.5)
        }

        // Data block.
        if showDataBlocks {
            let arrow = ac.isArrival ? "▼" : "▲"
            let block = "\(ac.callsign)\n\(ac.altitudeLabel) \(arrow) \(ac.speedLabel)"
            context.draw(
                Text(block)
                    .font(ATC.mono(9, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? palette.selected : ATC.hud),
                at: CGPoint(x: p.x + 13, y: p.y - 12),
                anchor: .topLeading
            )
        }
    }

    private func drawDragVector(_ context: GraphicsContext, center: CGPoint, scale: CGFloat) {
        guard let id = dragOrigin, let heading = dragHeading, let point = dragPoint,
              let ac = engine.aircraft.first(where: { $0.id == id }) else { return }
        let from = screenPoint(ac.position, center: center, scale: scale)
        var path = Path(); path.move(to: from); path.addLine(to: point)
        context.stroke(path, with: .color(palette.selected.opacity(0.8)),
                       style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        let label = String(format: "%03.0f°", heading)
        context.draw(Text(label).font(ATC.mono(13, weight: .bold)).foregroundColor(palette.selected),
                     at: CGPoint(x: point.x, y: point.y - 18))
    }

    // MARK: Accessibility

    private var accessibilitySummary: String {
        let count = engine.aircraft.count
        let conflicts = engine.aircraft.filter(\.conflict).count
        var parts = ["\(count) aircraft on scope"]
        if conflicts > 0 { parts.append("\(conflicts) in conflict") }
        if let sel = engine.selected {
            parts.append("selected \(sel.callsign), altitude \(Int(sel.altitude)) feet, \(Int(sel.speed)) knots")
        }
        return parts.joined(separator: ", ")
    }
}
