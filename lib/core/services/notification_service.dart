import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Heure de rappel par défaut, dérivée de la réponse Q4 de l'onboarding
/// (« Quel serait ton moment à toi, dans la journée ? »). L'utilisateur a déjà
/// dit quand il préfère souffler — on s'en sert au lieu d'imposer une heure.
/// Repose sur les mots-clés « matin » / « journée » / « soir » présents dans
/// les libellés de _q4Options (onboarding_page.dart).
({int hour, int minute}) defaultReminderTime(Map<String, String> answers) {
  final q4 = answers['q4'] ?? '';
  if (q4.contains('matin')) return (hour: 8, minute: 0);
  if (q4.contains('journée')) return (hour: 12, minute: 30);
  if (q4.contains('soir')) return (hour: 19, minute: 30);
  return (hour: 19, minute: 0);
}

/// Rappel quotidien.
///
/// Philosophie (cf. discussion produit) : un rappel **doux, jamais
/// culpabilisant**. Une seule notification par jour, à une heure choisie par
/// l'utilisateur, désactivable en un tap. Si l'utilisateur a déjà fait sa
/// séance aujourd'hui, le rappel du jour est sauté (reprogrammé à demain).
///
/// Le texte change d'un jour à l'autre ([_bodies]) pour ne pas lasser. Une
/// notification répétitive a un contenu figé, donc on programme les
/// [_windowDays] prochains jours individuellement ; la fenêtre est
/// re-glissée à chaque ouverture de l'app (cf. QuietoApp.initState) et à
/// chaque reprogrammation.
class NotificationService {
  /// Ids réservés au rappel quotidien : _firstId .. _firstId+_windowDays-1.
  static const _firstId = 1;

  /// 30 jours d'avance : bien en dessous de la limite iOS de 64 notifications
  /// en attente, et il suffit d'ouvrir l'app une fois par mois pour que la
  /// fenêtre glisse.
  static const _windowDays = 30;
  static const _channelId = 'quieto_daily_reminder';

  /// Textes validés (discussion produit 2026-07-18). Le titre est toujours
  /// « Quieto ». Rotation stable par date : chaque jour calendaire a son
  /// texte, deux jours consécutifs sont toujours différents.
  static const _bodies = [
    'Louane est de retour pour discuter de ce qui te pèse ;)',
    'Tes séances t\'attendent pour relâcher la pression d\'aujourd\'hui ;)',
    'C\'est l\'heure de ta pause, viens souffler 5 minutes ;)',
  ];

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialise le plugin et la timezone locale. Sans danger d'appeler
  /// plusieurs fois. Ne demande AUCUNE permission (ça se fait au bon moment,
  /// jamais à froid au démarrage).
  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e) {
        // Timezone introuvable : on garde l'UTC par défaut. Le rappel sera
        // décalé mais l'app fonctionne.
        debugPrint('[Notifications] timezone locale introuvable : $e');
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // Les permissions sont demandées explicitement plus tard,
            // au moment où ça a du sens pour l'utilisateur.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[Notifications] init échoué (non-bloquant) : $e');
    }
  }

  /// Demande la permission système. Retourne true si accordée.
  Future<bool> requestPermission() async {
    if (!_initialized) await init();
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
    } catch (e) {
      debugPrint('[Notifications] requestPermission échoué : $e');
    }
    return false;
  }

  /// Programme (ou reprogramme) le rappel quotidien à [hour]:[minute] pour
  /// les [_windowDays] prochains jours, avec un texte différent chaque jour.
  /// [skipToday] : ne pas notifier aujourd'hui (l'utilisateur vient de faire
  /// sa séance) — première occurrence demain.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    bool skipToday = false,
  }) async {
    if (!_initialized) await init();
    try {
      await cancelDailyReminder();

      final now = tz.TZDateTime.now(tz.local);
      var first =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (skipToday || !first.isAfter(now)) {
        first = tz.TZDateTime(
            tz.local, now.year, now.month, now.day + 1, hour, minute);
      }

      for (var i = 0; i < _windowDays; i++) {
        // Reconstruction explicite (et non first.add(Duration)) : garde
        // l'heure « murale » identique même si l'heure d'été change dans
        // la fenêtre. Dart normalise les débordements de jour/mois.
        final date = tz.TZDateTime(
            tz.local, first.year, first.month, first.day + i, hour, minute);
        await _plugin.zonedSchedule(
          id: _firstId + i,
          title: 'Quieto',
          body: _bodyForDate(date),
          scheduledDate: date,
          // Inexact : pas besoin de la permission SCHEDULE_EXACT_ALARM, et
          // une minute près n'a aucune importance pour un rappel.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Rappel quotidien',
              channelDescription:
                  'Ton rappel quotidien pour prendre soin de toi.',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
      debugPrint(
          '[Notifications] rappels programmés : $first (+$_windowDays j)');
    } catch (e) {
      debugPrint('[Notifications] scheduleDailyReminder échoué : $e');
    }
  }

  /// Annule le rappel quotidien (toggle désactivé).
  Future<void> cancelDailyReminder() async {
    if (!_initialized) await init();
    try {
      for (var i = 0; i < _windowDays; i++) {
        await _plugin.cancel(id: _firstId + i);
      }
    } catch (e) {
      debugPrint('[Notifications] cancel échoué : $e');
    }
  }

  /// Texte du jour : indexé sur la date calendaire (jour de l'année), donc
  /// stable d'une reprogrammation à l'autre et jamais deux jours de suite
  /// identiques.
  String _bodyForDate(tz.TZDateTime date) {
    final dayOfYear =
        date.difference(tz.TZDateTime(tz.local, date.year, 1, 1)).inDays;
    return _bodies[dayOfYear % _bodies.length];
  }
}
