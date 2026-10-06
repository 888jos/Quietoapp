import Foundation

protocol QuietoSessionCatalogProviding {
    var sessions: [QuietoSession] { get }
}

struct SessionCatalog: QuietoSessionCatalogProviding {
    let sessions: [QuietoSession] = Self.build()

    private static func build() -> [QuietoSession] {
        [
            // Express
            make("express_1", "Avant un appel difficile", 1, "Un ancrage rapide pour arriver centré et calme à ton prochain appel.", "express-avant-un-appel-difficile.mp3", "express", false, .thoughts, .anchoring),
            make("express_2", "Transports bondés", 2, "Trouve ton calme intérieur même au milieu de la foule.", "express-transports-bondes.mp3", "express", false, .thoughts, .anchoring),
            make("express_3", "Petit déjeuner", 2, "Une minute de gratitude pour bien commencer ta journée.", "express-petit-dejeuner.mp3", "express", false, .emotions, .meditation),
            make("express_4", "Juste avant de dormir", 3, "Relâche les tensions de la journée pour mieux t'endormir.", "express-juste-avant-de-dormir.mp3", "express", false, .sleep, .relaxation),
            make("express_5", "Coup de stress au boulot", 2, "Quand la pression monte, reprends le contrôle en 90 secondes.", "express-coup-de-stress-au-boulot.mp3", "express", true, .stress, .anchoring),
            make("express_6", "Après une dispute", 2, "Reconnecte-toi à toi-même quand l'émotion a pris le dessus.", "express-apres-une-dispute.mp3", "express", true, .emotions, .anchoring),
            make("express_7", "Réveil en panique", 2, "Calme ton cœur quand tu te réveilles avec l'angoisse au ventre.", "express-reveil-en-panique.mp3", "express", true, .stress, .breathing),
            make("express_8", "Avant une présentation", 2, "Calme le trac avant de prendre la parole en public ou en examen.", "express-avant-une-presentation.mp3", "express", true, .stress, .anchoring),

            // Découverte
            make("decouverte_1", "Ma première méditation", 6, "Une introduction douce pour ceux qui n'ont jamais médité.", "01-decouverte-premiere-meditation.mp3", "decouverte", false, .thoughts, .meditation),
            make("decouverte_2", "Observer sans juger", 7, "Apprends à accueillir tes pensées sans t'y attacher.", "02-decouverte-observer-sans-juger.mp3", "decouverte", false, .thoughts, .meditation),
            make("decouverte_3", "Le moment présent", 6, "Entraîne-toi à revenir ici et maintenant, encore et encore.", "03-decouverte-moment-present.mp3", "decouverte", false, .thoughts, .anchoring),

            // Actualité & surcharge mentale
            make("actualite_1", "Quand le monde brûle", 7, "Déconnecte ton esprit du bruit informationnel.", "23-actualite-quand-le-monde-brule.mp3", "actualite", false, .thoughts, .meditation),
            make("actualite_2", "La guerre en bruit de fond", 8, "Trouve la sérénité malgré un monde en constante évolution.", "24-actualite-la-guerre-en-bruit-de-fond.mp3", "actualite", true, .thoughts, .meditation),
            make("actualite_3", "Débrancher quand tout crie", 8, "Une pause consciente loin des écrans et des titres.", "25-actualite-debrancher-quand-tout-crie.mp3", "actualite", false, .thoughts, .anchoring),
            make("actualite_4", "Recul sur l'actualité", 13, "Apprends à poser ton téléphone avec légèreté.", "26-actualite-recul-sur-lactualite.mp3", "actualite", true, .thoughts, .meditation),
            make("actualite_5", "Pause info", 7, "Prends de la hauteur sur les événements du monde.", "27-actualite-pause-info.mp3", "actualite", true, .thoughts, .meditation),

            // Stress & anxiété
            make("stress_1", "Quand le stress prend le dessus", 7, "Une séance pour revenir à toi quand la pression monte.", "08-stress-quand-le-stress-prend-le-dessus.mp3", "stress", false, .stress, .breathing),
            make("stress_2", "Respiration 4-7-8", 5, "Parcours ton corps pour relâcher les tensions.", "09-stress-respiration-4-7-8.mp3", "stress", true, .stress, .breathing),
            make("stress_3", "Relâche", 9, "Contracte et relâche chaque groupe musculaire.", "10-stress-relache.mp3", "stress", false, .stress, .relaxation),
            make("stress_4", "Ancrage", 6, "Reviens à toi grâce à une technique d'ancrage simple.", "11-stress-ancrage.mp3", "stress", false, .stress, .anchoring),
            make("stress_5", "Le voyageur qui s'arrête", 12, "Dissous les tensions mentales et retrouve un état de calme.", "12-stress-le-voyageur-qui-sarrete.mp3", "stress", true, .stress, .relaxation),

            // Sommeil
            make("sleep_1", "Détente du soir", 13, "Prépare ton corps et ton esprit au repos.", "13-sommeil-detente-du-soir.mp3", "sleep", false, .sleep, .relaxation),
            make("sleep_2", "Visualisation apaisante", 7, "Voyage mental dans un lieu calme et sécurisant.", "14-sommeil-visualisation-apaisante.mp3", "sleep", false, .sleep, .visualization),
            make("sleep_3", "Rituel pré-sommeil", 7, "Un rituel simple pour quitter doucement la journée.", "15-sommeil-rituel-pre-sommeil.mp3", "sleep", false, .sleep, .relaxation),
            make("sleep_4", "Entre deux mondes", 7, "Laisse les pensées ralentir avant la nuit.", "16-sommeil-entre-deux-mondes.mp3", "sleep", false, .sleep, .visualization),
            make("sleep_5", "Plongée dans le silence", 6, "Une pause silencieuse pour accompagner le coucher.", "17-sommeil-plongee-dans-le-silence.mp3", "sleep", true, .sleep, .meditation),

            // Respiration
            make("breathing_1", "Cohérence cardiaque", 4, "Une respiration guidée pour retrouver un rythme régulier.", "04-respiration-coherence-cardiaque.mp3", "breathing", false, .stress, .breathing),
            make("breathing_2", "Respiration alternée", 5, "Explore une respiration lente et attentive.", "05-respiration-respiration-alternee.mp3", "breathing", false, .stress, .breathing),
            make("breathing_3", "Souffle apaisant", 8, "Un temps pour ralentir et écouter ton souffle.", "06-respiration-souffle-apaisant.mp3", "breathing", false, .stress, .breathing),
            make("breathing_4", "Expansion thoracique", 9, "Redonne de l'espace à ta respiration.", "07-respiration-expansion-thoracique.mp3", "breathing", false, .stress, .breathing),

            // Émotions
            make("emotion_1", "Apprendre à s'aimer", 8, "Accueille-toi avec davantage de douceur.", "18-emotion-apprendre-a-saimer.mp3", "emotion", false, .emotions, .selfCompassion),
            make("emotion_2", "Joie et énergie", 9, "Reconnecte-toi à ce qui te fait du bien.", "19-emotion-joie-et-energie.mp3", "emotion", false, .emotions, .meditation),
            make("emotion_3", "De l'anxiété au sourire", 14, "Observe ton ressenti avec douceur et curiosité.", "20-emotion-de-lanxiete-au-sourire.mp3", "emotion", false, .emotions, .meditation),
            make("emotion_4", "Peur et courage", 7, "Fais une place à ce qui est là, sans te brusquer.", "21-emotion-peur-et-courage.mp3", "emotion", false, .emotions, .selfCompassion),
            make("emotion_5", "L'amour", 8, "Un moment de bienveillance envers toi et les autres.", "22-emotion-lamour.mp3", "emotion", false, .emotions, .selfCompassion),

            // Nouvelles pratiques — fatigue, concentration et récupération
            make("new_body_scan_sleep", "Le corps devient lourd", 10, "Un scan corporel progressif pour laisser la journée se déposer avant le sommeil.", "", "sleep", false, .sleep, .relaxation),
            make("new_nidra_pause", "Repos profond sans dormir", 12, "Une relaxation inspirée du yoga nidra pour récupérer sans obligation de t’endormir.", "", "recovery", true, .sleep, .relaxation),
            make("new_soft_reset", "Redémarrage en douceur", 5, "Une pause assise pour retrouver un peu d’énergie sans forcer.", "", "recovery", false, .emotions, .anchoring),
            make("new_thoughts_on_clouds", "Les pensées comme des nuages", 8, "Observer le passage des pensées sans devoir les suivre ni les repousser.", "", "thoughts", false, .thoughts, .visualization),
            make("new_sensory_shelter", "Un refuge sensoriel", 7, "Réduire la surcharge en revenant à quelques sensations simples et prévisibles.", "", "stress", true, .stress, .anchoring),
            make("new_focus_reset", "Une chose à la fois", 6, "Rassembler ton attention avant de reprendre une tâche précise.", "", "focus", false, .thoughts, .meditation),
            make("new_after_conflict", "Après les mots trop forts", 9, "Accueillir ce qui reste après un conflit avant de répondre ou de décider.", "", "emotion", true, .emotions, .selfCompassion),
            make("new_box_breathing", "Respiration carrée", 4, "Un cycle régulier en quatre temps, à raccourcir dès que nécessaire.", "", "breathing", false, .stress, .breathing),
            make("new_long_exhale", "L’expiration longue", 3, "Allonger doucement l’expiration pour ralentir le rythme sans retenir le souffle.", "", "breathing", false, .stress, .breathing),
            make("new_walking_pause", "Marcher en présence", 8, "Une méditation en mouvement centrée sur les appuis et le rythme des pas.", "", "movement", true, .thoughts, .anchoring),
            make("new_morning_window", "Ouvrir la matinée", 6, "Commencer la journée par les sensations plutôt que par les notifications.", "", "morning", false, .emotions, .meditation),
            make("new_commute_boundary", "La frontière du trajet", 7, "Créer une transition claire entre le travail, le trajet et le retour chez soi.", "", "transition", true, .thoughts, .visualization),
            make("new_safe_place", "Un lieu suffisamment sûr", 9, "Construire une image intérieure stable et réaliste où reprendre son souffle.", "", "stress", true, .emotions, .visualization)
            , make("breathing_5", "Souffle en escalier", 5, "Une respiration en vagues douces pour retrouver de l’espace.", "", "breathing", false, .stress, .breathing)

            // Méditations par moment de la journée — toutes vocales et distinctes.
            , make("daybreak_stillness", "Le calme avant les messages", 7, "Commencer sans donner toute ta matinée aux notifications.", "", "morning", false, .thoughts, .meditation)
            , make("daybreak_grounding", "Pieds au sol", 5, "Sentir les appuis avant de choisir la première chose à faire.", "", "morning", false, .stress, .anchoring)
            , make("morning_breathing_space", "L’espace entre deux tâches", 8, "Faire une vraie transition avant de passer à la suite.", "", "morning", false, .thoughts, .meditation)
            , make("morning_kind_start", "Commencer avec douceur", 10, "Entrer dans la journée avec une exigence plus juste.", "", "morning", true, .emotions, .selfCompassion)
            , make("late_morning_focus", "Revenir à l’essentiel", 6, "Rassembler l’attention sur une seule action présente.", "", "morning", false, .thoughts, .meditation)
            , make("lunch_reset", "La pause du déjeuner", 5, "Quitter l’écran quelques instants et retrouver les sensations.", "", "day", false, .emotions, .anchoring)
            , make("after_lunch_energy", "Énergie tranquille", 8, "Réveiller l’attention sans accélérer le rythme.", "", "day", true, .stress, .meditation)
            , make("afternoon_fog", "Quand l’après-midi ralentit", 9, "Accueillir la fatigue et repartir sans se brusquer.", "", "day", false, .thoughts, .relaxation)
            , make("afternoon_reframe", "Changer de perspective", 12, "Prendre du recul sur une situation qui occupe trop de place.", "", "day", true, .thoughts, .visualization)
            , make("before_meeting", "Avant de retrouver les autres", 4, "Arriver à une réunion avec une attention plus disponible.", "", "transition", false, .stress, .anchoring)
            , make("between_calls", "Entre deux appels", 3, "Laisser une conversation se terminer avant la suivante.", "", "transition", false, .emotions, .meditation)
            , make("after_work", "Fermer la journée de travail", 9, "Créer une frontière douce entre obligations et temps personnel.", "", "transition", false, .thoughts, .visualization)
            , make("commute_home", "Le trajet vers soi", 11, "Transformer le trajet en passage plutôt qu’en liste de tâches.", "", "transition", true, .thoughts, .meditation)
            , make("doorstep_pause", "Sur le seuil", 4, "Prendre une respiration avant d’entrer chez soi.", "", "transition", false, .stress, .anchoring)
            , make("evening_unwind", "Déposer la journée", 10, "Faire descendre progressivement le bruit de la journée.", "", "evening", false, .sleep, .relaxation)
            , make("evening_release", "Laisser partir le contrôle", 13, "Desserrer l’envie de tout résoudre ce soir.", "", "evening", true, .thoughts, .meditation)
            , make("blue_hour", "L’heure bleue", 8, "Habiter un moment de transition sans avoir à le remplir.", "", "evening", false, .emotions, .visualization)
            , make("after_dinner", "Après le repas", 6, "Revenir au corps dans le calme qui suit la journée.", "", "evening", false, .sleep, .anchoring)
            , make("screen_off", "Éteindre les écrans", 7, "Accompagner le passage du dehors vers un rythme plus lent.", "", "evening", true, .sleep, .relaxation)
            , make("night_watch", "Veille paisible", 15, "Rester présent quand le sommeil ne vient pas tout de suite.", "", "night", false, .sleep, .meditation)
            , make("middle_of_night", "Réveil nocturne", 8, "Retrouver un appui sans forcer le retour au sommeil.", "", "night", false, .sleep, .anchoring)
            , make("night_sky", "Sous le ciel immobile", 12, "Laisser les pensées s’éloigner comme des lumières au loin.", "", "night", true, .sleep, .visualization)
            , make("sunday_reset", "Recommencer doucement", 10, "Accueillir le début d’un nouveau cycle sans anticiper toute la semaine.", "", "weekly", false, .emotions, .selfCompassion)
            , make("monday_arrival", "Entrer dans lundi", 7, "Faire de la place avant que la semaine ne s’accélère.", "", "weekly", false, .stress, .meditation)
            , make("friday_release", "La semaine peut se terminer", 9, "Reconnaître ce qui a été fait et relâcher le reste.", "", "weekly", false, .thoughts, .relaxation)
            , make("lonely_evening", "Quand la maison est silencieuse", 11, "Créer une présence intérieure accueillante dans le calme.", "", "evening", true, .emotions, .selfCompassion)
            , make("decision_pause", "Avant de décider", 6, "Observer les options sans répondre dans l’urgence.", "", "stress", false, .thoughts, .meditation)
            , make("creative_block", "Faire de la place aux idées", 8, "Débloquer l’attention en relâchant la pression de produire.", "", "focus", false, .thoughts, .visualization)
            , make("gentle_recovery", "Récupérer sans culpabiliser", 14, "Offrir au corps une vraie pause quand l’énergie est basse.", "", "recovery", true, .sleep, .relaxation)
            , make("small_joy", "Remarquer le bon", 5, "Retrouver une sensation agréable sans devoir la retenir.", "", "day", false, .emotions, .meditation)
            , make("meditation_01", "Une minute de ciel", 4, "Ouvrir l’attention à l’espace autour de toi.", "", "anytime", false, .thoughts, .meditation)
            , make("meditation_02", "Le son le plus proche", 6, "S’appuyer sur l’écoute pour ralentir les pensées.", "", "anytime", false, .thoughts, .meditation)
            , make("meditation_03", "Respirer avec la lumière", 8, "Laisser une sensation claire guider la pause.", "", "morning", false, .emotions, .meditation)
            , make("meditation_04", "Le banc tranquille", 10, "S’asseoir intérieurement sans avoir à avancer.", "", "day", true, .stress, .meditation)
            , make("meditation_05", "Une place pour l’émotion", 9, "Reconnaître le ressenti sans le laisser décider de tout.", "", "anytime", false, .emotions, .meditation)
            , make("meditation_06", "Le fil de l’attention", 12, "Revenir à un point d’appui après chaque distraction.", "", "focus", false, .thoughts, .meditation)
            , make("meditation_07", "Pause au bord de l’eau", 7, "Accompagner les changements sans chercher à les retenir.", "", "day", true, .thoughts, .meditation)
            , make("meditation_08", "Laisser être", 14, "Faire moins de place à la lutte et plus à l’observation.", "", "anytime", true, .emotions, .meditation)
            , make("meditation_09", "Retour au visage", 5, "Détendre le front et la mâchoire avant de reprendre.", "", "stress", false, .stress, .meditation)
            , make("meditation_10", "La météo intérieure", 8, "Observer les variations du moment avec curiosité.", "", "anytime", false, .emotions, .meditation)
            , make("meditation_11", "Une pause dans le bruit", 11, "Créer un espace stable au milieu des sollicitations.", "", "day", true, .stress, .meditation)
            , make("meditation_12", "Le soir en trois gestes", 6, "Marquer la fin de la journée par quelques gestes simples.", "", "evening", false, .sleep, .meditation)
            , make("meditation_13", "Baisser le volume", 10, "Réduire l’intensité sans avoir à tout couper.", "", "stress", false, .thoughts, .meditation)
            , make("meditation_14", "Regarder passer", 15, "Laisser les pensées passer sans leur construire une histoire.", "", "anytime", true, .thoughts, .meditation)
            , make("meditation_15", "Présence dans les mains", 7, "Retrouver le corps par le contact et la chaleur.", "", "anytime", false, .emotions, .meditation)
            , make("meditation_16", "Le repos des yeux", 5, "Offrir une pause douce au regard après les écrans.", "", "evening", false, .sleep, .meditation)
            , make("meditation_17", "Finir sans conclure", 9, "Terminer une journée sans devoir lui donner une réponse parfaite.", "", "evening", true, .thoughts, .meditation)
        ]
    }

