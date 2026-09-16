import { useEffect, useRef, useState } from "react";
import { curriculum, goalMet, scenarioAircraft, type AcademyLesson } from "../engine/academy";
import { GameEngine } from "../engine/engine";
import { parseTransmission } from "../engine/phraseology";
import {
  DIFFICULTIES,
  difficultyMeta,
  emergencyMeta,
  gameOverHeadline,
  rankForHandled,
  rankProgress,
  rankRemaining,
  type Difficulty,
  type GameOverReason,
  type RunResult,
} from "../engine/types";
import { loadProfile, recordRun, saveProfile, type PlayerProfile } from "../store";
import { ControlDeck } from "./ControlDeck";
import { RadarScope } from "./RadarScope";

type Screen = "menu" | "academy" | "game" | "stats";

export function App() {
  const [screen, setScreen] = useState<Screen>("menu");
  const [profile, setProfile] = useState<PlayerProfile>(() => loadProfile());
  const [difficulty, setDifficulty] = useState<Difficulty>(profile.preferredDifficulty);

  const setPreferred = (next: Difficulty) => {
    setDifficulty(next);
    const updated = { ...profile, preferredDifficulty: next };
    saveProfile(updated);
    setProfile(updated);
  };

  return (
    <div className="crt">
      {screen === "menu" && (
        <MainMenu
          profile={profile}
          difficulty={difficulty}
          onDifficulty={setPreferred}
          onAcademy={() => setScreen("academy")}
          onPlay={() => setScreen("game")}
          onStats={() => setScreen("stats")}
        />
      )}
      {screen === "stats" && <StatsScreen profile={profile} onBack={() => setScreen("menu")} />}
      {screen === "game" && (
        <GameScreen
          difficulty={difficulty}
          onExit={(result) => {
            if (result) setProfile(recordRun(profile, result));
            setScreen("menu");
          }}
        />
      )}
      {screen === "academy" && (
        <AcademyScreen
          onExit={() => setScreen("menu")}
          onGraduate={(d) => {
            const updated = { ...profile, isCertified: true };
            saveProfile(updated);
            setProfile(updated);
            setDifficulty(d);
            setScreen("game");
          }}
        />
      )}
    </div>
  );
}

function MainMenu({
  profile,
  difficulty,
  onDifficulty,
  onAcademy,
  onPlay,
  onStats,
}: {
  profile: PlayerProfile;
  difficulty: Difficulty;
  onDifficulty: (d: Difficulty) => void;
  onAcademy: () => void;
  onPlay: () => void;
  onStats: () => void;
}) {
  const rank = rankForHandled(profile.lifetimeHandled);
  return (
    <div className="menu">
      <div className="menu-inner">
        <div className="brand">
          <div className="scope-mark" aria-hidden />
          <h1 className="glow">ATC222 TRAINER</h1>
          <p>APEX APPROACH</p>
        </div>

        <div className="panel rank">
          <div className="row" style={{ justifyContent: "space-between", alignItems: "center" }}>
            <strong>{rank.title}</strong>
            <span className="note">{rankRemaining(rank, profile.lifetimeHandled) ? `${rankRemaining(rank, profile.lifetimeHandled)} to promote` : "MAX RANK"}</span>
          </div>
          <div className="rank-bar">
            <span style={{ width: `${rankProgress(rank, profile.lifetimeHandled) * 100}%` }} />
          </div>
        </div>

        <div className="panel badge" style={{ display: "flex", gap: 10, alignItems: "center" }}>
          <span style={{ color: "var(--selected)" }}>★</span>
          <strong>BEST · {profile.bestScores[difficulty]}</strong>
        </div>

        <div className="panel" style={{ padding: 16 }}>
          <div className="kicker" style={{ marginBottom: 10 }}>
            DIFFICULTY
          </div>
          <div className="diff-grid">
            {DIFFICULTIES.map((d) => (
              <button key={d} className={d === difficulty ? "on" : ""} onClick={() => onDifficulty(d)}>
                {difficultyMeta[d].title}
              </button>
            ))}
          </div>
          <p className="note" style={{ margin: "10px 0 0" }}>
            {difficultyMeta[difficulty].blurb}
          </p>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {profile.isCertified ? (
            <button className="primary" onClick={onPlay}>
              TAKE POSITION
            </button>
          ) : (
            <button className="primary" onClick={onAcademy}>
              ENTER THE ACADEMY
            </button>
          )}
          <div className="row">
            <button className="secondary" onClick={profile.isCertified ? onAcademy : onPlay}>
              {profile.isCertified ? "ACADEMY" : "SKIP TO LIVE"}
            </button>
            <button className="secondary" onClick={onStats}>
              STATS
            </button>
          </div>
        </div>
        <p className="note" style={{ textAlign: "center" }}>
          Browser preview of the Apex Control scope. Tap or drag targets, then vector them onto runway 34.
        </p>
      </div>
    </div>
  );
}

