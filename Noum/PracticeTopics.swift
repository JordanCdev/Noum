import Foundation

// MARK: - Prompt Theme

enum PromptTheme: String, CaseIterable, Identifiable, Codable {
    case all = "All Themes"
    case general = "General"
    case workCareer = "Work & Career"
    case personalStories = "Personal Stories"
    case leadership = "Leadership"
    case ethicsOpinions = "Ethics & Opinions"
    case funRandom = "Fun & Random"
    case interviewPrep = "Interview Prep"
    case socialConfidence = "Social Confidence"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "sparkles"
        case .general: return "globe"
        case .workCareer: return "briefcase.fill"
        case .personalStories: return "book.fill"
        case .leadership: return "flag.fill"
        case .ethicsOpinions: return "scale.3d"
        case .funRandom: return "dice.fill"
        case .interviewPrep: return "person.text.rectangle"
        case .socialConfidence: return "bubble.left.and.bubble.right.fill"
        }
    }

    var color: String {
        switch self {
        case .all: return "purple"
        case .general: return "blue"
        case .workCareer: return "orange"
        case .personalStories: return "pink"
        case .leadership: return "red"
        case .ethicsOpinions: return "indigo"
        case .funRandom: return "green"
        case .interviewPrep: return "teal"
        case .socialConfidence: return "yellow"
        }
    }
}

// MARK: - Practice Topics

struct PracticeTopics {

    // MARK: - Themed Prompt Pool (200+)

