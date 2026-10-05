-- Adds the native narrated practices without rewriting existing catalog rows.
insert into public.sessions
  (id, title, intention, duration_seconds, category_id, pillar, practice_type, audio_path, artwork_path, is_premium, keywords)
values
  ('new_body_scan_sleep', '{"fr":"Le corps devient lourd"}', '{"fr":"Un scan corporel progressif pour laisser la journée se déposer avant le sommeil."}', 600, 'sleep', 'sleep', 'relaxation', null, 'session-new_body_scan_sleep.png', false, array['sommeil','corps','scan corporel']),
  ('new_nidra_pause', '{"fr":"Repos profond sans dormir"}', '{"fr":"Une relaxation inspirée du yoga nidra pour récupérer sans obligation de t’endormir."}', 720, 'recovery', 'sleep', 'relaxation', null, 'session-new_nidra_pause.png', true, array['repos','fatigue','relaxation']),
  ('new_soft_reset', '{"fr":"Redémarrage en douceur"}', '{"fr":"Une pause assise pour retrouver un peu d’énergie sans forcer."}', 300, 'recovery', 'emotions', 'anchoring', null, 'session-new_soft_reset.png', false, array['fatigue','énergie','ancrage']),
  ('new_thoughts_on_clouds', '{"fr":"Les pensées comme des nuages"}', '{"fr":"Observer le passage des pensées sans devoir les suivre ni les repousser."}', 480, 'thoughts', 'thoughts', 'visualization', null, 'session-new_thoughts_on_clouds.png', false, array['pensées','nuages','visualisation']),
  ('new_sensory_shelter', '{"fr":"Un refuge sensoriel"}', '{"fr":"Réduire la surcharge en revenant à quelques sensations simples et prévisibles."}', 420, 'stress', 'stress', 'anchoring', null, 'session-new_sensory_shelter.png', true, array['surcharge','sensations','ancrage']),
  ('new_focus_reset', '{"fr":"Une chose à la fois"}', '{"fr":"Rassembler ton attention avant de reprendre une tâche précise."}', 360, 'focus', 'thoughts', 'meditation', null, 'session-new_focus_reset.png', false, array['focus','attention','méditation']),
  ('new_after_conflict', '{"fr":"Après les mots trop forts"}', '{"fr":"Accueillir ce qui reste après un conflit avant de répondre ou de décider."}', 540, 'emotion', 'emotions', 'self_compassion', null, 'session-new_after_conflict.png', true, array['conflit','émotions','bienveillance']),
  ('new_box_breathing', '{"fr":"Respiration carrée"}', '{"fr":"Un cycle régulier en quatre temps, à raccourcir dès que nécessaire."}', 240, 'breathing', 'stress', 'breathing', null, 'session-new_box_breathing.png', false, array['respiration','carrée','stress']),
  ('new_long_exhale', '{"fr":"L’expiration longue"}', '{"fr":"Allonger doucement l’expiration pour ralentir le rythme sans retenir le souffle."}', 180, 'breathing', 'stress', 'breathing', null, 'session-new_long_exhale.png', false, array['expiration','respiration','court']),
  ('new_walking_pause', '{"fr":"Marcher en présence"}', '{"fr":"Une méditation en mouvement centrée sur les appuis et le rythme des pas."}', 480, 'movement', 'thoughts', 'anchoring', null, 'session-new_walking_pause.png', true, array['marche','mouvement','ancrage']),
  ('new_morning_window', '{"fr":"Ouvrir la matinée"}', '{"fr":"Commencer la journée par les sensations plutôt que par les notifications."}', 360, 'morning', 'emotions', 'meditation', null, 'session-new_morning_window.png', false, array['matin','notifications','méditation']),
  ('new_commute_boundary', '{"fr":"La frontière du trajet"}', '{"fr":"Créer une transition claire entre le travail, le trajet et le retour chez soi."}', 420, 'transition', 'thoughts', 'visualization', null, 'session-new_commute_boundary.png', true, array['trajet','travail','transition']),
  ('new_safe_place', '{"fr":"Un lieu suffisamment sûr"}', '{"fr":"Construire une image intérieure stable et réaliste où reprendre son souffle."}', 540, 'stress', 'emotions', 'visualization', null, 'session-new_safe_place.png', true, array['sécurité','visualisation','stress'])
on conflict (id) do update set
  title = excluded.title,
  intention = excluded.intention,
  duration_seconds = excluded.duration_seconds,
  category_id = excluded.category_id,
  pillar = excluded.pillar,
  practice_type = excluded.practice_type,
  audio_path = excluded.audio_path,
  artwork_path = excluded.artwork_path,
  is_premium = excluded.is_premium,
  keywords = excluded.keywords,
  catalog_version = public.sessions.catalog_version + 1,
  updated_at = now();

update public.sessions
set artwork_path = 'session-' || id || '.png', updated_at = now()
where artwork_path is null;
