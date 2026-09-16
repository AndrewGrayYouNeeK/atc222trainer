# ATC222 Trainer

ATC222 Trainer is an aviation training app focused on helping pilots and students practice core ATC-related scenarios in a structured, repeatable way.

This repository now includes a **browser preview** of the Apex Approach scope: a phosphor radar, Academy lessons, and a live traffic shift. The original iOS simulation (`YouNeeKATC` / Apex Control) still lives on the `baseline` branch.

## Why this project?

Training for ATC communication and decision-making gets better with repetition.  
This project is intended to provide a lightweight way to practice key scenarios without needing a full simulator setup every time.

## Web preview

The playable preview lives in `web/`.

```bash
cd web
npm install
npm run dev
```

Then open the printed local URL (typically http://localhost:5173).

- **Academy** — six modules plus a certification check ride (scope, vectors, separation, final, sequencing, departures, emergencies).
- **Live shift** — tap a target, drag a heading, step altitude/speed, and clear arrivals onto runway 34.
- **Phraseology** — type a transmission such as `United 319, turn left heading 270, descend and maintain 5000` and hit **PTT**.

```bash
npm test      # engine / phraseology unit tests
npm run build # production bundle
```

## Goals

- Make ATC practice sessions simple to start
- Provide repeatable scenario-based training
- Keep the experience fast and focused for everyday use

## Project Status

This project is under active development and will continue to improve over time with new training flows, refinements, and quality-of-life updates.

## Contributing

Contributions are welcome. If you have ideas for new scenarios, UX improvements, or training features:

1. Open an issue describing the idea
2. Submit a pull request with clear context and testing notes

## License

Add a license file (for example, MIT) to define usage terms for this project.
