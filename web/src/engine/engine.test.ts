import { describe, expect, it } from "vitest";
import { Nav } from "./nav";
import { parseTransmission } from "./phraseology";
import { GameEngine } from "./engine";
import { scriptedArrival } from "./engine";

describe("Nav", () => {
  it("normalizes headings", () => {
    expect(Nav.normalize(370)).toBe(10);
    expect(Nav.normalize(-10)).toBe(350);
  });

  it("computes signed turn deltas", () => {
    expect(Nav.signedDelta(350, 10)).toBe(20);
    expect(Nav.signedDelta(10, 350)).toBe(-20);
  });

  it("computes north-east bearings", () => {
    expect(Math.round(Nav.bearing({ x: 0, y: 0 }, { x: 0, y: 10 }))).toBe(0);
    expect(Math.round(Nav.bearing({ x: 0, y: 0 }, { x: 10, y: 0 }))).toBe(90);
  });
});

describe("phraseology", () => {
  it("parses a standard vector transmission", () => {
    const parsed = parseTransmission("United 319, turn left heading 270, descend and maintain 5000", [
      { callsign: "UAL319", spoken: "United 319" },
    ]);
    expect(parsed.targetCallsign).toBe("UAL319");
    expect(parsed.commands).toEqual(
      expect.arrayContaining([
        { type: "turn", kind: "left", heading: 270 },
        { type: "descend", altitude: 5000 },
      ]),
    );
  });
});

describe("GameEngine", () => {
  it("applies heading and altitude commands", () => {
    const engine = new GameEngine({ difficulty: "relaxed", training: true });
    const ac = scriptedArrival("UAL319", "United 319", "jet", { x: 10, y: 10 }, 180, 8000, 250);
    engine.loadScenario([ac]);
    engine.apply(
      parseTransmission("United 319 turn left heading 270 descend and maintain 5000", engine.callsignCandidates),
    );
    expect(engine.selected?.targetHeading).toBe(270);
    expect(engine.selected?.targetAltitude).toBe(5000);
  });
});