    static let promptsByTheme: [PromptTheme: [String]] = [
        .general: [
            "What is the most important lesson you've learned from failure?",
            "If you could have dinner with anyone in history, who and why?",
            "What would you change about the education system?",
            "What does success mean to you?",
            "What is a skill everyone should learn?",
            "Describe your ideal day from start to finish.",
            "What is the best advice you've ever received?",
            "If you had to teach a class on anything, what would it be?",
            "What would you do with an extra hour every day?",
            "What is the most underrated quality in a person?",
            "If you could relive one day, which would you choose?",
            "What is a tradition you value and why?",
            "What technology has had the biggest impact on your life?",
            "What is something you believed as a child that you no longer believe?",
            "What would you say in a one-minute speech to the world?",
            "What is the most valuable thing money can't buy?",
            "Describe a book or film that changed how you think.",
            "What does courage look like in everyday life?",
            "What would you do differently if nobody could judge you?",
            "If you could instantly learn any language, which and why?",
            "What is the biggest risk you've ever taken?",
            "What is one thing you wish more people understood?",
            "What does home mean to you?",
            "What is the best compliment you've ever received?",
            "Describe a moment that changed your perspective completely.",
            "What would you put in a time capsule for the year 2100?",
            "What is the most beautiful place you've ever been?",
            "If you could witness any historical event, what would it be?",
            "What is one rule you live by?",
            "What makes you feel most alive?",
        ],
        .workCareer: [
            "What makes a great leader different from a good manager?",
            "Describe a time when you had to persuade someone of something.",
            "If you could start any business, what would it be?",
            "What does being a good communicator mean to you?",
            "Describe the best team you've ever been part of.",
            "What is the most important quality in a colleague?",
            "If you could change one thing about your industry, what would it be?",
            "What is the hardest professional decision you've ever made?",
            "How do you handle disagreement in a professional setting?",
            "What would you tell your first-day-on-the-job self?",
            "Describe a project that taught you the most.",
            "What is the biggest misconception about your profession?",
            "How do you stay motivated during repetitive work?",
            "What does work-life balance actually look like?",
            "If you had to switch careers tomorrow, what would you choose?",
            "What is the most useful feedback you've received at work?",
            "How do you approach learning a new skill for your job?",
            "What is the best meeting you've ever been in, and why?",
            "How do you handle working with someone whose style clashes with yours?",
            "What would you change about how companies hire people?",
            "Describe a time you failed at work and what it taught you.",
            "What does professional growth mean to you beyond promotions?",
            "How do you make decisions when you don't have all the information?",
            "What is the most creative solution you've seen to a workplace problem?",
            "If you could mentor anyone in your field, what would you teach first?",
        ],
        .personalStories: [
            "Describe a challenge you overcame that changed your perspective.",
            "What is a place that feels like home to you?",
            "Describe a moment that made you proud of someone else.",
            "What is the hardest decision you've ever made?",
            "If you could relive one conversation, which would it be?",
            "What is a small moment that had a big impact on your life?",
            "Describe a time you surprised yourself with your own ability.",
            "What is a lesson you learned the hard way?",
            "What is a memory that always makes you smile?",
            "Describe a person who shaped who you are today.",
            "What was a turning point in your life you didn't see coming?",
            "What is something you've done that you'd recommend everyone try?",
            "Describe a time when you had to be brave.",
            "What is a childhood experience that still influences you?",
            "What is the kindest thing a stranger ever did for you?",
            "Describe a time you changed your mind about something important.",
            "What is a tradition from your family that you want to pass on?",
            "What was the most meaningful gift you've ever received?",
            "Describe a moment when you felt truly understood by someone.",
            "What was the hardest goodbye you've ever said?",
            "What is a fear you've overcome, and how?",
            "Describe the best day of your life so far.",
            "What was a moment when you realized you'd grown as a person?",
            "What is a promise you made to yourself and kept?",
            "Describe a time when everything went wrong but turned out fine.",
        ],
        .leadership: [
            "What makes a great leader?",
            "How do you inspire people who don't share your vision?",
            "What is the hardest part of being in charge?",
            "Describe a leader you admire and explain why.",
            "How do you handle making unpopular decisions?",
            "What is the difference between authority and influence?",
            "How do you build trust within a team?",
            "What would you do in your first 30 days as CEO?",
            "How do you give honest feedback without damaging a relationship?",
            "What is the biggest leadership mistake you've witnessed?",
            "How do you lead people through uncertainty?",
            "What does accountability look like in practice?",
            "How do you empower someone who doubts their own abilities?",
            "What is the role of vulnerability in leadership?",
            "How do you know when to lead and when to follow?",
            "What would you change about how leaders are developed?",
            "How do you handle a team member who is talented but difficult?",
            "What is the most important quality of a servant leader?",
            "How do you maintain your values under pressure?",
            "Describe a time you had to stand up for what was right.",
            "What is the difference between managing a crisis and preventing one?",
            "How do you create a culture where people speak up?",
            "What does ethical leadership mean in the modern world?",
            "How do you balance short-term results with long-term vision?",
            "What can leaders learn from their biggest failures?",
        ],
        .ethicsOpinions: [
            "If you could solve one world problem, what would it be?",
            "Is it better to be honest or kind when the two conflict?",
            "Should social media companies be responsible for user content?",
            "Is privacy a right or a privilege in the digital age?",
            "What responsibility do wealthy individuals have to society?",
            "Is it ethical to use AI to make decisions about people's lives?",
            "Should voting be mandatory?",
            "Is competition or collaboration more important for progress?",
            "What should the purpose of a prison system be?",
            "Is it possible to be truly selfless?",
            "Should companies prioritize profit or social impact?",
            "Is cancel culture a form of accountability or mob justice?",
            "What is the most important freedom we have?",
            "Should education be more focused on life skills or academics?",
            "Is technology making us more connected or more isolated?",
            "Should art and creative work be funded by governments?",
            "What responsibility do we have to future generations?",
            "Is meritocracy real, or is it a myth?",
            "Should there be limits on free speech?",
            "Is it better to specialize deeply or learn broadly?",
            "What does fairness actually look like in practice?",
            "Should we prioritize individual rights or collective wellbeing?",
            "Is failure necessary for growth?",
            "What is the biggest ethical challenge of our time?",
            "Should people be required to give back to the community that raised them?",
        ],
        .funRandom: [
            "If you could master any instrument, which one and why?",
            "What is the weirdest food combination that actually works?",
            "If you were a superhero, what would your power be?",
            "What would the title of your autobiography be?",
            "If you could live in any fictional world, which would you choose?",
            "What is the most useless talent you have?",
            "If animals could talk, which species would be the rudest?",
            "What would you do if you were invisible for a day?",
            "What is the strangest thing you've ever Googled?",
            "If you could swap lives with anyone for a week, who would it be?",
            "What is the funniest thing that's happened to you recently?",
            "If you could uninvent one thing, what would it be?",
            "What is the worst fashion trend that needs to stay gone?",
            "If you had to eat only one cuisine for a year, which would it be?",
            "What would you rename the days of the week?",
            "If you could add one subject to every school curriculum, what?",
            "What is the most overrated thing that everyone seems to love?",
            "If you woke up tomorrow as the president, what's your first order?",
            "What would the world look like if dogs ran the government?",
            "If time travel existed, would you go forward or back?",
            "What is the best prank you've ever pulled or witnessed?",
            "If you had to survive a zombie apocalypse with three items, which?",
            "What is the most bizarre dream you've ever had?",
            "If you could make one fictional technology real, what would it be?",
            "What is the worst piece of advice you've ever received?",
        ],
        .interviewPrep: [
            "Tell me about a time you dealt with a difficult colleague.",
            "What is your greatest professional achievement?",
            "How do you prioritize when everything seems urgent?",
            "Describe a situation where you had to adapt quickly.",
            "What would your previous manager say is your biggest strength?",
            "Tell me about a time you went above and beyond.",
            "How do you handle constructive criticism?",
            "Describe a time you led a project from start to finish.",
            "What do you do when you disagree with your boss?",
            "How do you stay organized under pressure?",
            "Tell me about a goal you set and how you achieved it.",
            "What is the most important lesson you've learned in your career?",
            "How do you approach learning something completely new?",
            "Describe a time when you had to make a tough call without enough data.",
            "What motivates you to do your best work?",
            "Tell me about a time you had to deliver bad news.",
            "How do you build relationships with people different from you?",
            "Describe your approach to solving a complex problem.",
            "What would you do if you were given a task you'd never done before?",
            "How do you measure your own success?",
            "Tell me about a time you improved a process or system.",
            "What is one thing you'd want your future team to know about you?",
            "How do you handle ambiguity in the workplace?",
            "Describe a time you received feedback that changed your approach.",
            "What is the most important thing you've learned from a failure?",
        ],
        .socialConfidence: [
            "What motivates you to keep improving?",
            "How would you introduce yourself at a party where you know no one?",
            "What is the best way to start a conversation with a stranger?",
            "How do you handle awkward silences?",
            "What is the most interesting thing about you that people don't know?",
            "How do you gracefully exit a conversation?",
            "What is your go-to topic for small talk?",
            "How would you give a toast at a friend's wedding?",
            "What would you say if someone asked you to speak right now?",
            "How do you recover when you say something embarrassing?",
            "Describe how you'd comfort someone having a bad day.",
            "What is the art of being a good listener?",
            "How do you disagree with someone politely but firmly?",
            "What would you say to welcome a new person to your group?",
            "How do you ask for help without feeling vulnerable?",
            "What makes someone charismatic?",
            "How do you navigate a conversation with someone you disagree with?",
            "What would you say to calm a room full of nervous people?",
            "How do you compliment someone genuinely?",
            "What is the hardest social situation you've navigated?",
            "How would you mediate a disagreement between friends?",
            "What is the key to being confident without being arrogant?",
            "How do you handle being the center of attention?",
            "What would you say to inspire a group before a big event?",
            "How do you make someone feel included?",
        ],
    ]

