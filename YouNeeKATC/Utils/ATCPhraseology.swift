import Foundation

/// A single, executable ATC instruction extracted from a transmission.
nonisolated enum ATCCommand: Equatable, Sendable {
    case turn(TurnKind, heading: Int)
    case climb(altitude: Int)
    case descend(altitude: Int)
    case maintainAltitude(Int)
    case speed(SpeedKind, knots: Int)
    case direct(fix: String)
    case clearedToLand(runway: String?)
    case contactTower
    case sayAgain

    enum TurnKind: String, Sendable { case left, right, shortest }
    enum SpeedKind: String, Sendable { case increase, reduce, maintain }

    /// Phraseology-correct read-back fragment for the HUD / acknowledgement.
    var phrase: String {
        switch self {
        case let .turn(kind, hdg):
            let h = String(format: "%03d", hdg == 0 ? 360 : hdg)
            switch kind {
            case .left: return "turn left heading \(h)"
            case .right: return "turn right heading \(h)"
            case .shortest: return "fly heading \(h)"
            }
        case let .climb(a): return "climb and maintain \(a.formattedAltitude)"
        case let .descend(a): return "descend and maintain \(a.formattedAltitude)"
        case let .maintainAltitude(a): return "maintain \(a.formattedAltitude)"
        case let .speed(kind, k):
            switch kind {
            case .increase: return "increase speed \(k) knots"
            case .reduce: return "reduce speed \(k) knots"
            case .maintain: return "maintain \(k) knots"
            }
        case let .direct(fix): return "proceed direct \(fix)"
        case let .clearedToLand(rwy):
            return rwy.map { "cleared to land runway \($0)" } ?? "cleared to land"
        case .contactTower: return "contact tower"
        case .sayAgain: return "say again"
        }
    }
}

/// One parsed transmission: who it was addressed to, and what was instructed.
nonisolated struct ParsedTransmission: Equatable, Sendable {
    var targetCallsign: String?
    var spokenCallsign: String?
    var commands: [ATCCommand]
    var rawText: String

    var isActionable: Bool { !commands.isEmpty }

    /// Combined read-back, e.g. "turn left heading 270, descend and maintain 3000".
    var readback: String {
        commands.map(\.phrase).joined(separator: ", ")
    }
}

/// Lightweight target identity used to resolve a callsign from free speech.
nonisolated struct CallsignCandidate: Sendable, Equatable {
    let callsign: String   // canonical, e.g. "DAL482"
    let spoken: String     // telephony, e.g. "Delta 482"
}

