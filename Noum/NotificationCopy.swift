import Foundation

// MARK: - Notification Copy
//
// All notification title + body strings live here so the voice rules apply
// uniformly. Each helper returns the copy variant most fitting for the
// user's current state — we never ship "Don't break the streak" to a user
// at streak 0, never ship a generic "open the app" body when we can name
// the actual numbers.
//
// Voice rules (lifted from `.claude/skills/noum-design`):
// - No "Let's", no chirpy filler
// - No emoji
// - Sentence case (titles can be Title Case)
// - Concrete numbers when available
// - Lock-screen-safe: never quote the user's typed goal text directly
//
// M14 polish: notification copy now respects the user's selected practice
// locale. A French user practicing in fr-FR gets French reminders on the
// lock screen — not English, even if iOS UI locale is something else.
// Defaults to en-US when no locale is provided.

struct NotificationLine {
    let title: String
    let body: String
}

enum NotificationCopy {

    // MARK: - Daily reminder

    /// User picked a specific time. We have no information about whether
    /// they've already practiced today (the `todayDone` flag is filled by
    /// the caller from `SharedNoumState`).
    static func dailyReminder(streakDays: Int, todayDone: Bool, locale: PracticeLocale = .enUS) -> NotificationLine {
        if todayDone {
            return NotificationLine(
                title: stackTitle(locale: locale),
                body: stackBody(locale: locale)
            )
        }

        switch streakDays {
        case 0:
            return NotificationLine(
                title: dayOneTitle(locale: locale),
                body: dayOneBody(locale: locale)
            )
        case 1...2:
            return NotificationLine(
                title: dayCountTitle(streakDays + 1, locale: locale),
                body: twoDaysHabitBody(locale: locale)
            )
        case 3...6:
            return NotificationLine(
                title: holdStreakTitle(streakDays, locale: locale),
                body: weekRemainingBody(daysLeft: 7 - streakDays, locale: locale)
            )
        case 7...:
            return NotificationLine(
                title: yoursToKeepTitle(streakDays, locale: locale),
                body: yoursToKeepBody(locale: locale)
            )
        default:
            return NotificationLine(
                title: waitingTitle(locale: locale),
                body: rhythmBody(locale: locale)
            )
        }
    }

    // MARK: - Streak warning (loss-aversion)

    /// Fired late evening only when the user has a real streak to lose.
    /// Phrased as a deadline, with a stronger frame as the streak gets longer.
    static func streakWarning(streakDays: Int, freezesAvailable: Int, locale: PracticeLocale = .enUS) -> NotificationLine {
        let freezeLine = freezesAvailable > 0
            ? freezeCoverLine(locale: locale)
            : noFreezeLine(locale: locale)

        switch streakDays {
        case 0:
            return NotificationLine(
                title: waitingTitle(locale: locale),
                body: rhythmBody(locale: locale)
            )
        case 1...2:
            return NotificationLine(
                title: warnKeepTitle(streakDays, locale: locale),
                body: warnShortBody(freeze: freezeLine, locale: locale)
            )
        case 3...6:
            return NotificationLine(
                title: warnRiskTitle(streakDays, locale: locale),
                body: warnTwoMinBody(freeze: freezeLine, locale: locale)
            )
        case 7...13:
            return NotificationLine(
                title: warnEndsTonightTitle(streakDays, locale: locale),
                body: warnHabitBody(freeze: freezeLine, locale: locale)
            )
        case 14...29:
            return NotificationLine(
                title: warnOnLineTitle(streakDays, locale: locale),
                body: warnTwoWeeksBody(freeze: freezeLine, locale: locale)
            )
        case 30...:
            return NotificationLine(
                title: warnBuzzerTitle(streakDays, locale: locale),
                body: warnFootnoteBody(freeze: freezeLine, locale: locale)
            )
        default:
            return NotificationLine(
                title: warnGenericTitle(locale: locale),
                body: warnGenericBody(freeze: freezeLine, locale: locale)
            )
        }
    }

    // MARK: - Weekly digest

    static func weeklyDigest(weeklyReps: Int, locale: PracticeLocale = .enUS) -> NotificationLine {
        switch weeklyReps {
        case 0:
            return NotificationLine(
                title: digestQuietTitle(locale: locale),
                body: digestQuietBody(locale: locale)
            )
        case 1...2:
            return NotificationLine(
                title: digestLightTitle(weeklyReps, locale: locale),
                body: digestLightBody(locale: locale)
            )
        case 3...4:
            return NotificationLine(
                title: digestSteadyTitle(weeklyReps, locale: locale),
                body: digestSteadyBody(locale: locale)
            )
        case 5...6:
            return NotificationLine(
                title: digestStrongTitle(weeklyReps, locale: locale),
                body: digestStrongBody(locale: locale)
            )
        case 7...:
            return NotificationLine(
                title: digestTopTitle(weeklyReps, locale: locale),
                body: digestTopBody(locale: locale)
            )
        default:
            return NotificationLine(
                title: digestQuietTitle(locale: locale),
                body: digestQuietBody(locale: locale)
            )
        }
    }
}

