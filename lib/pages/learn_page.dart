import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'package:fintech/services/learning_progress_service.dart';

const Color _learnBg = Color(0xFFF5F6F7);
const Color _learnCard = Colors.white;
const Color _learnInk = Colors.black87;
const Color _learnMuted = Colors.black54;

double _scaledFont(BuildContext context, double size) {
  final width = MediaQuery.sizeOf(context).width;
  final factor = (width / 390).clamp(0.85, 1.2);
  final base = size * factor;
  return MediaQuery.textScalerOf(context).scale(base);
}

enum _AdUnlockType { lesson, quiz, scenario, coins }

/// Page d'apprentissage façon Duolingo pour l'onglet "Learn".
class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> with SingleTickerProviderStateMixin {
  static const int _dailyGoal = 120;
  static const double _stageIncrement = 0.12;
  static const int _dailyQuizCount = 10;
  static const int _freeLessonsPerDay = 3;
  static const int _freeQuizzesPerDay = 5;
  static const int _freeScenariosPerDay = 1;
  static const int _maxLessonTickets = 2;
  static const int _maxQuizTickets = 2;
  static const int _maxScenarioTickets = 3;
  static const int _minScenarioStake = 40;
  static const int _maxScenarioStake = 1000;
  static const int _lessonCoinReward = 24;
  static const int _quizCoinReward = 14;
  static const int _adCoinBoost = 400;
  static const int _gemsPerStreak = 1;
  static const double _winBias = 0.82;
  static const double _lossBias = 1.12;

  final PageController _questionCtrl = PageController();
  late final AnimationController _pulseCtrl;

  bool _loadingProgress = true;
  String? _progressError;
  LearningProgress? _progress;

  final Map<String, int> _selectedAnswers = {};
  final Set<String> _validatedQuestions = <String>{};
  final Set<String> _awaitingReveal = <String>{};
  final Set<String> _revealedQuiz = <String>{};
  final Set<String> _correctlyAnsweredQuiz = <String>{};
  DateTime? _quizSeedDay;
  int _currentQuestion = 0;
  List<_QuizCardData> _activeQuiz = const <_QuizCardData>[];
  Timer? _heartTicker;
  String? _heartCountdownText;
  final Map<_AdUnlockType, bool> _adLoading = {
    _AdUnlockType.lesson: false,
    _AdUnlockType.quiz: false,
    _AdUnlockType.scenario: false,
    _AdUnlockType.coins: false,
  };