/// Stateless ATC phraseology parser. Converts free-form speech into a
/// `ParsedTransmission` using phonetic-number expansion, keyword scanning and
/// fuzzy callsign matching.
nonisolated enum ATCPhraseology {

    // MARK: Public API

    static func parse(_ transcript: String, candidates: [CallsignCandidate]) -> ParsedTransmission {
        let words = normalize(transcript)
        let match = resolveCallsign(in: words, candidates: candidates)
        let commands = parseCommands(words)
        return ParsedTransmission(
            targetCallsign: match?.callsign,
            spokenCallsign: match?.spoken,
            commands: commands,
            rawText: transcript
        )
    }

    /// Convenience overload for tests / spoken-only callsign lists.
    static func parse(_ transcript: String, callsigns: [String]) -> ParsedTransmission {
        parse(transcript, candidates: callsigns.map { CallsignCandidate(callsign: $0, spoken: $0) })
    }

    // MARK: Normalisation

    private static func normalize(_ text: String) -> [String] {
        let cleaned = text.lowercased().map { ch -> Character in
            ch.isLetter || ch.isNumber || ch == " " ? ch : " "
        }
        return String(cleaned)
            .split(separator: " ")
            .map { phonetic[String($0)] ?? String($0) }
    }

    /// Phonetic / colloquial normalisations applied per-token.
    private static let phonetic: [String: String] = [
        "niner": "nine", "tree": "three", "fife": "five", "oh": "zero",
        "to": "to", "too": "to"
    ]

    // MARK: Number lexicons

    private static let digitMap: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
        "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9
    ]
    private static let teensMap: [String: Int] = [
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19
    ]
    private static let tensMap: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]

    private static func isNumberWord(_ w: String) -> Bool {
        digitMap[w] != nil || teensMap[w] != nil || tensMap[w] != nil
    }
    private static func isMultiDigit(_ w: String) -> Bool {
        !w.isEmpty && w.allSatisfy(\.isNumber)
    }

    // MARK: Command scanning

    private static func parseCommands(_ words: [String]) -> [ATCCommand] {
        var commands: [ATCCommand] = []
        var i = 0
        while i < words.count {
            let w = words[i]
            switch w {
            case "turn", "fly", "heading":
                var j = i + 1
                var kind: ATCCommand.TurnKind = .shortest
                if w == "turn" {
                    if word(words, j) == "left" { kind = .left; j += 1 }
                    else if word(words, j) == "right" { kind = .right; j += 1 }
                }
                while ["to", "heading", "onto", "a", "fly"].contains(word(words, j)) { j += 1 }
                if let (value, next) = readDigits(words, from: j) {
                    commands.append(.turn(kind, heading: ((value % 360) + 360) % 360))
                    i = next; continue
                }

            case "climb":
                if let (alt, next) = readAltitude(words, from: i + 1) {
                    commands.append(.climb(altitude: alt)); i = next; continue
                }

            case "descend", "descent":
                if let (alt, next) = readAltitude(words, from: i + 1) {
                    commands.append(.descend(altitude: alt)); i = next; continue
                }

            case "maintain":
                // "maintain speed 250" -> speed, otherwise treat as altitude.
                if word(words, i + 1) == "speed" {
                    if let (kts, next) = readSpeed(words, from: i + 2) {
                        commands.append(.speed(.maintain, knots: kts)); i = next; continue
                    }
                } else if let (alt, next) = readAltitude(words, from: i + 1) {
                    commands.append(.maintainAltitude(alt)); i = next; continue
                }

            case "reduce", "increase":
                let kind: ATCCommand.SpeedKind = (w == "reduce") ? .reduce : .increase
                if let (kts, next) = readSpeed(words, from: i + 1) {
                    commands.append(.speed(kind, knots: kts)); i = next; continue
                }

            case "speed":
                if let (kts, next) = readSpeed(words, from: i + 1) {
                    commands.append(.speed(.maintain, knots: kts)); i = next; continue
                }

            case "direct", "proceed":
                var j = i + 1
                while ["direct", "to", "fix", "waypoint"].contains(word(words, j)) { j += 1 }
                if let fix = readFix(words, at: j) {
                    commands.append(.direct(fix: fix)); i = j + 1; continue
                }

            case "cleared":
                var j = i + 1
                if word(words, j) == "to" && word(words, j + 1) == "land" {
                    j += 2
                    let (runway, next) = readRunway(words, from: j)
                    commands.append(.clearedToLand(runway: runway)); i = next; continue
                } else {
                    while ["direct", "to"].contains(word(words, j)) { j += 1 }
                    if let fix = readFix(words, at: j) {
                        commands.append(.direct(fix: fix)); i = j + 1; continue
                    }
                }

            case "contact":
                if word(words, i + 1) == "tower" {
                    commands.append(.contactTower); i += 2; continue
                }

            case "say":
                if word(words, i + 1) == "again" {
                    commands.append(.sayAgain); i += 2; continue
                }

            default:
                break
            }
            i += 1
        }
        return commands
    }

    // MARK: Number readers

    /// Reads a contiguous run of number-bearing tokens (digits, teen/tens words,
    /// "hundred"/"thousand"), skipping interleaved "and" connectors.
    private static func readNumberRun(_ words: [String], from: Int) -> ([String], Int) {
        var tokens: [String] = []
        var i = from
        while i < words.count {
            let w = words[i]
            if isNumberWord(w) || isMultiDigit(w) || w == "hundred" || w == "thousand" {
                tokens.append(w); i += 1
            } else if w == "and", !tokens.isEmpty {
                i += 1
            } else {
                break
            }
        }
        return (tokens, i)
    }

    /// Heading / runway style: concatenated single digits ("two seven zero" -> 270).
    private static func readDigits(_ words: [String], from: Int) -> (Int, Int)? {
        let (tokens, next) = readNumberRun(words, from: from)
        guard let value = interpretDigits(tokens) else { return nil }
        return (value, next)
    }

    private static func readAltitude(_ words: [String], from: Int) -> (Int, Int)? {
        var i = from
        while ["and", "maintain", "to", "at", "altitude"].contains(word(words, i)) { i += 1 }

        if word(words, i) == "flight" {
            var j = i + 1
            if word(words, j) == "level" { j += 1 }
            let (tokens, next) = readNumberRun(words, from: j)
            guard let fl = interpretDigits(tokens), fl > 0 else { return nil }
            return (fl * 100, next)
        }

        let (tokens, next) = readNumberRun(words, from: i)
        guard !tokens.isEmpty else { return nil }
        let hasMagnitude = tokens.contains("thousand") || tokens.contains("hundred")
        let value = hasMagnitude ? interpretMagnitude(tokens) : (interpretDigits(tokens) ?? 0)
        guard value > 0 else { return nil }
        return (value, next)
    }

    private static func readSpeed(_ words: [String], from: Int) -> (Int, Int)? {
        var i = from
        while ["speed", "to", "of", "at"].contains(word(words, i)) { i += 1 }
        let (tokens, next) = readNumberRun(words, from: i)
        guard !tokens.isEmpty else { return nil }
        let hasMagnitude = tokens.contains("hundred") || tokens.contains("thousand")
        let value = hasMagnitude ? interpretMagnitude(tokens) : (interpretDigits(tokens) ?? 0)
        guard value > 0 else { return nil }
        return (value, next)
    }

    private static func readFix(_ words: [String], at index: Int) -> String? {
        guard let token = words[safe: index], token.count >= 2, token.allSatisfy(\.isLetter)
        else { return nil }
        return token.uppercased()
    }

    private static func readRunway(_ words: [String], from: Int) -> (String?, Int) {
        var i = from
        if word(words, i) == "runway" { i += 1 }
        guard let (number, next) = readDigits(words, from: i), number > 0, number <= 36 else {
            return (nil, i)
        }
        var runway = String(number)
        var j = next
        switch word(words, j) {
        case "left": runway += "L"; j += 1
        case "right": runway += "R"; j += 1
        case "center", "centre": runway += "C"; j += 1
        default: break
        }
        return (runway, j)
    }

    /// Concatenates digit tokens, e.g. ["two","seven","zero"] -> 270, ["3000"] -> 3000.
    private static func interpretDigits(_ tokens: [String]) -> Int? {
        var string = ""
        for t in tokens {
            if let d = digitMap[t] { string += String(d) }
            else if isMultiDigit(t) { string += t }
        }
        return string.isEmpty ? nil : Int(string)
    }

    /// Interprets magnitude-bearing runs: "five thousand" -> 5000,
    /// "three thousand five hundred" -> 3500, "two hundred fifty" -> 250.
    private static func interpretMagnitude(_ tokens: [String]) -> Int {
        var result = 0
        var digits = ""
        var trailing = 0
        for t in tokens {
            if let d = digitMap[t] { digits += String(d) }
            else if isMultiDigit(t) { digits += t }
            else if let teen = teensMap[t] { trailing += teen }
            else if let ten = tensMap[t] { trailing += ten }
            else if t == "hundred" {
                let base = digits.isEmpty ? 1 : Int(digits)!
                result += base * 100; digits = ""
            } else if t == "thousand" {
                let base = digits.isEmpty ? 1 : Int(digits)!
                result += base * 1000; digits = ""
            }
        }
        if !digits.isEmpty { result += Int(digits)! }
        return result + trailing
    }

    // MARK: Callsign resolution

    private static func resolveCallsign(in words: [String], candidates: [CallsignCandidate]) -> CallsignCandidate? {
        // 1) Exact contiguous spoken match (handles tail numbers like "n172sp").
        for candidate in candidates {
            let spoken = normalize(candidate.spoken)
            if !spoken.isEmpty, indexOfSubsequence(spoken, in: words) != nil {
                return candidate
            }
        }
        // 2) Airline word(s) followed by the flight-number digits.
        for candidate in candidates {
            let spoken = normalize(candidate.spoken)
            let airlineWords = spoken.filter { !isNumberWord($0) && !isMultiDigit($0) }
            let numberTokens = spoken.filter { isNumberWord($0) || isMultiDigit($0) }
            guard !airlineWords.isEmpty,
                  let targetNumber = interpretDigits(numberTokens),
                  let start = indexOfSubsequence(airlineWords, in: words)
            else { continue }

            var k = start + airlineWords.count
            var skipped = 0
            while k < words.count, !(isNumberWord(words[k]) || isMultiDigit(words[k])), skipped < 2 {
                k += 1; skipped += 1
            }
            if let (value, _) = readDigits(words, from: k), value == targetNumber {
                return candidate
            }
        }
        return nil
    }

    private static func indexOfSubsequence(_ needle: [String], in haystack: [String]) -> Int? {
        guard !needle.isEmpty, needle.count <= haystack.count else { return nil }
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<start + needle.count]) == needle { return start }
        }
        return nil
    }

    private static func word(_ words: [String], _ index: Int) -> String {
        words[safe: index] ?? ""
    }
}

