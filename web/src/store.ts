import type { Difficulty, RunResult } from "./engine/types";

const KEY = "atc222-trainer-preview";

export type PlayerProfile = {
  isCertified: boolean;
  preferredDifficulty: Difficulty;
  lifetimeHandled: number;
  bestScores: Record<Difficulty, number>;
  history: RunResult[];
};

const empty: PlayerProfile = {
  isCertified: false,
  preferredDifficulty: "relaxed",
  lifetimeHandled: 0,
  bestScores: { relaxed: 0, standard: 0, intense: 0 },
  history: [],
};

export function loadProfile(): PlayerProfile {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return { ...empty, bestScores: { ...empty.bestScores } };
    return { ...empty, ...JSON.parse(raw) };
  } catch {
    return { ...empty, bestScores: { ...empty.bestScores } };
  }
}

export function saveProfile(profile: PlayerProfile) {
  localStorage.setItem(KEY, JSON.stringify(profile));
}

export function recordRun(profile: PlayerProfile, result: RunResult): PlayerProfile {
  const next: PlayerProfile = {
    ...profile,
    lifetimeHandled: profile.lifetimeHandled + result.landings + result.departures,
    bestScores: {
      ...profile.bestScores,
      [result.difficulty]: Math.max(profile.bestScores[result.difficulty], result.score),
    },
    history: [result, ...profile.history].slice(0, 20),
  };
  saveProfile(next);
  return next;
}
