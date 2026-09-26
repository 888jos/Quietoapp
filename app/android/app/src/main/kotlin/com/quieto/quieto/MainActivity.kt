package com.quieto.quieto

import com.ryanheise.audioservice.AudioServiceFragmentActivity

// AudioServiceFragmentActivity et surtout PAS :
// - FlutterActivity : l'app se lançait en double (une copie invisible pour le
//   service audio), musique d'accueil jouée deux fois (bug parents, 1.0.12) ;
// - AudioServiceActivity : le plugin `health` (Apple Santé / Health Connect)
//   exige une ComponentActivity au démarrage → ClassCastException, crash
//   SYSTÉMATIQUE à l'ouverture sur tout appareil avec Health Connect
//   (incident 1.0.13 build 18, retirée par Google le 5 août 2026).
// Cette variante partage le moteur Flutter avec le service audio ET hérite
// de FragmentActivity, ce qui satisfait les deux plugins.
class MainActivity : AudioServiceFragmentActivity()