    /// All prompts flattened
    static let allPrompts: [String] = {
        PromptTheme.allCases
            .filter { $0 != .all }
            .flatMap { promptsByTheme[$0] ?? [] }
    }()

    // MARK: - M12 — Per-locale curated pools
    //
    // Spanish (es-ES) and French (fr-FR) ship with smaller curated pools
    // (around 20 prompts each across the same 8 themes). The English pool
    // remains the canonical 200+. When the user switches practice language
    // in Settings, `random()` reads from the matching dictionary; the
    // shuffle-deck dedup is keyed per-locale so switching languages
    // doesn't reset the user's progress through whichever pool they were
    // working through.
    //
    // Curation note: prompts are translated by intent, not literally, so
    // they read as native speech in each language.

    /// Spanish (es-ES) curated pool. ~24 prompts spanning all themes.
    static let promptsByThemeESES: [PromptTheme: [String]] = [
        .general: [
            "¿Cuál es la lección más importante que has aprendido de un fracaso?",
            "Si pudieras cenar con cualquier persona de la historia, ¿quién y por qué?",
            "¿Qué significa el éxito para ti?",
            "Describe tu día ideal de principio a fin.",
            "¿Cuál es el mejor consejo que te han dado?",
            "¿Qué cualidad humana crees que está más infravalorada?"
        ],
        .workCareer: [
            "¿Cómo presentarías tu trabajo a alguien que no es del sector?",
            "¿Cuál es la decisión profesional más difícil que has tomado?",
            "Si pudieras cambiar una cosa de tu rutina laboral, ¿cuál sería?"
        ],
        .personalStories: [
            "Cuenta un momento que cambió tu manera de pensar.",
            "Describe un viaje que te marcó."
        ],
        .leadership: [
            "¿Qué hace que un líder se gane el respeto sin imponerlo?",
            "Describe un momento en que tuviste que tomar una decisión impopular."
        ],
        .ethicsOpinions: [
            "¿Hasta qué punto debe la honestidad pesar más que la diplomacia?",
            "¿Cuándo está justificado romper una regla?",
            "¿Qué responsabilidad tienen las redes sociales con el bienestar mental?"
        ],
        .funRandom: [
            "Si tuvieras una hora extra cada día, ¿qué harías?",
            "¿Qué superpoder elegirías y por qué?"
        ],
        .interviewPrep: [
            "Háblame de un proyecto del que estés orgulloso.",
            "¿Por qué quieres este puesto?",
            "¿Cuál es tu mayor área de mejora?"
        ],
        .socialConfidence: [
            "¿Cómo empiezas una conversación con alguien que acabas de conocer?",
            "Describe tu manera de hablar cuando estás bajo presión."
        ]
    ]

