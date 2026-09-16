/** Navigation maths. Positions are NM from the field: +y north, +x east. */

export type Vec = { x: number; y: number };

export const Nav = {
  normalize(degrees: number): number {
    const v = degrees % 360;
    return v < 0 ? v + 360 : v;
  },

  signedDelta(from: number, to: number): number {
    let diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  },

  vector(heading: number): Vec {
    const rad = (heading * Math.PI) / 180;
    return { x: Math.sin(rad), y: Math.cos(rad) };
  },

  bearing(origin: Vec, point: Vec): number {
    const dx = point.x - origin.x;
    const dy = point.y - origin.y;
    return Nav.normalize((Math.atan2(dx, dy) * 180) / Math.PI);
  },

  distance(a: Vec, b: Vec): number {
    return Math.hypot(a.x - b.x, a.y - b.y);
  },
};

export function rangeFromField(p: Vec): number {
  return Math.hypot(p.x, p.y);
}
