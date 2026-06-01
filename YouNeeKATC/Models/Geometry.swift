import CoreGraphics
import Foundation

/// Small grab-bag of navigation maths shared by the engine and the radar view.
/// All positions are expressed in nautical miles relative to the airport, with
/// +y pointing north and +x pointing east. Headings are degrees clockwise from
/// north (000 = north, 090 = east), matching real ATC convention.
enum Nav {

    /// Wraps any angle into the 0..<360 range.
    static func normalize(_ degrees: Double) -> Double {
        let v = degrees.truncatingRemainder(dividingBy: 360)
        return v < 0 ? v + 360 : v
    }

    /// Signed smallest turn from `current` to `target`, in -180...180 degrees.
    /// Negative means turn left (counter-clockwise), positive means turn right.
    static func signedDelta(from current: Double, to target: Double) -> Double {
        var diff = (target - current).truncatingRemainder(dividingBy: 360)
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        return diff
    }

    /// Unit movement vector for a heading (per the +y-north convention).
    static func vector(forHeading heading: Double) -> CGPoint {
        let rad = heading * .pi / 180
        return CGPoint(x: sin(rad), y: cos(rad))
    }

    /// Compass bearing from `origin` to `point` in degrees (0..<360).
    static func bearing(from origin: CGPoint, to point: CGPoint) -> Double {
        let dx = Double(point.x - origin.x)
        let dy = Double(point.y - origin.y)
        return normalize(atan2(dx, dy) * 180 / .pi)
    }

    /// Great-plane distance in NM between two sector points.
    static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        Double(hypot(a.x - b.x, a.y - b.y))
    }
}

extension Double {
    /// Convenience wrapper used throughout the engine for heading wrap-around.
    var normalizedHeading: Double { Nav.normalize(self) }
}

extension CGPoint {
    /// Magnitude from the origin (range from the airport, in NM).
    var rangeFromField: Double { Double(hypot(x, y)) }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}