  final List<_LearningStage> _stages = const [
    _LearningStage(
      id: 'fundamentals',
      title: 'Analyse fondamentale',
      subtitle: 'Bilans, valorisation, ratios',
      icon: Icons.stacked_line_chart_rounded,
      accent: Color(0xFF3D82F7),
    ),
    _LearningStage(
      id: 'technical',
      title: 'Analyse technique',
      subtitle: 'Supports, figures & momentum',
      icon: Icons.timeline_rounded,
      accent: Color(0xFF8F67FF),
    ),
    _LearningStage(
      id: 'intuition',
      title: 'Intuition & bon sens',
      subtitle: 'Macro, psychologie, news',
      icon: Icons.psychology_rounded,
      accent: Color(0xFFFF9E64),
    ),
    _LearningStage(
      id: 'history',
      title: 'Questions historiques',
      subtitle: 'Bulles, crises, leçons clés',
      icon: Icons.history_edu_rounded,
      accent: Color(0xFF00BFA6),
      locked: true,
    ),
    _LearningStage(
      id: 'psychology',
      title: 'Gestion & psychologie',
      subtitle: 'Discipline, biais, money management',
      icon: Icons.self_improvement_rounded,
      accent: Color(0xFFD65DB1),
    ),
    _LearningStage(
      id: 'esg',
      title: 'Macro durable / ESG',
      subtitle: 'Transition, COP, énergie propre',
      icon: Icons.eco_rounded,
      accent: Color(0xFF4CAF50),
    ),
    _LearningStage(
      id: 'derivatives',
      title: 'Dérivés & couverture',
      subtitle: 'Options, VIX, spreads',
      icon: Icons.multiline_chart_rounded,
      accent: Color(0xFF00BCD4),
      locked: true,
    ),
  ];

List<_MiniLesson>? _cachedLessons;
List<_MiniLesson> get _lessons {
  _cachedLessons ??= List.unmodifiable([
    ..._baseLessons,
    ..._buildGeneratedLessons(),
  ]);
  return _cachedLessons!;
}

static const List<_MiniLesson> _baseLessons = [
    _MiniLesson(
      id: 'lesson_fcf',
      stageId: 'fundamentals',
      title: 'Free cash-flow',
      summary: 'Comprends pourquoi le FCF protège l’actionnaire.',
      duration: '5 min',
      rewardXp: 8,
      icon: Icons.ssid_chart_rounded,
      bulletPoints: [
        'FCF = flux opérationnel − investissements. Il mesure le cash réellement libre.',
        'Comparer l’évolution du FCF avec le bénéfice net pour détecter une qualité douteuse.',
        'Un FCF positif permet de financer dividendes, rachats et désendettement sans lever de fonds.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_peg',
      stageId: 'fundamentals',
      title: 'PEG et croissance',
      summary: 'Relie PER et croissance pour qualifier une valorisation.',
      duration: '4 min',
      rewardXp: 8,
      icon: Icons.percent_rounded,
      bulletPoints: [
        'PEG = PER / taux de croissance attendu. 1 ≈ valorisation équilibrée.',
        'Un PEG > 2 signale souvent une croissance surestimée ou un risque accru.',
        'Toujours comparer les PEG d’entreprises du même secteur.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_supports',
      stageId: 'technical',
      title: 'Supports dynamiques',
      summary: 'Les moyennes mobiles comme filet de sécurité.',
      duration: '6 min',
      rewardXp: 10,
      icon: Icons.timeline_rounded,
      bulletPoints: [
        'La MM50 sert souvent de support sur une tendance haussière de moyen terme.',
        'Une cassure avec volume valide la fin de tendance, sauf faux signaux intraday.',
        'Combiner MM avec RSI/MACD pour confirmer la dynamique.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_macro',
      stageId: 'intuition',
      title: 'Lire un agenda macro',
      summary: 'Filtrer les évènements qui touchent ton portefeuille.',
      duration: '5 min',
      rewardXp: 8,
      icon: Icons.event_note_rounded,
      bulletPoints: [
        'Associe chaque ligne de ton portefeuille à 2/3 indicateurs macro sensibles.',
        'Utilise la colonne « consensus » pour anticiper volatilité en cas de surprise.',
        'Planifie tes entrées/TP avant les publications majeures (CPI, FOMC, COP).',
      ],
    ),
    _MiniLesson(
      id: 'lesson_crises',
      stageId: 'history',
      title: 'Crises à effet domino',
      summary: 'Comprendre comment un choc local devient global.',
      duration: '7 min',
      rewardXp: 10,
      icon: Icons.history_toggle_off_rounded,
      bulletPoints: [
        '2008 : titrisation + CDS = propagation planétaire en moins de 3 mois.',
        'Toujours analyser les expositions croisées (banques, assureurs, fonds).',
        'Surveille la liquidité obligataire : un spread qui explose précède souvent la crise actions.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_capex',
      stageId: 'fundamentals',
      title: 'Capex intelligents',
      summary: 'Différencier CAPEX de maintenance vs croissance.',
      duration: '6 min',
      rewardXp: 10,
      icon: Icons.factory_rounded,
      bulletPoints: [
        'Capex de maintenance = garder l’outil productif ; croissance = expansion.',
        'Comparer capex/CA aux pairs pour détecter des plans agressifs.',
        'Surveiller si le Free Cash Flow reste positif après investissements.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_breakout',
      stageId: 'technical',
      title: 'Reconnaître les faux breakouts',
      summary: 'Savoir lire volumes et pullbacks.',
      duration: '5 min',
      rewardXp: 9,
      icon: Icons.show_chart_rounded,
      bulletPoints: [
        'Vérifie le volume : un breakout sans volume est suspect.',
        'Attends souvent un pullback réussi pour confirmer.',
        'Placer un stop serré sous la résistance évite les pièges.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_spreads',
      stageId: 'derivatives',
      title: 'Spreads de crédit',
      summary: 'Lien spreads ↔ sentiment de marché.',
      duration: '5 min',
      rewardXp: 9,
      icon: Icons.trending_down_rounded,
      bulletPoints: [
        'Spreads high yield ↑ = prime de risque ↑, attention aux valeurs fragiles.',
        'Comparer aux spreads investment grade pour jauger l’ampleur.',
        'Coupler avec VIX et flux ETF pour affiner tes décisions.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_drawdown',
      stageId: 'psychology',
      title: 'Maîtriser le drawdown',
      summary: 'Calcule et surveille la baisse maximale.',
      duration: '4 min',
      rewardXp: 8,
      icon: Icons.shield_moon_rounded,
      bulletPoints: [
        'Max drawdown = pire perte entre un pic et un creux.',
        'Fixe-toi un plafond pour préserver ta psychologie.',
        'Utilise des stops dynamiques pour limiter la casse.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_rate_moves',
      stageId: 'intuition',
      title: 'Impact des taux réels',
      summary: 'Comprendre pourquoi les growth bafouillent.',
      duration: '6 min',
      rewardXp: 9,
      icon: Icons.percent_rounded,
      bulletPoints: [
        'Taux réels = taux nominaux − inflation attendue.',
        'Des taux réels hauts pèsent sur la duration longue (tech).',
        'Les banques et financières peuvent en profiter via marges nettes.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_options_vol',
      stageId: 'derivatives',
      title: 'Volatilité implicite & VIX',
      summary: 'Adapter ses couvertures.',
      duration: '5 min',
      rewardXp: 9,
      icon: Icons.bolt_rounded,
      bulletPoints: [
        'VIX ↑ = options plus chères, couvre-toi avant la tempête.',
        'Surveille skew pour détecter un stress sur puts.',
        'Combine delta/beta pour calibrer la taille de couverture.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_macro_calendar',
      stageId: 'intuition',
      title: 'Agenda macro avancé',
      summary: 'Prioriser CPI, FOMC, PMI, etc.',
      duration: '5 min',
      rewardXp: 8,
      icon: Icons.event_available_rounded,
      bulletPoints: [
        'Associe chaque valeur à 2 indicateurs macro sensibles.',
        'Analyse l’écart vs consensus pour anticiper la volatilité.',
        'Désactive les ordres durant les annonces majeures.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_history_blackmonday',
      stageId: 'history',
      title: 'Lundi Noir 1987',
      summary: 'Ce que cela a changé pour la gestion du risque.',
      duration: '4 min',
      rewardXp: 8,
      icon: Icons.warning_amber_rounded,
      bulletPoints: [
        'Le trading programmé a accéléré la chute.',
        'Importance d’avoir des coupe-circuits et plans de liquidité.',
        'Diversifier les styles réduit l’impact d’un choc systémique.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_biases',
      stageId: 'psychology',
      title: 'Biais comportementaux',
      summary: 'Évite euphorie et panique.',
      duration: '6 min',
      rewardXp: 9,
      icon: Icons.scatter_plot_rounded,
      bulletPoints: [
        'Biais de confirmation : tu cherches les infos qui vont dans ton sens.',
        'Effet de récence : ne pas extrapoler un mouvement court terme.',
        'Mettre des règles écrites aide à contrer ces biais.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_money_management',
      stageId: 'psychology',
      title: 'Money management',
      summary: 'Position sizing et discipline.',
      duration: '5 min',
      rewardXp: 9,
      icon: Icons.balance_rounded,
      bulletPoints: [
        'Fixe un risque % par trade et respecte-le.',
        'Rééquilibre ton portefeuille quand un poids dépasse ton plan.',
        'Utilise un journal de trades pour rester cohérent.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_cop',
      stageId: 'esg',
      title: 'Lire un agenda COP',
      summary: 'Anticipe les annonces climat.',
      duration: '5 min',
      rewardXp: 8,
      icon: Icons.public_rounded,
      bulletPoints: [
        'Identifie les secteurs gagnants/perdants selon les quotas.',
        'Surveille les financements verts et subventions.',
        'Intègre les objectifs climatiques dans tes DCF.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_esg_score',
      stageId: 'esg',
      title: 'Scores ESG',
      summary: 'Que valent-ils réellement ?',
      duration: '4 min',
      rewardXp: 7,
      icon: Icons.star_rounded,
      bulletPoints: [
        'Comparer plusieurs agences pour éviter les biais.',
        'Comprendre les controverses et leur impact sur prime de risque.',
        'Utilise-les comme complément, pas comme vérité absolue.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_offsetting',
      stageId: 'derivatives',
      title: 'Couvertures delta / gamma',
      summary: 'Calibrer options et futures.',
      duration: '6 min',
      rewardXp: 10,
      icon: Icons.swap_calls_rounded,
      bulletPoints: [
        'Delta = sensibilité directionnelle, gamma = réaction du delta.',
        'Utiliser des spreads pour limiter le coût des protections.',
        'Réviser la couverture quand la volatilité évolue.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_psy_plan',
      stageId: 'psychology',
      title: 'Plan anti-panique',
      summary: 'Savoir comment agir avant la tempête.',
      duration: '5 min',
      rewardXp: 8,
      icon: Icons.rule_rounded,
      bulletPoints: [
        'Prépare un playbook écrit pour chaque niveau de baisse.',
        'Définis qui prévenir / quelles métriques surveiller.',
        'Respire, vérifie les chiffres avant de cliquer.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_psy_journal',
      stageId: 'psychology',
      title: 'Journal de positions',
      summary: 'Objectiver tes décisions.',
      duration: '4 min',
      rewardXp: 7,
      icon: Icons.menu_book_rounded,
      bulletPoints: [
        'Note le rationnel, l’horizon, le niveau de risque.',
        'Analyse régulièrement les biais récurrents.',
        'Associe chaque trade à un KPI émotionnel (stress, confiance).',
      ],
    ),
    _MiniLesson(
      id: 'lesson_esg_greenpremium',
      stageId: 'esg',
      title: 'Green premium',
      summary: 'Mesurer le surcoût des actifs verts.',
      duration: '5 min',
      rewardXp: 8,
      icon: Icons.energy_savings_leaf_rounded,
      bulletPoints: [
        'Comparer coûts de financement vert vs traditionnel.',
        'Évaluer l’impact sur marge brute et pricing power.',
        'Repérer les opportunités lorsque le green premium s’inverse.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_esg_supplychain',
      stageId: 'esg',
      title: 'Chaîne d’approvisionnement durable',
      summary: 'De la matière première au produit fini.',
      duration: '6 min',
      rewardXp: 9,
      icon: Icons.local_shipping_rounded,
      bulletPoints: [
        'Identifie les fournisseurs critiques et leur score ESG.',
        'Evalue le risque réglementaire par région.',
        'Intègre la traçabilité dans ton analyse de marge.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_derivatives_calendar',
      stageId: 'derivatives',
      title: 'Calendar spreads',
      summary: 'Jouer la courbe de volatilité.',
      duration: '6 min',
      rewardXp: 9,
      icon: Icons.timeline_rounded,
      bulletPoints: [
        'Acheter et vendre des options de maturités différentes.',
        'Profite d’une vol courte chère avant publication.',
        'Surveille theta pour éviter une érosion excessive.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_derivatives_tail',
      stageId: 'derivatives',
      title: 'Protection tail-risk',
      summary: 'Se couvrir contre les chocs extrêmes.',
      duration: '5 min',
      rewardXp: 8,
      icon: Icons.health_and_safety_rounded,
      bulletPoints: [
        'Utilise des puts OTM ou des spreads de catastrophe.',
        'Calcule le coût annuel vs probabilité d’occurrence.',
        'Diversifie les échéances pour lisser la prime.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_psy_routine',
      stageId: 'psychology',
      title: 'Routines d’apprentissage',
      summary: 'Ancre tes habitudes quotidiennes de Learn.',
      duration: '4 min',
      rewardXp: 7,
      icon: Icons.repeat_rounded,
      bulletPoints: [
        'Planifie un créneau fixe pour revoir tes quiz.',
        'Associe la session à un rituel (café, marche) pour tenir la cadence.',
        'Utilise des rappels pour ne pas casser ta série.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_psy_breathe',
      stageId: 'psychology',
      title: 'Micro-pauses conscientes',
      summary: 'Respire avant chaque décision clé.',
      duration: '4 min',
      rewardXp: 7,
      icon: Icons.air_rounded,
      bulletPoints: [
        'Applique une respiration 4-7-8 pour diminuer le stress.',
        'Pose-toi 3 questions : “Pourquoi ? Risque ? Horizon ?”.',
        'Reviens sur ta check-list plutôt que de cliquer impulsivement.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_fund_working_capital',
      stageId: 'fundamentals',
      title: 'Maîtriser le BFR',
      summary: 'Comprendre l’impact du besoin en fonds de roulement.',
      duration: '6 min',
      rewardXp: 9,
      icon: Icons.inventory_rounded,
      bulletPoints: [
        'BFR = stocks + créances − dettes fournisseurs.',
        'Un BFR qui explose consomme du cash, même avec un bénéfice positif.',
        'Compare le BFR/CA aux pairs pour détecter les dérapages.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_macro_policy',
      stageId: 'intuition',
      title: 'Lecture des communiqués banquiers centraux',
      summary: 'Repérer les signaux de changement de ton.',
      duration: '5 min',
      rewardXp: 8,
      icon: Icons.record_voice_over_rounded,
      bulletPoints: [
        'Traque les mots-clés (“vigile”, “patient”, “résolu”).',
        'Croise avec les projections de dot plots pour ajuster ton portefeuille.',
        'Regarde la réaction des taux et devises dans les minutes qui suivent.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_esg_disclosure',
      stageId: 'esg',
      title: 'CSRD & reporting extra-financier',
      summary: 'Prépare-toi aux nouvelles obligations européennes.',
      duration: '6 min',
      rewardXp: 9,
      icon: Icons.description_rounded,
      bulletPoints: [
        'Comprends les KPIs obligatoires (émissions, gouvernance).',
        'Vérifie la maturité des systèmes de collecte interne.',
        'Anticipe les coûts de conformité dans tes modèles.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_derivatives_skew',
      stageId: 'derivatives',
      title: 'Comprendre le skew',
      summary: 'Pourquoi les puts coûtent plus cher ?',
      duration: '5 min',
      rewardXp: 8,
      icon: Icons.show_chart_rounded,
      bulletPoints: [
        'Le skew mesure l’asymétrie de volatilité entre calls et puts.',
        'Marché craintif = skew plus pentu, cost of protection ↑.',
        'Utilise-le pour timer les couvertures ou vendre des spreads.',
      ],
    ),
    _MiniLesson(
      id: 'lesson_history_dotcom',
      stageId: 'history',
      title: 'Leçons du krach dotcom',
      summary: 'Croissance infinie vs fondamentaux.',
      duration: '5 min',
      rewardXp: 8,
      icon: Icons.history_rounded,
      bulletPoints: [
        'Rev-lag : croissance de revenus sans profits n’est pas durable.',
        'Importance de la valorisation relative (EV/ventes).',
        'Suivre la liquidité des introductions pour détecter la fin du cycle.',
      ],
    ),
  ];

  final List<_DailyChallenge> _challenges = const [
    _DailyChallenge(
      id: 'challenge_balance',
      stageId: 'fundamentals',
      title: 'Lecture de bilan',
      description: 'Classe les postes du bilan par solidité financière.',
      question: 'Quel indicateur confirme qu’un bilan est suffisamment solide pour absorber un choc ?',
      options: const [
        'Une dette nette supérieure aux capitaux propres',
        'Un ratio courant supérieur à 1,5',
        'Un BFR qui explose trimestre après trimestre',
        'Des stocks représentant 60% de l’actif',
      ],
      correctIndex: 1,
      rationale: 'Un ratio courant >1,5 signifie que les actifs court terme couvrent largement les dettes court terme.',
      rewardXp: 20,
      tag: 'Fondamental',
    ),
    _DailyChallenge(
      id: 'challenge_candles',
      stageId: 'technical',
      title: 'Chandeliers japonais',
      description: 'Identifie la force d’un marteau inversé sur le CAC 40.',
      question: 'Un marteau inversé sur support suivi d’une clôture verte impliquera le plus souvent…',
      options: const [
        'Une poursuite baissière automatique',
        'Un possible retournement si confirmé par volumes et clôture',
        'Une absence de signal, il faut shorter',
        'Un signal haussier garanti sans confirmation',
      ],
      correctIndex: 1,
      rationale: 'Le marteau inversé indique une tentative de reprise que l’on valide uniquement avec volume et clôture haussière.',
      rewardXp: 15,
      tag: 'Technique',
    ),
    _DailyChallenge(
      id: 'challenge_rates',
      stageId: 'intuition',
      title: 'Décision intuitive',
      description: 'Quelle serait ta réaction à une baisse surprise des taux ?',
      question: 'Quelle action privilégier après une baisse surprise des taux directeurs ?',
      options: const [
        'Vendre toutes les valeurs de croissance immédiatement',
        'Renforcer les valeurs longues durée (tech, immobilier coté)',
        'Couper les financières car les marges montent',
        'Passer 100% cash',
      ],
      correctIndex: 1,
      rationale: 'Les baisses de taux soutiennent les actifs à duration longue (growth, immobilier) qui bénéficient d’un coût du capital plus faible.',
      rewardXp: 25,
      tag: 'Intuition',
    ),
    _DailyChallenge(
      id: 'challenge_fx',
      stageId: 'intuition',
      title: 'Risque de change',
      description: 'Évalue l’impact d’un EUR/USD à 1.15 sur un portefeuille US.',
      question: 'Comment couvrir un portefeuille libellé en USD si EUR/USD monte à 1,15 ?',
      options: const [
        'Acheter des contrats futures EUR/USD pour neutraliser l’effet devise',
        'Renforcer les exportateurs européens sans couverture',
        'Convertir tout le portefeuille en euros immédiatemment',
        'Ignorer le mouvement car la devise ne bougera plus',
      ],
      correctIndex: 0,
      rationale: 'Une couverture via futures ou forwards sur EUR/USD neutralise l’écart de change sans liquider les positions actions.',
      rewardXp: 18,
      tag: 'Macro',
    ),
    _DailyChallenge(
      id: 'challenge_fcf',
      stageId: 'fundamentals',
      title: 'Flux de trésorerie',
      description: 'Analyse la capacité d’une valeur à couvrir ses dividendes par FCF.',
      question: 'Quel signal garantit le mieux qu’un dividende est soutenable ?',
      options: const [
        'Un payout ratio <70% calculé sur le free cash-flow',
        'Une croissance des stocks de 30%',
        'Une hausse de la dette court terme',
        'Un nombre de filiales en augmentation',
      ],
      correctIndex: 0,
      rationale: 'Quand le free cash-flow couvre largement le dividende, la distribution reste soutenable sans s’endetter.',
      rewardXp: 18,
      tag: 'Fondamental',
    ),
    _DailyChallenge(
      id: 'challenge_rotation',
      stageId: 'fundamentals',
      title: 'Rotation sectorielle',
      description: 'Réorganise une allocation après un changement de cycle (value vs growth).',
      question: 'Une rotation value > growth confirmée incite surtout à…',
      options: const [
        'Conserver uniquement les valeurs technologiques momentum',
        'Réallouer vers banques/énergie et alléger progressivement la croissance longue',
        'Passer entièrement en cash',
        'Renforcer les obligations long terme',
      ],
      correctIndex: 1,
      rationale: 'Une rotation value pousse à augmenter les secteurs cycliques bon marché et réduire l’exposition growth surpondérée.',
      rewardXp: 22,
      tag: 'Stratégie',
    ),
    _DailyChallenge(
      id: 'challenge_gap',
      stageId: 'technical',
      title: 'Gestion des gaps',
      description: 'Planifie une entrée quand un indice ouvre avec un gap >1.5%.',
      question: 'Sur un gap d’ouverture >1,5%, la meilleure discipline est…',
      options: const [
        'Entrer immédiatement en suivant le gap',
        'Attendre confirmation intraday (ex : clôture 30 min) et définir un stop',
        'Shorter automatiquement à l’ouverture',
        'Ignorer totalement le signal',
      ],
      correctIndex: 1,
      rationale: 'On laisse la volatilité initiale se calmer avant de définir un plan d’entrée avec stop pour éviter les faux signaux.',
      rewardXp: 16,
      tag: 'Technique',
    ),
    _DailyChallenge(
      id: 'challenge_vol',
      stageId: 'derivatives',
      title: 'Volatilité implicite',
      description: 'Explique comment la hausse de VIX modifie tes couvertures.',
      question: 'Un VIX qui bondit de 30% implique surtout…',
      options: const [
        'Des primes d’options moins chères',
        'La nécessité d’anticiper et calibrer les couvertures avant la flambée des primes',
        'Qu’il faut vendre toutes les protections existantes',
        'Que les marchés deviennent automatiquement haussiers',
      ],
      correctIndex: 1,
      rationale: 'Un VIX en hausse renchérit les primes : on verrouille les couvertures tôt ou on réduit leur taille pour tenir budget.',
      rewardXp: 19,
      tag: 'Options',
    ),
    _DailyChallenge(
      id: 'challenge_leverage',
      stageId: 'fundamentals',
      title: 'Dette nette/EBITDA',
      description: 'Classe plusieurs entreprises selon leur levier financier.',
      question: 'Un ratio dette nette / EBITDA de 4x indique…',
      options: const [
        'Une entreprise sans levier',
        'Un levier élevé nécessitant un suivi attentif',
        'Une trésorerie excédentaire',
        'Que l’entreprise ne verse pas de dividende',
      ],
      correctIndex: 1,
      rationale: 'Au-delà de 3-4x, le levier devient tendu : on surveille refinancement et covenants.',
      rewardXp: 17,
      tag: 'Fondamental',
    ),
    _DailyChallenge(
      id: 'challenge_esg',
      stageId: 'esg',
      title: 'Indices climatiques',
      description: 'Choisis quelles positions profiteront d’un accord COP 30 ambitieux.',
      question: 'Quel profil profite le plus d’un accord COP ambitieux ?',
      options: const [
        'Les utilities 100% charbon',
        'Les développeurs d’énergies renouvelables avec projets financés',
        'Les compagnies aériennes court-courrier',
        'Les raffineurs sans objectifs net zero',
      ],
      correctIndex: 1,
      rationale: 'Un accord ambitieux redirige les capitaux vers les acteurs renouvelables ayant déjà pipeline et financements verts.',
      rewardXp: 21,
      tag: 'ESG',
    ),
    _DailyChallenge(
      id: 'challenge_psy',
      stageId: 'psychology',
      title: 'Psychologie de marché',
      description: 'Décris ta réaction si un titre en portefeuille gagne +15% sur news.',
      question: 'Un titre en portefeuille prend +15% après news. Que faire ?',
      options: const [
        'Vendre immédiatement toute la position par peur de rendre le gain',
        'Suivre ta check-list (prise partielle, stop suiveur) alignée sur le plan initial',
        'Doubler la taille de position sans analyse',
        'Ne rien noter dans ton journal',
      ],
      correctIndex: 1,
      rationale: 'On suit le plan écrit : journal, prise partielle, ajustement du stop pour préserver la discipline émotionnelle.',
      rewardXp: 16,
      tag: 'Intuition',
    ),
    _DailyChallenge(
      id: 'challenge_book',
      stageId: 'technical',
      title: 'Lecture de carnet d’ordres',
      description: 'Interprète un déséquilibre entre bid/ask sur une small cap.',
      question: 'Si le carnet montre peu de bids et beaucoup d’asks empilés, cela signifie…',
      options: const [
        'Une pression vendeuse potentielle et une liquidité fragile',
        'Une certitude de hausse',
        'Un signal neutre sans conséquence',
        'Qu’il faut acheter massivement',
      ],
      correctIndex: 0,
      rationale: 'Un déséquilibre ask >> bid révèle un risque de débouclage rapide et une liquidité limitée : prudence sur l’exécution.',
      rewardXp: 15,
      tag: 'Microstructure',
    ),
  ];

List<_QuizCardData>? _cachedQuiz;
List<_QuizCardData>? _cachedChallengeQuiz;
List<_QuizCardData> get _quiz {
  _cachedQuiz ??= List.unmodifiable([
    ..._baseQuiz,
    ..._challengeQuiz,
    ..._buildGeneratedQuiz(),
  ]);
  return _cachedQuiz!;
}

List<_QuizCardData> get _challengeQuiz {
  _cachedChallengeQuiz ??= _challenges.map(_challengeToQuiz).toList(growable: false);
  return _cachedChallengeQuiz!;
}

_QuizCardData _challengeToQuiz(_DailyChallenge challenge) {
  return _QuizCardData(
    id: challenge.id,
    stageId: challenge.stageId,
    category: challenge.tag,
    rewardXp: challenge.rewardXp,
    question: challenge.question,
    options: challenge.options,
    correctIndex: challenge.correctIndex,
    explanation: challenge.rationale,
  );
}

static const List<_QuizCardData> _baseQuiz = [
    _QuizCardData(
      id: 'quiz_margin_drop',
      stageId: 'fundamentals',
      category: 'Fondamental',
      rewardXp: 15,
      question: 'Une marge opérationnelle qui passe de 18% à 10% indique…',
      options: const [
        'Une amélioration de la rentabilité',
        'Une baisse d’efficacité opérationnelle',
        'Un effet de levier positif',
        'Un changement de devise',
      ],
      correctIndex: 1,
      explanation: 'La marge opérationnelle mesure la capacité à générer du résultat avant charges financières. Une chute signale une efficacité moindre.',
    ),
    _QuizCardData(
      id: 'quiz_support_break',
      stageId: 'technical',
      category: 'Technique',
      rewardXp: 15,
      question: 'Quel signal donne la cassure d’un support majeur accompagnée d’un volume élevé ?',
      options: const [
        'Poursuite baissière probable',
        'Renversement haussier imminent',
        'Consolidation neutre',
        'Absence d’information exploitable',
      ],
      correctIndex: 0,
      explanation: 'La cassure d’un support clé sur volume valide souvent la poursuite du mouvement vendeur.',
    ),
    _QuizCardData(
      id: 'quiz_cash_cycle',
      stageId: 'fundamentals',
      category: 'Fondamental',
      rewardXp: 15,
      question: 'Quel indicateur suit la vitesse à laquelle une entreprise transforme ses stocks en cash ?',
      options: const [
        'Le beta',
        'Le cash conversion cycle',
        'Le ratio de distribution',
        'La duration obligataire',
      ],
      correctIndex: 1,
      explanation: 'Le cash conversion cycle mesure le nombre de jours nécessaires pour convertir les stocks en trésorerie après règlement fournisseurs.',
    ),
    _QuizCardData(
      id: 'quiz_event_cop',
      stageId: 'esg',
      category: 'ESG',
      rewardXp: 20,
      question: 'Avant la COP 30, quel facteur surveiller pour une major pétrolière ? ',
      options: const [
        'Le niveau de RSI à 14 périodes',
        'Les annonces de quotas carbone ou taxes sur le scope 3',
        'Le split action envisagé par la société',
        'Le taux de marge nette trimestrielle',
      ],
      correctIndex: 1,
      explanation: 'Les décisions sur les quotas carbone ou les taxes peuvent rogner les cash-flows futurs des énergéticiens.',
    ),
    _QuizCardData(
      id: 'quiz_dividend_cut',
      stageId: 'fundamentals',
      category: 'Fondamental',
      rewardXp: 15,
      question: 'Un payout ratio qui passe de 70% à 110% suggère…',
      options: const [
        'Une marge brute record',
        'Un dividende devenu supérieur au résultat net',
        'Un effet saisonnier normal',
        'Une inflation maîtrisée',
      ],
      correctIndex: 1,
      explanation: 'Au-delà de 100%, la société distribue plus que son bénéfice, ce qui n’est pas soutenable sans puiser dans la trésorerie.',
    ),
    _QuizCardData(
      id: 'quiz_rsi_extreme',
      stageId: 'technical',
      category: 'Technique',
      rewardXp: 15,
      question: 'RSI(14) à 78 sur une valeur en tendance haussière stable signifie…',
      options: const [
        'Un signal de survente',
        'Un momentum fort mais susceptible de corriger',
        'Une divergence haussière automatique',
        'Que le volume est nul',
      ],
      correctIndex: 1,
      explanation: 'Un RSI proche de 80 traduit un emballement haussier qui peut entraîner une respiration technique.',
    ),
    _QuizCardData(
      id: 'quiz_history_cds',
      stageId: 'history',
      category: 'Histoire',
      rewardXp: 20,
      question: 'Quelle crise a mis en lumière le rôle systémique des CDS ?',
      options: const [
        'Crise asiatique 1997',
        'Crise des subprimes 2008',
        'Crise de la dette grecque 2010',
        'Krach des dotcom 2000',
      ],
      correctIndex: 1,
      explanation: 'Les Credit Default Swaps sont devenus célèbres pendant la crise des subprimes, révélant l’interconnexion des banques.',
    ),
    _QuizCardData(
      id: 'quiz_inflation_surprise',
      stageId: 'intuition',
      category: 'Macro',
      rewardXp: 20,
      question: 'Une inflation réelle > consensus impacte un portefeuille growth en raison…',
      options: const [
        'D’une hausse probable des taux longs',
        'D’une baisse mécanique des volumes',
        'D’un split action imminent',
        'D’un rebond obligatoire du dollar',
      ],
      correctIndex: 0,
      explanation: 'Une inflation supérieure au consensus pousse les taux longs à la hausse et pénalise les valorisations de croissance.',
    ),
    _QuizCardData(
      id: 'quiz_capex_spike',
      stageId: 'fundamentals',
      category: 'Fondamental',
      rewardXp: 18,
      question: 'Une hausse subite des capex sans croissance du CA peut signifier…',
      options: [
        'Un investissement stratégique dilutif à court terme',
        'Une amélioration immédiate du ROE',
        'Une réduction automatique de la dette',
        'Une stabilité des flux',
      ],
      correctIndex: 0,
      explanation: 'Des capex massifs pèsent sur les flux avant d’apporter du retour, il faut vérifier la rentabilité future.',
    ),
    _QuizCardData(
      id: 'quiz_breakout_failure',
      stageId: 'technical',
      category: 'Technique',
      rewardXp: 18,
      question: 'Un faux breakout rapidement invalidé indique souvent…',
      options: [
        'Un piège haussier et un risque de correction',
        'Un signal haussier renforcé',
        'Un manque d’intérêt vendeurs',
        'Une absence de volatilité',
      ],
      correctIndex: 0,
      explanation: 'Les faux signaux démontrent l’épuisement des acheteurs et appellent à la prudence.',
    ),
    _QuizCardData(
      id: 'quiz_inverted_curve',
      stageId: 'intuition',
      category: 'Macro',
      rewardXp: 18,
      question: 'Une courbe des taux inversée reflète surtout…',
      options: [
        'Des attentes de ralentissement et de futures baisses de taux',
        'Un choc inflationniste',
        'Un dollar faible',
        'Une hausse des matières premières',
      ],
      correctIndex: 0,
      explanation: 'Les investisseurs anticipent une baisse des taux courts quand la croissance ralentit.',
    ),
    _QuizCardData(
      id: 'quiz_drawdown_control',
      stageId: 'psychology',
      category: 'Gestion',
      rewardXp: 17,
      question: 'Quel indicateur suit la profondeur maximale d’une baisse ?',
      options: [
        'Le max drawdown',
        'La marge brute',
        'Le rendement annualisé',
        'Le free cash-flow',
      ],
      correctIndex: 0,
      explanation: 'Le max drawdown mesure la perte maximale entre un sommet et un creux.',
    ),
    _QuizCardData(
      id: 'quiz_rate_cut',
      stageId: 'intuition',
      category: 'Macro',
      rewardXp: 20,
      question: 'Une baisse surprise des taux directeurs favorise principalement…',
      options: [
        'Les valeurs de croissance à duration longue',
        'Les matières premières',
        'Les obligations indexées inflation',
        'Les devises refuges',
      ],
      correctIndex: 0,
      explanation: 'Un coût du capital inférieur revalorise les flux lointains (tech, immobilier coté, growth).',
    ),
    _QuizCardData(
      id: 'quiz_earnings_surprise',
      stageId: 'fundamentals',
      category: 'Résultats',
      rewardXp: 18,
      question: 'Pour valider un “beat” sur EPS tu dois vérifier…',
      options: [
        'Que les ventes et marges progressent aussi',
        'Que le flottant augmente',
        'Que la société annonce un split',
        'Que le beta diminue',
      ],
      correctIndex: 0,
      explanation: 'Un beat reposant uniquement sur le nombre d’actions n’est pas durable.',
    ),
    _QuizCardData(
      id: 'quiz_split_history',
      stageId: 'history',
      category: 'Histoire',
      rewardXp: 18,
      question: 'Le krach de 1987 a révélé…',
      options: [
        'Les limites du trading programmé',
        'Un excès d’inflation',
        'Une crise pétrolière',
        'La création des ETF',
      ],
      correctIndex: 0,
      explanation: 'Le “Lundi noir” a montré l’effet amplificateur des stratégies dynamiques de couverture.',
    ),
    _QuizCardData(
      id: 'quiz_eps_dilution',
      stageId: 'fundamentals',
      category: 'Fondamental',
      rewardXp: 15,
      question: 'Une forte augmentation du flottant provoque…',
      options: [
        'Une dilution du bénéfice par action',
        'Une hausse immédiate de la marge nette',
        'Une baisse automatique du levier',
        'Un rendement obligataire plus faible',
      ],
      correctIndex: 0,
      explanation: 'Plus d’actions en circulation divisent le BPA si le résultat reste stable.',
    ),
    _QuizCardData(
      id: 'quiz_volume_climax',
      stageId: 'technical',
      category: 'Technique',
      rewardXp: 16,
      question: 'Un climax de volume proche d’un sommet peut signifier…',
      options: [
        'La fin probable du mouvement haussier',
        'Un nouveau rallye assuré',
        'Une volatilité nulle',
        'Un signal de survente',
      ],
      correctIndex: 0,
      explanation: 'Un volume record après une longue hausse traduit une distribution.',
    ),
    _QuizCardData(
      id: 'quiz_credit_spread',
      stageId: 'derivatives',
      category: 'Macro',
      rewardXp: 18,
      question: 'Des spreads high yield qui s’élargissent rapidement indiquent…',
      options: [
        'Une prime de risque croissante et un stress sur les sociétés fragiles',
        'Une envolée des cycliques',
        'Un flux massif vers les small caps',
        'Une hausse certaine des dividendes',
      ],
      correctIndex: 0,
      explanation: 'L’élargissement des spreads suggère que le marché exige plus de rendement pour compenser un risque perçu.',
    ),
    _QuizCardData(
      id: 'quiz_buyback_vs_dividend',
      stageId: 'fundamentals',
      category: 'Allocation',
      rewardXp: 17,
      question: 'Quand un rachat d’actions crée-t-il plus de valeur qu’un dividende ?',
      options: [
        'Quand l’action se traite sous sa valeur intrinsèque et que la dette reste maîtrisée',
        'Quand le payout dépasse 100%',
        'Quand la volatilité est nulle',
        'Quand la société n’a plus de cash',
      ],
      correctIndex: 0,
      explanation: 'Les rachats sont pertinents lorsque le titre est décoté et que la structure financière est saine.',
    ),
    _QuizCardData(
      id: 'quiz_bollinger_squeeze',
      stageId: 'technical',
      category: 'Technique',
      rewardXp: 16,
      question: 'Un “squeeze” sur les bandes de Bollinger annonce…',
      options: [
        'Une phase de volatilité accrue imminente',
        'Une chute certaine',
        'Une absence de signal',
        'La fin définitive de la tendance',
      ],
      correctIndex: 0,
      explanation: 'Le resserrement des bandes précède souvent une expansion de volatilité.',
    ),
    _QuizCardData(
      id: 'quiz_liquidity_trap',
      stageId: 'history',
      category: 'Histoire',
      rewardXp: 18,
      question: 'Le Japon des années 90 illustre…',
      options: [
        'Une trappe à liquidité et la difficulté à réamorcer le crédit',
        'Une hyperinflation',
        'Une crise énergétique',
        'Un choc de devises',
      ],
      correctIndex: 0,
      explanation: 'Malgré des taux bas, l’économie est restée engluée dans la déflation et l’endettement.',
    ),
    _QuizCardData(
      id: 'quiz_real_rate',
      stageId: 'intuition',
      category: 'Macro',
      rewardXp: 19,
      question: 'Des taux réels durablement positifs pénalisent surtout…',
      options: [
        'Les valeurs de croissance à flux lointains',
        'Les banques de détail',
        'Les minières',
        'Les utilities régulées',
      ],
      correctIndex: 0,
      explanation: 'Des taux réels plus élevés réduisent la valeur actualisée des profits futurs.',
    ),
    _QuizCardData(
      id: 'quiz_drawdown_psy',
      stageId: 'psychology',
      category: 'Psychologie',
      rewardXp: 17,
      question: 'Quel réflexe aide à éviter les ventes paniques ?',
      options: [
        'Avoir un plan écrit avec seuils de perte',
        'Multiplier les notifications news',
        'Retirer tous les stops',
        'Doubler chaque position perdante',
      ],
      correctIndex: 0,
      explanation: 'Un plan défini à froid limite les biais émotionnels en période de stress.',
    ),
    _QuizCardData(
      id: 'quiz_vix_spike',
      stageId: 'derivatives',
      category: 'Dérivés',
      rewardXp: 18,
      question: 'VIX>35 signifie…',
      options: [
        'Une volatilité implicite très élevée et des options coûteuses',
        'Un marché calme',
        'Une baisse du beta',
        'Une hausse automatique des dividendes',
      ],
      correctIndex: 0,
      explanation: 'Un VIX élevé reflète des primes de risque dominantes et nécessite des couvertures calibrées.',
    ),
    _QuizCardData(
      id: 'quiz_esg_transition',
      stageId: 'esg',
      category: 'ESG',
      rewardXp: 18,
      question: 'Quel indicateur suivre pour une entreprise alignée sur la transition ?',
      options: [
        'Le % du CAPEX dédié aux projets bas carbone',
        'La couleur du logo',
        'Le nombre de divisions',
        'Le ratio prix/valeur comptable uniquement',
      ],
      correctIndex: 0,
      explanation: 'Le CAPEX vert reflète l’effort réel de transition énergétique.',
    ),
    _QuizCardData(
      id: 'quiz_psy_biais',
      stageId: 'psychology',
      category: 'Psychologie',
      rewardXp: 17,
      question: 'Quel biais pousse à renforcer une position perdante pour “se refaire” ?',
      options: [
        'Biais de disposition',
        'Effet d’ancrage',
        'Effet d’endowment',
        'Biais de récence',
      ],
      correctIndex: 0,
      explanation: 'Le biais de disposition incite à couper les gagnants trop tôt et garder/renforcer les perdants.',
    ),
    _QuizCardData(
      id: 'quiz_carbon_price',
      stageId: 'esg',
      category: 'ESG',
      rewardXp: 18,
      question: 'Une hausse soutenue du prix du carbone impacte surtout…',
      options: [
        'Les industries intensives en scope 1/2',
        'Les sociétés de logiciels',
        'Les banques de détail',
        'Les REIT logistiques',
      ],
      correctIndex: 0,
      explanation: 'Plus l’empreinte directe est élevée, plus la facture carbone pèse sur les marges.',
    ),
    _QuizCardData(
      id: 'quiz_collar',
      stageId: 'derivatives',
      category: 'Dérivés',
      rewardXp: 18,
      question: 'Un collar protecteur consiste à…',
      options: [
        'Acheter un put et vendre un call sur la même ligne',
        'Acheter deux calls',
        'Vendre des futures uniquement',
        'Acheter un straddle',
      ],
      correctIndex: 0,
      explanation: 'Le collar verrouille un range : put pour le plancher, call couvert pour financer la prime.',
    ),
    _QuizCardData(
      id: 'quiz_working_cap',
      stageId: 'fundamentals',
      category: 'Fondamental',
      rewardXp: 17,
      question: 'Un BFR qui augmente plus vite que le CA peut impliquer…',
      options: [
        'Une consommation de trésorerie et un risque de financement',
        'Une hausse automatique du ROE',
        'Une baisse des stocks',
        'Un effet neutre',
      ],
      correctIndex: 0,
      explanation: 'Si le besoin en fonds de roulement explose, l’entreprise brûle du cash malgré un bénéfice positif.',
    ),
    _QuizCardData(
      id: 'quiz_vol_smile',
      stageId: 'derivatives',
      category: 'Dérivés',
      rewardXp: 18,
      question: 'Un “smile” de volatilité plat indique…',
      options: [
        'Une perception symétrique des risques haussiers/baissiers',
        'Une forte peur de baisse uniquement',
        'Une absence totale de volatilité',
        'Un marché fermé',
      ],
      correctIndex: 0,
      explanation: 'Quand la vol implicite est uniforme, le marché ne privilégie pas une direction ; utile pour straddle neutre.',
    ),
    _QuizCardData(
      id: 'quiz_psy_overtrade',
      stageId: 'psychology',
      category: 'Psychologie',
      rewardXp: 17,
      question: 'Quel signal montre que tu over-trades après une série gagnante ?',
      options: [
        'Augmenter la taille des positions sans mise à jour du plan',
        'Réduire ton risque par trade',
        'Revoir ton journal',
        'Faire une pause planifiée',
      ],
      correctIndex: 0,
      explanation: 'L’excès de confiance pousse à prendre plus de risque alors que ton plan ne change pas.',
    ),
    _QuizCardData(
      id: 'quiz_csrd',
      stageId: 'esg',
      category: 'ESG',
      rewardXp: 18,
      question: 'La directive CSRD impose notamment…',
      options: [
        'Un reporting extra-financier standardisé pour de nombreuses sociétés européennes',
        'La suppression des dividendes',
        'Un taux d’IS unique',
        'La fermeture des sites pollués sous 6 mois',
      ],
      correctIndex: 0,
      explanation: 'CSRD étend le champ de la transparence ESG avec des KPIs précis.',
    ),
    _QuizCardData(
      id: 'quiz_macro_tone',
      stageId: 'intuition',
      category: 'Macro',
      rewardXp: 18,
      question: 'Le passage d’un ton “hawkish” à “data dependent” signale…',
      options: [
        'Une banque centrale prête à réagir aux prochains chiffres plutôt qu’à monter automatiquement',
        'Une hausse automatique des taux',
        'Une sortie de récession',
        'Une absence de communication',
      ],
      correctIndex: 0,
      explanation: 'Cela prépare le marché à plus de flexibilité et peut réduire la volatilité si les données coopèrent.',
    ),
    _QuizCardData(
      id: 'quiz_tail_protect',
      stageId: 'derivatives',
      category: 'Dérivés',
      rewardXp: 18,
      question: 'Pour se protéger d’un choc extrême à faible probabilité tu peux…',
      options: [
        'Acheter des puts très hors de la monnaie',
        'Vendre des calls couverts uniquement',
        'Augmenter ton levier',
        'Ignorer la volatilité',
      ],
      correctIndex: 0,
      explanation: 'Les puts OTM servent de police d’assurance contre les “tail events”.',
    ),
    _QuizCardData(
      id: 'quiz_psy_riskplan',
      stageId: 'psychology',
      category: 'Psychologie',
      rewardXp: 17,
      question: 'Quel élément doit figurer dans un plan de gestion du risque ?',
      options: [
        'Un pourcentage max de perte par trade',
        'Le nombre de followers sur les réseaux',
        'La couleur des bougies',
        'Le montant de dividendes souhaité',
      ],
      correctIndex: 0,
      explanation: 'Limiter la perte par trade garantit que ta série négative reste contrôlée.',
    ),
    _QuizCardData(
      id: 'quiz_green_bonds',
      stageId: 'esg',
      category: 'ESG',
      rewardXp: 18,
      question: 'Un green bond crédible implique…',
      options: [
        'Un usage des fonds strictement lié à des projets verts vérifiables',
        'Un taux plus élevé sans contraintes',
        'Une absence de reporting',
        'Un rating crédit automatique AAA',
      ],
      correctIndex: 0,
      explanation: 'Les green bonds exigent traçabilité et reporting pour conserver le label.',
    ),
    _QuizCardData(
      id: 'quiz_vol_regime',
      stageId: 'derivatives',
      category: 'Dérivés',
      rewardXp: 18,
      question: 'Passer d’un régime de vol basse à haute signifie…',
      options: [
        'Adapter la taille des positions/options au nouveau niveau de risque',
        'Ignorer la var',
        'Supprimer les hedges',
        'Ne rien changer',
      ],
      correctIndex: 0,
      explanation: 'Changer de régime de volatilité impose d’ajuster marges, stops et prix des options.',
    ),
    _QuizCardData(
      id: 'quiz_macro_supply',
      stageId: 'intuition',
      category: 'Macro',
      rewardXp: 18,
      question: 'Des goulets d’étranglement logistiques prolongés peuvent provoquer…',
      options: [
        'Une inflation persistante liée à l’offre',
        'Une baisse automatique des taux',
        'Une diminution des exportations énergétiques uniquement',
        'Une appréciation monétaire certaine',
      ],
      correctIndex: 0,
      explanation: 'Quand l’offre reste contrainte, les prix montent malgré la demande stable.',
    ),
    _QuizCardData(
      id: 'quiz_psy_breaks',
      stageId: 'psychology',
      category: 'Psychologie',
      rewardXp: 16,
      question: 'Pourquoi programmer des pauses régulières ?',
      options: [
        'Pour réduire la fatigue décisionnelle et garder la lucidité',
        'Pour suivre plus de news',
        'Pour augmenter ton levier',
        'Pour ignorer ton plan',
      ],
      correctIndex: 0,
      explanation: 'Des pauses courtes empêchent l’over-trading et améliorent la qualité des décisions.',
    ),
  ];

List<_PortfolioScenario>? _cachedScenarios;
List<_PortfolioScenario> get _scenarios {
  _cachedScenarios ??= List.unmodifiable([
    ..._baseScenarios,
    ..._buildGeneratedScenarios(),
  ]);
  return _cachedScenarios!;
}

static const List<_PortfolioScenario> _baseScenarios = [
    _PortfolioScenario(
      id: 'scenario_green_energy',
      title: 'Portefeuille énergie verte',
      description: '50 k€ répartis sur 3 ETF propres et 2 valeurs climat. Hausse de 20% du pétrole : comment sécurises-tu la performance ? ',
      focus: 'Transition',
      risk: 'Volatilité élevée',
      stageId: 'intuition',
      rewardXp: 18,
      prompts: [
        'Réévalue l’arbitrage entre pure players et majors hybrides.',
        'Couverture possible via ventes à terme ou ETF inverse énergie classique.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_defensive',
      title: 'Allocation défensive',
      description: '25 k€ mêlant dividendes aristocrates et cash. Un secteur défensif perd -8% en 2 semaines.',
      focus: 'Income',
      risk: 'Risque modéré',
      stageId: 'fundamentals',
      rewardXp: 16,
      prompts: [
        'Tes dividendes sont-ils couverts par les cash-flows ?',
        'Faut-il renforcer ou conserver du cash pour d’éventuelles opportunités ?',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_growth',
      title: 'Hypercroissance en repli',
      description: 'Portefeuille fictif 40 k€ orienté SaaS. Le Nasdaq décroche -12% après guidance prudente d’un leader.',
      focus: 'Croissance',
      risk: 'Elevé',
      stageId: 'technical',
      rewardXp: 18,
      prompts: [
        'Identifier les zones techniques clefs pour renforcer.',
        'Réduire ou couvrir les positions beta>1 via options/ETF inverses.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_emerging',
      title: 'Marchés émergents',
      description: 'Allocation Asie 30 k€. Une banque centrale surprise par une dévaluation.',
      focus: 'Macro',
      risk: 'FX',
      stageId: 'intuition',
      rewardXp: 20,
      prompts: [
        'Gérer le risque devise (couverture, diversification multi-zone).',
        'Prioriser les sociétés exportatrices vs. importatrices nettes.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_luxury',
      title: 'Avertissement luxe',
      description: 'Résultats Richemont en retard, craintes sur la demande chinoise.',
      focus: 'Secteur',
      risk: 'Sentiment',
      stageId: 'history',
      rewardXp: 17,
      prompts: [
        'Comparer les multiples vs. historique post-avertissement (2015/2020).',
        'Alléger les valeurs les plus exposées à l’Asie avant réaction du marché.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_rate_cut',
      title: 'Baisse surprise des taux',
      description: 'La banque centrale réduit ses taux de 50 pb vs +25 attendu.',
      focus: 'Macro',
      risk: 'Repricing',
      stageId: 'psychology',
      rewardXp: 18,
      prompts: [
        'Quels secteurs renforcer (growth, immobilier, high beta) ?',
        'Comment hedger une hausse possible des devises refuges ?',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_vol_spike',
      title: 'Volatilité en explosion',
      description: 'VIX > 35, rotation brutale vers les valeurs défensives.',
      focus: 'Risque',
      risk: 'Gamma',
      stageId: 'derivatives',
      rewardXp: 17,
      prompts: [
        'Réduire l’exposition beta, augmenter cash/hedge options.',
        'Identifier les lignes à alléger vs conserver (pricing power).',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_high_yield',
      title: 'Stress crédit high yield',
      description: 'Les spreads HY s’écartent de 150 pb en 10 jours.',
      focus: 'Crédit',
      risk: 'Default',
      stageId: 'derivatives',
      rewardXp: 19,
      prompts: [
        'Réévalue les sociétés les plus endettées de ton portefeuille.',
        'Réduis la dette nette via arbitrages cross-sectoriels.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_emerging_fx',
      title: 'Dévaluation émergente',
      description: 'Une devise EM chute de 12% en une semaine.',
      focus: 'FX',
      risk: 'Devises',
      stageId: 'psychology',
      rewardXp: 18,
      prompts: [
        'Couvrir l’exposition via forwards ou ETF multi-devises.',
        'Favoriser les exportateurs nets vs importateurs dépendants.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_energy_shock',
      title: 'Choc énergétique',
      description: 'Le pétrole bondit à 120\$ suite à une tension géopolitique.',
      focus: 'Commodities',
      risk: 'Inflation',
      stageId: 'esg',
      rewardXp: 19,
      prompts: [
        'Surpondérer les producteurs intégrés, couvrir les secteurs énergivores.',
        'Analyser l’impact sur les marges des industries consommatrices de pétrole.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_covid_crash',
      title: 'COVID-19 mars 2020',
      description: 'Krach brutal puis rebond partiel grâce aux plans monétaires.',
      focus: 'Histoire',
      risk: 'Volatilité extrême',
      stageId: 'history',
      rewardXp: 20,
      prompts: [
        'Décide quand renforcer vs. rester liquide.',
        'Compare indices larges, tech et énergie au plus fort du stress.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_taper',
      title: 'Taper tantrum',
      description: 'Remontée rapide des taux longs, tech et EM sous pression.',
      focus: 'Macro',
      risk: 'Taux longs',
      stageId: 'intuition',
      rewardXp: 18,
      prompts: [
        'Rééquilibre croissance/valeur quand les taux réels montent.',
        'Couvre la duration longue ou réduis les obligations longues.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_usd_spike',
      title: 'Dollar qui s’envole',
      description: 'Le DXY grimpe, les matières premières et EM vacillent.',
      focus: 'FX',
      risk: 'Devise',
      stageId: 'psychology',
      rewardXp: 17,
      prompts: [
        'Favorise les exportateurs US, couvre l’EM via USD.',
        'Arbitre or vs USD fort et matières premières.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_ai_craze',
      title: 'Bull tech IA',
      description: 'Rotation violente vers l’IA, valorisations sous tension.',
      focus: 'Tech',
      risk: 'Ebullition',
      stageId: 'technical',
      rewardXp: 18,
      prompts: [
        'Dose l’exposition aux semi/Nvidia/Cloud vs cash/defensifs.',
        'Planifie prises de profits progressives et stops larges.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_europe_gas',
      title: 'Choc gaz Europe',
      description: 'Explosion des prix du gaz, industrie EU sous pression.',
      focus: 'Commodities',
      risk: 'Coût énergie',
      stageId: 'esg',
      rewardXp: 18,
      prompts: [
        'Comparer exposés (chimie, sidérurgie) vs gagnants (utilities régulées, LNG).',
        'Décider combien garder en cash pour amortir la vol.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_psy_drawdown',
      title: 'Séquence de pertes',
      description: 'Ton portefeuille enregistre -12% en 3 semaines sans news majeures.',
      focus: 'Discipline',
      risk: 'Biais',
      stageId: 'psychology',
      rewardXp: 18,
      prompts: [
        'Revois ton plan de risques et tes stops.',
        'Décide d’un gel temporaire des entrées pour retrouver de la clarté.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_esg_regulation',
      title: 'Nouvelle régulation carbone',
      description: 'L’Europe annonce un durcissement des quotas CO₂.',
      focus: 'ESG',
      risk: 'Réglementaire',
      stageId: 'esg',
      rewardXp: 18,
      prompts: [
        'Identifier les sociétés pénalisées (scope 3 élevé).',
        'Favoriser celles qui investissent déjà dans des technologies propres.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_derivatives_gamma',
      title: 'Gamma squeeze',
      description: 'Un titre shorté voit son gamma exploser à la hausse.',
      focus: 'Dérivés',
      risk: 'Gamma',
      stageId: 'derivatives',
      rewardXp: 19,
      prompts: [
        'Ajuster la couverture pour éviter de sur-réagir aux mouvements extrêmes.',
        'Utiliser options ou futures pour capter/contrer l’explosion de volatilité.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_psy_euphoria',
      title: 'Euphorie généralisée',
      description: 'Ton portefeuille grimpe de 18% en un mois, tentation d’augmenter la taille.',
      focus: 'Psychologie',
      risk: 'Excès de confiance',
      stageId: 'psychology',
      rewardXp: 17,
      prompts: [
        'Respecter le plan de risques malgré la hausse.',
        'Prendre des profits partiels et remonter les stops.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_esg_hydrogen',
      title: 'Boom hydrogène',
      description: 'Les subventions H2 sont doublées, rotation vers les valeurs green.',
      focus: 'ESG',
      risk: 'Execution',
      stageId: 'esg',
      rewardXp: 17,
      prompts: [
        'Identifier les gagnants avec capex réellement financé.',
        'Eviter les “greenwashing” qui ne profitent pas du plan.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_psy_burnout',
      title: 'Fatigue décisionnelle',
      description: 'Après 20 trades en deux jours, tu dois décider de nouvelles entrées.',
      focus: 'Psychologie',
      risk: 'Sur-trading',
      stageId: 'psychology',
      rewardXp: 16,
      prompts: [
        'Impose-toi un “cooldown” avant de reprendre les décisions.',
        'Revois ton journal pour valider que ton edge est toujours présent.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_derivatives_volcrush',
      title: 'Volatilité qui s’effondre',
      description: 'Après une grosse annonce, la vol implicite retombe de 10 points.',
      focus: 'Dérivés',
      risk: 'Vol crush',
      stageId: 'derivatives',
      rewardXp: 18,
      prompts: [
        'Fermer rapidement les straddles achetés qui perdent de la valeur.',
        'Basculer sur des stratégies vendeuses de vol si le contexte reste calme.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_macro_policy',
      title: 'Choc de politique économique',
      description: 'Un gouvernement annonce un plan fiscal massif non anticipé.',
      focus: 'Macro',
      risk: 'Budgetaire',
      stageId: 'intuition',
      rewardXp: 18,
      prompts: [
        'Réévaluer les secteurs gagnants (construction, énergie) et perdants (banques).',
        'Adapter tes couvertures taux/dette selon le profil de financement.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_working_cap',
      title: 'Tension BFR',
      description: 'Une société de ton portefeuille annonce une hausse brutale de son BFR.',
      focus: 'Fondamental',
      risk: 'Liquidité',
      stageId: 'fundamentals',
      rewardXp: 17,
      prompts: [
        'Analyser si la hausse vient des stocks ou des créances.',
        'Décider d’un allègement en attendant un financement long terme.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_esg_divest',
      title: 'Désinvestissement ESG',
      description: 'Plusieurs fonds annoncent sortir d’un secteur à forte empreinte.',
      focus: 'ESG',
      risk: 'Flux',
      stageId: 'esg',
      rewardXp: 18,
      prompts: [
        'Identifier les valeurs les plus exposées aux ventes forcées.',
        'Chercher les gagnants potentiels (solutions de substitution).',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_psy_news',
      title: 'Cascade de news contradictoires',
      description: 'En 24h, trois rumeurs opposées sortent sur la même entreprise.',
      focus: 'Psychologie',
      risk: 'FOMO/FUD',
      stageId: 'psychology',
      rewardXp: 16,
      prompts: [
        'Revenir aux fondamentaux et attendre une confirmation officielle.',
        'Limiter la taille d’une éventuelle position jusqu’à clarification.',
      ],
    ),
    _PortfolioScenario(
      id: 'scenario_derivatives_roll',
      title: 'Roll de couverture',
      description: 'Tes puts arrivent à échéance alors que la menace persiste.',
      focus: 'Dérivés',
      risk: 'Rollover',
      stageId: 'derivatives',
      rewardXp: 18,
      prompts: [
        'Décider de rouler les puts plus loin ou d’opter pour un collar.',
        'Calibrer la taille pour tenir compte du coût actuel de la vol.',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    _questionCtrl.addListener(() {
      final page = _questionCtrl.page;
      if (page != null && page.round() != _currentQuestion) {
        setState(() => _currentQuestion = page.round());
      }
    });

    _loadProgress();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _pulseCtrl.dispose();
    _heartTicker?.cancel();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _progress = null;
        _loadingProgress = false;
      });
      return;
    }
    setState(() {
      _loadingProgress = true;
      _progressError = null;
    });
    try {
      final data = await LearningProgressService.loadProgress(user.uid);
      if (!mounted) return;
      setState(() {
        _applyProgressLocally(data);
        _loadingProgress = false;
      });
      _startHeartTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progressError = 'Impossible de charger ta progression pour le moment.';
        _loadingProgress = false;
      });
    }
  }

  LearningProgress _normalizeProgress(LearningProgress progress) {
    final normalizedChallenges = progress.completedChallengeIds.map(_baseChallengeId).toSet();
    if (normalizedChallenges.isEmpty) return progress;
    final mergedQuiz = Set<String>.from(progress.completedQuizIds)..addAll(normalizedChallenges);
    if (mergedQuiz.length == progress.completedQuizIds.length) {
      return progress;
    }
    return progress.copyWith(completedQuizIds: mergedQuiz);
  }

  String _baseChallengeId(String challengeInstanceId) {
    final match = RegExp(r'^(.*)_\d{8}$').firstMatch(challengeInstanceId);
    return match != null ? match.group(1)! : challengeInstanceId;
  }

  void _applyProgressLocally(LearningProgress progress) {
    final sanitized = progress.copyWith(
      gems: _safeGems(progress),
      lastGemStreak: _safeLastGemStreak(progress),
    );
    final normalized = _normalizeProgress(progress);
    final existingSelections = Map<String, int>.from(_selectedAnswers);
    _selectedAnswers
      ..clear()
      ..addAll(existingSelections)
      ..addEntries(
        _quiz
            .where((q) => normalized.completedQuizIds.contains(q.id))
            .map((q) => MapEntry(q.id, q.correctIndex)),
      );
    _validatedQuestions
      ..removeWhere((id) => !normalized.completedQuizIds.contains(id));
    _progress = normalized.copyWith(
      gems: sanitized.gems,
      lastGemStreak: sanitized.lastGemStreak,
    );
    final dayKey = _todayKey();
    final shouldRefreshQuiz = _quizSeedDay == null || _quizSeedDay != dayKey || _activeQuiz.isEmpty;
    if (shouldRefreshQuiz) {
      _activeQuiz = _buildDailyQuizSet(normalized, seedDate: dayKey);
      _quizSeedDay = dayKey;
      _revealedQuiz.clear();
      _awaitingReveal.clear();
      _correctlyAnsweredQuiz.clear();
      _currentQuestion = 0;
      if (_questionCtrl.hasClients) {
        _questionCtrl.jumpToPage(0);
      }
    } else {
      _currentQuestion = _activeQuiz.isEmpty ? 0 : math.min(_currentQuestion, _activeQuiz.length - 1);
    }
    _quizSeedDay ??= dayKey;
    final activeIds = _activeQuiz.map((q) => q.id).toSet();
    _selectedAnswers.removeWhere((key, _) => !activeIds.contains(key));
    _awaitingReveal.removeWhere((id) => !activeIds.contains(id));
    _revealedQuiz.removeWhere((id) => !activeIds.contains(id));
    _correctlyAnsweredQuiz.removeWhere((id) => !activeIds.contains(id));
    _updateHeartCountdown();
  }

  int _maxLessonsPerDay(LearningProgress progress) => _freeLessonsPerDay + progress.lessonTickets;
  int _maxQuizPerDay(LearningProgress progress) => _freeQuizzesPerDay + progress.quizTickets;
  int _maxScenariosPerDay(LearningProgress progress) => _freeScenariosPerDay + progress.scenarioTickets;

  bool _hasLessonAllowance(LearningProgress progress) => progress.lessonsDoneToday < _maxLessonsPerDay(progress);
  bool _hasQuizAllowance(LearningProgress progress) => progress.quizDoneToday < _maxQuizPerDay(progress);
  bool _hasScenarioAllowance(LearningProgress progress) => progress.scenariosDoneToday < _maxScenariosPerDay(progress);

  int _suggestStake(LearningProgress progress) {
    if (progress.coins <= _minScenarioStake) return progress.coins;
    final target = (progress.coins * 0.18).round();
    return target.clamp(_minScenarioStake, _maxScenarioStake);
  }

  Future<void> _unlockWithAd(_AdUnlockType type) async {
    final progress = _progress;
    if (progress == null || _adLoading[type] == true) return;
    bool alreadyMaxed = false;
    switch (type) {
      case _AdUnlockType.lesson:
        alreadyMaxed = progress.lessonTickets >= _maxLessonTickets;
        break;
      case _AdUnlockType.quiz:
        alreadyMaxed = progress.quizTickets >= _maxQuizTickets;
        break;
      case _AdUnlockType.scenario:
        alreadyMaxed = progress.scenarioTickets >= _maxScenarioTickets;
        break;
      case _AdUnlockType.coins:
        alreadyMaxed = false;
        break;
    }
    if (alreadyMaxed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite de pubs atteinte pour aujourd’hui.')),
      );
      return;
    }
    setState(() {
      _adLoading[type] = true;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    LearningProgress updated = progress;
    switch (type) {
      case _AdUnlockType.lesson:
        updated = updated.copyWith(lessonTickets: updated.lessonTickets + 1);
        break;
      case _AdUnlockType.quiz:
        updated = updated.copyWith(quizTickets: updated.quizTickets + 1);
        break;
      case _AdUnlockType.scenario:
        updated = updated.copyWith(scenarioTickets: updated.scenarioTickets + 1);
        break;
      case _AdUnlockType.coins:
        updated = updated.copyWith(coins: updated.coins + _adCoinBoost);
        break;
    }
    await _persistProgress(updated);
    if (!mounted) return;
    setState(() {
      _adLoading[type] = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          type == _AdUnlockType.coins ? '+$_adCoinBoost coins ajoutés' : '+1 slot débloqué via pub',
        ),
      ),
    );
  }

  LearningProgress _adjustCoins(LearningProgress progress, int delta) {
    final next = math.max(0, progress.coins + delta);
    return progress.copyWith(coins: next);
  }

  void _startHeartTicker() {
    _heartTicker?.cancel();
    _heartTicker = Timer.periodic(const Duration(seconds: 1), (_) => _updateHeartCountdown());
    _updateHeartCountdown();
  }

  void _updateHeartCountdown() {
    final progress = _progress;
    if (!mounted) return;
    if (progress == null || progress.hearts >= LearningProgress.defaultHearts) {
      if (_heartCountdownText != null) {
        setState(() => _heartCountdownText = null);
      }
      return;
    }
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    final diff = next.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;
    final formatted = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    if (_heartCountdownText != formatted) {
      setState(() => _heartCountdownText = formatted);
    }
  }

  void _promptUnlock(_AdUnlockType type, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Limite $label atteinte pour aujourd’hui.'),
        action: SnackBarAction(label: 'Pub +1', onPressed: () => _unlockWithAd(type)),
      ),
    );
  }

  Future<void> _persistProgress(LearningProgress updated) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _applyProgressLocally(updated);
    });
    await LearningProgressService.saveProgress(user.uid, updated);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildGuestState();
    }
    if (_loadingProgress) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_progressError != null) {
      return _buildErrorState();
    }
    final progress = _progress;
    if (progress == null) {
      return _buildErrorState();
    }

    return Container(
      color: _learnBg,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntro(progress),
                    const SizedBox(height: 16),
                    _buildDailyCaps(progress),
                    const SizedBox(height: 16),
                    _buildProgressCard(progress),
                    const SizedBox(height: 20),
                    _buildMiniLessons(progress),
                    const SizedBox(height: 24),
                    _buildQuizCarousel(progress),
                    const SizedBox(height: 24),
                    _buildScenarios(progress),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestState() {
    return Container(
      color: _learnBg,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_outline_rounded, color: _learnInk, size: 32),
          SizedBox(height: 12),
          Text('Connecte-toi pour suivre ta progression Learn.', textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: _learnBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 32),
          const SizedBox(height: 12),
          Text(
            _progressError ?? 'Progression indisponible.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _learnMuted),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadProgress,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(LearningProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _CoinPill(
              balance: progress.coins,
              loading: _adLoading[_AdUnlockType.coins] == true,
              onBoost: () => _unlockWithAd(_AdUnlockType.coins),
            ),
            _GemPill(gems: _safeGems(progress)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Learn',
                        style: TextStyle(fontSize: _scaledFont(context, 28), fontWeight: FontWeight.w800, color: _learnInk),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(999)),
                        child: Text('Mode jeu', style: TextStyle(fontSize: _scaledFont(context, 12), fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Avance chaque jour sur ton parcours boursier.',
                    style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 15), fontWeight: FontWeight.w500, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final scale = 1 + (_pulseCtrl.value * 0.05);
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildProgressCard(LearningProgress progress) {
    final xpRatio = (progress.dailyXp / _dailyGoal).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: _learnCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 12)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStreak(progress),
              const SizedBox(width: 18),
              Expanded(child: _buildHearts(progress)),
            ],
          ),
          const SizedBox(height: 18),
          Text('Objectif quotidien', style: TextStyle(fontSize: _scaledFont(context, 14), color: _learnMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    children: [
                      Container(height: 12, color: Colors.grey.shade200),
                      FractionallySizedBox(
                        widthFactor: xpRatio,
                        child: Container(
                          height: 12,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF3D82F7), Color(0xFF26D3AE)]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${progress.dailyXp}/$_dailyGoal XP', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCaps(LearningProgress progress) {
    final items = [
      _CapItem(
        label: 'Leçons',
        icon: Icons.menu_book_rounded,
        used: progress.lessonsDoneToday,
        total: _maxLessonsPerDay(progress),
        free: _freeLessonsPerDay,
        tickets: progress.lessonTickets,
        ticketsMax: _maxLessonTickets,
        adType: _AdUnlockType.lesson,
      ),
      _CapItem(
        label: 'Quiz',
        icon: Icons.quiz_rounded,
        used: progress.quizDoneToday,
        total: _maxQuizPerDay(progress),
        free: _freeQuizzesPerDay,
        tickets: progress.quizTickets,
        ticketsMax: _maxQuizTickets,
        adType: _AdUnlockType.quiz,
      ),
      _CapItem(
        label: 'Portefeuille',
        icon: Icons.wallet_rounded,
        used: progress.scenariosDoneToday,
        total: _maxScenariosPerDay(progress),
        free: _freeScenariosPerDay,
        tickets: progress.scenarioTickets,
        ticketsMax: _maxScenarioTickets,
        adType: _AdUnlockType.scenario,
      ),
    ];
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _DailyCapTile(
                  item: items[0],
                  loading: _adLoading[items[0].adType] == true,
                  onAd: () => _unlockWithAd(items[0].adType),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DailyCapTile(
                  item: items[1],
                  loading: _adLoading[items[1].adType] == true,
                  onAd: () => _unlockWithAd(items[1].adType),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DailyCapTile(
                  item: items[2],
                  loading: _adLoading[items[2].adType] == true,
                  onAd: () => _unlockWithAd(items[2].adType),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreak(LearningProgress progress) {
    final bars = List.generate(7, (index) {
      final filled = index < (progress.streak % 7);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 6),
        width: 14,
        height: 32,
        decoration: BoxDecoration(
          color: filled ? Colors.orangeAccent : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 22),
            const SizedBox(width: 6),
            Text('${progress.streak} j', style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 18))),
          ],
        ),
        const SizedBox(height: 8),
        Row(children: bars),
      ],
    );
  }

  Widget _buildHearts(LearningProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 20),
            SizedBox(width: 6),
            Text('Coeurs', style: TextStyle(fontWeight: FontWeight.w600, color: _learnMuted)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(LearningProgress.defaultHearts, (i) {
            final filled = i < progress.hearts;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedScale(
                scale: filled ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  filled ? Icons.favorite : Icons.favorite_border,
                  color: filled ? Colors.pinkAccent : Colors.grey.shade400,
                ),
              ),
            );
          }),
        ),
        if (progress.hearts < LearningProgress.defaultHearts && _heartCountdownText != null) ...[
          const SizedBox(height: 6),
          Text(
            'Recharge à minuit : $_heartCountdownText',
            style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12)),
          ),
        ],
      ],
    );
  }

  Widget _buildMiniLessons(LearningProgress progress) {
    final completed = progress.completedLessonIds;
    final nextLesson = _nextLessonForUser(progress);
    if (nextLesson == null) {
      return const SizedBox.shrink();
    }
    final done = completed.contains(nextLesson.id);
    final locked = !done && !_hasLessonAllowance(progress);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Petites leçons', style: TextStyle(fontSize: _scaledFont(context, 18), fontWeight: FontWeight.w700, color: _learnInk)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(999)),
              child: Text('Prochaine', style: TextStyle(fontSize: _scaledFont(context, 12), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 290,
          child: _MiniLessonCard(
            lesson: nextLesson,
            completed: done,
            locked: locked,
            onTap: () => _handleLessonTap(nextLesson, done),
          ),
        ),
      ],
    );
  }

  _MiniLesson? _nextLessonForUser(LearningProgress progress) {
    final pending = _lessons.where((l) => !progress.completedLessonIds.contains(l.id)).toList();
    if (pending.isNotEmpty) return pending.first;
    return _lessons.isNotEmpty ? _lessons.first : null;
  }

  Future<void> _handleLessonTap(_MiniLesson lesson, bool completed) async {
    final progress = _progress;
    if (progress == null) return;
    if (!completed && !_hasLessonAllowance(progress)) {
      _promptUnlock(_AdUnlockType.lesson, 'leçons');
      return;
    }
    await _openLesson(lesson, completed);
  }

  Widget _buildQuizCompletedState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Questions du jour', style: TextStyle(fontSize: _scaledFont(context, 18), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tu as terminé les 10 questions du jour. Reviens demain pour un nouveau set !',
                  style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_QuizCardData> _buildDailyQuizSet(LearningProgress progress, {DateTime? seedDate}) {
    final day = _todayKey(seedDate);
    final userHash = FirebaseAuth.instance.currentUser?.uid.hashCode ?? 0;
    final seed = day.millisecondsSinceEpoch ^ userHash ^ progress.completedQuizIds.length.hashCode ^ progress.completedLessonIds.length.hashCode;
    final random = math.Random(seed);
    final pending = _quiz.where((q) => !progress.completedQuizIds.contains(q.id)).toList()
      ..shuffle(random);
    final reviewed = _quiz.where((q) => progress.completedQuizIds.contains(q.id)).toList()
      ..shuffle(random);
    final merged = <_QuizCardData>[...pending, ...reviewed];
    return merged.take(_dailyQuizCount).toList();
  }

  Widget _buildQuizCarousel(LearningProgress progress) {
    final quizSet = _activeQuiz;
    final totalQuiz = quizSet.length;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final double cardHeight = math.min(math.max(screenHeight * 0.58, 360.0), 460.0);
    if (totalQuiz == 0) {
      return _buildQuizCompletedState();
    }
    final currentIndex = _currentQuestion.clamp(0, math.max(totalQuiz - 1, 0));
    final displayIndex = currentIndex + 1;
    final remaining = (_maxQuizPerDay(progress) - progress.quizDoneToday).clamp(0, 99);
    final locked = remaining <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Questions du jour', style: TextStyle(fontSize: _scaledFont(context, 18), fontWeight: FontWeight.w700, color: _learnInk)),
            ),
            Text('$displayIndex/$totalQuiz', style: const TextStyle(color: _learnMuted)),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: locked || remaining <= 2 ? () => _unlockWithAd(_AdUnlockType.quiz) : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(10, 36),
              ),
              icon: _adLoading[_AdUnlockType.quiz] == true
                  ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_circle_fill_rounded, size: 18),
              label: Text(locked ? 'Pub +1' : '+1'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _questionCtrl,
            itemCount: totalQuiz,
            onPageChanged: (index) {
              setState(() => _currentQuestion = index);
            },
            itemBuilder: (context, index) {
              final question = quizSet[index];
              final selected = _selectedAnswers[question.id];
              final alreadyCompleted = progress.completedQuizIds.contains(question.id);
              final awaitingReveal = _awaitingReveal.contains(question.id);
              final blocked = progress.hearts <= 0 && !alreadyCompleted;
              return _QuizCard(
                question: question,
                selectedOption: selected,
                awaitingReveal: awaitingReveal,
                reveal: _revealedQuiz.contains(question.id),
                answeredCorrectly: _correctlyAnsweredQuiz.contains(question.id),
                alreadyCompleted: alreadyCompleted,
                heartsBlocked: blocked,
                onOptionTap: (optionIndex) {
                  if (_revealedQuiz.contains(question.id) || awaitingReveal) return;
                  setState(() => _selectedAnswers[question.id] = optionIndex);
                },
                onValidate: () => _handleQuizAction(question),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalQuiz, (i) {
            final selected = i == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: selected ? 28 : 12,
              decoration: BoxDecoration(
                color: selected ? Colors.black87 : Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _validateAnswer(_QuizCardData question) async {
    final progress = _progress;
    if (progress == null) return;
    if (_revealedQuiz.contains(question.id)) return;
    final selection = _selectedAnswers[question.id];
    if (selection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une réponse avant de valider.')),
      );
      return;
    }

    final alreadyCompleted = progress.completedQuizIds.contains(question.id);
    if (progress.hearts <= 0 && !alreadyCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plus de cœurs pour aujourd’hui, reviens demain.')),
      );
      return;
    }
    if (!alreadyCompleted && !_hasQuizAllowance(progress)) {
      _promptUnlock(_AdUnlockType.quiz, 'quiz');
      return;
    }

    final isCorrect = selection == question.correctIndex;
    if (isCorrect) {
      setState(() => _validatedQuestions.add(question.id));
      if (alreadyCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question déjà validée, XP acquis.')),
        );
      } else {
        var updated = _gainXp(progress, question.rewardXp, question.stageId);
        final completed = Set<String>.from(updated.completedQuizIds)..add(question.id);
        final useTicket = updated.quizDoneToday >= _freeQuizzesPerDay && updated.quizTickets > 0;
        updated = updated.copyWith(
          completedQuizIds: completed,
          quizDoneToday: updated.quizDoneToday + 1,
          quizTickets: useTicket ? math.max(0, updated.quizTickets - 1) : updated.quizTickets,
        );
        updated = _adjustCoins(updated, _quizCoinReward);
        await _persistProgress(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('+${question.rewardXp} XP • +$_quizCoinReward coins – ${question.category}')),
          );
        }
      }
    } else {
      if (!alreadyCompleted) {
        final useTicket = progress.quizDoneToday >= _freeQuizzesPerDay && progress.quizTickets > 0;
        final updated = progress.copyWith(
          quizDoneToday: progress.quizDoneToday + 1,
          quizTickets: useTicket ? math.max(0, progress.quizTickets - 1) : progress.quizTickets,
        );
        await _persistProgress(updated);
      }
      await _consumeHeart();
    }
    _handleQuestionResolution(question, isCorrect);
  }

  void _handleQuizAction(_QuizCardData question) {
    if (_revealedQuiz.contains(question.id)) {
      _dismissQuestion(question);
      return;
    }
    if (_awaitingReveal.contains(question.id)) {
      setState(() {
        _revealedQuiz.add(question.id);
        _awaitingReveal.remove(question.id);
      });
      return;
    }
    _validateAnswer(question);
  }

  Future<void> _consumeHeart() async {
    final progress = _progress;
    if (progress == null) return;
    if (progress.hearts <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tes cœurs sont épuisés pour aujourd’hui.')),
      );
      return;
    }
    final updated = progress.copyWith(hearts: math.max(0, progress.hearts - 1));
    await _persistProgress(updated);
    if (!mounted) return;
    final remaining = updated.hearts;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Oups ! Plus que $remaining cœur(s).')),
    );
  }

  void _handleQuestionResolution(_QuizCardData question, bool wasCorrect) {
    setState(() {
      _awaitingReveal.add(question.id);
      if (wasCorrect) {
        _correctlyAnsweredQuiz.add(question.id);
      } else {
        _correctlyAnsweredQuiz.remove(question.id);
      }
    });
  }

  void _updateCurrentQuestionAfterRemoval() {
    if (_activeQuiz.isEmpty) {
      _currentQuestion = 0;
      return;
    }
    final newIndex = math.min(_currentQuestion, _activeQuiz.length - 1);
    _currentQuestion = newIndex;
    if (_questionCtrl.hasClients) {
      _questionCtrl.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _dismissQuestion(_QuizCardData question) {
    setState(() {
      _activeQuiz = List<_QuizCardData>.from(_activeQuiz)..removeWhere((q) => q.id == question.id);
      _revealedQuiz.remove(question.id);
      _awaitingReveal.remove(question.id);
      _correctlyAnsweredQuiz.remove(question.id);
      _selectedAnswers.remove(question.id);
      _validatedQuestions.remove(question.id);
      _updateCurrentQuestionAfterRemoval();
    });
  }

  LearningProgress _gainXp(LearningProgress progress, int amount, String stageId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = progress.lastActivityDate;
    final bool wasYesterday = last != null && _isYesterday(last, today);
    final bool sameDay = LearningProgress.isSameDay(last, today);
    final int newStreak = sameDay ? progress.streak : (wasYesterday ? progress.streak + 1 : 1);

    var updated = progress
        .copyWith(
          dailyXp: progress.dailyXp + amount,
          totalXp: progress.totalXp + amount,
          lastActivityDate: today,
          streak: newStreak,
        )
        .updateStage(stageId, _stageIncrement);

    final reachedGoal = updated.dailyXp >= _dailyGoal;
    if (reachedGoal && !LearningProgress.isSameDay(progress.lastGoalCompletedDate, today)) {
      updated = updated.copyWith(lastGoalCompletedDate: today);
    }
    updated = _maybeAwardGem(updated);
    return updated;
  }

  DateTime _todayKey([DateTime? reference]) {
    final ref = reference ?? DateTime.now();
    return DateTime(ref.year, ref.month, ref.day);
  }

  bool _isYesterday(DateTime date, DateTime today) {
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  LearningProgress _maybeAwardGem(LearningProgress progress) {
    final gems = _safeGems(progress);
    final lastGem = _safeLastGemStreak(progress);
    if (progress.streak >= 7 && progress.streak % 7 == 0 && progress.streak > lastGem) {
      return progress.copyWith(
        gems: gems + _gemsPerStreak,
        lastGemStreak: progress.streak,
      );
    }
    return progress;
  }

  int _safeGems(LearningProgress progress) {
    try {
      return progress.gems;
    } catch (_) {
      return 0;
    }
  }

  int _safeLastGemStreak(LearningProgress progress) {
    try {
      return progress.lastGemStreak;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildScenarios(LearningProgress progress) {
    final completed = progress.completedScenarioIds;
    final remaining = (_maxScenariosPerDay(progress) - progress.scenariosDoneToday).clamp(0, 99);
    final locked = remaining <= 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text('Mises en situation portefeuille', style: TextStyle(fontSize: _scaledFont(context, 18), fontWeight: FontWeight.w700)),
          subtitle: Row(
            children: [
              Text('1 gratuite/jour', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 13))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: locked ? Colors.red.withOpacity(0.08) : Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  locked ? 'Regarde une pub' : '$remaining restantes',
                  style: TextStyle(
                    color: locked ? Colors.redAccent : Colors.green,
                    fontSize: _scaledFont(context, 12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          iconColor: Colors.black,
          collapsedIconColor: Colors.black54,
          children: [
            Row(
              children: [
                Text(locked ? 'Plus de slot gratuit' : '$remaining slot(s) restants', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
                const Spacer(),
                TextButton.icon(
                  onPressed: progress.scenarioTickets >= _maxScenarioTickets ? null : () => _unlockWithAd(_AdUnlockType.scenario),
                  icon: _adLoading[_AdUnlockType.scenario] == true
                      ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_circle_fill_rounded, size: 18),
                  label: const Text('Pub +1'),
                  style: TextButton.styleFrom(foregroundColor: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._scenarios
                .map(
                  (scenario) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ScenarioCard(
                      scenario: scenario,
                      completed: completed.contains(scenario.id),
                      locked: locked,
                      onTap: () => _handleScenarioTap(progress, scenario, completed.contains(scenario.id)),
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Color _stageColor(String stageId) {
    final match = _stages.firstWhere(
      (stage) => stage.id == stageId,
      orElse: () => _stages.first,
    );
    return match.accent;
  }

  String _stageLabel(String stageId) {
    final match = _stages.firstWhere(
      (stage) => stage.id == stageId,
      orElse: () => _stages.first,
    );
    return match.title;
  }

  Future<void> _openLesson(_MiniLesson lesson, bool completed) async {
    final accent = _stageColor(lesson.stageId);
    final stageLabel = _stageLabel(lesson.stageId);
    final shouldValidate = await showCupertinoModalBottomSheet<bool>(
      context: context,
      expand: true,
      builder: (context) => _LessonDetailSheet(
        lesson: lesson,
        completed: completed,
        accent: accent,
        stageLabel: stageLabel,
      ),
    );
    if (shouldValidate == true) {
      await _completeLesson(lesson);
    }
  }

  Future<void> _completeLesson(_MiniLesson lesson) async {
    final progress = _progress;
    if (progress == null) return;
    if (progress.completedLessonIds.contains(lesson.id)) return;
    if (!_hasLessonAllowance(progress)) {
      _promptUnlock(_AdUnlockType.lesson, 'leçons');
      return;
    }
    var updated = _gainXp(progress, lesson.rewardXp, lesson.stageId);
    final done = Set<String>.from(updated.completedLessonIds)..add(lesson.id);
    final useTicket = updated.lessonsDoneToday >= _freeLessonsPerDay && updated.lessonTickets > 0;
    updated = updated.copyWith(
      completedLessonIds: done,
      lessonsDoneToday: updated.lessonsDoneToday + 1,
      lessonTickets: useTicket ? math.max(0, updated.lessonTickets - 1) : updated.lessonTickets,
    );
    updated = _adjustCoins(updated, _lessonCoinReward);
    await _persistProgress(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('+${lesson.rewardXp} XP • +$_lessonCoinReward coins – ${lesson.title}')), 
    );
  }

  Future<void> _handleScenarioTap(LearningProgress progress, _PortfolioScenario scenario, bool completed) async {
    if (!completed && !_hasScenarioAllowance(progress)) {
      _promptUnlock(_AdUnlockType.scenario, 'situations');
      return;
    }
    if (progress.coins < _minScenarioStake) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solde insuffisant pour miser. Regarde une pub ou termine un quiz/leçon.')),
      );
      return;
    }
    await _openScenario(progress, scenario, completed);
  }

  Future<void> _openScenario(LearningProgress progress, _PortfolioScenario scenario, bool completed) async {
    final accent = _stageColor(scenario.stageId);
    final result = await showCupertinoModalBottomSheet<_ScenarioResult?>(
      context: context,
      expand: true,
      builder: (context) => _ScenarioSimulationSheet(
        scenario: scenario,
        completed: completed,
        accent: accent,
        availableCoins: progress.coins,
        initialStake: _suggestStake(progress),
      ),
    );
    if (result != null) {
      await _completeScenario(scenario, result);
    }
  }

  Future<void> _completeScenario(_PortfolioScenario scenario, _ScenarioResult outcome) async {
    final progress = _progress;
    if (progress == null) return;
    final alreadyCompleted = progress.completedScenarioIds.contains(scenario.id);
    if (!_hasScenarioAllowance(progress)) {
      _promptUnlock(_AdUnlockType.scenario, 'situations');
      return;
    }
    var updated = progress;
    if (!alreadyCompleted) {
      updated = _gainXp(progress, scenario.rewardXp, scenario.stageId);
      final done = Set<String>.from(updated.completedScenarioIds)..add(scenario.id);
      updated = updated.copyWith(completedScenarioIds: done);
    }
    final useTicket = updated.scenariosDoneToday >= _freeScenariosPerDay && updated.scenarioTickets > 0;
    updated = updated.copyWith(
      scenariosDoneToday: updated.scenariosDoneToday + 1,
      scenarioTickets: useTicket ? math.max(0, updated.scenarioTickets - 1) : updated.scenarioTickets,
    );
    updated = _adjustCoins(updated, outcome.coinDelta);
    await _persistProgress(updated);
    if (!mounted) return;
    final deltaSign = outcome.coinDelta >= 0 ? '+' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${alreadyCompleted ? "Simulation rejouée" : "+${scenario.rewardXp} XP"} • $deltaSign${outcome.coinDelta} coins – ${scenario.title}',
        ),
      ), 
    );
  }
}

class _MiniLessonCard extends StatelessWidget {
  const _MiniLessonCard({required this.lesson, required this.completed, required this.onTap, this.locked = false});

  final _MiniLesson lesson;
  final bool completed;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(locked ? 0.7 : 1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                  child: Icon(lesson.icon, color: Colors.black87),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(999)),
                  child: Text(lesson.duration, style: TextStyle(fontSize: _scaledFont(context, 12), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(lesson.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 16))),
            const SizedBox(height: 6),
            SizedBox(
              height: 120,
              child: _AutoScrollText(
                text: lesson.summary,
                style: TextStyle(color: _learnMuted, height: 1.3, fontSize: _scaledFont(context, 13)),
                maxHeight: 120,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  locked
                      ? Icons.lock_rounded
                      : completed
                          ? Icons.check_circle
                          : Icons.play_circle_fill,
                  color: locked
                      ? Colors.grey
                      : completed
                          ? Colors.green
                          : Colors.black,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locked ? 'Pub pour débloquer' : (completed ? 'Révision' : 'Commencer'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.balance, required this.onBoost, this.loading = false});

  final int balance;
  final VoidCallback onBoost;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFC107), Color(0xFFFFA726)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded, color: Colors.black87),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Coins', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _scaledFont(context, 13))),
              Text(
                balance.toString(),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 15)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: loading ? null : onBoost,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(10, 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: loading
                ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Pub + coins', style: TextStyle(fontSize: 11)),
          )
        ],
      ),
    );
  }
}

class _GemPill extends StatelessWidget {
  const _GemPill({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4A00E0).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gemmes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _scaledFont(context, 13), color: Colors.white)),
              Text(
                gems.toString(),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 15), color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapItem {
  const _CapItem({
    required this.label,
    required this.icon,
    required this.used,
    required this.total,
    required this.free,
    required this.tickets,
    required this.ticketsMax,
    required this.adType,
  });

  final String label;
  final IconData icon;
  final int used;
  final int total;
  final int free;
  final int tickets;
  final int ticketsMax;
  final _AdUnlockType adType;
}

class _DailyCapTile extends StatelessWidget {
  const _DailyCapTile({required this.item, required this.loading, required this.onAd});

  final _CapItem item;
  final bool loading;
  final VoidCallback onAd;

  @override
  Widget build(BuildContext context) {
    final locked = item.used >= item.total;
    final showAd = item.used >= item.free;
    final barValue = (item.used / item.total).clamp(0.0, 1.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                child: Icon(item.icon, size: 18),
              ),
              const Spacer(),
              Text('${item.used}/${item.total}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _scaledFont(context, 14))),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 13))),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: barValue,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: locked ? Colors.redAccent : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  showAd ? 'Pub pour +1' : '${item.free} gratuits',
                  style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 11)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showAd)
                TextButton(
                  onPressed: loading || item.tickets >= item.ticketsMax ? null : onAd,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(10, 32),
                    foregroundColor: Colors.black,
                  ),
                  child: loading
                      ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Pub +1'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoScrollText extends StatefulWidget {
  const _AutoScrollText({
    required this.text,
    required this.style,
    this.maxHeight,
  });

  final String text;
  final TextStyle style;
  final double? maxHeight;

  @override
  State<_AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<_AutoScrollText> {
  final ScrollController _controller = ScrollController();
  Timer? _resumeTimer;
  bool _autoEnabled = true;
  bool _loopActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateScrollNeed());
  }

  @override
  void didUpdateWidget(covariant _AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text || widget.maxHeight != oldWidget.maxHeight) {
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }
      _autoEnabled = true;
      _loopActive = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateScrollNeed());
    }
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _evaluateScrollNeed() {
    if (!mounted) return;
    if (!_controller.hasClients) {
      Future.delayed(const Duration(milliseconds: 200), _evaluateScrollNeed);
      return;
    }
    final needsScroll = _controller.position.maxScrollExtent > 4;
    if (needsScroll && !_loopActive) {
      _loopActive = true;
      _autoLoop();
    } else if (!needsScroll) {
      _loopActive = false;
    }
  }

  Future<void> _autoLoop() async {
    while (mounted && _loopActive) {
      if (!_controller.hasClients) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) {
        _loopActive = false;
        break;
      }
      if (!_autoEnabled) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_autoEnabled) continue;
      final durationMs = (max * 18).clamp(1200, 5000).toInt();
      try {
        await _controller.animateTo(
          max,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeInOut,
        );
      } catch (_) {
        _loopActive = false;
        break;
      }
      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_autoEnabled) continue;
      try {
        await _controller.animateTo(
          0,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeInOut,
        );
      } catch (_) {
        _loopActive = false;
        break;
      }
    }
  }

  void _pauseAutoScroll() {
    _autoEnabled = false;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _autoEnabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          _pauseAutoScroll();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Text(widget.text, style: widget.style),
      ),
    );

    if (widget.maxHeight != null) {
      return SizedBox(height: widget.maxHeight, child: scrollable);
    }
    return scrollable;
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.question,
    required this.selectedOption,
    required this.awaitingReveal,
    required this.reveal,
    required this.answeredCorrectly,
    required this.alreadyCompleted,
    required this.heartsBlocked,
    required this.onOptionTap,
    required this.onValidate,
  });

  final _QuizCardData question;
  final int? selectedOption;
  final bool awaitingReveal;
  final bool reveal;
  final bool answeredCorrectly;
  final bool alreadyCompleted;
  final bool heartsBlocked;
  final ValueChanged<int> onOptionTap;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 10)),
        ],
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: reveal ? 1 : 0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          final angle = value * math.pi;
          final showBack = angle > math.pi / 2;
          final displayAngle = showBack ? angle - math.pi : angle;
          final content = showBack ? _buildBack(context) : _buildFront(context);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(displayAngle),
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildFront(BuildContext context) {
    final disabled = heartsBlocked && !awaitingReveal && !reveal;
    final buttonLabel = reveal
        ? 'Continuer'
        : awaitingReveal
            ? 'Voir solution'
            : alreadyCompleted
                ? 'Réviser'
                : 'Valider';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.08), borderRadius: BorderRadius.circular(999)),
              child: Text(question.category, style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 12), letterSpacing: .5)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
              child: Text('+${question.rewardXp} XP', style: TextStyle(fontSize: _scaledFont(context, 12), fontWeight: FontWeight.w600, color: Colors.green)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(question.question, style: TextStyle(fontSize: _scaledFont(context, 17), fontWeight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: _buildShuffledOptions().map((entry) {
                final optionIndex = entry.key;
                final option = entry.value;
                final isSelected = selectedOption == optionIndex;
                final isCorrect = optionIndex == question.correctIndex;
                Color border = Colors.black12;
                Color? fill;
                if (reveal && isCorrect) {
                  border = Colors.green;
                  fill = Colors.green.withOpacity(0.08);
                } else if (reveal && isSelected && !isCorrect) {
                  border = Colors.red;
                  fill = Colors.red.withOpacity(0.08);
                } else if (isSelected) {
                  border = Colors.black;
                  fill = Colors.black.withOpacity(0.04);
                }

                return GestureDetector(
                  onTap: disabled ? null : () => onOptionTap(optionIndex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                    child: Row(
                      children: [
                        Expanded(child: Text(option, style: TextStyle(fontSize: _scaledFont(context, 15), fontWeight: FontWeight.w600))),
                        if (reveal && isCorrect) const Icon(Icons.check_circle, color: Colors.green)
                        else if (reveal && isSelected && !isCorrect) const Icon(Icons.cancel, color: Colors.red),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (awaitingReveal && !reveal)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Réponse enregistrée • Clique sur "Voir solution"', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
          ),
        if (alreadyCompleted)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Text('XP déjà obtenu', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
              ],
            ),
          ),
        if (heartsBlocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Plus de cœurs • attend la prochaine recharge', style: TextStyle(color: Colors.redAccent, fontSize: _scaledFont(context, 12))),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: disabled ? null : onValidate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(buttonLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildBack(BuildContext context) {
    final color = answeredCorrectly ? Colors.green : Colors.redAccent;
    final headline = answeredCorrectly ? 'Bonne réponse !' : 'Réponse incorrecte';
    final rewardText = answeredCorrectly ? '+${question.rewardXp} XP gagnés' : '−1 cœur consommé';
    final correctOption = question.options[question.correctIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
              child: Icon(answeredCorrectly ? Icons.emoji_events_rounded : Icons.favorite, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(headline, style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 16), color: color)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(rewardText, style: TextStyle(color: color, fontSize: _scaledFont(context, 14), fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Réponse attendue : $correctOption', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 13))),
        const SizedBox(height: 12),
        Text('Explication', style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 15))),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              question.explanation,
              style: TextStyle(color: _learnMuted, height: 1.4, fontSize: _scaledFont(context, 14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Appuie sur "Continuer" pour passer à la prochaine question.', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
      ],
    );
  }

  List<MapEntry<int, String>> _buildShuffledOptions() {
    final entries = List<MapEntry<int, String>>.generate(
      question.options.length,
      (index) => MapEntry(index, question.options[index]),
    );
    entries.shuffle(math.Random(question.id.hashCode));
    return entries;
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario, required this.completed, required this.onTap, this.locked = false});

  final _PortfolioScenario scenario;
  final bool completed;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(locked ? 0.9 : 1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          if (!locked)
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  scenario.title,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 16)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(999)),
                child: Text(scenario.focus, style: TextStyle(fontSize: _scaledFont(context, 12), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(scenario.description, style: const TextStyle(color: _learnInk, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.amber.shade700, size: 18),
              const SizedBox(width: 6),
              Text(scenario.risk, style: TextStyle(fontWeight: FontWeight.w600, color: _learnMuted, fontSize: _scaledFont(context, 13))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                child: Text('+${scenario.rewardXp} XP', style: TextStyle(fontSize: _scaledFont(context, 12), fontWeight: FontWeight.w600, color: Colors.green)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onTap,
              style: TextButton.styleFrom(foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              icon: Icon(locked ? Icons.lock_rounded : (completed ? Icons.refresh_rounded : Icons.play_circle_fill_rounded)),
              label: Text(locked ? 'Regarder une pub' : (completed ? 'Rejouer' : 'Simuler')),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonDetailSheet extends StatefulWidget {
  const _LessonDetailSheet({
    required this.lesson,
    required this.completed,
    required this.accent,
    required this.stageLabel,
  });

  final _MiniLesson lesson;
  final bool completed;
  final Color accent;
  final String stageLabel;

  @override
  State<_LessonDetailSheet> createState() => _LessonDetailSheetState();
}

class _LessonDetailSheetState extends State<_LessonDetailSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _illustrationCtrl;

  @override
  void initState() {
    super.initState();
    _illustrationCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _illustrationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _lessonSectionsFor(widget.lesson);
    final examples = _lessonExamplesFor(widget.lesson);
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Scaffold(
          backgroundColor: _learnBg,
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader(context)),
                      SliverToBoxAdapter(child: _buildIllustration()),
                      SliverToBoxAdapter(child: _buildKeyConcepts()),
                      if (sections.isNotEmpty)
                        SliverToBoxAdapter(child: _buildSections(sections)),
                      if (examples.isNotEmpty)
                        SliverToBoxAdapter(child: _buildExamples(examples)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedOpacity(
                        opacity: widget.completed ? 1 : 0.5,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          widget.completed ? 'Déjà marqué comme appris' : 'Prêt à valider ?',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: widget.accent, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(widget.completed ? 'Réviser à nouveau' : 'J’ai compris'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final durationChip = _LessonChip(label: widget.lesson.duration, color: widget.accent);
    final stageChip = _LessonChip(label: widget.stageLabel, color: widget.accent.withOpacity(0.15), textColor: widget.accent);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.accent, widget.accent.withOpacity(0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.lesson.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _scaledFont(context, 22),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.lesson.summary,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: _scaledFont(context, 15),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                durationChip,
                stageChip,
                if (widget.completed)
                  const _LessonChip(
                    label: 'Déjà acquise',
                    color: Color(0xFFE6F4EA),
                    textColor: Color(0xFF188038),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: _LessonIllustration(
        accent: widget.accent,
        controller: _illustrationCtrl,
        stageId: widget.lesson.stageId,
        stageLabel: widget.stageLabel,
      ),
    );
  }

  Widget _buildKeyConcepts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Concepts clés', style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 18))),
          const SizedBox(height: 12),
          ...widget.lesson.bulletPoints.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: widget.accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(fontSize: _scaledFont(context, 14), height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSections(List<_LessonSection> sections) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Approfondir', style: TextStyle(fontSize: _scaledFont(context, 18), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...sections.map((section) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(section.icon, color: widget.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(section.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 16))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(section.description, style: TextStyle(fontSize: _scaledFont(context, 14), height: 1.5, color: Colors.black87)),
                  if (section.bullets.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...section.bullets.map(
                      (bullet) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(child: Text(bullet, style: TextStyle(fontSize: _scaledFont(context, 13), height: 1.4))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExamples(List<_LessonExample> examples) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mises en pratique', style: TextStyle(fontSize: _scaledFont(context, 18), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: examples.map((example) {
                return Container(
                  width: 240,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withOpacity(0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(example.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 15))),
                      const SizedBox(height: 6),
                      Text(example.description, style: TextStyle(fontSize: _scaledFont(context, 13), height: 1.4)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<_LessonSection> _lessonSectionsFor(_MiniLesson lesson) {
    switch (lesson.stageId) {
      case 'fundamentals':
        return _buildFundamentalSections(lesson);
      case 'technical':
        return _buildTechnicalSections(lesson);
      case 'intuition':
        return _buildIntuitionSections(lesson);
      case 'history':
        return _buildHistorySections(lesson);
      case 'psychology':
        return _buildPsychologySections(lesson);
      case 'esg':
        return _buildEsgSections(lesson);
      case 'derivatives':
        return _buildDerivativeSections(lesson);
      default:
        return _buildGenericSections(lesson);
    }
  }

  List<_LessonExample> _lessonExamplesFor(_MiniLesson lesson) {
    switch (lesson.stageId) {
      case 'fundamentals':
        return _buildFundamentalExamples(lesson);
      case 'technical':
        return _buildTechnicalExamples(lesson);
      case 'intuition':
        return _buildIntuitionExamples(lesson);
      case 'history':
        return _buildHistoryExamples(lesson);
      case 'psychology':
        return _buildPsychologyExamples(lesson);
      case 'esg':
        return _buildEsgExamples(lesson);
      case 'derivatives':
        return _buildDerivativeExamples(lesson);
      default:
        return _buildGenericExamples(lesson);
    }
  }
}

class _LessonChip extends StatelessWidget {
  const _LessonChip({required this.label, required this.color, this.textColor = Colors.white});

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: _scaledFont(context, 12),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LessonIllustration extends StatelessWidget {
  const _LessonIllustration({
    required this.accent,
    required this.controller,
    required this.stageId,
    required this.stageLabel,
  });

  final Color accent;
  final Animation<double> controller;
  final String stageId;
  final String stageLabel;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForStage(stageId, accent);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final progress = controller.value;
          final wave = math.sin(progress * math.pi * 2);
          final bounce = (math.sin(progress * math.pi) + 1) / 2;
          return Container(
            height: 240,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.dark, palette.mid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.25,
                      child: CustomPaint(
                        painter: _LessonSparklinePainter(progress: progress, color: palette.highlight),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6 + wave * 2,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(palette.icon, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            stageLabel,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: _scaledFont(context, 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: _buildScene(progress, wave, bounce, palette),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Transform.translate(
                      offset: Offset(math.sin(progress * math.pi * 2) * 6, -6 * bounce),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            'Focus visuel',
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: _scaledFont(context, 11)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScene(double progress, double wave, double bounce, _IllustrationPalette palette) {
    switch (stageId) {
      case 'technical':
        return _buildTechnicalScene(progress, palette);
      case 'intuition':
        return _buildMacroScene(bounce, palette);
      case 'history':
        return _buildHistoryScene(progress, palette);
      case 'psychology':
        return _buildPsychologyScene(progress, palette);
      case 'esg':
        return _buildEsgScene(progress, palette);
      case 'derivatives':
        return _buildDerivativeScene(progress, palette);
      case 'fundamentals':
      default:
        return _buildFundamentalScene(progress, palette);
    }
  }

  Widget _buildFundamentalScene(double progress, _IllustrationPalette palette) {
    final bars = [70.0, 110.0, 90.0, 140.0, 95.0];
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(bars.length, (index) {
          final ratio = (math.sin(progress * math.pi * 2 + index) + 1) / 2;
          final height = bars[index] * (0.55 + ratio * 0.5);
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [palette.highlight.withOpacity(0.85), palette.detail.withOpacity(0.85)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTechnicalScene(double progress, _IllustrationPalette palette) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(5, (index) {
          final swing = (math.sin(progress * math.pi * 2 + index) + 1) / 2;
          final body = 60 + swing * 60;
          final wick = body + 30;
          final bull = swing > 0.5;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(width: 3, height: wick, color: Colors.white30),
              const SizedBox(height: 4),
              Container(
                width: 18,
                height: body,
                decoration: BoxDecoration(
                  color: bull ? palette.highlight : palette.detail,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMacroScene(double bounce, _IllustrationPalette palette) {
    final alignX = -1 + bounce * 2;
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(height: 2, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        ),
        ...List.generate(5, (index) {
          return Align(
            alignment: Alignment(-1 + index * 0.5, 0),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: index.isEven ? palette.highlight : Colors.white38,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment(alignX, -0.4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(16)),
            child: const Text('Agenda critique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
        Align(
          alignment: Alignment(alignX, 0.4),
          child: Container(
            width: 90,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.highlight.withOpacity(0.25),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Impact', style: TextStyle(color: Colors.white70, fontSize: 11)),
                SizedBox(height: 4),
                Text('Filtre prioritaire', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryScene(double progress, _IllustrationPalette palette) {
    final years = ['1987', '2000', '2008', '2020'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: years.map((year) {
        final offset = years.indexOf(year).toDouble();
        final tilt = 0.08 * math.sin(progress * math.pi * 2 + offset);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Transform.rotate(
            angle: tilt,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08 + offset * 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(year, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const Icon(Icons.trending_flat, color: Colors.white54, size: 20),
                  const Text('Impact marché', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPsychologyScene(double progress, _IllustrationPalette palette) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(6, (index) {
        final pulse = 0.9 + 0.2 * math.sin(progress * math.pi * 2 + index);
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(index.isEven ? Icons.favorite_rounded : Icons.self_improvement_rounded, color: palette.highlight),
          ),
        );
      }),
    );
  }

  Widget _buildEsgScene(double progress, _IllustrationPalette palette) {
    final sway = math.sin(progress * math.pi * 2) * 0.3;
    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.highlight.withOpacity(0.4), palette.detail.withOpacity(0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        Align(
          alignment: Alignment(-0.6 + sway, -0.2),
          child: Icon(Icons.energy_savings_leaf_rounded, color: Colors.white.withOpacity(0.9), size: 56),
        ),
        Align(
          alignment: Alignment(0.7 + sway, -0.1),
          child: Icon(Icons.water_drop_rounded, color: Colors.white.withOpacity(0.6), size: 44),
        ),
        Align(
          alignment: Alignment(0, -0.5 + sway * 0.3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Transition en cours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildDerivativeScene(double progress, _IllustrationPalette palette) {
    final slider = (math.sin(progress * math.pi * 2) + 1) / 2;
    final alignX = -1 + slider * 2;
    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(height: 2, color: Colors.white30),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(width: 2, height: 120, color: Colors.white30),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _LessonPayoffPainter(color: palette.highlight),
          ),
        ),
        Align(
          alignment: Alignment(alignX, 0.2),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.analytics_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _LessonSparklinePainter extends CustomPainter {
  const _LessonSparklinePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path();
    const samples = 24;
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final wave = math.sin((t * 3 + progress * 2) * math.pi);
      final y = size.height * (0.6 - wave * 0.15);
      final x = size.width * t;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LessonSparklinePainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}

class _LessonPayoffPainter extends CustomPainter {
  const _LessonPayoffPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path();
    final centerY = size.height * 0.6;
    path.moveTo(0, centerY + 20);
    path.lineTo(size.width * 0.4, centerY + 10);
    path.lineTo(size.width * 0.7, centerY - 30);
    path.lineTo(size.width, centerY - 40);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LessonPayoffPainter oldDelegate) => oldDelegate.color != color;
}

class _IllustrationPalette {
  const _IllustrationPalette({
    required this.dark,
    required this.mid,
    required this.highlight,
    required this.detail,
    required this.icon,
  });

  final Color dark;
  final Color mid;
  final Color highlight;
  final Color detail;
  final IconData icon;
}

_IllustrationPalette _paletteForStage(String stageId, Color accent) {
  switch (stageId) {
    case 'technical':
      return _IllustrationPalette(
        dark: const Color(0xFF1F1B3A),
        mid: const Color(0xFF3D2C6E),
        highlight: const Color(0xFF8F67FF),
        detail: const Color(0xFFED6A5A),
        icon: Icons.timeline_rounded,
      );
    case 'intuition':
      return _IllustrationPalette(
        dark: const Color(0xFF1E2A38),
        mid: const Color(0xFF2F4858),
        highlight: const Color(0xFFFF9E64),
        detail: const Color(0xFF4AC1A2),
        icon: Icons.public_rounded,
      );
    case 'history':
      return _IllustrationPalette(
        dark: const Color(0xFF2B1F1C),
        mid: const Color(0xFF4E342E),
        highlight: const Color(0xFFFFD180),
        detail: const Color(0xFFFFA726),
        icon: Icons.history_edu_rounded,
      );
    case 'psychology':
      return _IllustrationPalette(
        dark: const Color(0xFF361C3E),
        mid: const Color(0xFF512751),
        highlight: const Color(0xFFD65DB1),
        detail: const Color(0xFFFF7EB6),
        icon: Icons.self_improvement_rounded,
      );
    case 'esg':
      return _IllustrationPalette(
        dark: const Color(0xFF153F2D),
        mid: const Color(0xFF1F5A3E),
        highlight: const Color(0xFF81C784),
        detail: const Color(0xFF4CAF50),
        icon: Icons.eco_rounded,
      );
    case 'derivatives':
      return _IllustrationPalette(
        dark: const Color(0xFF102A38),
        mid: const Color(0xFF124559),
        highlight: const Color(0xFF00BCD4),
        detail: const Color(0xFF4DD0E1),
        icon: Icons.multiline_chart_rounded,
      );
    case 'fundamentals':
    default:
      return _IllustrationPalette(
        dark: _tintColor(accent, -0.35),
        mid: _tintColor(accent, -0.15),
        highlight: accent,
        detail: _tintColor(accent, 0.2),
        icon: Icons.ssid_chart_rounded,
      );
  }
}

Color _tintColor(Color base, double amount) {
  final hsl = HSLColor.fromColor(base);
  final doubleLight = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(doubleLight).toColor();
}

enum _SimulationPhase { brief, allocate, play, debrief }

class _ScenarioSimulationSheet extends StatefulWidget {
  const _ScenarioSimulationSheet({
    required this.scenario,
    required this.completed,
    required this.accent,
    required this.availableCoins,
    required this.initialStake,
  });

  final _PortfolioScenario scenario;
  final bool completed;
  final Color accent;
  final int availableCoins;
  final int initialStake;

  @override
  State<_ScenarioSimulationSheet> createState() => _ScenarioSimulationSheetState();
}

class _ScenarioSimulationSheetState extends State<_ScenarioSimulationSheet> {
  late final _SimulationConfig _config;
  _SimulationPhase _phase = _SimulationPhase.brief;
  int _currentStep = 0;
  bool _playing = false;
  bool _rebalanceUsed = false;
  late int _stake;
  Map<String, double> _weights = {};
  Map<String, double> _positions = {};
  double _cash = 0;
  List<double> _portfolioHistory = [];
  double _maxValue = 0;
  double _maxDrawdown = 0;

  @override
  void initState() {
    super.initState();
    _config = _simulationConfigFor(widget.scenario);
    _weights = Map<String, double>.from(_config.suggestedAllocation);
    _cash = _config.initialCash;
    final capped = math.min(widget.availableCoins, _LearnPageState._maxScenarioStake);
    final safeMin = _LearnPageState._minScenarioStake;
    _stake = widget.initialStake.clamp(safeMin, math.max(safeMin, capped));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _learnBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 8),
              _buildStepper(),
              const SizedBox(height: 12),
              Expanded(child: _buildPhaseBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.scenario.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: _scaledFont(context, 18))),
              Text(_config.periodLabel, style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 13))),
              Text('${_config.durationLabel} • ${_config.stepLabel}', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: widget.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
              child: Text('+${widget.scenario.rewardXp} XP', style: TextStyle(color: widget.accent, fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 12))),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
              child: Text('Mise $_stake coins', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 12))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepper() {
    final phases = const [
      'Brief',
      'Allocation',
      'Simulation',
      'Debrief',
    ];
    return Row(
      children: List.generate(phases.length, (i) {
        final active = i <= _phase.index;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 6,
            decoration: BoxDecoration(
              color: active ? widget.accent : Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPhaseBody(BuildContext context) {
    switch (_phase) {
      case _SimulationPhase.brief:
        return _buildBrief();
      case _SimulationPhase.allocate:
        return _buildAllocation();
      case _SimulationPhase.play:
        return _buildSimulation();
      case _SimulationPhase.debrief:
        return _buildDebrief();
    }
  }

  Widget _buildBrief() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_config.headline, style: TextStyle(fontSize: _scaledFont(context, 17), fontWeight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 10),
        Text(widget.scenario.description, style: const TextStyle(color: _learnInk, height: 1.35)),
        const SizedBox(height: 14),
        ..._config.cues.map((cue) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.radio_button_checked, size: 16, color: widget.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(cue, style: const TextStyle(height: 1.35))),
                ],
              ),
            )),
        const SizedBox(height: 12),
        _buildStakeSelector(),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: widget.accent),
              const SizedBox(width: 10),
              Expanded(child: Text('Capital initial : ${_fmtCurrency(_config.initialCash)}', style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.schedule_rounded, color: widget.accent),
            const SizedBox(width: 8),
            Text('${_config.durationLabel} • ${_config.stepLabel}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _phase = _SimulationPhase.allocate),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Configurer mon portefeuille'),
          ),
        ),
      ],
    );
  }

  Widget _buildStakeSelector() {
    final min = _LearnPageState._minScenarioStake.toDouble();
    final max = math.max(min, math.min(_LearnPageState._maxScenarioStake.toDouble(), widget.availableCoins.toDouble()));
    final divisions = max - min <= 0 ? 1 : math.max(1, ((max - min) / 20).round());
    final projectedCoins = _coinDeltaFromPnl(8); // petite projection sur +8%
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Choisis ta mise', style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 14))),
              const Spacer(),
              Text('Solde ${widget.availableCoins} coins', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
            ],
          ),
          const SizedBox(height: 8),
          Text('$_stake coins', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _scaledFont(context, 18))),
          Slider(
            value: _stake.toDouble().clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: Colors.black,
            onChanged: (value) => setState(() => _stake = value.round()),
          ),
          Text('Projection: ~${projectedCoins >= 0 ? '+' : ''}$projectedCoins coins si +8%', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
        ],
      ),
    );
  }

  Widget _buildAllocation() {
    final totalWeight = _weights.values.fold<double>(0, (a, b) => a + b);
    final remaining = (100 - totalWeight).clamp(-999, 999);
    final bool okRange = totalWeight >= 85 && totalWeight <= 105;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Alloue ton capital sur les lignes proposées. Tu peux garder du cash pour amortir le choc.', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 14))),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${totalWeight.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _scaledFont(context, 18))),
                Text(remaining >= 0 ? 'Reste ${remaining.toStringAsFixed(0)}%' : 'Dépassé ${(remaining.abs()).toStringAsFixed(0)}%', style: TextStyle(color: remaining >= 0 ? _learnMuted : Colors.redAccent, fontSize: _scaledFont(context, 12))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _config.assets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final asset = _config.assets[index];
              final weight = _weights[asset.id] ?? 0;
              return _AllocationCard(
                asset: asset,
                weight: weight,
                accent: widget.accent,
                onChanged: (value) {
                  setState(() {
                    _weights[asset.id] = value;
                  });
                },
              );
            },
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: okRange ? _prepareSimulation : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Lancer la simulation'),
          ),
        ),
        const SizedBox(height: 6),
        Text('Tip : vise entre 90% et 100% investi. Le reste en cash.', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
      ],
    );
  }

  Widget _buildSimulation() {
    final steps = _config.timelineLength;
    final progress = (_currentStep + 1) / steps;
    final currentValue = _portfolioHistory.isNotEmpty ? _portfolioHistory.last : _config.initialCash;
    final pnlPct = ((currentValue - _config.initialCash) / _config.initialCash) * 100;
    final drawdownPct = _maxDrawdown * 100;
    final coinDeltaLive = _coinDeltaFromPnl(pnlPct);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Lecture accélérée', style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 16)))),
            Text('${(_currentStep + 1)}/${steps}', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 13))),
          ],
        ),
        const SizedBox(height: 4),
        Text('${_config.durationLabel} • ${_config.stepLabel}', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.black12,
            color: widget.accent,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: coinDeltaLive >= 0 ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(coinDeltaLive >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: coinDeltaLive >= 0 ? Colors.green : Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                '${coinDeltaLive >= 0 ? '+' : ''}$coinDeltaLive coins en jeu',
                style: TextStyle(fontWeight: FontWeight.w700, color: coinDeltaLive >= 0 ? Colors.green : Colors.redAccent),
              ),
              const Spacer(),
              Text('Mise $_stake', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SimulationTicker(
          accent: widget.accent,
          currentValue: currentValue,
          pnlPct: pnlPct,
          drawdownPct: drawdownPct,
          rebalanceUsed: _rebalanceUsed,
          onRebalance: _rebalanceUsed ? null : _rebalanceToCash,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _PriceTape(
            assets: _config.assets,
            step: _currentStep,
            accent: widget.accent,
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _playing ? null : _goDebrief,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_playing ? 'Simulation en cours...' : 'Passer au debrief'),
          ),
        ),
      ],
    );
  }

  Widget _buildDebrief() {
    if (_portfolioHistory.isEmpty) {
      return const Center(child: Text('Aucune simulation enregistrée.'));
    }
    final finalValue = _portfolioHistory.last;
    final pnlPct = ((finalValue - _config.initialCash) / _config.initialCash) * 100;
    final coinDelta = _coinDeltaFromPnl(pnlPct);
    final best = _portfolioHistory.reduce(math.max);
    final worst = _portfolioHistory.reduce(math.min);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Debrief', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _scaledFont(context, 18))),
        const SizedBox(height: 12),
        _StatRow(label: 'Performance', value: '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)} %', highlight: pnlPct >= 0),
        _StatRow(label: 'Valeur finale', value: _fmtCurrency(finalValue)),
        _StatRow(label: 'Max drawdown', value: '${(_maxDrawdown * 100).toStringAsFixed(1)} %'),
        _StatRow(label: 'Pic / creux', value: '${_fmtCurrency(best)} / ${_fmtCurrency(worst)}'),
        _StatRow(label: 'Résultat en coins', value: '${coinDelta >= 0 ? '+' : ''}$coinDelta', highlight: coinDelta >= 0),
        const SizedBox(height: 12),
        Text('Points d’attention', style: TextStyle(fontWeight: FontWeight.w700, fontSize: _scaledFont(context, 15))),
        const SizedBox(height: 8),
        ..._buildLearnings(pnlPct, _maxDrawdown),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_ScenarioResult(pnlPct: pnlPct, coinDelta: coinDelta, stake: _stake)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(widget.completed ? 'Valider (révision)' : 'Valider ce scénario'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _resetForReplay,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: const BorderSide(color: Colors.black)),
            child: const Text('Rejouer avec une autre allocation'),
          ),
        ),
      ],
    );
  }

  void _prepareSimulation() {
    double total = 0;
    _weights.forEach((_, w) => total += w);
    final norm = total > 100 ? 100 / total : 1.0;
    final investedRatio = (total * norm) / 100;
    _positions.clear();
    _cash = _config.initialCash * (1 - investedRatio).clamp(0, 1);
    for (final asset in _config.assets) {
      final weight = (_weights[asset.id] ?? 0) * norm;
      if (weight <= 0) continue;
      final invest = _config.initialCash * (weight / 100);
      final price0 = asset.prices.first;
      if (price0 <= 0) continue;
      _positions[asset.id] = invest / price0;
    }
    _portfolioHistory = [_portfolioValueAt(0)];
    _maxValue = _portfolioHistory.first;
    _maxDrawdown = 0;
    _rebalanceUsed = false;
    _currentStep = 0;
    _phase = _SimulationPhase.play;
    setState(() {});
    _startPlayback();
  }

  void _startPlayback() async {
    if (_playing) return;
    _playing = true;
    for (var i = 1; i < _config.timelineLength; i++) {
      await Future.delayed(Duration(milliseconds: _config.playbackMs));
      if (!mounted) return;
      final value = _portfolioValueAt(i);
      setState(() {
        _currentStep = i;
        _portfolioHistory.add(value);
        _maxValue = math.max(_maxValue, value);
        _maxDrawdown = math.max(_maxDrawdown, (_maxValue - value) / _maxValue);
      });
    }
    if (!mounted) return;
    setState(() {
      _playing = false;
      _phase = _SimulationPhase.debrief;
    });
  }

  void _rebalanceToCash() {
    final priceStep = _currentStep;
    double investedValue = 0;
    for (final asset in _config.assets) {
      final units = _positions[asset.id] ?? 0;
      investedValue += units * asset.prices[priceStep];
    }
    final total = investedValue + _cash;
    if (investedValue == 0) return;
    final targetInvested = total * 0.75;
    final scale = targetInvested / investedValue;
    double newInvested = 0;
    for (final asset in _config.assets) {
      final units = _positions[asset.id] ?? 0;
      final newUnits = units * scale;
      _positions[asset.id] = newUnits;
      newInvested += newUnits * asset.prices[priceStep];
    }
    _cash = total - newInvested;
    _rebalanceUsed = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rééquilibrage effectué : +cash, positions allégées.')),
    );
  }

  void _goDebrief() {
    if (_playing) return;
    setState(() {
      _phase = _SimulationPhase.debrief;
    });
  }

  void _resetForReplay() {
    setState(() {
      _phase = _SimulationPhase.allocate;
      _currentStep = 0;
      _portfolioHistory.clear();
      _positions.clear();
      _cash = _config.initialCash;
      _rebalanceUsed = false;
    });
  }

  int _coinDeltaFromPnl(double pnlPct) {
    final bias = pnlPct >= 0 ? _LearnPageState._winBias : _LearnPageState._lossBias;
    final delta = (_stake * (pnlPct / 100) * bias).round();
    if (delta == 0 && pnlPct.abs() > 0.01) {
      return pnlPct > 0 ? 1 : -1;
    }
    return delta;
  }

  double _portfolioValueAt(int step) {
    double invested = 0;
    for (final asset in _config.assets) {
      final units = _positions[asset.id] ?? 0;
      invested += units * asset.prices[step];
    }
    return invested + _cash;
  }

  List<Widget> _buildLearnings(double pnlPct, double drawdown) {
    final List<String> notes = [];
    if (pnlPct < 0) {
      notes.add('Tes arbitrages n’ont pas évité la perte : teste une version plus défensive ou plus graduelle.');
    } else {
      notes.add('Bonne trajectoire : garde ce modèle et compare-le sur une autre période.');
    }
    if (_rebalanceUsed) {
      notes.add('Tu as rééquilibré en cours de route : note les critères qui t’ont poussé à agir.');
    } else {
      notes.add('Aucun arbitrage mid-simulation : envisage un protocole de rééquilibrage si la volatilité monte.');
    }
    if (drawdown > 0.15) {
      notes.add('Drawdown > 15% : augmente la part de cash/defensif ou protège via couvertures.');
    } else {
      notes.add('Drawdown contenu : bonne discipline de risque.');
    }
    return notes
        .map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(n, style: const TextStyle(height: 1.35))),
                ],
              ),
            ))
        .toList();
  }

  String _fmtCurrency(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)} M€';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} k€';
    return '${value.toStringAsFixed(0)} €';
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({
    required this.asset,
    required this.weight,
    required this.accent,
    required this.onChanged,
  });

  final _SimulationAsset asset;
  final double weight;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.show_chart_rounded, color: Colors.black87),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(asset.role, style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
                  ],
                ),
              ),
              Text('${weight.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _scaledFont(context, 16))),
            ],
          ),
          Slider(
            value: weight,
            min: 0,
            max: 70,
            divisions: 14,
            activeColor: Colors.black,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SimulationTicker extends StatelessWidget {
  const _SimulationTicker({
    required this.accent,
    required this.currentValue,
    required this.pnlPct,
    required this.drawdownPct,
    required this.rebalanceUsed,
    required this.onRebalance,
  });

  final Color accent;
  final double currentValue;
  final double pnlPct;
  final double drawdownPct;
  final bool rebalanceUsed;
  final VoidCallback? onRebalance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valeur', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
                    Text('${currentValue.toStringAsFixed(0)} €', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _scaledFont(context, 18))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('P&L', style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
                  Text(
                    '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)} %',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: _scaledFont(context, 18),
                      color: pnlPct >= 0 ? Colors.green : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded, color: accent),
                    const SizedBox(width: 6),
                    Text('Drawdown ${drawdownPct.toStringAsFixed(1)}%', style: TextStyle(color: _learnMuted)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onRebalance,
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: Text(rebalanceUsed ? 'Rééquilibrage fait' : 'Rééquilibrer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceTape extends StatelessWidget {
  const _PriceTape({
    required this.assets,
    required this.step,
    required this.accent,
  });

  final List<_SimulationAsset> assets;
  final int step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: assets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final asset = assets[index];
        final price = asset.prices[step];
        final start = asset.prices.first;
        final pct = ((price - start) / start) * 100;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(asset.role, style: TextStyle(color: _learnMuted, fontSize: _scaledFont(context, 12))),
                  ],
                ),
              ),
              Text(
                price.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: pct >= 0 ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                  style: TextStyle(color: pct >= 0 ? Colors.green : Colors.redAccent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: _learnMuted))),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: highlight ? Colors.green : Colors.black),
          ),
        ],
      ),
    );
  }
}

class _ScenarioResult {
  const _ScenarioResult({required this.pnlPct, required this.coinDelta, required this.stake});

  final double pnlPct;
  final int coinDelta;
  final int stake;
}

class _SimulationConfig {
  const _SimulationConfig({
    required this.headline,
    required this.periodLabel,
    required this.durationLabel,
    required this.stepLabel,
    required this.initialCash,
    required this.assets,
    required this.cues,
    required this.suggestedAllocation,
    required this.playbackMs,
  });

  final String headline;
  final String periodLabel;
  final String durationLabel;
  final String stepLabel;
  final double initialCash;
  final List<_SimulationAsset> assets;
  final List<String> cues;
  final Map<String, double> suggestedAllocation;
  final int playbackMs;

  int get timelineLength => assets.isEmpty ? 1 : assets.first.prices.length;
}

class _SimulationAsset {
  const _SimulationAsset({
    required this.id,
    required this.label,
    required this.prices,
    required this.role,
  });

  final String id;
  final String label;
  final List<double> prices;
  final String role;
}

_SimulationConfig _simulationConfigFor(_PortfolioScenario scenario) {
  switch (scenario.id) {
    case 'scenario_energy_shock':
      return _SimulationConfig(
        headline: 'Choc pétrolier : teste une allocation entre majors, énergies propres et valeurs sensibles.',
        periodLabel: 'Printemps 2022 — tension géopolitique',
        durationLabel: '6 semaines de stress',
        stepLabel: '1 semaine par pas',
        initialCash: 20000,
        playbackMs: 900,
        assets: const [
          _SimulationAsset(id: 'majors', label: 'ETF majors pétrolières (XLE)', prices: [100, 114, 130, 118, 112, 110], role: 'Énergie intégrée'),
          _SimulationAsset(id: 'renew', label: 'Énergies renouvelables (ICLN)', prices: [100, 92, 85, 88, 94, 98], role: 'Transition verte'),
          _SimulationAsset(id: 'airlines', label: 'Compagnies aériennes (JETS)', prices: [100, 78, 62, 58, 62, 66], role: 'Consommation pétrole'),
          _SimulationAsset(id: 'chemicals', label: 'Chimie / plastiques (BASF/LYB)', prices: [100, 94, 88, 86, 88, 90], role: 'Industries énergivores'),
          _SimulationAsset(id: 'utilities', label: 'Utilities (XLU)', prices: [100, 101, 102, 103, 103, 104], role: 'Défensif dividende'),
          _SimulationAsset(id: 'tankers', label: 'Transport pétrolier (STNG/EURN)', prices: [100, 120, 140, 138, 135, 132], role: 'Logistique pétrole'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'Les majors explosent mais deviennent volatiles.',
          'Les valeurs vertes souffrent puis rebondissent avec les plans de subventions.',
          'Les secteurs gourmands en pétrole se compressent.',
          'Les transporteurs de brut profitent de la tension logistique.',
        ],
        suggestedAllocation: const {
          'majors': 25,
          'renew': 18,
          'airlines': 8,
          'chemicals': 8,
          'utilities': 16,
          'tankers': 10,
          'cash': 15,
        },
      );
    case 'scenario_rate_cut':
      return _SimulationConfig(
        headline: 'Baisse surprise des taux : teste croissance vs financières vs immobilier.',
        periodLabel: 'Réunion banque centrale — choc accommodant',
        durationLabel: '6 semaines post-annonce',
        stepLabel: '1 semaine par pas',
        initialCash: 15000,
        playbackMs: 850,
        assets: const [
          _SimulationAsset(id: 'growth', label: 'Nasdaq 100', prices: [100, 108, 114, 115, 116, 118], role: 'Duration longue'),
          _SimulationAsset(id: 'banks', label: 'Banques US', prices: [100, 98, 94, 93, 94, 95], role: 'Sensibles aux taux'),
          _SimulationAsset(id: 'reit', label: 'REIT US', prices: [100, 104, 108, 110, 111, 112], role: 'Immobilier coté'),
          _SimulationAsset(id: 'treasury', label: 'UST 10Y (prix)', prices: [100, 103, 104, 105, 105, 105], role: 'Taux longs'),
          _SimulationAsset(id: 'russell', label: 'Small caps (Russell 2000)', prices: [100, 104, 106, 107, 108, 109], role: 'Beta domestique'),
          _SimulationAsset(id: 'homebuilders', label: 'Constructeurs maison (ITB)', prices: [100, 105, 110, 112, 113, 113], role: 'Sensibles aux taux immo'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'Les valeurs de croissance se réévaluent vite.',
          'Les banques voient leurs marges se comprimer.',
          'Les REIT bénéficient d’un coût du capital plus faible.',
          'Les small caps réagissent fort à la détente des taux.',
          'Les homebuilders profitent du crédit moins cher.',
        ],
        suggestedAllocation: const {
          'growth': 28,
          'banks': 10,
          'reit': 16,
          'treasury': 14,
          'russell': 12,
          'homebuilders': 10,
          'cash': 10,
        },
      );
    case 'scenario_high_yield':
      return _SimulationConfig(
        headline: 'Stress crédit high yield : spreads qui s’écartent vite, arbitrage HY/IG/cash.',
        periodLabel: 'Écartement de spreads (crédit US)',
        durationLabel: '4 semaines tendues',
        stepLabel: '1 semaine par pas',
        initialCash: 16000,
        playbackMs: 850,
        assets: const [
          _SimulationAsset(id: 'hy', label: 'ETF HY (HYG)', prices: [100, 95, 90, 89, 91, 93], role: 'Crédit spéculatif'),
          _SimulationAsset(id: 'ig', label: 'ETF IG (LQD)', prices: [100, 98, 97, 97, 98, 99], role: 'Crédit qualité'),
          _SimulationAsset(id: 'equity', label: 'S&P 500', prices: [100, 96, 93, 94, 95, 97], role: 'Actions'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1, 1], role: 'Liquidités'),
          _SimulationAsset(id: 'gold', label: 'Or', prices: [100, 102, 103, 104, 104, 105], role: 'Couverture'),
          _SimulationAsset(id: 'em_bond', label: 'Dette EM USD', prices: [100, 96, 93, 92, 93, 94], role: 'Crédit émergent'),
        ],
        cues: const [
          'Le HY se dégrade rapidement, l’IG résiste mieux.',
          'Les actions suivent de près le crédit quand la liquidité se tend.',
          'L’or peut amortir un choc de confiance.',
          'La dette EM en USD souffre de l’aversion au risque.',
        ],
        suggestedAllocation: const {
          'hy': 18,
          'ig': 22,
          'equity': 22,
          'gold': 10,
          'em_bond': 12,
          'cash': 16,
        },
      );
    case 'scenario_covid_crash':
      return _SimulationConfig(
        headline: 'COVID-19 mars 2020 : krach puis rebond partiel. Teste tes arbitrages.',
        periodLabel: 'Mars-avril 2020 (prix normalisés)',
        durationLabel: '8 semaines de crise',
        stepLabel: '1 semaine par pas',
        initialCash: 25000,
        playbackMs: 850,
        assets: const [
          _SimulationAsset(id: 'sp500', label: 'S&P 500', prices: [100, 88, 76, 79, 83, 90, 97, 103], role: 'Actions US'),
          _SimulationAsset(id: 'nasdaq', label: 'Nasdaq 100', prices: [100, 90, 80, 83, 89, 99, 110, 118], role: 'Tech'),
          _SimulationAsset(id: 'xle', label: 'Énergie (XLE)', prices: [100, 75, 55, 50, 56, 64, 70, 76], role: 'Énergie'),
          _SimulationAsset(id: 'jpm', label: 'Banques US (KBE)', prices: [100, 85, 70, 68, 72, 78, 84, 88], role: 'Financières'),
          _SimulationAsset(id: 'xlv', label: 'Santé (XLV)', prices: [100, 98, 96, 100, 104, 110, 115, 118], role: 'Défensif santé'),
          _SimulationAsset(id: 'online', label: 'E-commerce / cloud', prices: [100, 95, 100, 110, 122, 135, 140, 145], role: 'Gagnants confinement'),
          _SimulationAsset(id: 'gold', label: 'Or', prices: [100, 104, 108, 104, 106, 110, 112, 114], role: 'Couverture'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'Les indices chutent brutalement puis rebondissent avec les plans monétaires.',
          'La tech surperforme le S&P dans le rebond.',
          'L’énergie reste sous pression malgré le rallye général.',
          'Les banques restent fragiles malgré le rallye.',
          'Santé et e-commerce tiennent ou surperforment.',
        ],
        suggestedAllocation: const {
          'sp500': 20,
          'nasdaq': 20,
          'xle': 8,
          'jpm': 10,
          'xlv': 12,
          'online': 15,
          'gold': 10,
          'cash': 5,
        },
      );
    case 'scenario_emerging_fx':
      return _SimulationConfig(
        headline: 'Dévaluation émergente : devise locale qui plonge, arbitrage exportateurs/importateurs.',
        periodLabel: 'Crise FX locale',
        durationLabel: '6 semaines',
        stepLabel: '1 semaine par pas',
        initialCash: 15000,
        playbackMs: 850,
        assets: const [
          _SimulationAsset(id: 'export', label: 'Exportateurs nets', prices: [100, 103, 105, 107, 108, 110, 111, 113], role: 'Bénéficie de la dévaluation'),
          _SimulationAsset(id: 'import', label: 'Importateurs nets', prices: [100, 95, 90, 88, 89, 90, 91, 92], role: 'Sensible au FX'),
          _SimulationAsset(id: 'banks_local', label: 'Banques locales', prices: [100, 96, 92, 90, 91, 93, 94, 95], role: 'Tension bilans'),
          _SimulationAsset(id: 'usd_bonds', label: 'Obligations USD', prices: [100, 101, 102, 103, 103, 104, 104, 105], role: 'Refuge'),
          _SimulationAsset(id: 'commod', label: 'Cuivre / matières premières', prices: [100, 99, 97, 96, 98, 101, 103, 105], role: 'Soutien inflation importée'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'La devise locale plonge : les exportateurs résistent mieux.',
          'Les importateurs et banques subissent le choc de financement.',
          'Les obligations USD et le cash stabilisent le portefeuille.',
          'Les commodités peuvent profiter d’un choc d’offre.',
        ],
        suggestedAllocation: const {
          'export': 26,
          'import': 10,
          'banks_local': 12,
          'usd_bonds': 22,
          'commod': 10,
          'cash': 20,
        },
      );
    case 'scenario_taper':
      return _SimulationConfig(
        headline: 'Taper tantrum : taux longs en hausse, duration et EM sous pression.',
        periodLabel: 'Hausse rapide des taux réels',
        durationLabel: '6 semaines',
        stepLabel: '1 semaine par pas',
        initialCash: 16000,
        playbackMs: 850,
        assets: const [
          _SimulationAsset(id: 'ust10', label: 'Oblig. US 10Y (prix)', prices: [100, 98, 96, 95, 95, 96], role: 'Duration'),
          _SimulationAsset(id: 'value', label: 'Value / banques', prices: [100, 101, 102, 103, 103, 104], role: 'Sensibles aux taux'),
          _SimulationAsset(id: 'growth', label: 'Growth/tech', prices: [100, 96, 92, 90, 91, 93], role: 'Duration longue'),
          _SimulationAsset(id: 'em_eq', label: 'Actions émergentes', prices: [100, 97, 93, 92, 92, 93], role: 'EM sensible USD'),
          _SimulationAsset(id: 'tips', label: 'TIPS (indexées inflation)', prices: [100, 101, 102, 103, 103, 104], role: 'Hedge inflation'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'La duration souffre, la value résiste mieux.',
          'L’EM et la tech sont pénalisés par un USD fort et des taux réels en hausse.',
          'Les TIPS et le cash amortissent partiellement.',
        ],
        suggestedAllocation: const {
          'ust10': 10,
          'value': 25,
          'growth': 18,
          'em_eq': 14,
          'tips': 18,
          'cash': 15,
        },
      );
    case 'scenario_usd_spike':
      return _SimulationConfig(
        headline: 'Dollar qui s’envole : arbitrage USD/commod/EM.',
        periodLabel: 'Appétit pour le dollar',
        durationLabel: '5 semaines',
        stepLabel: '1 semaine par pas',
        initialCash: 15000,
        playbackMs: 850,
        assets: const [
          _SimulationAsset(id: 'usd', label: 'USD/DXY proxy', prices: [100, 103, 106, 107, 108], role: 'Devise forte'),
          _SimulationAsset(id: 'commod', label: 'Commodities larges', prices: [100, 97, 94, 93, 94], role: 'Matières premières'),
          _SimulationAsset(id: 'gold', label: 'Or', prices: [100, 100, 99, 99, 100], role: 'Refuge non-USD'),
          _SimulationAsset(id: 'em', label: 'Actions EM', prices: [100, 95, 91, 90, 90], role: 'Risque FX'),
          _SimulationAsset(id: 'export_us', label: 'Exportateurs US', prices: [100, 102, 104, 104, 105], role: 'Bénéfice USD fort'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'Le dollar grimpe, pèse sur EM et certaines commodités.',
          'Les exportateurs US tiennent mieux, or amortit partiellement.',
        ],
        suggestedAllocation: const {
          'usd': 15,
          'commod': 15,
          'gold': 15,
          'em': 18,
          'export_us': 22,
          'cash': 15,
        },
      );
    case 'scenario_ai_craze':
      return _SimulationConfig(
        headline: 'Bull IA : rotation violente vers semi/IA, valorisations sous tension.',
        periodLabel: 'Phase euphorique IA',
        durationLabel: '5 semaines',
        stepLabel: '1 semaine par pas',
        initialCash: 20000,
        playbackMs: 800,
        assets: const [
          _SimulationAsset(id: 'semi', label: 'Semi & GPU (SOXX/NVDA)', prices: [100, 112, 122, 130, 135], role: 'Coeur IA'),
          _SimulationAsset(id: 'cloud', label: 'Cloud / hyperscalers', prices: [100, 105, 110, 114, 116], role: 'Infra IA'),
          _SimulationAsset(id: 'legacy', label: 'Tech legacy', prices: [100, 100, 98, 97, 98], role: 'Lagging'),
          _SimulationAsset(id: 'value', label: 'Value / industrielles', prices: [100, 101, 102, 102, 103], role: 'Diversification'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'Les semi mènent la danse, le cloud suit.',
          'Tech legacy traîne, value reste neutre.',
          'Gérer prise de profits et concentration.',
        ],
        suggestedAllocation: const {
          'semi': 32,
          'cloud': 24,
          'legacy': 10,
          'value': 14,
          'cash': 20,
        },
      );
    case 'scenario_europe_gas':
      return _SimulationConfig(
        headline: 'Choc gaz Europe : coût de l’énergie en flèche.',
        periodLabel: 'Stress gaz EU',
        durationLabel: '6 semaines',
        stepLabel: '1 semaine par pas',
        initialCash: 17000,
        playbackMs: 900,
        assets: const [
          _SimulationAsset(id: 'utilities', label: 'Utilities régulées EU', prices: [100, 101, 102, 102, 103, 104], role: 'Défensif'),
          _SimulationAsset(id: 'chem', label: 'Chimie EU', prices: [100, 95, 88, 86, 87, 88], role: 'Énergivore'),
          _SimulationAsset(id: 'industrials', label: 'Industriels EU (auto/siderurgie)', prices: [100, 96, 92, 90, 91, 92], role: 'Sensibles coût gaz'),
          _SimulationAsset(id: 'lng', label: 'Transport LNG / exportateurs gaz', prices: [100, 112, 120, 124, 124, 122], role: 'Gagnants du choc'),
          _SimulationAsset(id: 'renew', label: 'Renouvelables EU', prices: [100, 97, 94, 95, 98, 101], role: 'Transition'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'Les énergivores souffrent, les transporteurs LNG gagnent.',
          'Les utilities régulées amortissent, les renouvelables rebondissent.',
        ],
        suggestedAllocation: const {
          'utilities': 18,
          'chem': 10,
          'industrials': 12,
          'lng': 24,
          'renew': 16,
          'cash': 20,
        },
      );
    case 'scenario_vol_spike':
      return _SimulationConfig(
        headline: 'Volatilité en explosion : protège le portefeuille et arbitre la tech.',
        periodLabel: 'VIX > 35 — flux vers défensifs',
        durationLabel: '2 semaines de stress',
        stepLabel: '2 jours par pas',
        initialCash: 18000,
        playbackMs: 800,
        assets: const [
          _SimulationAsset(id: 'index', label: 'S&P 500', prices: [100, 92, 88, 89, 91, 93], role: 'Exposure marché'),
          _SimulationAsset(id: 'staples', label: 'Consommation de base', prices: [100, 101, 102, 102, 103, 104], role: 'Défensif'),
          _SimulationAsset(id: 'tech', label: 'Tech momentum', prices: [100, 85, 80, 78, 80, 83], role: 'Cyclicité'),
          _SimulationAsset(id: 'hedge', label: 'ETF VIX / hedge', prices: [100, 135, 160, 150, 135, 125], role: 'Couverture'),
          _SimulationAsset(id: 'gold', label: 'Or', prices: [100, 102, 103, 103, 104, 105], role: 'Refuge'),
          _SimulationAsset(id: 'smallcaps', label: 'Small caps US', prices: [100, 90, 86, 84, 86, 88], role: 'Beta élevé'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'Les indices plongent puis se stabilisent.',
          'Les défensifs tiennent mieux le choc.',
          'Les couvertures gagnent vite puis se dégonflent.',
          'L’or amortit partiellement le stress.',
        ],
        suggestedAllocation: const {
          'index': 22,
          'staples': 22,
          'tech': 12,
          'hedge': 14,
          'gold': 10,
          'smallcaps': 10,
          'cash': 10,
        },
      );
    case 'scenario_growth':
      return _SimulationConfig(
        headline: 'Tech en repli après warning : arbitre entre growth, value et cash.',
        periodLabel: 'Guidance prudente d’un leader SaaS',
        durationLabel: '6 semaines de digestion',
        stepLabel: '1 semaine par pas',
        initialCash: 18000,
        playbackMs: 850,
        assets: const [
          _SimulationAsset(id: 'saas', label: 'SaaS high growth', prices: [100, 94, 88, 86, 89, 93, 97, 102], role: 'Croissance'),
          _SimulationAsset(id: 'semis', label: 'Semi-conducteurs', prices: [100, 96, 92, 91, 94, 99, 104, 108], role: 'Cyclique tech'),
          _SimulationAsset(id: 'value', label: 'Value US (DJI)', prices: [100, 101, 102, 103, 104, 105, 106, 107], role: 'Pilier défensif'),
          _SimulationAsset(id: 'cyber', label: 'Cyber / software (HACK)', prices: [100, 92, 88, 87, 90, 95, 100, 106], role: 'Sous-segment tech'),
          _SimulationAsset(id: 'staples', label: 'Consommation de base', prices: [100, 101, 102, 103, 104, 105, 106, 107], role: 'Défensif'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'Les multiples se compressent vite sur le SaaS.',
          'Les semi-conducteurs suivent la macro mais rebondissent souvent plus tôt.',
          'La value amortit le choc mais peut sous-performer si le rebond est puissant.',
          'Les sous-segments (cyber/software) peuvent diverger du SaaS large.',
        ],
        suggestedAllocation: const {
          'saas': 24,
          'semis': 22,
          'value': 18,
          'cyber': 12,
          'staples': 12,
          'cash': 12,
        },
      );
    default:
      return _SimulationConfig(
        headline: 'Stress multi-actifs : compose ton mix puis teste-le sur un choc court.',
        periodLabel: 'Simulation rapide (mini stress-test)',
        durationLabel: '6 pas (~6 semaines)',
        stepLabel: '1 semaine par pas',
        initialCash: 12000,
        playbackMs: 800,
        assets: const [
          _SimulationAsset(id: 'equity', label: 'Actions monde (ACWI)', prices: [100, 96, 94, 95, 96, 98], role: 'Noyau MSCI'),
          _SimulationAsset(id: 'em', label: 'Actions émergentes', prices: [100, 95, 91, 90, 91, 92], role: 'EM sensible FX'),
          _SimulationAsset(id: 'small', label: 'Small caps dev.', prices: [100, 96, 92, 91, 92, 94], role: 'Beta'),
          _SimulationAsset(id: 'value', label: 'Value / Cycliques', prices: [100, 98, 95, 94, 96, 98], role: 'Cycliques'),
          _SimulationAsset(id: 'quality', label: 'Qualité', prices: [100, 101, 102, 102, 103, 104], role: 'Défensif'),
          _SimulationAsset(id: 'gold', label: 'Or', prices: [100, 103, 106, 107, 108, 109], role: 'Couverture'),
          _SimulationAsset(id: 'inflation', label: 'Obligations indexées', prices: [100, 101, 102, 102, 103, 103], role: 'Inflation hedge'),
          _SimulationAsset(id: 'cash', label: 'Cash', prices: [1, 1, 1, 1, 1, 1], role: 'Liquidités'),
        ],
        cues: const [
          'Teste un mix cœur + hedge pour amortir la chute.',
          'Observe la différence entre valeur, qualité et couverture.',
        ],
        suggestedAllocation: const {
          'equity': 22,
          'em': 12,
          'small': 12,
          'value': 14,
          'quality': 12,
          'gold': 10,
          'inflation': 8,
          'cash': 10,
        },
      );
  }
}

class _LearningStage {
  const _LearningStage({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.locked = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool locked;
}

class _MiniLesson {
  const _MiniLesson({
    required this.id,
    required this.stageId,
    required this.title,
    required this.summary,
    required this.duration,
    required this.rewardXp,
    required this.icon,
    required this.bulletPoints,
  });

  final String id;
  final String stageId;
  final String title;
  final String summary;
  final String duration;
  final int rewardXp;
  final IconData icon;
  final List<String> bulletPoints;
}

class _LessonSection {
  const _LessonSection({
    required this.title,
    required this.description,
    required this.bullets,
    required this.icon,
  });

  final String title;
  final String description;
  final List<String> bullets;
  final IconData icon;
}

class _LessonExample {
  const _LessonExample({required this.title, required this.description});

  final String title;
  final String description;
}

String _lessonSubject(_MiniLesson lesson) {
  final raw = lesson.title.trim();
  if (raw.isEmpty) return 'la thématique';
  if (raw.length == 1) return raw.toLowerCase();
  return '${raw[0].toLowerCase()}${raw.substring(1)}';
}

List<String> _fillTemplates(String subject, List<String> templates) {
  return templates.map((template) => template.replaceAll('{subject}', subject)).toList();
}

List<_LessonSection> _buildFundamentalSections(_MiniLesson lesson) {
  final subject = _lessonSubject(lesson);
  return [
    _LessonSection(
      title: 'Diagnostic express',
      description: 'Passe $subject au crible des états financiers et du cash.',
      bullets: _fillTemplates(subject, [
        'Compare l’évolution du chiffre d’affaires et des marges pour {subject}.',
        'Relis la qualité du cash-flow libre à la dette nette.',
        'Cherche les signaux d’alerte dans le BFR ou les provisions.',
      ]),
      icon: Icons.data_thresholding_rounded,
    ),
    _LessonSection(
      title: 'Questions structurantes',
      description: '3 angles pour décider si tu poursuis l’analyse.',
      bullets: _fillTemplates(subject, [
        'Quel est le moteur principal de {subject} (pricing, volume, mix) ?',
        'Les investissements annoncés améliorent-ils la compétitivité de {subject} ?',
        'La valorisation actuelle intègre-t-elle déjà les catalyseurs de {subject} ?',
      ]),
      icon: Icons.fact_check_rounded,
    ),
    _LessonSection(
      title: 'Plan d’action',
      description: 'Transforme la théorie en plan concret.',
      bullets: _fillTemplates(subject, [
        'Construis deux scénarios (prudent / ambitieux) pour {subject}.',
        'Prépare un tableau de suivi des KPI qui influent sur {subject}.',
        'Note les conditions de sortie si la thèse {subject} se dégrade.',
      ]),
      icon: Icons.playlist_add_check_rounded,
    ),
  ];
}

List<_LessonSection> _buildTechnicalSections(_MiniLesson lesson) {
  final subject = _lessonSubject(lesson);
  return [
    _LessonSection(
      title: 'Plan graphique',
      description: 'Décompose $subject en séquence de prix lisible.',
      bullets: _fillTemplates(subject, [
        'Repère le range dominant autour de {subject}.',
        'Dessine les niveaux de validation/invalidation pour {subject}.',
        'Observe le volume relatif et les indicateurs de momentum.',
      ]),
      icon: Icons.stacked_line_chart,
    ),
    _LessonSection(
      title: 'Tempo & gestion',
      description: 'Anticipe l’exécution AVANT d’appuyer sur “acheter/vendre”.',
      bullets: _fillTemplates(subject, [
        'Prévois au moins deux points d’entrée possibles sur {subject}.',
        'Définis un ratio gain/risque réaliste en fonction de la structure de {subject}.',
        'Prépare une sortie partielle si {subject} accélère plus vite que prévu.',
      ]),
      icon: Icons.speed_rounded,
    ),
    _LessonSection(
      title: 'Pièges fréquents',
      description: 'Reste lucide lorsque le marché teste ta patience.',
      bullets: _fillTemplates(subject, [
        'Ne confonds pas simple mèche et cassure validée sur {subject}.',
        'Évite d’augmenter la taille tant que {subject} n’a pas confirmé son mouvement.',
        'Couple la lecture graphique avec le flux news lié à {subject}.',
      ]),
      icon: Icons.warning_amber_rounded,
    ),
  ];
}

List<_LessonSection> _buildIntuitionSections(_MiniLesson lesson) {
  final subject = _lessonSubject(lesson);
  return [
    _LessonSection(
      title: 'Agenda macro',
      description: 'Identifie les évènements qui pèsent sur $subject.',
      bullets: _fillTemplates(subject, [
        'Associe {subject} à trois indicateurs macro (taux, inflation, devise).',
        'Classe les publications essentielles par ordre d’impact.',
        'Prépare un plan communication pour expliquer {subject} à ton entourage/clients.',
      ]),
      icon: Icons.event_note_rounded,
    ),
    _LessonSection(
      title: 'Stress tests',
      description: 'Projette plusieurs contextes macro pour $subject.',
      bullets: _fillTemplates(subject, [
        'Simule un choc de +100 pb sur les taux et mesure l’effet sur {subject}.',
        'Imagine un scénario “surprise” (politique, géopolitique, COP) lié à {subject}.',
        'Note quelles positions du portefeuille amortissent ou amplifient {subject}.',
      ]),
      icon: Icons.analytics_rounded,
    ),
    _LessonSection(
      title: 'Décisions rapides',
      description: 'Formalise ce que tu feras si la situation bouge.',
      bullets: _fillTemplates(subject, [
        'Fixe trois seuils d’alerte chiffrés pour {subject}.',
        'Prépare un message type pour expliquer ton arbitrage sur {subject}.',
        'Ajoute {subject} à ton calendrier d’alertes avec rappel mobile.',
      ]),
      icon: Icons.bolt_rounded,
    ),
  ];
}

List<_LessonSection> _buildHistorySections(_MiniLesson lesson) {
  final subject = _lessonSubject(lesson);
  return [
    _LessonSection(
      title: 'Leçons du passé',
      description: 'Fais dialoguer $subject avec les grandes crises.',
      bullets: _fillTemplates(subject, [
        'Identifie un épisode historique similaire à {subject}.',
        'Compare la structure de marché passée à celle de {subject} aujourd’hui.',
        'Repère les catalyseurs qui avaient accéléré la résolution.',
      ]),
      icon: Icons.history_edu_rounded,
    ),
    _LessonSection(
      title: 'Transposition 2024',
      description: 'Adapte l’enseignement historique aux outils actuels.',
      bullets: _fillTemplates(subject, [
        'Quels indicateurs modernes (liquidité, flux ETF) peuvent suivre {subject} ?',
        'Quelle communication institutionnelle pourrait apaiser {subject} ?',
        'Quels secteurs servaient de refuge la dernière fois pour {subject} ?',
      ]),
      icon: Icons.compare_rounded,
    ),
    _LessonSection(
      title: 'Filet de sécurité',
      description: 'Prépare-toi mentalement à revivre le stress.',
      bullets: _fillTemplates(subject, [
        'Élabore une règle “si X se reproduit alors Y” pour {subject}.',
        'Découpe le plan d’action en tâches simples à cocher.',
        'Garde une to-do de vérifications pour valider ou invalider {subject}.',
      ]),
      icon: Icons.health_and_safety_rounded,
    ),
  ];
}

List<_LessonSection> _buildPsychologySections(_MiniLesson lesson) {
  final subject = _lessonSubject(lesson);
  return [
    _LessonSection(
      title: 'Routine mentale',
      description: 'Crée un rituel avant d’attaquer $subject.',
      bullets: _fillTemplates(subject, [
        'Respire 2 minutes et définis l’intention de la session {subject}.',
        'Évalue ton niveau d’énergie et adapte la taille des prises de décision.',
        'Prépare une checklist émotionnelle (stress, excitation) avant {subject}.',
      ]),
      icon: Icons.self_improvement_rounded,
    ),
    _LessonSection(
      title: 'Biais à surveiller',
      description: 'Identifie ce qui peut saboter ton plan.',
      bullets: _fillTemplates(subject, [
        'Repère les situations où tu sur-réagis sur {subject}.',
        'Mets un garde-fou quand tu as envie d’augmenter rapidement {subject}.',
        'Partage ton plan {subject} avec un pair pour garder un regard externe.',
      ]),
      icon: Icons.psychology_rounded,
    ),
    _LessonSection(
      title: 'Discipline & suivi',
      description: 'Assure-toi que les actions prévues sont exécutées.',
      bullets: _fillTemplates(subject, [
        'Consigne chaque décision liée à {subject} dans ton journal.',
        'Bloque une plage pour débriefer à froid cette leçon {subject}.',
        'Planifie une récompense positive quand tu respectes ton protocole.',
      ]),
      icon: Icons.fact_check_outlined,
    ),
  ];
}

List<_LessonSection> _buildEsgSections(_MiniLesson lesson) {
  final subject = _lessonSubject(lesson);
  return [
    _LessonSection(
      title: 'Enjeux de transition',
      description: 'Cartographie l’impact climatique ou social de $subject.',
      bullets: _fillTemplates(subject, [
        'Liste les objectifs officiels associés à {subject}.',
        'Identifie gagnants/perdants si les régulateurs accélèrent sur {subject}.',
        'Croise {subject} avec les scénarios COP / Fit for 55 / taxonomie.',
      ]),
      icon: Icons.eco_rounded,
    ),
    _LessonSection(
      title: 'KPI à suivre',
      description: 'Crée un tableau de bord ESG actionnable.',
      bullets: _fillTemplates(subject, [
        'Quelle métrique prouve la crédibilité de {subject} (capex verts, intensity carbone) ?',
        'Comment {subject} se compare-t-il aux pairs responsables ?',
        'Quels signaux d’alerte pourraient faire dérailler {subject} ?',
      ]),
      icon: Icons.assessment_rounded,
    ),
    _LessonSection(
      title: 'Intégration portefeuille',
      description: 'Ajoute $subject à la sélection investissement.',
      bullets: _fillTemplates(subject, [
        'Définis un seuil minimum de notation interne pour {subject}.',
        'Ajoute {subject} aux notes préparant les comités d’investissement.',
        'Planifie les sources gratuites (rapports COP, ONG) pour vérifier {subject}.',
      ]),
      icon: Icons.folder_shared_rounded,
    ),
  ];
}

List<_LessonSection> _buildDerivativeSections(_MiniLesson lesson) {
  final subject = _lessonSubject(lesson);
  return [
    _LessonSection(
      title: 'Lecture de volatilité',
      description: 'Comprends dans quel régime appliquer $subject.',
      bullets: _fillTemplates(subject, [
        'Mappe la volatilité implicite vs réalisée pour {subject}.',
        'Note l’impact des skew/smile sur le prix de {subject}.',
        'Identifie les variables qui font varier la prime (taux, dividendes).',
      ]),
      icon: Icons.multiline_chart_rounded,
    ),
    _LessonSection(
      title: 'Paramétrage de la stratégie',
      description: 'Calibre précisément ta couverture ou ton pari directionnel.',
      bullets: _fillTemplates(subject, [
        'Définis la taille notionnelle optimale pour {subject}.',
        'Calcule le breakeven et la perte maximale sur {subject}.',
        'Prépare un plan de “roll” ou de débouclage anticipé de {subject}.',
      ]),
      icon: Icons.tune_rounded,
    ),
    _LessonSection(
      title: 'Contrôle du risque',
      description: 'Surveille la cohérence avec le portefeuille global.',
      bullets: _fillTemplates(subject, [
        'Mesure l’impact de {subject} sur la VaR du portefeuille.',
        'Prépare une couverture secondaire si {subject} devient trop coûteux.',
        'Documente les hypothèses pour pouvoir les challenger plus tard.',
      ]),
      icon: Icons.shield_rounded,
    ),
  ];
}

List<_LessonSection> _buildGenericSections(_MiniLesson lesson) {
  final subject = _lessonSubject(lesson);
  return [
    _LessonSection(
      title: 'Synthèse',
      description: lesson.summary,
      bullets: lesson.bulletPoints,
      icon: Icons.menu_book_rounded,
    ),
    _LessonSection(
      title: 'Application concrète',
      description: 'Relie $subject à tes positions actuelles.',
      bullets: _fillTemplates(subject, [
        'Associe {subject} à une valeur précise de ton portefeuille.',
        'Définis ce qui validera ou invalidera {subject}.',
        'Prends une note pour partager {subject} avec un ami/communauté.',
      ]),
      icon: Icons.lightbulb_outline,
    ),
  ];
}

List<_LessonExample> _buildFundamentalExamples(_MiniLesson lesson) {
  return [
    _LessonExample(
      title: 'Mini DCF sur ${lesson.title}',
      description: 'Projette deux scénarios de croissance et observe la sensibilité de la valeur intrinsèque.',
    ),
    _LessonExample(
      title: 'Comparaison sectorielle',
      description: 'Compare trois pairs sur marge, leverage et cash-flow pour mettre ${lesson.title} en perspective.',
    ),
    _LessonExample(
      title: 'Stress-test des marges',
      description: 'Diminue d’un point la marge opérationnelle et mesure l’impact sur le BPA projeté.',
    ),
  ];
}

List<_LessonExample> _buildTechnicalExamples(_MiniLesson lesson) {
  return [
    _LessonExample(
      title: 'Scénario H4',
      description: 'Trace les niveaux clés sur un graphique 4h de ${lesson.title} et prépare trois alertes.',
    ),
    _LessonExample(
      title: 'Replay du breakout',
      description: 'Analyse ce qui s’est passé lors de la précédente cassure majeure sur ${lesson.title}.',
    ),
    _LessonExample(
      title: 'Journal visuel',
      description: 'Capture avant/après et annote la psychologie ressentie durant le trade.',
    ),
  ];
}

List<_LessonExample> _buildIntuitionExamples(_MiniLesson lesson) {
  return [
    _LessonExample(
      title: 'Agenda macro personnalisé',
      description: 'Crée une vue calendrier avec les annonces qui influencent ${lesson.title}.',
    ),
    _LessonExample(
      title: 'Radar news intelligent',
      description: 'Filtre 5 sources gratuites (Yahoo, newsletters, podcasts) pour suivre ${lesson.title}.',
    ),
    _LessonExample(
      title: 'Synthèse de scénario',
      description: 'Écris en 5 lignes ce que tu ferais si un choc inattendu touchait ${lesson.title}.',
    ),
  ];
}

List<_LessonExample> _buildHistoryExamples(_MiniLesson lesson) {
  return [
    _LessonExample(
      title: 'Parallèle historique',
      description: 'Choisis un précédent similaire et liste les points communs/différences avec ${lesson.title}.',
    ),
    _LessonExample(
      title: 'Signal avant-coureur',
      description: 'Quel indicateur avait prévenu la dernière fois ? Ajoute-le à ton tableau de bord.',
    ),
    _LessonExample(
      title: 'Plan de protection',
      description: 'Définis comment couvrir ton portefeuille si la crise se répétait sur ${lesson.title}.',
    ),
  ];
}

List<_LessonExample> _buildPsychologyExamples(_MiniLesson lesson) {
  return [
    _LessonExample(
      title: 'Routine 5 minutes',
      description: 'Note trois respirations, un objectif et un rappel positif avant d’étudier ${lesson.title}.',
    ),
    _LessonExample(
      title: 'Débrief émotionnel',
      description: 'Après la séance, écris ce que tu as ressenti sur ${lesson.title} et pourquoi.',
    ),
    _LessonExample(
      title: 'Contrôle du sizing',
      description: 'Associe la taille de position à ton niveau de confiance et reste fidèle au plan.',
    ),
  ];
}

List<_LessonExample> _buildEsgExamples(_MiniLesson lesson) {
  return [
    _LessonExample(
      title: 'Impact COP',
      description: 'Simule comment la prochaine COP pourrait modifier les flux sur ${lesson.title}.',
    ),
    _LessonExample(
      title: 'Cartographie parties prenantes',
      description: 'Liste régulateurs, ONG et clients qui influencent ${lesson.title}.',
    ),
    _LessonExample(
      title: 'Score maison',
      description: 'Attribue une note interne (0-5) à ${lesson.title} et justifie-la avec des données publiques.',
    ),
  ];
}

List<_LessonExample> _buildDerivativeExamples(_MiniLesson lesson) {
  return [
    _LessonExample(
      title: 'Simulation de payoff',
      description: 'Trace un payoff simplifié de ${lesson.title} et note les points morts.',
    ),
    _LessonExample(
      title: 'Volatilité implicite vs réalisée',
      description: 'Récupère deux séries gratuites (Yahoo) et compare-les pour ${lesson.title}.',
    ),
    _LessonExample(
      title: 'Couverture multi-actifs',
      description: 'Associe ${lesson.title} à l’indice ou la matière première qui l’équilibre le mieux.',
    ),
  ];
}

List<_LessonExample> _buildGenericExamples(_MiniLesson lesson) {
  return [
    _LessonExample(
      title: 'Application immédiate',
      description: 'Choisis une valeur favorite et applique pas à pas cette leçon.',
    ),
    _LessonExample(
      title: 'Explication à un pair',
      description: 'Enregistre un vocal ou un post résumant ${lesson.title}.',
    ),
  ];
}

class _DailyChallenge {
  const _DailyChallenge({
    required this.id,
    required this.stageId,
    required this.title,
    required this.description,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.rationale,
    required this.rewardXp,
    required this.tag,
  });

  final String id;
  final String stageId;
  final String title;
  final String description;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String rationale;
  final int rewardXp;
  final String tag;
}

class _QuizCardData {
  const _QuizCardData({
    required this.id,
    required this.stageId,
    required this.category,
    required this.rewardXp,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String id;
  final String stageId;
  final String category;
  final int rewardXp;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class _PortfolioScenario {
  const _PortfolioScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.focus,
    required this.risk,
    required this.stageId,
    required this.rewardXp,
    required this.prompts,
  });

  final String id;
  final String title;
  final String description;
  final String focus;
  final String risk;
  final String stageId;
  final int rewardXp;
  final List<String> prompts;
}

List<_MiniLesson> _buildGeneratedLessons() {
  final lessons = <_MiniLesson>[];
  for (final template in _lessonTemplates) {
    for (final topic in template.topics) {
      final id = '${template.idPrefix}_${_slugify(topic)}';
      lessons.add(
        _MiniLesson(
          id: id,
          stageId: template.stageId,
          title: template.titlePattern.replaceAll('{topic}', topic),
          summary: template.summaryPattern.replaceAll('{topic}', topic),
          duration: template.duration,
          rewardXp: template.rewardXp,
          icon: template.icon,
          bulletPoints:
              template.bulletPatterns
                  .map((pattern) => pattern.replaceAll('{topic}', topic))
                  .toList(),
        ),
      );
    }
  }
  return lessons;
}

List<_QuizCardData> _buildGeneratedQuiz() {
  final quiz = <_QuizCardData>[];
  for (final template in _quizTemplates) {
    for (final topic in template.topics) {
      final id = '${template.idPrefix}_${_slugify(topic)}';
      quiz.add(
        _QuizCardData(
          id: id,
          stageId: template.stageId,
          category: template.category,
          rewardXp: template.rewardXp,
          question: template.questionPattern.replaceAll('{topic}', topic),
          options:
              template.options
                  .map((option) => option.replaceAll('{topic}', topic))
                  .toList(),
          correctIndex: template.correctIndex,
          explanation:
              template.explanationPattern.replaceAll('{topic}', topic),
        ),
      );
    }
  }
  return quiz;
}

List<_PortfolioScenario> _buildGeneratedScenarios() {
  final scenarios = <_PortfolioScenario>[];
  for (final template in _scenarioTemplates) {
    for (final topic in template.topics) {
      final id = '${template.idPrefix}_${_slugify(topic)}';
      scenarios.add(
        _PortfolioScenario(
          id: id,
          title: template.titlePattern.replaceAll('{topic}', topic),
          description: template.descriptionPattern.replaceAll('{topic}', topic),
          focus: template.focus,
          risk: template.risk,
          stageId: template.stageId,
          rewardXp: template.rewardXp,
          prompts:
              template.promptPatterns
                  .map((prompt) => prompt.replaceAll('{topic}', topic))
                  .toList(),
        ),
      );
    }
  }
  return scenarios;
}

String _slugify(String input) {
  var lower = input.toLowerCase();
  const replacements = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  replacements.forEach((key, value) {
    lower = lower.replaceAll(key, value);
  });
  final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final normalized = cleaned.replaceAll(RegExp(r'_+'), '_');
  return normalized.replaceAll(RegExp(r'^_|_$'), '');
}

class _LessonTemplateData {
  const _LessonTemplateData({
    required this.idPrefix,
    required this.stageId,
    required this.titlePattern,
    required this.summaryPattern,
    required this.duration,
    required this.rewardXp,
    required this.icon,
    required this.bulletPatterns,
    required this.topics,
  });

  final String idPrefix;
  final String stageId;
  final String titlePattern;
  final String summaryPattern;
  final String duration;
  final int rewardXp;
  final IconData icon;
  final List<String> bulletPatterns;
  final List<String> topics;
}

class _QuizTemplateData {
  const _QuizTemplateData({
    required this.idPrefix,
    required this.stageId,
    required this.category,
    required this.rewardXp,
    required this.questionPattern,
    required this.options,
    required this.correctIndex,
    required this.explanationPattern,
    required this.topics,
  });

  final String idPrefix;
  final String stageId;
  final String category;
  final int rewardXp;
  final String questionPattern;
  final List<String> options;
  final int correctIndex;
  final String explanationPattern;
  final List<String> topics;
}

class _ScenarioTemplateData {
  const _ScenarioTemplateData({
    required this.idPrefix,
    required this.titlePattern,
    required this.descriptionPattern,
    required this.focus,
    required this.risk,
    required this.stageId,
    required this.rewardXp,
    required this.promptPatterns,
    required this.topics,
  });

  final String idPrefix;
  final String titlePattern;
  final String descriptionPattern;
  final String focus;
  final String risk;
  final String stageId;
  final int rewardXp;
  final List<String> promptPatterns;
  final List<String> topics;
}

const List<_LessonTemplateData> _lessonTemplates = [
  _LessonTemplateData(
    idPrefix: 'lesson_sector_margin',
    stageId: 'fundamentals',
    titlePattern: 'Analyse de marge – {topic}',
    summaryPattern: 'Comprendre comment la marge nette évolue pour {topic}.',
    duration: '5 min',
    rewardXp: 8,
    icon: Icons.trending_up_rounded,
    bulletPatterns: [
      'Compare la marge de {topic} à celle des pairs.',
      'Identifie les coûts variables qui pèsent sur {topic}.',
      'Décide si la compression de marge est temporaire ou structurelle.',
    ],
    topics: [
      'les constructeurs automobiles',
      'les acteurs du luxe',
      'les banques de détail',
      'les plateformes e-commerce',
      'les utilities européennes',
      'les sociétés de semi-conducteurs',
      'les maisons de cosmétiques',
      'les industriels aéronautiques',
    ],
  ),
  _LessonTemplateData(
    idPrefix: 'lesson_chart_patterns',
    stageId: 'technical',
    titlePattern: 'Lire la figure graphique {topic}',
    summaryPattern: 'Savoir confirmer ou invalider {topic}.',
    duration: '5 min',
    rewardXp: 8,
    icon: Icons.show_chart_rounded,
    bulletPatterns: [
      'Repère les volumes associés à {topic}.',
      'Place un stop cohérent sous/au-dessus du niveau clé.',
      'Utilise un objectif de prix basé sur la hauteur de la figure.',
    ],
    topics: [
      'épaule-tête-épaule',
      'double creux',
      'canal haussier',
      'triangle symétrique',
      'drapeau',
      'biseau descendant',
    ],
  ),
  _LessonTemplateData(
    idPrefix: 'lesson_psy_focus',
    stageId: 'psychology',
    titlePattern: 'Routine mentale – {topic}',
    summaryPattern: 'Verrouille un rituel pour {topic}.',
    duration: '4 min',
    rewardXp: 7,
    icon: Icons.self_improvement_rounded,
    bulletPatterns: [
      'Prépare ton plan de session {topic} avec 3 objectifs.',
      'Définis un signal clair pour interrompre {topic} si tu perds ta lucidité.',
      'Fais un débrief écrit après la séquence {topic}.',
    ],
    topics: [
      'du matin',
      'de midi',
      'de clôture',
      'du week-end',
      'après une série de gains',
      'après une série de pertes',
    ],
  ),
  _LessonTemplateData(
    idPrefix: 'lesson_esg_theme',
    stageId: 'esg',
    titlePattern: 'Thèse ESG – {topic}',
    summaryPattern: 'Anticipe les implications d’un focus {topic}.',
    duration: '5 min',
    rewardXp: 8,
    icon: Icons.eco_rounded,
    bulletPatterns: [
      'Mappe les gagnants et perdants si {topic} est favorisé.',
      'Contrôle les capex annoncés pour répondre à {topic}.',
      'Intègre les risques réglementaires liés à {topic}.',
    ],
    topics: [
      'hydrogène vert',
      'captation de CO₂',
      'biodiversité',
      'recyclage des batteries',
      'sobriété énergétique',
      'mobilité douce',
    ],
  ),
  _LessonTemplateData(
    idPrefix: 'lesson_derivatives_strategy',
    stageId: 'derivatives',
    titlePattern: 'Stratégie options – {topic}',
    summaryPattern: 'Comprendre quand utiliser {topic}.',
    duration: '5 min',
    rewardXp: 9,
    icon: Icons.swap_calls_rounded,
    bulletPatterns: [
      'Identifie l’environnement de volatilité idéal pour {topic}.',
      'Calcule le coût net et le point mort de {topic}.',
      'Planifie le unwind avant l’échéance pour {topic}.',
    ],
    topics: [
      'straddle',
      'strangle',
      'butterfly',
      'ratio put spread',
      'covered call dynamique',
      'iron condor',
    ],
  ),
  _LessonTemplateData(
    idPrefix: 'lesson_macro_region',
    stageId: 'intuition',
    titlePattern: 'Lecture macro – {topic}',
    summaryPattern: 'Les indicateurs prioritaires pour {topic}.',
    duration: '5 min',
    rewardXp: 8,
    icon: Icons.public_rounded,
    bulletPatterns: [
      'Suit les PMI/ISM de {topic}.',
      'Observe l’inflation cœur de {topic}.',
      'Analyse les politiques budgétaires en cours dans {topic}.',
    ],
    topics: [
      'États-Unis',
      'Zone euro',
      'Chine',
      'Inde',
      'Brésil',
      'Afrique du Sud',
    ],
  ),
];

const List<String> _quizSectorTopics = [
  'l’énergie',
  'le luxe',
  'la banque de détail',
  'les fintechs',
  'les semi-conducteurs',
  'la cybersécurité',
  'le tourisme',
  'l’aéronautique',
  'les utilities',
  'les jeux vidéo',
  'la santé numérique',
  'les constructeurs auto',
  'les plateformes e-commerce',
  'les médias',
  'l’agroalimentaire',
  'les mines',
  'les cryptomonnaies',
  'les REIT européens',
  'la logistique',
  'les assurances',
];

const List<String> _quizEsgTopics = [
  'l’hydrogène',
  'les batteries',
  'l’éolien offshore',
  'le solaire résidentiel',
  'l’économie circulaire',
  'la biodiversité',
  'les forêts tropicales',
  'la sobriété énergétique',
  'les obligations vertes',
  'les normes CSRD',
];

const List<_QuizTemplateData> _quizTemplates = [
  _QuizTemplateData(
    idPrefix: 'quiz_fcf_dividende',
    stageId: 'fundamentals',
    category: 'Fondamental',
    rewardXp: 18,
    questionPattern: 'Pour {topic}, quel indicateur confirme la capacité à financer un dividende croissant ?',
    options: [
      'Flux de trésorerie disponibles',
      'Nombre de followers Instagram',
      'Cours du baril',
      'Budget marketing',
    ],
    correctIndex: 0,
    explanationPattern: 'Les FCF montrent si {topic} génère assez de cash pour rémunérer durablement ses actionnaires.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_debt_ratio',
    stageId: 'fundamentals',
    category: 'Fondamental',
    rewardXp: 17,
    questionPattern: 'Avant une hausse de taux, quel ratio surveiller pour {topic} ?',
    options: [
      'Dette nette / EBITDA',
      'Nombre de boutiques',
      'Cours EUR/USD',
      'Panier moyen',
    ],
    correctIndex: 0,
    explanationPattern: 'Le levier financier de {topic} indique sa sensibilité à une hausse du coût du capital.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_gross_margin',
    stageId: 'fundamentals',
    category: 'Fondamental',
    rewardXp: 17,
    questionPattern: 'Pour {topic}, quelle métrique signale un pouvoir de fixation des prix ?',
    options: [
      'Marge brute',
      'Nombre de salariés',
      'Cours de l’or',
      'Audience TikTok',
    ],
    correctIndex: 0,
    explanationPattern: 'Une marge brute stable ou en hausse indique que {topic} conserve son pricing power.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_eps_quality',
    stageId: 'fundamentals',
    category: 'Fondamental',
    rewardXp: 18,
    questionPattern: 'Comment vérifier la qualité d’un beat EPS pour {topic} ?',
    options: [
      'Comparer croissance de revenus et marges',
      'Regarder uniquement le titre en Bourse',
      'Observer le nombre de RH',
      'Vérifier le prix de l’immobilier',
    ],
    correctIndex: 0,
    explanationPattern: 'Un beat solide chez {topic} doit être soutenu par les ventes et marges, pas seulement par le rachat d’actions.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_working_cap',
    stageId: 'fundamentals',
    category: 'Fondamental',
    rewardXp: 17,
    questionPattern: 'Quelle alerte envoie un BFR qui explose pour {topic} ?',
    options: [
      'Un risque de tension de trésorerie',
      'Une meilleure image marketing',
      'Un split action imminent',
      'Une hausse automatique du taux de change',
    ],
    correctIndex: 0,
    explanationPattern: 'Si le besoin en fonds de roulement grimpe, {topic} peut manquer de cash malgré un bénéfice net.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_pattern_break',
    stageId: 'technical',
    category: 'Technique',
    rewardXp: 17,
    questionPattern: 'Que signifie la cassure d’un support majeur sur {topic} accompagnée de volumes ?',
    options: [
      'Une poursuite baissière probable',
      'Un rallye certain',
      'Un manque de volatilité',
      'Une absence d’information',
    ],
    correctIndex: 0,
    explanationPattern: 'Les volumes valident souvent la sortie de range pour {topic}.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_rsi_signal',
    stageId: 'technical',
    category: 'Technique',
    rewardXp: 16,
    questionPattern: 'Un RSI > 75 sur {topic} indique…',
    options: [
      'Un momentum fort mais susceptible de corriger',
      'Une survente',
      'Une absence de volume',
      'Une certitude de hausse',
    ],
    correctIndex: 0,
    explanationPattern: 'Un RSI extrême signale que {topic} peut respirer avant de repartir.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_vol_regime',
    stageId: 'derivatives',
    category: 'Dérivés',
    rewardXp: 18,
    questionPattern: 'Passer d’un régime de vol basse à haute pour {topic} implique…',
    options: [
      'D’ajuster la taille et le prix des options',
      'D’arrêter toute couverture',
      'De vendre toutes les positions',
      'De supprimer le journal de trades',
    ],
    correctIndex: 0,
    explanationPattern: 'La hausse de volatilité accroît le coût des protections sur {topic}.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_collars',
    stageId: 'derivatives',
    category: 'Dérivés',
    rewardXp: 18,
    questionPattern: 'Un collar sur {topic} consiste à…',
    options: [
      'Acheter un put et vendre un call couvert',
      'Acheter uniquement des calls',
      'Vendre des futures sans couverture',
      'Ignorer la volatilité',
    ],
    correctIndex: 0,
    explanationPattern: 'Le collar fixe un plancher et finance une partie de la prime pour {topic}.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_macro_inflation',
    stageId: 'intuition',
    category: 'Macro',
    rewardXp: 18,
    questionPattern: 'Une inflation surprise au-dessus du consensus pour {topic} entraîne…',
    options: [
      'Une remontée possible des taux longs',
      'Une baisse mécanique des dividendes',
      'Un split action',
      'Une absence de volatilité',
    ],
    correctIndex: 0,
    explanationPattern: 'Les taux montent pour compenser et pèsent sur les valeurs de croissance exposées à {topic}.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_macro_tone',
    stageId: 'intuition',
    category: 'Macro',
    rewardXp: 18,
    questionPattern: 'Quand une banque centrale devient “data dependent” pour {topic}, cela signifie…',
    options: [
      'Qu’elle attend les prochains chiffres avant de décider',
      'Qu’elle monte automatiquement les taux',
      'Qu’elle arrête toute communication',
      'Qu’elle double son bilan',
    ],
    correctIndex: 0,
    explanationPattern: 'Le message prépare {topic} à une politique adaptable selon les datas.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_esg_metric',
    stageId: 'esg',
    category: 'ESG',
    rewardXp: 18,
    questionPattern: 'Quel indicateur ESG est prioritaire pour {topic} ?',
    options: [
      'CAPEX dédié aux projets bas carbone',
      'Likes Instagram',
      'Nombre de boutiques',
      'Cours du bitcoin',
    ],
    correctIndex: 0,
    explanationPattern: 'Les investissements verts concrets montrent l’engagement de {topic}.',
    topics: _quizEsgTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_esg_bond',
    stageId: 'esg',
    category: 'ESG',
    rewardXp: 18,
    questionPattern: 'Un green bond crédible chez {topic} implique…',
    options: [
      'Un usage des fonds traçable',
      'Aucun reporting',
      'Une prime de risque illimitée',
      'Une suppression des audits',
    ],
    correctIndex: 0,
    explanationPattern: '{topic} doit détailler les projets financés pour garder le label.',
    topics: _quizEsgTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_psy_bias',
    stageId: 'psychology',
    category: 'Psychologie',
    rewardXp: 17,
    questionPattern: 'Quel biais menace {topic} lors des phases euphoriques ?',
    options: [
      'Le biais de disposition',
      'La loi de Moore',
      'Le coût marginal',
      'L’effet de levier financier',
    ],
    correctIndex: 0,
    explanationPattern: 'Ce biais pousse {topic} à couper les gagnants trop tôt et garder les perdants.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_psy_journal',
    stageId: 'psychology',
    category: 'Psychologie',
    rewardXp: 16,
    questionPattern: 'Pourquoi tenir un journal de trades pour {topic} ?',
    options: [
      'Pour objectiver les décisions et détecter les biais',
      'Pour suivre le cours météo',
      'Pour augmenter la TVA',
      'Pour oublier son plan',
    ],
    correctIndex: 0,
    explanationPattern: 'Le journal aide {topic} à analyser ses réactions et améliorer sa discipline.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_macro_currency',
    stageId: 'intuition',
    category: 'Macro',
    rewardXp: 18,
    questionPattern: 'Une forte dépréciation de la devise locale de {topic} impacte surtout…',
    options: [
      'Les importateurs nets',
      'Les sociétés 100% domestiques sans import',
      'Le nombre de followers',
      'Le salaire des dirigeants',
    ],
    correctIndex: 0,
    explanationPattern: 'Les importateurs de {topic} voient leurs coûts exploser dans la devise forte.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_supply_chain',
    stageId: 'fundamentals',
    category: 'Fondamental',
    rewardXp: 17,
    questionPattern: 'Quel KPI te renseigne sur la fluidité supply-chain de {topic} ?',
    options: [
      'Les jours de stock (DIO)',
      'Le nombre de likes Twitter',
      'La météo à Paris',
      'Le prix du cuivre à 3 ans',
    ],
    correctIndex: 0,
    explanationPattern: 'Un DIO qui s’étire signale des stocks mal gérés chez {topic}.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_tech_break',
    stageId: 'technical',
    category: 'Technique',
    rewardXp: 17,
    questionPattern: 'Quelle est la meilleure confirmation d’un breakout haussier sur {topic} ?',
    options: [
      'Clôture au-dessus de la résistance avec volume supérieur à la moyenne',
      'Lecture d’un tweet',
      'Un simple gap nocturne',
      'Le nombre de salariés',
    ],
    correctIndex: 0,
    explanationPattern: 'Volume + clôture solide renforcent la cassure sur {topic}.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_derivative_tail',
    stageId: 'derivatives',
    category: 'Dérivés',
    rewardXp: 18,
    questionPattern: 'Pour couvrir un risque extrême sur {topic}, tu privilégies…',
    options: [
      'Des puts très hors de la monnaie',
      'Des ventes nues de calls',
      'Des actions gratuites',
      'Des obligations convertibles',
    ],
    correctIndex: 0,
    explanationPattern: 'Les puts OTM sont une assurance contre les “black swans” sur {topic}.',
    topics: _quizSectorTopics,
  ),
  _QuizTemplateData(
    idPrefix: 'quiz_macro_supply',
    stageId: 'intuition',
    category: 'Macro',
    rewardXp: 18,
    questionPattern: 'Des goulets d’étranglement prolongés pour {topic} génèrent…',
    options: [
      'Une inflation importée basée sur l’offre',
      'Une baisse de la volatilité',
      'Une certitude de hausse des dividendes',
      'Un apaisement monétaire',
    ],
    correctIndex: 0,
    explanationPattern: 'Les contraintes logistiques poussent les coûts de {topic} à la hausse et nourrissent l’inflation.',
    topics: _quizSectorTopics,
  ),
];

const List<_ScenarioTemplateData> _scenarioTemplates = [
  _ScenarioTemplateData(
    idPrefix: 'scenario_supply_chain',
    titlePattern: 'Blocage logistique sur {topic}',
    descriptionPattern: 'Un fournisseur clé de {topic} annonce une fermeture de quatre semaines.',
    focus: 'Chaîne logistique',
    risk: 'Approvisionnement',
    stageId: 'fundamentals',
    rewardXp: 18,
    promptPatterns: [
      'Réévalue l’impact sur les marges de {topic}.',
      'Cherche des fournisseurs alternatifs ou des stocks disponibles.',
    ],
    topics: [
      'constructeurs automobiles européens',
      'fabricants de smartphones',
      'industries aéronautiques',
      'producteurs de semi-conducteurs',
      'groupes de luxe',
      'équipementiers sportifs',
    ],
  ),
  _ScenarioTemplateData(
    idPrefix: 'scenario_fx_shock',
    titlePattern: 'Choc de devise pour {topic}',
    descriptionPattern: 'La devise locale de {topic} perd 12% en deux semaines.',
    focus: 'FX',
    risk: 'Devises',
    stageId: 'psychology',
    rewardXp: 17,
    promptPatterns: [
      'Couvre l’exposition via forwards ou ETF multi-devises.',
      'Favorise les exportateurs nets vs importateurs dépendants.',
    ],
    topics: [
      'exportateurs indiens',
      'sociétés turques',
      'groupes brésiliens',
      'industries sud-africaines',
      'valeurs mexicaines',
      'entreprises australiennes',
    ],
  ),
  _ScenarioTemplateData(
    idPrefix: 'scenario_esg_push',
    titlePattern: 'Accélération verte pour {topic}',
    descriptionPattern: 'Un plan public gigantesque soutient les investissements {topic}.',
    focus: 'ESG',
    risk: 'Execution',
    stageId: 'esg',
    rewardXp: 17,
    promptPatterns: [
      'Sélectionne les acteurs déjà prêts à déployer les capex.',
      'Évite les dossiers greenwashing sans pipeline concret.',
    ],
    topics: [
      'hydrogène',
      'batteries solides',
      'captation de CO₂',
      'pompes à chaleur',
      'agriculture régénérative',
      'réseaux intelligents',
    ],
  ),
  _ScenarioTemplateData(
    idPrefix: 'scenario_macro_policy',
    titlePattern: 'Virage budgétaire pour {topic}',
    descriptionPattern: 'Le gouvernement annonce un plan fiscal massif ciblant {topic}.',
    focus: 'Macro',
    risk: 'Budgetaire',
    stageId: 'intuition',
    rewardXp: 18,
    promptPatterns: [
      'Identifie les segments avantagés et ceux surtaxés.',
      'Adapte tes couvertures taux selon la trajectoire de dette.',
    ],
    topics: [
      'l’immobilier locatif',
      'les énergéticiens',
      'les fonds d’infrastructure',
      'les transports publics',
      'les hôpitaux privés',
      'les industriels',
    ],
  ),
  _ScenarioTemplateData(
    idPrefix: 'scenario_volatility',
    titlePattern: 'Volatilité extrême sur {topic}',
    descriptionPattern: 'Le VIX spécifique à {topic} dépasse 40.',
    focus: 'Risque',
    risk: 'Volatilité',
    stageId: 'derivatives',
    rewardXp: 18,
    promptPatterns: [
      'Réduis le beta et renforce les couvertures optionnelles.',
      'Choisis quelles lignes conserver pour profiter d’un rebond.',
    ],
    topics: [
      'indices technologiques',
      'ETF émergents',
      'valeurs bancaires',
      'cryptomonnaies',
      'small caps européennes',
      'biotechs',
    ],
  ),
  _ScenarioTemplateData(
    idPrefix: 'scenario_earnings',
    titlePattern: 'Publication délicate pour {topic}',
    descriptionPattern: '{topic} prévient d’une croissance plus faible pour le prochain trimestre.',
    focus: 'Fondamental',
    risk: 'Guidance',
    stageId: 'fundamentals',
    rewardXp: 17,
    promptPatterns: [
      'Analyser si la visibilité se dégrade ou si c’est un trimestre isolé.',
      'Décider d’un allègement ou d’un renforcement graduel.',
    ],
    topics: [
      'SaaS américain',
      'retail chinois',
      'luxe européen',
      'banques canadiennes',
      'équipementiers auto',
      'santé digitale',
    ],
  ),
  _ScenarioTemplateData(
    idPrefix: 'scenario_psy_cycle',
    titlePattern: 'Cascade émotionnelle sur {topic}',
    descriptionPattern: 'Trois news contradictoires tombent sur {topic} en 24h.',
    focus: 'Psychologie',
    risk: 'FOMO/FUD',
    stageId: 'psychology',
    rewardXp: 16,
    promptPatterns: [
      'Revenir au plan initial et attendre des confirmations officielles.',
      'Limiter la taille d’une éventuelle position tant que la situation n’est pas clarifiée.',
    ],
    topics: [
      'valeurs biotechs',
      'crypto-actifs',
      'startups foodtech',
      'SPAC américains',
      'petites capitalisations minières',
      'entreprises de défense',
    ],
  ),
  _ScenarioTemplateData(
    idPrefix: 'scenario_rate_path',
    titlePattern: 'Changement de trajectoire des taux pour {topic}',
    descriptionPattern: 'La banque centrale indique deux baisses de taux supplémentaires concernant {topic}.',
    focus: 'Macro',
    risk: 'Taux',
    stageId: 'intuition',
    rewardXp: 18,
    promptPatterns: [
      'Renforcer les valeurs sensibles aux taux bas.',
      'Couvrir les valeurs bancaires ou financières si besoin.',
    ],
    topics: [
      'immobilier coté',
      'tech US',
      'marché obligataire investment grade',
      'indices high yield',
      'constructeurs résidentiels',
      'REIT logistiques',
    ],
  ),
  _ScenarioTemplateData(
    idPrefix: 'scenario_weather',
    titlePattern: 'Évènement climatique sur {topic}',
    descriptionPattern: 'Une canicule/période de froid extrême affecte {topic}.',
    focus: 'ESG',
    risk: 'Climatique',
    stageId: 'esg',
    rewardXp: 17,
    promptPatterns: [
      'Évaluer l’impact sur la demande énergétique.',
      'Identifier les sociétés capables d’en profiter (stockage, réseau).',
    ],
    topics: [
      'réseaux électriques européens',
      'producteurs d’énergies renouvelables',
      'compagnies aériennes',
      'agro-industrie américaine',
      'stations de ski',
      'gestionnaires d’eau',
    ],
  ),
  _ScenarioTemplateData(
    idPrefix: 'scenario_credit',
    titlePattern: 'Stress crédit sur {topic}',
    descriptionPattern: 'Les spreads high yield de {topic} s’écartent de 200 pb.',
    focus: 'Crédit',
    risk: 'Financement',
    stageId: 'derivatives',
    rewardXp: 19,
    promptPatterns: [
      'Réévaluer les sociétés les plus endettées.',
      'Mettre en place des couvertures via CDS/ETF inverses.',
    ],
    topics: [
      'sociétés pétrolières US',
      'retail spéculatif',
      'constructeurs chinois',
      'valeurs aériennes',
      'promoteurs immobiliers',
      'métaux et mines',
    ],
  ),
  _ScenarioTemplateData(
    idPrefix: 'scenario_rotation',
    titlePattern: 'Rotation sectorielle vers {topic}',
    descriptionPattern: 'Les flux ETF montrent une bascule massive vers {topic}.',
    focus: 'Stratégie',
    risk: 'Allocation',
    stageId: 'fundamentals',
    rewardXp: 17,
    promptPatterns: [
      'Réduire l’exposition aux secteurs délaissés.',
      'Identifier les valeurs à renforcer pour accompagner la rotation.',
    ],
    topics: [
      'valeurs value européennes',
      'croissance US',
      'énergie fossile',
      'utilities défensives',
      'banques japonaises',
      'santé mondiale',
    ],
  ),
];