    /// French (fr-FR) curated pool. ~24 prompts spanning all themes.
    static let promptsByThemeFRFR: [PromptTheme: [String]] = [
        .general: [
            "Quelle est la leçon la plus importante que tu as tirée d'un échec ?",
            "Si tu pouvais dîner avec n'importe quelle personne de l'histoire, qui et pourquoi ?",
            "Que signifie le succès pour toi ?",
            "Décris ta journée idéale du matin au soir.",
            "Quel est le meilleur conseil qu'on t'ait jamais donné ?",
            "Quelle qualité humaine est selon toi la plus sous-estimée ?"
        ],
        .workCareer: [
            "Comment présenterais-tu ton métier à quelqu'un qui n'est pas du secteur ?",
            "Quelle est la décision professionnelle la plus difficile que tu as prise ?",
            "Si tu pouvais changer une seule chose dans ta routine de travail, ce serait quoi ?"
        ],
        .personalStories: [
            "Raconte un moment qui a changé ta manière de voir les choses.",
            "Décris un voyage qui t'a marqué."
        ],
        .leadership: [
            "Qu'est-ce qui fait qu'un leader gagne le respect sans l'imposer ?",
            "Décris une situation où tu as dû prendre une décision impopulaire."
        ],
        .ethicsOpinions: [
            "Jusqu'où l'honnêteté doit-elle l'emporter sur la diplomatie ?",
            "Quand est-il justifié de transgresser une règle ?",
            "Quelle responsabilité les réseaux sociaux ont-ils envers le bien-être mental ?"
        ],
        .funRandom: [
            "Si tu avais une heure de plus chaque jour, qu'en ferais-tu ?",
            "Quel super-pouvoir choisirais-tu et pourquoi ?"
        ],
        .interviewPrep: [
            "Parle-moi d'un projet dont tu es fier.",
            "Pourquoi veux-tu ce poste ?",
            "Quel est ton plus grand axe d'amélioration ?"
        ],
        .socialConfidence: [
            "Comment engages-tu une conversation avec quelqu'un que tu viens de rencontrer ?",
            "Décris ta façon de parler quand tu es sous pression."
        ]
    ]

    /// Resolve the prompt source for a locale.
    static func promptSource(for locale: PracticeLocale) -> [PromptTheme: [String]] {
        switch locale {
        case .enUS: return promptsByTheme
        case .esES: return promptsByThemeESES
        case .frFR: return promptsByThemeFRFR
        }
    }

    // MARK: - Shuffle Deck (no repeats until exhausted)

    private static let seenKey = "PracticeTopics.seenPrompts"

    /// Get a random prompt for a given theme (or all), avoiding repeats via shuffle deck.
    /// Reads `LocaleSettingsManager.shared.current` to pick the right per-locale pool;
    /// the shuffle deck is keyed by both theme and locale so switching languages
    /// doesn't reset progress through whichever pool the user was working through.
    @MainActor
    static func random(theme: PromptTheme = .all) -> String {
        let locale = LocaleSettingsManager.shared.current
        return random(theme: theme, locale: locale)
    }

