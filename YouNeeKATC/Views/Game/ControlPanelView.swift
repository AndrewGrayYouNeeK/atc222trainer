import SwiftUI

/// The bottom command deck. Shows nothing until an aircraft is selected, then
/// exposes heading, altitude, speed and clearance controls for it. Every control
/// is a real button/stepper (not just the scope drag) so the game is fully
/// operable with VoiceOver and Switch Control.
struct ControlPanelView: View {
    @Bindable var engine: GameEngine

    var body: some View {
        VStack(spacing: 12) {
            if let selected = engine.selected {
                selectedStrip(selected)
                HStack(alignment: .top, spacing: 12) {
                    HeadingDial(
                        heading: selected.targetHeading ?? selected.heading,
                        onChange: { engine.setHeading($0) }
                    )
                    .frame(width: 104, height: 104)

                    VStack(spacing: 8) {
                        stepperRow(
                            label: "ALT",
                            value: "\(Int((selected.targetAltitude ?? selected.altitude)))′",
                            onDown: { adjustAltitude(selected, by: -1000) },
                            onUp: { adjustAltitude(selected, by: 1000) }
                        )
                        stepperRow(
                            label: "SPD",
                            value: "\(Int((selected.targetSpeed ?? selected.speed)))kt",
                            onDown: { adjustSpeed(selected, by: -10) },
                            onUp: { adjustSpeed(selected, by: 10) }
                        )
                    }
                }
                actionRow(selected)
            } else {
                Text("TAP AN AIRCRAFT TO TAKE CONTROL")
                    .font(ATC.mono(13, weight: .semibold))
                    .foregroundStyle(ATC.hudDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .accessibilityLabel("No aircraft selected. Tap an aircraft on the radar to control it.")
            }
        }
        .padding(14)
        .panel()
    }

    // MARK: Selected strip

    private func selectedStrip(_ ac: Aircraft) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ac.emergency != nil ? ATC.emergency : (ac.conflict ? ATC.conflict : ATC.selected))
                .frame(width: 8, height: 8)
            Text(ac.callsign)
                .font(ATC.mono(16, weight: .bold))
                .foregroundStyle(ATC.selected)
            Text(ac.isArrival ? "ARRIVAL" : "DEPARTURE")
                .font(ATC.mono(10, weight: .semibold))
                .foregroundStyle(ATC.hudDim)
            Spacer()
            if let emergency = ac.emergency {
                Label(emergency.title, systemImage: "exclamationmark.triangle.fill")
                    .font(ATC.mono(10, weight: .bold))
                    .foregroundStyle(ATC.emergency)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Controls

    private func stepperRow(label: LocalizedStringResource, value: String,
                            onDown: @escaping () -> Void, onUp: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label).font(ATC.mono(12, weight: .bold)).foregroundStyle(ATC.hudDim).frame(width: 34, alignment: .leading)
            roundButton("minus", action: onDown).accessibilityLabel("Decrease \(String(localized: label))")
            Text(value)
                .font(ATC.mono(15, weight: .bold))
                .foregroundStyle(ATC.hud)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
            roundButton("plus", action: onUp).accessibilityLabel("Increase \(String(localized: label))")
        }
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ATC.void)
                .frame(width: 40, height: 36)
                .background(RoundedRectangle(cornerRadius: 9).fill(ATC.phosphor))
        }
        .buttonStyle(PressableStyle())
    }

    private func actionRow(_ ac: Aircraft) -> some View {
        HStack(spacing: 10) {
            if ac.isArrival {
                actionButton(ac.clearedToLand ? "GO AROUND" : "CLEARED TO LAND",
                             tint: ac.clearedToLand ? ATC.caution : ATC.success) {
                    if ac.clearedToLand { engine.goAround() } else { engine.clearSelectedToLand() }
                }
            } else if case let .departure(fix) = ac.intent {
                actionButton("DIRECT \(fix)", tint: ATC.success) {
                    engine.directTo(fixNamed: fix)
                }
            }
        }
    }

    private func actionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ATC.mono(14, weight: .bold))
                .foregroundStyle(ATC.void)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 11).fill(tint))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Adjust helpers

    private func adjustAltitude(_ ac: Aircraft, by delta: Double) {
        let current = (ac.targetAltitude ?? ac.altitude)
        let rounded = (current / 1000).rounded() * 1000
        engine.setAltitude(min(max(rounded + delta, 0), 16000))
    }

    private func adjustSpeed(_ ac: Aircraft, by delta: Double) {
        let current = (ac.targetSpeed ?? ac.speed)
        let rounded = (current / 10).rounded() * 10
        engine.setSpeed(rounded + delta)
    }
}

// MARK: - Heading dial

/// A circular, draggable heading selector with a numeric readout in the centre.
/// Dragging anywhere on the ring sets the heading to that bearing.
struct HeadingDial: View {
    let heading: Double
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2
            ZStack {
                Circle().stroke(ATC.phosphor.opacity(0.35), lineWidth: 2)
                ForEach(0..<12) { i in
                    let isCardinal = i % 3 == 0
                    Rectangle()
                        .fill(ATC.phosphor.opacity(isCardinal ? 0.8 : 0.35))
                        .frame(width: isCardinal ? 2 : 1, height: isCardinal ? 9 : 5)
                        .offset(y: -radius + 6)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
                // Bug marker at current heading.
                Circle()
                    .fill(ATC.selected)
                    .frame(width: 9, height: 9)
                    .offset(y: -radius + 6)
                    .rotationEffect(.degrees(heading))
                VStack(spacing: 0) {
                    Text(String(format: "%03.0f", heading))
                        .font(ATC.mono(20, weight: .bold))
                        .foregroundStyle(ATC.selected)
                    Text("HDG").font(ATC.mono(8, weight: .semibold)).foregroundStyle(ATC.hudDim)
                }
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        guard hypot(dx, dy) > radius * 0.25 else { return }
                        onChange(Nav.normalize(atan2(Double(dx), Double(-dy)) * 180 / .pi))
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Heading")
        .accessibilityValue("\(Int(heading)) degrees")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(Nav.normalize(heading + 10))
            case .decrement: onChange(Nav.normalize(heading - 10))
            default: break
            }
        }
    }
}