extension ATCPhraseology {

    private static let digitWords = ["zero", "one", "two", "three", "four",
                                     "five", "six", "seven", "eight", "nine"]

    /// Renders an integer as spoken digit groups, e.g. 270 -> "two seven zero".
    /// Pass `width` to zero-pad (headings use width 3).
    static func spokenDigits(_ value: Int, width: Int = 0) -> String {
        var string = String(max(value, 0))
        while string.count < width { string = "0" + string }
        return string.compactMap { $0.wholeNumberValue }
            .map { digitWords[$0] }
            .joined(separator: " ")
    }

    /// Natural pilot rendering of an altitude. Below FL180 the numeral is read
    /// naturally by the synthesiser ("3000" -> "three thousand"); at/above
    /// FL180 it becomes "flight level two five zero".
    static func spokenAltitude(_ feet: Int) -> String {
        feet >= 18_000 ? "flight level " + spokenDigits(feet / 100, width: 3) : "\(feet)"
    }

    private static func spokenRunway(_ runway: String) -> String {
        var spoken: [String] = []
        for ch in runway {
            if let d = ch.wholeNumberValue { spoken.append(digitWords[d]) }
            else if ch == "L" { spoken.append("left") }
            else if ch == "R" { spoken.append("right") }
            else if ch == "C" { spoken.append("center") }
        }
        return spoken.joined(separator: " ")
    }