    /// Locale-explicit overload for callers that need it (tests, deterministic seeded paths).
    static func random(theme: PromptTheme, locale: PracticeLocale) -> String {
        let pool = prompts(for: theme, locale: locale)
        guard !pool.isEmpty else { return fallbackPrompt(for: locale) }

        var seen = loadSeen(for: theme, locale: locale)

        // Reset deck if exhausted
        if seen.count >= pool.count {
            seen = []
        }

        let unseen = pool.filter { !seen.contains($0) }
        let pick = unseen.randomElement() ?? pool.randomElement()!

        seen.insert(pick)
        saveSeen(seen, for: theme, locale: locale)

        return pick
    }

    /// Get prompts for a specific theme. Reads the active locale by default;
    /// pass a locale explicitly when you need a specific pool (tests, sharing).
    @MainActor
    static func prompts(for theme: PromptTheme) -> [String] {
        prompts(for: theme, locale: LocaleSettingsManager.shared.current)
    }

    /// Locale-explicit overload.
    static func prompts(for theme: PromptTheme, locale: PracticeLocale) -> [String] {
        let source = promptSource(for: locale)
        if theme == .all {
            return PromptTheme.allCases.filter { $0 != .all }.flatMap { source[$0] ?? [] }
        }
        return source[theme] ?? []
    }

