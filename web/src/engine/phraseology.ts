export type TurnKind = "left" | "right" | "shortest";
export type SpeedKind = "increase" | "reduce" | "maintain";

export type ATCCommand =
  | { type: "turn"; kind: TurnKind; heading: number }
  | { type: "climb"; altitude: number }
  | { type: "descend"; altitude: number }
  | { type: "maintainAltitude"; altitude: number }
  | { type: "speed"; kind: SpeedKind; knots: number }
  | { type: "direct"; fix: string }
  | { type: "clearedToLand"; runway: string | null };

export type CallsignCandidate = { callsign: string; spoken: string };

export type ParsedTransmission = {
  targetCallsign: string | null;
  spokenCallsign: string | null;
  commands: ATCCommand[];
  rawText: string;
};

const phonetic: Record<string, string> = {
  niner: "nine",
  tree: "three",
  fife: "five",
  oh: "zero",
};

const digitMap: Record<string, number> = {
  zero: 0,
  one: 1,
  two: 2,
  three: 3,
  four: 4,
  five: 5,
  six: 6,
  seven: 7,
  eight: 8,
  nine: 9,
};

const teensMap: Record<string, number> = {
  ten: 10,
  eleven: 11,
  twelve: 12,
  thirteen: 13,
  fourteen: 14,
  fifteen: 15,
  sixteen: 16,
  seventeen: 17,
  eighteen: 18,
  nineteen: 19,
};

const tensMap: Record<string, number> = {
  twenty: 20,
  thirty: 30,
  forty: 40,
  fifty: 50,
  sixty: 60,
  seventy: 70,
  eighty: 80,
  ninety: 90,
};

function normalize(text: string): string[] {
  const cleaned = text.toLowerCase().replace(/[^a-z0-9 ]/g, " ");
  return cleaned
    .split(/\s+/)
    .filter(Boolean)
    .map((w) => phonetic[w] ?? w);
}

function isNumberWord(w: string): boolean {
  return w in digitMap || w in teensMap || w in tensMap || /^\d+$/.test(w);
}

function consumeNumber(words: string[], from: number): { value: number; next: number } | null {
  let i = from;
  while (i < words.length && ["and", "to", "the", "maintain", "heading", "knots", "feet", "flight", "level"].includes(words[i]!)) {
    if (words[i] === "maintain" || words[i] === "heading") break;
    i++;
  }
  if (i >= words.length) return null;
  const first = words[i]!;
  if (/^\d+$/.test(first)) {
    let value = Number(first);
    i++;
    while (i < words.length && /^\d+$/.test(words[i]!) && words[i]!.length === 1) {
      value = value * 10 + Number(words[i]);
      i++;
    }
    return { value, next: i };
  }
  if (first in teensMap) return { value: teensMap[first]!, next: i + 1 };
  if (first in tensMap) {
    let value = tensMap[first]!;
    i++;
    if (i < words.length && first in tensMap && words[i]! in digitMap) {
      value += digitMap[words[i]!]!;
      i++;
    }
    return { value, next: i };
  }
  if (first in digitMap) {
    let value = 0;
    while (i < words.length && words[i]! in digitMap) {
      value = value * 10 + digitMap[words[i]!]!;
      i++;
    }
    return { value, next: i };
  }
  return null;
}

function readAltitude(words: string[], from: number): { value: number; next: number } | null {
  let i = from;
  while (i < words.length && ["and", "maintain", "to", "the", "flight", "level"].includes(words[i]!)) i++;
  const n = consumeNumber(words, i);
  if (!n) return null;
  let alt = n.value;
  if (alt < 20) alt *= 1000;
  else if (alt < 200) alt *= 100;
  return { value: alt, next: n.next };
}

function readSpeed(words: string[], from: number): { value: number; next: number } | null {
  let i = from;
  while (i < words.length && ["speed", "to", "knots", "kts"].includes(words[i]!)) i++;
  const n = consumeNumber(words, i);
  if (!n) return null;
  return { value: n.value, next: n.next };
}