    private static func make(_ id: String, _ title: String, _ duration: Int, _ intention: String, _ audio: String, _ category: String, _ premium: Bool, _ pillar: QuietoPillar, _ practice: QuietoPracticeType) -> QuietoSession {
        let situations = QuietoSituation.allCases.filter { $0.sessionIDs.contains(id) }
        let contextualThemes = Set(situations.flatMap(\.themes))
        let pillarTheme: QuietoTheme = switch pillar {
        case .sleep: .sleep
        case .stress: .stress
        case .thoughts: .focus
        case .emotions: .emotions
        }
        let themes = Array(contextualThemes.union([pillarTheme])).sorted { $0.rawValue < $1.rawValue }
        let searchTerms = [title, category, pillar.rawValue, practice.rawValue, intention]
            + themes.map(\.rawValue)
            + situations.flatMap { [$0.rawValue, $0.subtitle] }
        return QuietoSession(
            id: id,
            title: title,
            durationMinutes: duration,
            subtitle: practice.rawValue,
            imageName: "session-\(id).png",
            isPremium: premium,
            audioFile: audio,
            categoryID: category,
            pillar: pillar,
            practiceType: practice,
            intention: intention,
            keywords: searchTerms,
            themes: themes,
            situations: situations,
            longDescription: detail(for: id, title: title, duration: duration, intention: intention, practice: practice),
            breathingPattern: pattern(for: id, practice: practice)
        )
    }