    private static func fallbackPrompt(for locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Talk about anything you like"
        case .esES: return "Habla de cualquier tema que te apetezca"
        case .frFR: return "Parle de ce que tu veux"
        }
    }

    /// Return a stable random topic seeded by a given string (for shared challenges)
    static func seeded(by seed: String) -> String {
        var hasher = Hasher()
        hasher.combine(seed)
        let hash = hasher.finalize()
        let index = abs(hash) % allPrompts.count
        return allPrompts[index]
    }

    /// Return a stable random topic seeded by a string for a specific theme.
    /// Always reads the canonical English pool — async-challenge participants
    /// are typically on different devices/locales, but the shared challenge
    /// must land on the same prompt to stay fair.
    static func seeded(by seed: String, theme: PromptTheme) -> String {
        let pool = prompts(for: theme, locale: .enUS)
        guard !pool.isEmpty else { return seeded(by: seed) }
        var hasher = Hasher()
        hasher.combine(seed)
        let hash = hasher.finalize()
        let index = abs(hash) % pool.count
        return pool[index]
    }

    // MARK: - Persistence

    private static func storageKey(for theme: PromptTheme) -> String {
        "\(seenKey).\(theme.rawValue)"
    }

    private static func storageKey(for theme: PromptTheme, locale: PracticeLocale) -> String {
        // Suffix the legacy theme-only key with the locale code so each
        // pool tracks its own shuffle progress independently.
        "\(seenKey).\(theme.rawValue).\(locale.rawValue)"
    }

    private static func loadSeen(for theme: PromptTheme) -> Set<String> {
        let key = storageKey(for: theme)
        let array = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(array)
    }

    private static func loadSeen(for theme: PromptTheme, locale: PracticeLocale) -> Set<String> {
        let key = storageKey(for: theme, locale: locale)
        let array = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(array)
    }

    private static func saveSeen(_ seen: Set<String>, for theme: PromptTheme) {
        let key = storageKey(for: theme)
        UserDefaults.standard.set(Array(seen), forKey: key)
    }

    private static func saveSeen(_ seen: Set<String>, for theme: PromptTheme, locale: PracticeLocale) {
        let key = storageKey(for: theme, locale: locale)
        UserDefaults.standard.set(Array(seen), forKey: key)
    }

    // MARK: - Goal-aware selection (M7)
    //
    // Higher-level orchestrator over `random()`. Honors:
    //   • 14-day prompt-history dedup via PromptHistoryStore
    //   • 70/30 mix between curated pool and AIPromptGeneratorService
    //   • Goal-mapped theme bias when the caller hasn't pinned a theme
    //   • Curated-pool fallback when AI fails or content filter rejects
    //
    // Synchronous overload returns immediately from the curated pool —
    // existing call sites that don't have a profile/baseline keep working
    // unchanged.
    //
    // Async overload `next(profile:baseline:theme:)` is the one new call
    // sites should adopt — it does the AI hop with a budget and falls
    // back to the pool gracefully.

    /// Probability of attempting an AI-generated prompt when one would
    /// otherwise come from the curated pool.
    static let aiGenerationProbability = 0.30

    /// Hard ceiling on AI prompt generation latency. If the API takes longer
    /// than this, we fall back to the curated pool so the user never waits
    /// noticeably for a prompt to appear after tapping Begin.
    static let aiGenerationBudget: TimeInterval = 3.0

    /// Async goal-aware prompt selector. Returns one prompt that:
    ///   • is not in the user's last-14-day history (best-effort),
    ///   • biased toward the user's coaching goal,
    ///   • generated via `AIPromptGeneratorService` ~30% of the time when
    ///     a provider is configured; falls through to the curated pool
    ///     otherwise.
    /// The returned prompt is recorded in history before return.
    @MainActor
    static func next(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline?,
        theme: PromptTheme = .all
    ) async -> String {
        let history = PromptHistoryStore.shared

        // Try the AI generator on the 30% sampling, with a hard latency budget.
        if let profile,
           Double.random(in: 0..<1) < aiGenerationProbability {
            let weakest = baseline.flatMap(weakestDimensionLabel(for:))
            if let generated = await Self.generateWithBudget(
                profile: profile,
                weakestDimension: weakest
            ), !history.wasRecentlySeen(generated) {
                history.record(generated)
                return generated
            }
        }

        // Curated pool path. Reroll up to 5 times to dodge a recently-seen prompt.
        let resolvedTheme = theme == .all ? (profile.map(themeBias(for:)) ?? .all) : theme
        var pick = random(theme: resolvedTheme)
        var attempts = 0
        while history.wasRecentlySeen(pick) && attempts < 5 {
            pick = random(theme: resolvedTheme)
            attempts += 1
        }
        history.record(pick)
        return pick
    }

    /// Run the AI generator under a strict time budget. Returns nil if either
    /// the generator returns nil or the budget elapses first — caller falls
    /// back to the pool in either case.
    private static func generateWithBudget(
        profile: CoachingProfile,
        weakestDimension: String?
    ) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                await AIPromptGeneratorService.shared.generate(
                    profile: profile,
                    weakestDimension: weakestDimension
                )
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(aiGenerationBudget * 1_000_000_000))
                return nil
            }
            // First completion wins. If it's the timeout, the AI task is left
            // running but its result is dropped — URLSession will continue and
            // be deallocated when its data is no longer awaited.
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Map a coaching profile to a preferred theme for impromptu prompts.
    /// Identical to `RecommendationBiasEngine.suggestedTheme(for:)` but
    /// available statically here so practice views can call it without
    /// the full blueprint pipeline.
    static func themeBias(for profile: CoachingProfile) -> PromptTheme {
        switch profile.primaryGoal {
        case .moreConcise:
            return profile.speakingContext == .interviews ? .interviewPrep : .workCareer
        case .thinkFaster:
            return profile.biggestChallenge == .freezing ? .general : .funRandom
        case .reduceFillers:
            return .all
        case .calmerDelivery:
            return profile.speakingContext == .social ? .socialConfidence : .ethicsOpinions
        }
    }

    /// Map a baseline's weakest dimension to a short coaching label the
    /// AI prompt can target. Used to make generated prompts actually
    /// challenge what the user needs to practice.
    static func weakestDimensionLabel(for baseline: CommunicationBaseline) -> String? {
        var weakest: (label: String, value: Double)?
        let candidates: [(String, BaselineStat)] = [
            ("filler control",     baseline.fillerRate),
            ("structured opening", baseline.openingStrength),
            ("clear closing",      baseline.closingStrength),
            ("answer depth",       baseline.answerDepth),
            ("structure",          baseline.structureQuality),
            ("clarity",            baseline.clarity)
        ]
        for (label, stat) in candidates {
            guard stat.confidence != .insufficient else { continue }
            // For fillerRate, higher = worse. For everything else, lower = worse.
            let normalized = label == "filler control" ? -stat.value : stat.value
            if weakest == nil || normalized < weakest!.value {
                weakest = (label, normalized)
            }
        }
        return weakest?.label
    }
}