// MARK: - Localised strings

private extension NotificationCopy {

    // Daily reminder — "you've already practiced today"
    static func stackTitle(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Stack a second rep"
        case .esES: return "Suma una segunda sesión"
        case .frFR: return "Empile une seconde séance"
        }
    }
    static func stackBody(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Today's already counts. A second rep is where the muscle gets built."
        case .esES: return "La de hoy ya cuenta. La segunda es la que construye el músculo."
        case .frFR: return "Celle d'aujourd'hui compte déjà. La seconde, c'est celle qui construit le muscle."
        }
    }

    // Daily reminder — streak 0
    static func dayOneTitle(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Today is rep one"
        case .esES: return "Hoy es la sesión número uno"
        case .frFR: return "Aujourd'hui, c'est la séance numéro un"
        }
    }
    static func dayOneBody(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "One short drill sets your baseline. Two minutes is enough."
        case .esES: return "Una sesión corta fija tu baseline. Bastan dos minutos."
        case .frFR: return "Une courte séance fixe ta baseline. Deux minutes suffisent."
        }
    }

    // Daily reminder — day 2/3
    static func dayCountTitle(_ day: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Day \(day) starts now"
        case .esES: return "El día \(day) empieza ahora"
        case .frFR: return "Le jour \(day) commence maintenant"
        }
    }
    static func twoDaysHabitBody(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Two days don't make a habit. Today's rep is the one that does."
        case .esES: return "Dos días no forman un hábito. La sesión de hoy sí."
        case .frFR: return "Deux jours ne font pas une habitude. La séance d'aujourd'hui, si."
        }
    }

    // Daily reminder — streak 3-6
    static func holdStreakTitle(_ days: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Hold your \(days)-day streak"
        case .esES: return "Mantén tu racha de \(days) días"
        case .frFR: return "Garde ta série de \(days) jours"
        }
    }
    static func weekRemainingBody(daysLeft: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS:
            return "You're \(daysLeft) day\(daysLeft == 1 ? "" : "s") from a full week. One short rep keeps it going."
        case .esES:
            return "Te falta\(daysLeft == 1 ? "" : "n") \(daysLeft) día\(daysLeft == 1 ? "" : "s") para la semana completa. Una sesión corta la mantiene viva."
        case .frFR:
            return "Plus que \(daysLeft) jour\(daysLeft == 1 ? "" : "s") pour une semaine complète. Une courte séance suffit."
        }
    }

    // Daily reminder — streak 7+
    static func yoursToKeepTitle(_ days: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Your \(days)-day streak is yours to keep"
        case .esES: return "Tu racha de \(days) días es tuya"
        case .frFR: return "Ta série de \(days) jours t'appartient"
        }
    }
    static func yoursToKeepBody(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Habits this old are worth one more rep today."
        case .esES: return "Hábitos así de viejos merecen una sesión más hoy."
        case .frFR: return "Des habitudes aussi anciennes méritent une séance de plus aujourd'hui."
        }
    }

    // Daily reminder — generic fallback
    static func waitingTitle(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Today's rep is waiting"
        case .esES: return "La sesión de hoy te espera"
        case .frFR: return "La séance du jour t'attend"
        }
    }
    static func rhythmBody(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "A short drill keeps the rhythm."
        case .esES: return "Una sesión corta mantiene el ritmo."
        case .frFR: return "Une courte séance maintient le rythme."
        }
    }

    // Streak warning — freeze tail
    static func freezeCoverLine(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Or your weekly freeze covers a single miss."
        case .esES: return "O tu congelación semanal cubre un día perdido."
        case .frFR: return "Ou ta protection hebdomadaire couvre un jour manqué."
        }
    }
    static func noFreezeLine(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "No freeze left this week — only a rep saves it."
        case .esES: return "Sin congelaciones esta semana — solo una sesión la salva."
        case .frFR: return "Plus de protection cette semaine — seule une séance la sauve."
        }
    }

    // Streak warning — short streak
    static func warnKeepTitle(_ days: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "\(days)-day streak — keep it"
        case .esES: return "Racha de \(days) días — mantenla"
        case .frFR: return "Série de \(days) jours — garde-la"
        }
    }
    static func warnShortBody(freeze: String, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "A short rep before midnight protects the streak. \(freeze)"
        case .esES: return "Una sesión corta antes de medianoche protege la racha. \(freeze)"
        case .frFR: return "Une courte séance avant minuit protège la série. \(freeze)"
        }
    }

    // Streak warning — 3-6
    static func warnRiskTitle(_ days: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "\(days) days in a row at risk"
        case .esES: return "\(days) días seguidos en riesgo"
        case .frFR: return "\(days) jours d'affilée en danger"
        }
    }
    static func warnTwoMinBody(freeze: String, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Two minutes saves it. \(freeze)"
        case .esES: return "Dos minutos la salvan. \(freeze)"
        case .frFR: return "Deux minutes la sauvent. \(freeze)"
        }
    }

    // Streak warning — 7-13
    static func warnEndsTonightTitle(_ days: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Your \(days)-day streak ends tonight"
        case .esES: return "Tu racha de \(days) días termina esta noche"
        case .frFR: return "Ta série de \(days) jours finit ce soir"
        }
    }
    static func warnHabitBody(freeze: String, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Habits this old are worth two minutes. \(freeze)"
        case .esES: return "Hábitos así de viejos merecen dos minutos. \(freeze)"
        case .frFR: return "Des habitudes aussi anciennes méritent deux minutes. \(freeze)"
        }
    }

    // Streak warning — 14-29
    static func warnOnLineTitle(_ days: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "\(days) days, all on the line"
        case .esES: return "\(days) días, todo en juego"
        case .frFR: return "\(days) jours, tout en jeu"
        }
    }
    static func warnTwoWeeksBody(freeze: String, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Two weeks of work hangs on one short rep. \(freeze)"
        case .esES: return "Dos semanas de trabajo penden de una sola sesión corta. \(freeze)"
        case .frFR: return "Deux semaines de travail tiennent à une courte séance. \(freeze)"
        }
    }

    // Streak warning — 30+
    static func warnBuzzerTitle(_ days: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Don't lose \(days) days at the buzzer"
        case .esES: return "No pierdas \(days) días en el último minuto"
        case .frFR: return "Ne perds pas \(days) jours au buzzer"
        }
    }
    static func warnFootnoteBody(freeze: String, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "A streak this long doesn't deserve a footnote. \(freeze)"
        case .esES: return "Una racha así de larga no merece una nota a pie de página. \(freeze)"
        case .frFR: return "Une série aussi longue ne mérite pas une note de bas de page. \(freeze)"
        }
    }

    // Streak warning — generic fallback
    static func warnGenericTitle(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Streak ends tonight"
        case .esES: return "La racha termina esta noche"
        case .frFR: return "La série finit ce soir"
        }
    }
    static func warnGenericBody(freeze: String, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "A short rep keeps it alive. \(freeze)"
        case .esES: return "Una sesión corta la mantiene viva. \(freeze)"
        case .frFR: return "Une courte séance la garde en vie. \(freeze)"
        }
    }

    // Weekly digest
    static func digestQuietTitle(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Your week, summed up"
        case .esES: return "Tu semana, en resumen"
        case .frFR: return "Ta semaine, résumée"
        }
    }
    static func digestQuietBody(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Quiet week. The path is still here when you are."
        case .esES: return "Semana tranquila. El camino sigue aquí cuando tú vuelvas."
        case .frFR: return "Semaine calme. Le parcours t'attend quand tu reviens."
        }
    }
    static func digestLightTitle(_ reps: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Light week — \(reps) rep\(reps == 1 ? "" : "s")"
        case .esES: return "Semana ligera — \(reps) sesión\(reps == 1 ? "" : "es")"
        case .frFR: return "Semaine légère — \(reps) séance\(reps == 1 ? "" : "s")"
        }
    }
    static func digestLightBody(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "One more rep next week and you're at four. Open Noum to see what's trending."
        case .esES: return "Una sesión más la próxima semana y llegas a cuatro. Abre Noum para ver la tendencia."
        case .frFR: return "Une séance de plus la semaine prochaine et tu seras à quatre. Ouvre Noum pour voir la tendance."
        }
    }
    static func digestSteadyTitle(_ reps: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Steady week — \(reps) reps in"
        case .esES: return "Semana constante — \(reps) sesiones hechas"
        case .frFR: return "Semaine régulière — \(reps) séances bouclées"
        }
    }
    static func digestSteadyBody(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Open Noum to see how this week shaped up — score, pace, and what's trending."
        case .esES: return "Abre Noum para ver cómo terminó la semana — puntuación, ritmo y tendencia."
        case .frFR: return "Ouvre Noum pour voir comment la semaine s'est dessinée — note, rythme, tendance."
        }
    }
    static func digestStrongTitle(_ reps: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Strong week — \(reps) reps in"
        case .esES: return "Semana fuerte — \(reps) sesiones hechas"
        case .frFR: return "Semaine forte — \(reps) séances bouclées"
        }
    }
    static func digestStrongBody(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Open Noum to see your week. Score and pace are working together when reps stack like this."
        case .esES: return "Abre Noum para ver tu semana. Puntuación y ritmo trabajan juntos cuando las sesiones se acumulan así."
        case .frFR: return "Ouvre Noum pour voir ta semaine. Note et rythme avancent ensemble quand les séances s'enchaînent."
        }
    }
    static func digestTopTitle(_ reps: Int, locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Top week — \(reps) reps cleared"
        case .esES: return "Semana cumbre — \(reps) sesiones completadas"
        case .frFR: return "Semaine au sommet — \(reps) séances terminées"
        }
    }
    static func digestTopBody(locale: PracticeLocale) -> String {
        switch locale {
        case .enUS: return "Speakers who hit a rep a day are the ones whose voices change. Open Noum for the read."
        case .esES: return "Los que hacen una sesión al día son los que cambian la voz. Abre Noum para verlo."
        case .frFR: return "Ceux qui font une séance par jour sont ceux dont la voix change. Ouvre Noum pour la lecture."
        }
    }
}
