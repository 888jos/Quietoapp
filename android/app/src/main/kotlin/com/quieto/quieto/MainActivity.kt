package com.quieto.quieto

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity (et pas FlutterActivity) : oblige l'activité et le
// service audio à partager le MÊME moteur Flutter. Avec FlutterActivity,
// Android lançait l'app en double (une copie invisible pour le service),
// d'où la musique d'accueil jouée deux fois avec un écho impossible à couper
// depuis le profil (bug parents, version 1.0.12).
class MainActivity : AudioServiceActivity()