function parseCommands(words: string[]): ATCCommand[] {
  const commands: ATCCommand[] = [];
  let i = 0;
  while (i < words.length) {
    const w = words[i]!;
    if (w === "turn" || w === "fly" || w === "heading") {
      let j = i + 1;
      let kind: TurnKind = "shortest";
      if (w === "turn") {
        if (words[j] === "left") {
          kind = "left";
          j++;
        } else if (words[j] === "right") {
          kind = "right";
          j++;
        }
      }
      while (["to", "heading", "onto", "a", "fly"].includes(words[j] ?? "")) j++;
      const n = consumeNumber(words, j);
      if (n) {
        commands.push({ type: "turn", kind, heading: ((n.value % 360) + 360) % 360 });
        i = n.next;
        continue;
      }
    } else if (w === "climb") {
      const alt = readAltitude(words, i + 1);
      if (alt) {
        commands.push({ type: "climb", altitude: alt.value });
        i = alt.next;
        continue;
      }
    } else if (w === "descend" || w === "descent") {
      const alt = readAltitude(words, i + 1);
      if (alt) {
        commands.push({ type: "descend", altitude: alt.value });
        i = alt.next;
        continue;
      }
    } else if (w === "maintain") {
      if (words[i + 1] === "speed") {
        const kts = readSpeed(words, i + 2);
        if (kts) {
          commands.push({ type: "speed", kind: "maintain", knots: kts.value });
          i = kts.next;
          continue;
        }
      } else {
        const alt = readAltitude(words, i + 1);
        if (alt) {
          commands.push({ type: "maintainAltitude", altitude: alt.value });
          i = alt.next;
          continue;
        }
      }
    } else if (w === "reduce" || w === "increase") {
      const kts = readSpeed(words, i + 1);
      if (kts) {
        commands.push({ type: "speed", kind: w === "reduce" ? "reduce" : "increase", knots: kts.value });
        i = kts.next;
        continue;
      }
    } else if (w === "speed") {
      const kts = readSpeed(words, i + 1);
      if (kts) {
        commands.push({ type: "speed", kind: "maintain", knots: kts.value });
        i = kts.next;
        continue;
      }
    } else if (w === "direct" || (w === "proceed" && words[i + 1] === "direct")) {
      const idx = w === "direct" ? i + 1 : i + 2;
      const fix = words[idx];
      if (fix && !isNumberWord(fix) && !["to", "the"].includes(fix)) {
        commands.push({ type: "direct", fix: fix.toUpperCase() });
        i = idx + 1;
        continue;
      }
    } else if (w === "cleared" || (w === "clear" && words[i + 1] === "to")) {
      commands.push({ type: "clearedToLand", runway: null });
      i += 1;
      continue;
    }
    i++;
  }
  return commands;
}

function resolveCallsign(words: string[], candidates: CallsignCandidate[]): CallsignCandidate | null {
  const joined = words.join(" ");
  for (const c of candidates) {
    const spoken = c.spoken.toLowerCase();
    const code = c.callsign.toLowerCase();
    if (joined.includes(spoken) || joined.includes(code)) return c;
    const airline = spoken.split(" ")[0];
    const number = spoken.split(" ").slice(1).join(" ");
    if (airline && number && joined.includes(airline) && joined.includes(number)) return c;
  }
  return null;
}

export function parseTransmission(transcript: string, candidates: CallsignCandidate[]): ParsedTransmission {
  const words = normalize(transcript);
  const match = resolveCallsign(words, candidates);
  return {
    targetCallsign: match?.callsign ?? null,
    spokenCallsign: match?.spoken ?? null,
    commands: parseCommands(words),
    rawText: transcript,
  };
}

export function commandPhrase(command: ATCCommand): string {
  switch (command.type) {
    case "turn": {
      const h = String(command.heading === 0 ? 360 : command.heading).padStart(3, "0");
      if (command.kind === "left") return `turn left heading ${h}`;
      if (command.kind === "right") return `turn right heading ${h}`;
      return `fly heading ${h}`;
    }
    case "climb":
      return `climb and maintain ${command.altitude}`;
    case "descend":
      return `descend and maintain ${command.altitude}`;
    case "maintainAltitude":
      return `maintain ${command.altitude}`;
    case "speed":
      if (command.kind === "increase") return `increase speed ${command.knots} knots`;
      if (command.kind === "reduce") return `reduce speed ${command.knots} knots`;
      return `maintain ${command.knots} knots`;
    case "direct":
      return `proceed direct ${command.fix}`;
    case "clearedToLand":
      return command.runway ? `cleared to land runway ${command.runway}` : "cleared to land";
  }
}