    private static func pattern(for id: String, practice: QuietoPracticeType) -> QuietoBreathingPattern? {
        guard practice == .breathing else { return nil }
        if id.contains("4-7") || id == "breathing_2" { return .fourSevenEight }
        if id.contains("box") { return .box }
        if id.contains("long") { return .longExhale }
        return id == "breathing_5" ? .box : .coherence
    }

    private static func detail(for id: String, title: String, duration: Int, intention: String, practice: QuietoPracticeType) -> String {
        if practice == .breathing {
            return "Cet exercice de \(duration) minutes se pratique sans narration. Un point suit une courbe : la montée accompagne l’inspiration, le plateau indique une pause éventuelle et la descente guide l’expiration. \(intention) Le rythme peut être interrompu ou adapté à tout moment ; il ne faut jamais forcer ni retenir le souffle si cela devient inconfortable."
        }
        if id == "sleep_4" {
            return "Entre deux mondes accompagne précisément le passage entre l’éveil et le sommeil. La séance commence par les points de contact du corps, ralentit le souffle sans imposer de compte, puis utilise une visualisation très simple pour laisser les pensées perdre leur urgence. Tu peux l’écouter au lit : la fin ne demande aucune action et laisse une plage de silence pour continuer à t’endormir."
        }
        return "Cette séance de \(duration) minutes utilise la \(practice.rawValue.lowercased()) pour répondre à une situation concrète : \(intention.lowercased()) Elle alterne des consignes courtes et des silences afin de te laisser pratiquer réellement. Aucune sensation particulière n’est attendue ; l’objectif est seulement de créer un peu plus de choix dans la suite de ta journée."
    }
}