    private static let phoneticAlphabet: [Character: String] = [
        "a": "Alpha", "b": "Bravo", "c": "Charlie", "d": "Delta", "e": "Echo",
        "f": "Foxtrot", "g": "Golf", "h": "Hotel", "i": "India", "j": "Juliet",
        "k": "Kilo", "l": "Lima", "m": "Mike", "n": "November", "o": "Oscar",
        "p": "Papa", "q": "Quebec", "r": "Romeo", "s": "Sierra", "t": "Tango",
        "u": "Uniform", "v": "Victor", "w": "Whiskey", "x": "Xray",
        "y": "Yankee", "z": "Zulu"
    ]

    /// Re-speaks a callsign for authentic readback audio: numbers digit-by-digit
    /// ("Delta 214" -> "Delta two one four") and mixed tail numbers spelled with
    /// the NATO phonetic alphabet ("N172SP" -> "November one seven two Sierra Papa").
    static func spokenCallsignForSpeech(_ spoken: String) -> String {
        spoken.split(separator: " ").map { token -> String in
            let string = String(token)
            if let value = Int(string) { return spokenDigits(value) }
            let hasLetter = string.contains { $0.isLetter }
            let hasDigit = string.contains { $0.isNumber }
            if hasLetter && hasDigit {
                return string.lowercased().compactMap { ch -> String? in
                    if let phon = phoneticAlphabet[ch] { return phon }
                    if let d = ch.wholeNumberValue, d < 10 { return digitWords[d] }
                    return nil
                }.joined(separator: " ")
            }
            return string
        }.joined(separator: " ")
    }

    /// Builds the pilot's read-back utterance for the speech synthesiser.
    static func readbackSpeech(callsign spoken: String, commands: [ATCCommand]) -> String {
        var parts: [String] = []
        for command in commands {
            switch command {
            case let .turn(kind, hdg):
                let heading = spokenDigits(hdg == 0 ? 360 : hdg, width: 3)
                switch kind {
                case .left: parts.append("left heading \(heading)")
                case .right: parts.append("right heading \(heading)")
                case .shortest: parts.append("heading \(heading)")
                }
            case let .climb(a): parts.append("climbing \(spokenAltitude(a))")
            case let .descend(a): parts.append("down to \(spokenAltitude(a))")
            case let .maintainAltitude(a): parts.append("maintaining \(spokenAltitude(a))")
            case let .speed(kind, k):
                let knots = spokenDigits(k)
                switch kind {
                case .reduce: parts.append("slowing \(knots) knots")
                case .increase: parts.append("speeding up \(knots) knots")
                case .maintain: parts.append("maintaining \(knots) knots")
                }
            case let .direct(fix): parts.append("direct \(fix)")
            case let .clearedToLand(rwy):
                parts.append(rwy.map { "cleared to land runway \(spokenRunway($0))" } ?? "cleared to land")
            case .contactTower: parts.append("over to tower")
            case .sayAgain: parts.append("say again")
            }
        }
        let callsign = spokenCallsignForSpeech(spoken)
        let body = parts.joined(separator: ", ")
        return body.isEmpty ? "\(callsign), roger" : "\(body), \(callsign)"
    }
}

extension Int {
    /// "5000" / "FL250" style altitude rendering.
    nonisolated var formattedAltitude: String {
        self >= 18_000 ? "FL\(self / 100)" : "\(self)"
    }
}

extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