function StatsScreen({ profile, onBack }: { profile: PlayerProfile; onBack: () => void }) {
  const rank = rankForHandled(profile.lifetimeHandled);
  return (
    <div className="menu">
      <div className="menu-inner">
        <div className="kicker">CAREER</div>
        <h2 className="glow" style={{ margin: 0, color: "var(--phosphor)" }}>
          {rank.title}
        </h2>
        <div className="panel" style={{ padding: 16 }}>
          <p>Lifetime handled: {profile.lifetimeHandled}</p>
          <p>Best relaxed: {profile.bestScores.relaxed}</p>
          <p>Best standard: {profile.bestScores.standard}</p>
          <p>Best intense: {profile.bestScores.intense}</p>
        </div>
        <button className="primary" onClick={onBack}>
          BACK
        </button>
      </div>
    </div>
  );
}

function useEngine(factory: () => GameEngine, extra?: (engine: GameEngine) => void) {
  const engineRef = useRef<GameEngine | null>(null);
  const [, setTick] = useState(0);
  if (!engineRef.current) engineRef.current = factory();
  const engine = engineRef.current;

  useEffect(() => {
    engine.onUi = () => setTick((n) => n + 1);
    extra?.(engine);
    engine.start();
    return () => {
      engine.teardown();
      engine.onUi = null;
      engine.onEvent = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [engine]);

  return engine;
}

function GameScreen({ difficulty, onExit }: { difficulty: Difficulty; onExit: (result?: RunResult) => void }) {
  const [paused, setPaused] = useState(false);
  const [finished, setFinished] = useState<{ result: RunResult; reason: GameOverReason } | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const engine = useEngine(
    () => new GameEngine({ difficulty }),
    (e) => {
      e.onEvent = (event) => {
        if (event.type === "landed") setToast(`${event.callsign} LANDED +${event.points}`);
        if (event.type === "departed") setToast(`${event.callsign} HANDOFF +${event.points}`);
        if (event.type === "gameOver") setFinished({ result: event.result, reason: event.reason });
      };
    },
  );

  useEffect(() => {
    if (!toast) return;
    const id = window.setTimeout(() => setToast(null), 1600);
    return () => window.clearTimeout(id);
  }, [toast]);

  const transmit = (text: string) => {
    engine.apply(parseTransmission(text, engine.callsignCandidates));
  };

  return (
    <div className="app-shell">
      <RadarScope engine={engine} />
      <header className="hud">
        <div className="row" style={{ justifyContent: "space-between", alignItems: "flex-start" }}>
          <div>
            <div style={{ color: "var(--phosphor)", fontWeight: 700 }}>{engine.airport.icao} APPROACH</div>
            <div className="note">
              RWY {engine.activeRunway.name} · WIND {String(Math.round(engine.weather.windDirection)).padStart(3, "0")}/{engine.weather.windSpeed}
            </div>
          </div>
          <div style={{ textAlign: "right" }}>
            <div style={{ color: "var(--selected)", fontSize: 28, fontWeight: 700 }}>{engine.score}</div>
            <div className="row" style={{ justifyContent: "flex-end", alignItems: "center", gap: 8 }}>
              {engine.streak >= 2 && <span style={{ color: "var(--success)", fontWeight: 700 }}>×{engine.streak}</span>}
              <div className="lives">
                {Array.from({ length: difficultyMeta[engine.difficulty].startingLives }, (_, i) => (
                  <span key={i} className={i < engine.lives ? "life on" : "life off"} />
                ))}
              </div>
            </div>
          </div>
          <button
            className="icon-btn"
            onClick={() => {
              engine.pause();
              setPaused(true);
            }}
            aria-label="Pause"
          >
            ❚❚
          </button>
        </div>
        {engine.emergencies
          .filter((e) => !e.resolved)
          .slice(0, 1)
          .map((e) => (
            <div key={e.id} className="panel emergency-banner">
              <span>
                {e.callsign} — {emergencyMeta[e.type].title}
              </span>
              <span>{Math.max(0, Math.round((e.deadline - performance.now()) / 1000))}s</span>
            </div>
          ))}
      </header>
      {toast && <div className="toast">{toast}</div>}
      <div className="scope-gap" />
      <ControlDeck engine={engine} onTransmit={transmit} />
      {paused && !finished && (
        <div className="overlay">
          <div className="overlay-card" style={{ textAlign: "center" }}>
            <h2 className="glow">PAUSED</h2>
            <button
              className="primary"
              onClick={() => {
                setPaused(false);
                engine.resume();
              }}
            >
              RESUME
            </button>
            <button
              className="secondary"
              style={{ marginTop: 12, width: "100%" }}
              onClick={() => {
                engine.quit();
              }}
            >
              RELIEVE POSITION
            </button>
          </div>
        </div>
      )}
      {finished && (
        <div className="overlay">
          <div className="overlay-card" style={{ textAlign: "center" }}>
            <div className="kicker">{gameOverHeadline[finished.reason]}</div>
            <h2 className="glow">{finished.result.score}</h2>
            <p>
              {finished.result.landings} landings · {finished.result.departures} handoffs · streak {finished.result.bestStreak}
            </p>
            <button className="primary" onClick={() => onExit(finished.result)}>
              MENU
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function AcademyScreen({ onExit, onGraduate }: { onExit: () => void; onGraduate: (d: Difficulty) => void }) {
  const [lessonIndex, setLessonIndex] = useState(0);
  const [showingBriefing, setShowingBriefing] = useState(true);
  const [lessonComplete, setLessonComplete] = useState(false);
  const [graduated, setGraduated] = useState(false);
  const [failed, setFailed] = useState(false);
  const engineRef = useRef<GameEngine | null>(null);
  const [, setTick] = useState(0);
  const baseline = useRef({ landings: 0, departures: 0, emergencies: 0, handled: 0 });
  const lesson = curriculum[lessonIndex]!;

  if (!engineRef.current) engineRef.current = new GameEngine({ difficulty: "relaxed", training: true });
  const engine = engineRef.current;

  useEffect(() => {
    engine.onUi = () => setTick((n) => n + 1);
    engine.onEvent = (event) => {
      if (event.type === "gameOver" && lesson.kind === "checkRide") setFailed(true);
    };
    engine.start();
    engine.loadScenario(scenarioAircraft(lesson.scenario, engine), lesson.goal.type !== "select");
    engine.pause();
    return () => engine.teardown();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (showingBriefing || lessonComplete || graduated || failed) return;
    if (goalMet(lesson.goal, engine, baseline.current)) {
      if (lesson.kind === "checkRide") {
        setGraduated(true);
        engine.teardown();
      } else {
        setLessonComplete(true);
        engine.pause();
      }
    }
  });

  const beginDrill = () => {
    setShowingBriefing(false);
    if (lesson.kind === "checkRide") {
      engine.teardown();
      const live = new GameEngine({ difficulty: "relaxed" });
      live.onUi = () => setTick((n) => n + 1);
      live.onEvent = (event) => {
        if (event.type === "gameOver") setFailed(true);
      };
      engineRef.current = live;
      live.start();
    } else {
      engine.resume();
      if (lesson.scenario === "emergency" && engine.aircraft[0]) {
        engine.triggerEmergency(engine.aircraft[0].id, "lowFuel", 180);
      }
    }
    const current = engineRef.current!;
    baseline.current = {
      landings: current.landings,
      departures: current.departures,
      emergencies: current.emergenciesHandled,
      handled: current.handled,
    };
  };

  const startLesson = (index: number) => {
    setLessonIndex(index);
    setLessonComplete(false);
    setFailed(false);
    setShowingBriefing(true);
    const next = curriculum[index]!;
    if (next.kind === "drill") {
      if (!engineRef.current?.isTraining || !engineRef.current.isRunning) {
        engineRef.current?.teardown();
        const trainer = new GameEngine({ difficulty: "relaxed", training: true });
        trainer.onUi = () => setTick((n) => n + 1);
        trainer.start();
        engineRef.current = trainer;
      }
      const e = engineRef.current!;
      e.loadScenario(scenarioAircraft(next.scenario, e), next.goal.type !== "select");
      e.pause();
    }
  };

  const transmit = (text: string) => {
    engineRef.current?.apply(parseTransmission(text, engineRef.current.callsignCandidates));
  };

  const live = engineRef.current!;

  return (
    <div className="app-shell">
      <RadarScope engine={live} />
      <header className="hud">
        <div className="row" style={{ justifyContent: "space-between" }}>
          <div>
            <div className="kicker">ACADEMY · MODULE {lesson.moduleNumber}</div>
            <div style={{ color: "var(--phosphor)", fontWeight: 700 }}>{lesson.moduleTitle}</div>
          </div>
          <div className="note" style={{ fontWeight: 700 }}>
            {lesson.kind === "checkRide" && !showingBriefing
              ? `HANDLED ${Math.max(0, live.handled - baseline.current.handled)}/6`
              : `LESSON ${lessonIndex + 1}/${curriculum.length}`}
          </div>
          <button className="icon-btn" onClick={onExit} aria-label="Exit academy">
            ✕
          </button>
        </div>
      </header>
      <div className="scope-gap" />
      {!showingBriefing && (
        <div>
          <div className="panel" style={{ margin: "0 14px 10px", padding: 12 }}>
            {lessonComplete ? (
              <button
                className="primary"
                onClick={() => {
                  if (lessonIndex >= curriculum.length - 1) onExit();
                  else startLesson(lessonIndex + 1);
                }}
              >
                {lesson.kind === "checkRide" ? "CERTIFIED" : "OBJECTIVE COMPLETE — CONTINUE"}
              </button>
            ) : (
              <div>{lesson.objective}</div>
            )}
          </div>
          <ControlDeck engine={live} onTransmit={transmit} />
        </div>
      )}
      {showingBriefing && <Briefing lesson={lesson} onBegin={beginDrill} />}
      {graduated && (
        <div className="overlay">
          <div className="overlay-card" style={{ textAlign: "center" }}>
            <div className="kicker">CERTIFIED</div>
            <h2 className="glow">CLEARED FOR LIVE TRAFFIC</h2>
            <button className="primary" onClick={() => onGraduate("relaxed")}>
              ENTER LIVE TRAFFIC
            </button>
            <button className="secondary" style={{ marginTop: 12, width: "100%" }} onClick={onExit}>
              BACK TO MENU
            </button>
          </div>
        </div>
      )}
      {failed && (
        <div className="overlay">
          <div className="overlay-card" style={{ textAlign: "center" }}>
            <h2>Check Ride Incomplete</h2>
            <p className="note">You lost the picture before handling six. Reset and try again.</p>
            <button className="primary" onClick={() => startLesson(lessonIndex)}>
              RETRY CHECK RIDE
            </button>
            <button className="secondary" style={{ marginTop: 12, width: "100%" }} onClick={onExit}>
              BACK TO MENU
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function Briefing({ lesson, onBegin }: { lesson: AcademyLesson; onBegin: () => void }) {
  return (
    <div className="overlay">
      <div className="overlay-card">
        <div className="kicker">
          MODULE {lesson.moduleNumber} · {lesson.moduleTitle}
        </div>
        <h2 style={{ color: "var(--phosphor)" }} className="glow">
          {lesson.title}
        </h2>
        {lesson.concept.split("\n\n").map((p) => (
          <p key={p.slice(0, 24)}>{p}</p>
        ))}
        <div className="panel phrase">
          <div className="kicker" style={{ color: "var(--selected)" }}>
            STANDARD PHRASEOLOGY
          </div>
          {lesson.phraseology.map((line) => (
            <p key={line}>{line}</p>
          ))}
        </div>
        {lesson.realismNote && <p className="note">{lesson.realismNote}</p>}
        <p style={{ color: "var(--selected)", fontWeight: 700 }}>{lesson.objective}</p>
        <button className="primary" onClick={onBegin}>
          {lesson.kind === "checkRide" ? "BEGIN CHECK RIDE" : "BEGIN DRILL"}
        </button>
      </div>
    </div>
  );
}
