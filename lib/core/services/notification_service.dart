import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Heure de rappel par défaut, dérivée de la réponse Q4 de l'onboarding
/// (« Tu aurais plutôt 5 minutes pour toi... ? »). L'utilisateur a déjà dit
/// quand il préfère méditer — on s'en sert au lieu d'imposer une heure.
({int hour, int minute}) defaultReminderTime(Map<String, String> answers) {
  final q4 = answers['q4'] ?? '';
  if (q4.contains('matin')) return (hour: 8, minute: 0);
  if (q4.contains('journée')) return (hour: 12, minute: 30);
  if (q4.contains('soir')) return (hour: 19, minute: 30);
  return (hour: 19, minute: 0);
}

/// Rappel quotidien de méditation.
///
/// Philosophie (cf. discussion produit) : un rappel **doux, jamais
/// culpabilisant**. Une seule notification par jour, à une heure choisie par
/// l'utilisateur, désactivable en un tap. Si l'utilisateur a déjà médité
/// aujourd'hui, le rappel du jour est sauté (reprogrammé à demain).
class NotificationService {
  static const _dailyReminderId = 1;
  static const _channelId = 'quieto_daily_reminder';

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

  /// Programme (ou reprogramme) le rappel quotidien à [hour]:[minute].
  /// [skipToday] : ne pas notifier aujourd'hui (l'utilisateur vient de
  /// méditer) — première occurrence demain.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    bool skipToday = false,
    String firstName = '',
  }) async {
    if (!_initialized) await init();
    try {
      await _plugin.cancel(id: _dailyReminderId);

      final now = tz.TZDateTime.now(tz.local);
      var first =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (skipToday || !first.isAfter(now)) {
        first = first.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: _dailyReminderId,
        title: _titleForHour(hour),
        body: _bodyFor(firstName),
        scheduledDate: first,
        // Se répète chaque jour à la même heure.
        matchDateTimeComponents: DateTimeComponents.time,
        // Inexact : pas besoin de la permission SCHEDULE_EXACT_ALARM, et une
        // minute près n'a aucune importance pour un rappel de méditation.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Rappel quotidien',
            channelDescription:
                'Un rappel doux pour ton moment de méditation.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      debugPrint('[Notifications] rappel programmé : $first');
    } catch (e) {
      debugPrint('[Notifications] scheduleDailyReminder échoué : $e');
    }
  }

  /// Annule le rappel quotidien (toggle désactivé).
  Future<void> cancelDailyReminder() async {
    if (!_initialized) await init();
    try {
      await _plugin.cancel(id: _dailyReminderId);
    } catch (e) {
      debugPrint('[Notifications] cancel échoué : $e');
    }
  }

  // Ton doux, jamais culpabilisant : une invitation, pas un reproche.
  String _titleForHour(int hour) {
    if (hour < 11) return 'Commence ta journée en douceur 🌿';
    if (hour < 17) return 'Une petite pause pour souffler ? 🍃';
    return 'Ton moment de calme t\'attend 🌙';
  }

  String _bodyFor(String firstName) {
    return firstName.isEmpty
        ? 'Quelques minutes pour toi, quand tu es prêt.'
        : '$firstName, quelques minutes pour toi, quand tu es prêt.';
  }
}
