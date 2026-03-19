import 'dart:math';

String _normalizeChapter4QuizKey(String value) {
  return value
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('--', '-')
      .replaceAll(r'$', '')
      .replaceAll(RegExp(r'^QCM\s*-\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const Map<String, String> _chapter4QuizLessonByHeading = {
  'Pourquoi la macroéconomie est indispensable pour comprendre la finance':
      'Pourquoi la macro encadre tous les marchés',
  'Le langage de base de la macro': 'La grammaire des agrégats macro',
  'Le PIB : trois mesures, une même réalité économique':
      'Production, revenu et dépense',
  'Du PIB au revenu disponible : ce que les investisseurs regardent vraiment':
      'Ce que les ménages peuvent vraiment dépenser',
  'PIB nominal, PIB réel et déflateur : distinguer quantités et prix':
      'Distinguer quantités et prix',
  'Croissance nominale vs réelle : un mini-raisonnement':
      'Une approximation utile pour les marchés',
  'Tendance de long terme et valorisation':
      'Pourquoi la croissance structurelle compte pour les actifs',
  'Croissance et profits': 'Le lien entre PIB, marges et bénéfices',
  'Productivité et capital : idée de modèle':
      'Une fonction de production agrégée simple',
  'Output gap et cycle': 'Comparer le PIB effectif au PIB potentiel',
  'Lien avec les marchés': 'Pourquoi les primes de risque sont cycliques',
  'Chômage : notion macroéconomique':
      'Le marché du travail comme indicateur cyclique',
  'Courbe de Phillips : intuition':
      'Inflation, anticipations et chômage naturel',
  'Schéma : Phillips (relation inverse stylisée)':
      'Inflation, anticipations et chômage naturel',
  'Pourquoi la monnaie est au cœur des marchés': 'Liquidité, dépôts et crédit',
  'Base monétaire, monnaie, multiplicateur : idée simple':
      'Une représentation simple de la création monétaire',
  'Objectifs typiques': 'Stabilité des prix et stabilité financière',
  'Le taux directeur : prix du temps et de la liquidité':
      'Le principal levier de la politique monétaire',
  'Règle de Taylor (forme simple)':
      'Une lecture stylisée des réactions de la banque centrale',
  'Prix d’une obligation (rappel intertemporel)':
      'Actualiser coupons et principal',
  'Duration : sensibilité au taux':
      'Pourquoi certaines obligations bougent plus que d’autres',
  'Courbe des taux : information macro condensée': 'Normale, plate ou inversée',
  'AD-AS (version simplifiée)': 'Chocs de demande et chocs d’offre',
  'AD-AS et inflation': 'Lire un déplacement de la demande globale',
  'IS : équilibre sur le marché des biens':
      'Pourquoi des taux plus élevés pèsent sur l’activité',
  'LM : équilibre monétaire (version pédagogique)':
      'Quand plus d’activité réclame plus de liquidité',
  'IS-LM et choc monétaire': 'Comment un assouplissement déplace l’équilibre',
  'Taux de change et actifs':
      'Compétitivité, inflation importée et performance financière',
  'Parité non couverte des taux d’intérêt (UIP) : idée':
      'Comparer rendements et change anticipé',
  'Marché des changes (offre/demande de devise)':
      'Le change comme prix d’équilibre',
  'Déficit et dette : définitions': 'Flux annuel contre stock accumulé',
  'Lien finance : souverain, taux, spreads':
      'Pourquoi le risque souverain se reflète dans les spreads',
  'Pourquoi les crises sont macro-financières':
      'Quand l’intermédiation se bloque',
  'Levier et ventes forcées':
      'Comment une baisse initiale peut s’auto-amplifier',
  'Boucle de rétroaction': 'Une crise comme dynamique endogène',
  'Deux moteurs des prix d’actifs':
      'Cash-flows attendus et facteur d’actualisation',
  'Prime de risque (macro-finance)': 'Une prime qui varie avec le régime macro',
  '« bonnes nouvelles » vs « mauvaises nouvelles » selon le régime':
      'La réaction dépend du régime macro dominant',
  "Indicateurs macro utiles pour l'investisseur":
      'Quels blocs d’indicateurs suivre',
  'Synthèse : une grille macro-finance cohérente':
      'Relier chocs macro, politiques et prix d’actifs',
  'Actualisation en présence d\'inflation':
      'Taux nominaux, taux réels et approximation de Fisher',
  'Sensibilité des actions aux taux : intuition':
      'Pourquoi les flux lointains sont les plus vulnérables',
};

class _Chapter4QuizToken {
  const _Chapter4QuizToken.heading(this.offset, this.level, this.value)
    : question = null,
      optionsBlock = null,
      answer = null;

  const _Chapter4QuizToken.question(
    this.offset,
    this.question,
    this.optionsBlock,
    this.answer,
  ) : level = null,
      value = null;

  final int offset;
  final String? level;
  final String? value;
  final String? question;
  final String? optionsBlock;
  final String? answer;

  bool get isHeading => level != null;
}

int _stableChapter4QuizSeed(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String _unwrapChapter4LatexCommand(String text, String command) {
  final pattern = RegExp('\\\\$command\\{([^{}]*)\\}');
  var result = text;
  while (pattern.hasMatch(result)) {
    result = result.replaceAllMapped(pattern, (match) => match.group(1) ?? '');
  }
  return result;
}

String _replaceChapter4Fractions(String text) {
  final pattern = RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}');
  var result = text;
  while (pattern.hasMatch(result)) {
    result = result.replaceAllMapped(pattern, (match) {
      final numerator = match.group(1)?.trim() ?? '';
      final denominator = match.group(2)?.trim() ?? '';
      return '$numerator / $denominator';
    });
  }
  return result;
}

String _replaceChapter4ScriptedSymbols(String text) {
  var result = text;
  result = result.replaceAllMapped(
    RegExp(r'_\{([^}]*)\}'),
    (match) => '[${match.group(1) ?? ''}]',
  );
  result = result.replaceAllMapped(
    RegExp(r'\^\{([^}]*)\}'),
    (match) => '^(${match.group(1) ?? ''})',
  );
  result = result.replaceAllMapped(
    RegExp(r'_([A-Za-z0-9+\-]+)'),
    (match) => '[${match.group(1) ?? ''}]',
  );
  result = result.replaceAllMapped(
    RegExp(r'\^([A-Za-z0-9+\-]+)'),
    (match) => '^${match.group(1) ?? ''}',
  );
  return result;
}

String _cleanChapter4QuizText(String value) {
  var text = value.replaceAll('\r', ' ').replaceAll('\n', ' ');
  text = text.replaceAll(r'\[', ' ');
  text = text.replaceAll(r'\]', ' ');
  text = text.replaceAll(r'\(', ' ');
  text = text.replaceAll(r'\)', ' ');
  text = text.replaceAll(r'\,', ' ');
  text = text.replaceAll(r'\qquad', ' ');
  text = text.replaceAll(r'\quad', ' ');
  text = text.replaceAll(r'\%', '%');
  text = text.replaceAll(r'\approx', '≈');
  text = text.replaceAll(r'\cdot', '·');
  text = text.replaceAll(r'\times', '×');
  text = text.replaceAll(r'\leftrightarrow', '↔');
  text = text.replaceAll(r'\Delta', 'Δ');
  text = text.replaceAll(r'\pi', 'π');
  text = text.replaceAll(r'\ln', 'ln');
  text = text.replaceAll(r'\mathbb{E}', 'E');
  text = text.replaceAll(r'\textbf', '');
  text = text.replaceAll(r'\displaystyle', '');
  text = _replaceChapter4Fractions(text);
  text = _replaceChapter4ScriptedSymbols(text);
  for (final command in ['textit', 'textbf', 'boxed', 'text', 'mathrm']) {
    text = _unwrapChapter4LatexCommand(text, command);
  }
  text = text.replaceAll(RegExp(r'\\begin\{[^}]+\}'), ' ');
  text = text.replaceAll(RegExp(r'\\end\{[^}]+\}'), ' ');
  text = text.replaceAll(RegExp(r'\\[a-zA-Z]+\*?'), ' ');
  text = text.replaceAll(r'$', '');
  text = text.replaceAll('{', '');
  text = text.replaceAll('}', '');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

Map<String, dynamic> _buildChapter4Question(
  String question,
  List<String> options,
  int correctIndex,
) {
  final indexedOptions = List.generate(
    options.length,
    (index) => MapEntry(index, options[index]),
  );
  final random = Random(
    _stableChapter4QuizSeed('$question|${options.join('|')}|$correctIndex'),
  );
  for (var index = indexedOptions.length - 1; index > 0; index -= 1) {
    final swapIndex = random.nextInt(index + 1);
    final current = indexedOptions[index];
    indexedOptions[index] = indexedOptions[swapIndex];
    indexedOptions[swapIndex] = current;
  }

  return {
    'question': question,
    'options': indexedOptions.map((entry) => entry.value).toList(),
    'correct_answer_index': indexedOptions.indexWhere(
      (entry) => entry.key == correctIndex,
    ),
  };
}

Map<String, List<String>> _collectChapter4LessonsByTopChapter(
  Map<String, dynamic> courseData,
) {
  final result = <String, List<String>>{};
  final chapters =
      (courseData['chapters'] as List).cast<Map<String, dynamic>>();

  void collectFromNode(Map<String, dynamic> node, String topChapterTitle) {
    final lessons =
        (node['lessons'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    for (final lesson in lessons) {
      result.putIfAbsent(topChapterTitle, () => <String>[]);
      result[topChapterTitle]!.add(lesson['lesson_title'] as String);
    }

    final subChapters =
        (node['sub_chapters'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    for (final subChapter in subChapters) {
      collectFromNode(subChapter, topChapterTitle);
    }
  }

  for (final chapter in chapters) {
    final topTitle = chapter['chapter_title'] as String;
    result[topTitle] = <String>[];
    collectFromNode(chapter, topTitle);
  }

  return result;
}

Map<String, List<Map<String, dynamic>>> _parseChapter4QuizQuestions() {
  final tokens = <_Chapter4QuizToken>[];
  final headingPattern = RegExp(r'\\(section|subsection)\{([^}]*)\}');
  final questionPattern = RegExp(
    r'\\item\s+(.*?)\s+\\begin\{itemize\}(.*?)\\end\{itemize\}\s*\\textbf\{Réponse\s*:\s*([A-D])\}',
    dotAll: true,
  );

  for (final match in headingPattern.allMatches(_chapter4QuizLatex)) {
    tokens.add(
      _Chapter4QuizToken.heading(match.start, match.group(1)!, match.group(2)!),
    );
  }

  for (final match in questionPattern.allMatches(_chapter4QuizLatex)) {
    tokens.add(
      _Chapter4QuizToken.question(
        match.start,
        match.group(1)!,
        match.group(2)!,
        match.group(3)!,
      ),
    );
  }

  tokens.sort((left, right) => left.offset.compareTo(right.offset));

  String? section;
  String? subsection;
  final lessonQuestions = <String, List<Map<String, dynamic>>>{};
  final optionPattern = RegExp(
    r'\\item\s+([A-D])\.\s+(.*?)(?=(?:\n\s*\\item\s+[A-D]\.\s)|$)',
    dotAll: true,
  );

  for (final token in tokens) {
    if (token.isHeading) {
      switch (token.level) {
        case 'section':
          section = token.value;
          subsection = null;
          break;
        case 'subsection':
          subsection = token.value;
          break;
      }
      continue;
    }

    final headingKey = _normalizeChapter4QuizKey(subsection ?? section ?? '');
    final lessonTitle = _chapter4QuizLessonByHeading[headingKey];
    if (lessonTitle == null) {
      continue;
    }

    final matches = optionPattern.allMatches(token.optionsBlock ?? '').toList();
    if (matches.isEmpty) {
      continue;
    }

    final options = <String>[];
    var correctIndex = -1;
    for (var index = 0; index < matches.length; index += 1) {
      final match = matches[index];
      final optionLabel = match.group(1);
      final optionText = _cleanChapter4QuizText(match.group(2) ?? '');
      if (optionText.isEmpty) {
        continue;
      }
      if (optionLabel == token.answer) {
        correctIndex = options.length;
      }
      options.add(optionText);
    }

    if (options.length < 2 ||
        correctIndex < 0 ||
        correctIndex >= options.length) {
      continue;
    }

    lessonQuestions.putIfAbsent(lessonTitle, () => <Map<String, dynamic>>[]);
    lessonQuestions[lessonTitle]!.add(
      _buildChapter4Question(
        _cleanChapter4QuizText(token.question ?? ''),
        options,
        correctIndex,
      ),
    );
  }

  return lessonQuestions;
}

final Map<String, List<Map<String, dynamic>>>
_chapter4SupplementalQuestions = <String, List<Map<String, dynamic>>>{
  'Actualiser coupons et principal': <Map<String, dynamic>>[
    _buildChapter4Question(
      'Que représente une obligation du point de vue financier ?',
      <String>[
        "Un titre qui donne un droit de propriété dans l'entreprise",
        'Un contrat qui promet une série de paiements futurs (coupons et remboursement du principal)',
        'Un instrument qui sert uniquement à fixer les taux d’intérêt',
        'Un actif qui ne génère aucun flux financier',
      ],
      1,
    ),
    _buildChapter4Question(
      'Quels sont les deux principaux flux versés par une obligation ?',
      <String>[
        'Les dividendes et les gains en capital',
        'Les coupons et le remboursement du principal',
        'Les salaires et les profits',
        'Les impôts et les transferts',
      ],
      1,
    ),
    _buildChapter4Question(
      'Dans la formule du prix d’une obligation, que représente la variable y ?',
      <String>[
        'Le taux d’inflation',
        'Le taux de croissance économique',
        'Le taux actuariel (yield) exigé par le marché',
        'Le niveau de la dette publique',
      ],
      2,
    ),
    _buildChapter4Question(
      'Pourquoi le prix d’une obligation baisse-t-il généralement lorsque les taux d’intérêt augmentent ?',
      <String>[
        'Parce que les coupons disparaissent',
        'Parce que les obligations deviennent illégales',
        'Parce que les flux futurs sont actualisés à un taux plus élevé',
        'Parce que les entreprises paient moins d’impôts',
      ],
      2,
    ),
    _buildChapter4Question(
      'Quelle idée fondamentale de la finance est illustrée par la formule du prix d’une obligation ?',
      <String>[
        'La valeur d’un actif dépend uniquement de son prix passé',
        'Les prix financiers sont fixés par les banques centrales',
        'Les profits déterminent toujours les prix des obligations',
        'La valeur d’un actif correspond à la valeur actualisée de ses flux futurs',
      ],
      3,
    ),
  ],
  'Comparer rendements et change anticipé': <Map<String, dynamic>>[
    _buildChapter4Question(
      'Que cherche à expliquer la parité non couverte des taux d’intérêt (UIP) ?',
      <String>[
        'La relation entre chômage et inflation',
        'La relation entre taux d’intérêt et taux de change',
        'La relation entre croissance économique et productivité',
        'La relation entre dette publique et inflation',
      ],
      1,
    ),
    _buildChapter4Question('Dans l’équation de la UIP, que représente S_t ?', <
      String
    >[
      'Le taux d’intérêt domestique',
      'Le taux d’inflation anticipé',
      'Le taux de change actuel (prix de la devise étrangère en monnaie domestique)',
      'Le niveau de production de l’économie',
    ], 2),
    _buildChapter4Question('Dans cette relation, que représente i* ?', <String>[
      'Le taux d’intérêt étranger',
      'Le taux d’inflation domestique',
      'Le taux de croissance économique',
      'Le taux de chômage naturel',
    ], 0),
    _buildChapter4Question(
      'Pourquoi les investisseurs internationaux comparent-ils les taux d’intérêt entre pays ?',
      <String>[
        'Pour déterminer la politique budgétaire',
        'Pour arbitrer entre les rendements offerts par différents marchés financiers',
        'Pour déterminer la croissance démographique',
        'Pour fixer les salaires dans l’économie',
      ],
      1,
    ),
    _buildChapter4Question(
      'Selon l’intuition de la UIP, que peut-il se produire si les taux d’intérêt domestiques deviennent plus élevés que les taux étrangers ?',
      <String>[
        'Les capitaux peuvent affluer vers ce pays et la devise domestique peut s’apprécier',
        'Les exportations disparaissent immédiatement',
        'Les salaires augmentent automatiquement',
        'Les banques centrales perdent tout contrôle sur la monnaie',
      ],
      0,
    ),
  ],
  'Cash-flows attendus et facteur d’actualisation': <Map<String, dynamic>>[
    _buildChapter4Question(
      'Selon l’intuition présentée, de quoi dépend principalement le prix d’un actif financier ?',
      <String>[
        'Des anticipations de cash-flows futurs et du facteur d’actualisation',
        'Uniquement du niveau de la dette publique',
        'Du nombre d’entreprises sur le marché',
        'Uniquement du taux de change',
      ],
      0,
    ),
    _buildChapter4Question(
      'Que représentent les cash-flows dans la valorisation d’un actif ?',
      <String>[
        'Les dépenses publiques futures',
        'Les flux futurs attendus par l’investisseur (dividendes, profits, croissance)',
        'Les impôts payés par les entreprises',
        'Les taux d’intérêt fixés par la banque centrale',
      ],
      1,
    ),
    _buildChapter4Question(
      'Pourquoi les cash-flows sont-ils sensibles à la situation macroéconomique ?',
      <String>[
        'Parce qu’ils dépendent de la croissance économique, du cycle et des marges des entreprises',
        'Parce qu’ils sont fixés par les banques centrales',
        'Parce qu’ils dépendent uniquement du taux de change',
        'Parce qu’ils sont indépendants de l’économie réelle',
      ],
      0,
    ),
    _buildChapter4Question(
      'Que signifie le processus d’actualisation des flux futurs ?',
      <String>[
        'Transformer les flux futurs en valeur présente',
        'Augmenter automatiquement les profits futurs',
        'Fixer les prix des actifs par décision publique',
        'Réduire les dividendes des entreprises',
      ],
      0,
    ),
    _buildChapter4Question(
      'Quel effet une hausse des taux d’intérêt a-t-elle généralement sur les prix des actifs ?',
      <String>[
        'Elle augmente toujours leur valeur',
        'Elle n’a aucun effet',
        'Elle réduit la valeur actuelle des flux futurs',
        'Elle supprime les primes de risque',
      ],
      2,
    ),
  ],
};

Map<String, dynamic> buildChapter4QuizData(Map<String, dynamic> courseData) {
  final lessonsByTopChapter = _collectChapter4LessonsByTopChapter(courseData);
  final lessonQuestions = _parseChapter4QuizQuestions();
  final chapters = <Map<String, dynamic>>[];
  final courseChapters =
      (courseData['chapters'] as List).cast<Map<String, dynamic>>();

  for (final chapter in courseChapters) {
    final chapterTitle = chapter['chapter_title'] as String;
    final lessonTitles = lessonsByTopChapter[chapterTitle] ?? const <String>[];
    final quizzes = <Map<String, dynamic>>[];

    for (final lessonTitle in lessonTitles) {
      final questions = <Map<String, dynamic>>[
        ...?lessonQuestions[lessonTitle],
        ...?_chapter4SupplementalQuestions[lessonTitle],
      ];
      if (questions.isEmpty) {
        continue;
      }
      quizzes.add({'lesson_title': lessonTitle, 'questions': questions});
    }

    if (quizzes.isNotEmpty) {
      chapters.add({'chapter_title': chapterTitle, 'quizzes': quizzes});
    }
  }

  return {
    'course_title': 'Macroéconomie et marchés financiers : QCM',
    'chapters': chapters,
  };
}

const List<String> _chapter4QuizLatexChunks = <String>[
  r'''
\section{QCM - Pourquoi la macroéconomie est indispensable pour comprendre la finance}

\begin{enumerate}

\item Quelle est la principale différence entre la microéconomie et la macroéconomie ?

\begin{itemize}
\item A. La microéconomie étudie les échanges internationaux alors que la macroéconomie étudie les entreprises.
\item B. La microéconomie analyse la formation des prix sur un marché particulier alors que la macroéconomie étudie les conditions économiques générales.
\item C. La microéconomie analyse uniquement les marchés financiers alors que la macroéconomie étudie les marchés de biens.
\item D. La microéconomie s'intéresse aux politiques publiques alors que la macroéconomie s'intéresse uniquement aux ménages.
\end{itemize}

\textbf{Réponse : B}

\item La macroéconomie cherche principalement à expliquer :

\begin{itemize}
\item A. Les décisions individuelles des consommateurs sur un marché précis.
\item B. Les stratégies de fixation des prix des entreprises.
\item C. Les grandes variables économiques comme la croissance, l’inflation ou le chômage.
\item D. Les coûts de production d'une entreprise.
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi les taux d’intérêt sont-ils particulièrement importants pour la finance ?

\begin{itemize}
\item A. Ils déterminent les salaires dans l’économie.
\item B. Ils déterminent l’actualisation des flux futurs.
\item C. Ils déterminent directement les impôts.
\item D. Ils déterminent les prix des biens de consommation.
\end{itemize}

\textbf{Réponse : B}

\item Les variables macroéconomiques influencent la valorisation des actions notamment parce qu’elles affectent :

\begin{itemize}
\item A. Les profits agrégés des entreprises.
\item B. Le nombre d’entreprises cotées.
\item C. La taille des marchés financiers.
\item D. Les préférences individuelles des consommateurs.
\end{itemize}

\textbf{Réponse : A}

\item Selon l’idée centrale présentée dans le cours, les marchés financiers valorisent principalement :

\begin{itemize}
\item A. Les actifs physiques des entreprises.
\item B. Les dirigeants des entreprises.
\item C. Des flux futurs dans un environnement macroéconomique.
\item D. Les quantités produites par les entreprises.
\end{itemize}

\textbf{Réponse : C}

\end{enumerate}

\section{QCM - Comptabilité nationale}

\subsection{QCM - Le langage de base de la macro}

\begin{enumerate}

\item Pourquoi la comptabilité nationale est-elle considérée comme la « grammaire » de la macroéconomie ?

\begin{itemize}
\item A. Parce qu’elle explique les règles linguistiques utilisées par les économistes.
\item B. Parce qu’elle permet de décrire de manière structurée qui produit, qui reçoit et qui dépense dans l’économie.
\item C. Parce qu’elle sert uniquement à calculer les profits des entreprises.
\item D. Parce qu’elle détermine les taux d’intérêt internationaux.
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi la comptabilité nationale est-elle importante pour les marchés financiers ?

\begin{itemize}
\item A. Parce qu’elle fixe directement les prix des actions.
\item B. Parce qu’elle détermine les stratégies des entreprises.
\item C. Parce que les marchés réagissent aux surprises concernant des agrégats comme la croissance, l’inflation ou les déficits.
\item D. Parce qu’elle détermine les taux de change de manière automatique.
\end{itemize}

\textbf{Réponse : C}

\item Dans le contexte financier, les « surprises macroéconomiques » correspondent :

\begin{itemize}
\item A. À des erreurs de calcul dans la comptabilité nationale.
\item B. À des écarts entre les données macroéconomiques publiées et les anticipations des marchés.
\item C. À des fluctuations aléatoires des marchés financiers.
\item D. À des changements de stratégie des entreprises.
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}

\subsection{QCM - Le PIB : trois mesures, une même réalité économique}

\begin{enumerate}

\item Que mesure le Produit Intérieur Brut (PIB) ?

\begin{itemize}
\item A. La richesse totale détenue par les ménages d’un pays.
\item B. La valeur de la production de biens et services finaux réalisée sur un territoire pendant une période donnée.
\item C. Le montant total des exportations d’un pays.
\item D. Le revenu total des entreprises uniquement.
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi l’approche par la valeur ajoutée est-elle utilisée dans la mesure du PIB ?

\begin{itemize}
\item A. Pour inclure les importations dans la production.
\item B. Pour éviter de compter plusieurs fois les biens intermédiaires.
\item C. Pour mesurer uniquement les profits des entreprises.
\item D. Pour exclure les salaires de la production.
\end{itemize}

\textbf{Réponse : B}

\item Selon l’approche revenu du PIB, produire dans l’économie génère :

\begin{itemize}
\item A. Uniquement des salaires.
\item B. Uniquement des profits.
\item C. Des revenus distribués sous forme de salaires, profits et impôts nets.
\item D. Uniquement des recettes fiscales.
\end{itemize}

\textbf{Réponse : C}

\item Quelle est l’identité du PIB selon l’approche dépense ?

\begin{itemize}
\item A. $Y = C + I + G$
\item B. $Y = C + I + G + (X-M)$
\item C. $Y = W + \Pi$
\item D. $Y = X + M$
\end{itemize}

\textbf{Réponse : B}

\item Dans l’analyse macroéconomique des marchés financiers, une variation de l’investissement ($I$) est souvent interprétée comme :

\begin{itemize}
\item A. Un indicateur du coût du capital et du cycle économique.
\item B. Un indicateur direct du taux de change.
\item C. Une mesure de la dette publique.
\item D. Une mesure de la consommation des ménages.
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}

\subsection{QCM - Du PIB au revenu disponible : ce que les investisseurs regardent vraiment}

\begin{enumerate}

\item Qu’appelle-t-on le \textbf{revenu disponible} des ménages ?

\begin{itemize}
\item A. Le PIB total d’une économie.
\item B. Le revenu dont disposent réellement les ménages pour consommer ou épargner après impôts et transferts.
\item C. La valeur totale de la production industrielle.
\item D. Le revenu des entreprises après paiement des salaires.
\end{itemize}

\textbf{Réponse : B}

\item L’approximation du revenu disponible peut s’écrire :

\begin{itemize}
\item A. $Y_d = Y + T + \text{transferts}$
\item B. $Y_d = Y - T + \text{transferts}$
\item C. $Y_d = Y - T - \text{transferts}$
\item D. $Y_d = Y + T - \text{transferts}$
\end{itemize}

\textbf{Réponse : B}

\item Que représentent les \textbf{transferts} dans cette relation ?

\begin{itemize}
\item A. Des paiements réalisés par les entreprises pour acheter des biens intermédiaires.
\item B. Des revenus reçus sans contrepartie de production, comme les allocations ou les retraites.
\item C. Les investissements réalisés par les ménages.
\item D. Les impôts indirects payés par les entreprises.
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi la consommation peut-elle stagner même si le PIB augmente ?

\begin{itemize}
\item A. Parce que les ménages produisent moins de biens.
\item B. Parce que les exportations diminuent.
\item C. Parce que les impôts augmentent ou que l’inflation réduit le pouvoir d’achat.
\item D. Parce que les entreprises augmentent leurs profits.
\end{itemize}

\textbf{Réponse : C}

\item Pour les investisseurs, analyser le revenu disponible est particulièrement important car il permet de mieux anticiper :

\begin{itemize}
\item A. La production industrielle mondiale.
\item B. La consommation des ménages.
\item C. Le niveau des exportations.
\item D. La quantité de monnaie en circulation.
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}

\subsection{QCM - PIB nominal, PIB réel et déflateur : distinguer quantités et prix}

\begin{enumerate}

\item Une hausse du PIB nominal peut provenir :

\begin{itemize}
\item A. Uniquement d’une hausse des exportations.
\item B. Uniquement d’une hausse des quantités produites.
\item C. D’une hausse des quantités produites et/ou d’une hausse des prix.
\item D. Uniquement d’une baisse des impôts.
\end{itemize}

\textbf{Réponse : C}

\item Quel indicateur permet d’isoler la croissance économique en volume (en neutralisant l’effet des prix) ?

\begin{itemize}
\item A. Le PIB nominal
\item B. Le PIB réel
\item C. Le déficit public
\item D. La balance commerciale
\end{itemize}

\textbf{Réponse : B}

\item Le déflateur du PIB est défini comme :

\begin{itemize}
\item A. $\dfrac{Y^{réel}}{Y^{nom}}$
\item B. $Y^{nom} - Y^{réel}$
\item C. $\dfrac{Y^{nom}}{Y^{réel}}$
\item D. $Y^{nom} + Y^{réel}$
\end{itemize}

\textbf{Réponse : C}

\item Quelle différence principale existe entre le déflateur du PIB et l’indice des prix à la consommation ?

\begin{itemize}
\item A. Le déflateur du PIB mesure uniquement les prix des importations.
\item B. L’indice des prix à la consommation couvre toute la production nationale.
\item C. Le déflateur du PIB couvre l’ensemble de la production domestique alors que l’indice des prix à la consommation se concentre sur le panier des ménages.
\item D. Les deux indices mesurent exactement la même chose.
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi une hausse de l’inflation anticipée est-elle généralement défavorable aux obligations nominales ?

\begin{itemize}
\item A. Parce que les flux versés par les obligations sont fixes en termes nominaux.
\item B. Parce que les obligations versent des dividendes variables.
\item C. Parce que l’inflation augmente automatiquement les coupons.
\item D. Parce que les obligations sont indexées sur les prix.
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}

\subsection{QCM - Croissance nominale vs réelle : un mini-raisonnement}

\begin{enumerate}

\item Quelle relation approximative relie la croissance du PIB nominal, la croissance du PIB réel et l’inflation ?

\begin{itemize}
\item A. $\Delta \ln(Y^{réel}) \approx \Delta \ln(Y^{nom}) + \pi$
\item B. $\Delta \ln(Y^{nom}) \approx \Delta \ln(Y^{réel}) + \pi$
\item C. $\Delta \ln(Y^{nom}) \approx \pi - \Delta \ln(Y^{réel})$
\item D. $\Delta \ln(Y^{nom}) \approx \Delta \ln(Y^{réel}) \times \pi$
\end{itemize}

\textbf{Réponse : B}

\item Si la croissance nominale d’une économie est élevée, cela peut s’expliquer :

\begin{itemize}
\item A. Uniquement par une hausse de la production réelle.
\item B. Uniquement par une baisse des prix.
\item C. Par une hausse de la production réelle et/ou par une inflation élevée.
\item D. Uniquement par une hausse des exportations.
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi les marchés financiers cherchent-ils à distinguer croissance réelle et inflation ?

\begin{itemize}
\item A. Parce que ces deux phénomènes ont des implications différentes pour les taux d’intérêt et les profits.
\item B. Parce que seule l’inflation influence les marchés financiers.
\item C. Parce que la croissance réelle n’a aucun impact sur les marchés.
\item D. Parce que les investisseurs ne s’intéressent qu’aux prix.
\end{itemize}

\textbf{Réponse : A}

\item Dans le circuit macroéconomique simplifié, que fournissent les ménages aux entreprises ?

\begin{itemize}
\item A. Des dividendes
\item B. Du travail
\item C. Des exportations
\item D. Des subventions
\end{itemize}

\textbf{Réponse : B}

\item Quel rôle joue le système financier dans ce circuit macroéconomique ?

\begin{itemize}
\item A. Il collecte l’épargne et fournit du crédit ou des capitaux aux entreprises.
\item B. Il fixe directement les impôts.
\item C. Il produit des biens et services.
\item D. Il détermine la consommation des ménages.
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}

\section{QCM - Croissance économique}

\subsection{QCM - Tendance de long terme et valorisation}

\begin{enumerate}

\item Que désigne la croissance économique dans ce contexte ?

\begin{itemize}
\item A. L’augmentation durable de la production réelle d’une économie au cours du temps.
\item B. L’augmentation du nombre d’entreprises cotées en bourse.
\item C. La hausse du niveau général des prix dans l’économie.
\item D. La variation annuelle des dépenses publiques.
\end{itemize}

\textbf{Réponse : A}

\item Pourquoi la croissance économique est-elle centrale pour la macro-finance ?

\begin{itemize}
\item A. Parce qu’elle détermine directement le taux de change.
\item B. Parce qu’elle influence à long terme les revenus, les profits des entreprises et les flux financiers valorisés sur les marchés.
\item C. Parce qu’elle fixe les prix des actifs financiers.
\item D. Parce qu’elle détermine uniquement la consommation publique.
\end{itemize}

\textbf{Réponse : B}

\item Lorsqu’ils valorisent une entreprise, les investisseurs cherchent principalement à :

\begin{itemize}
\item A. Observer uniquement les résultats passés de l’entreprise.
\item B. Comparer les salaires entre différents pays.
\item C. Anticiper la trajectoire future de l’économie dans laquelle l’entreprise évolue.
\item D. Étudier uniquement la politique budgétaire de l’État.
\end{itemize}

\textbf{Réponse : C}

\item Dans l’analyse des marchés actions, la croissance économique influence notamment :

\begin{itemize}
\item A. Le nombre de banques centrales dans le monde.
\item B. Le niveau de la dette publique uniquement.
\item C. La structure démographique d’un pays.
\item D. Les profits futurs des entreprises et les flux financiers attendus.
\end{itemize}

\textbf{Réponse : D}

\end{enumerate}

\subsection{QCM - Croissance et profits}

\begin{enumerate}

\item Quelle relation générale relie la croissance économique et les profits agrégés à long terme ?

\begin{itemize}
\item A. Les profits diminuent lorsque l’économie produit davantage.
\item B. Les profits évoluent indépendamment de la taille de l’économie.
\item C. Les profits agrégés ont tendance à croître avec la capacité productive et la taille de l’économie.
\item D. Les profits dépendent uniquement des politiques publiques.
\end{itemize}

\textbf{Réponse : C}

\item L’approximation reliant croissance des profits et activité économique peut s’écrire :

\begin{itemize}
\item A. $\Delta \ln(\text{profits}) \approx \Delta \ln(Y) + \text{effet marges}$
\item B. $\Delta \ln(\text{profits}) \approx \Delta \ln(Y) - \text{effet marges}$
\item C. $\Delta \ln(\text{profits}) \approx \text{effet marges}$
\item D. $\Delta \ln(\text{profits}) \approx \Delta \ln(Y)^2$
\end{itemize}

\textbf{Réponse : A}

\item Selon cette relation, la croissance des profits dépend principalement :

\begin{itemize}
\item A. Des taux de change uniquement.
\item B. De la croissance de l’activité économique et de l’évolution des marges des entreprises.
\item C. Du nombre d’entreprises dans l’économie.
\item D. Du niveau de la dette publique.
\end{itemize}

\textbf{Réponse : B}

\item Dans quel cas les profits peuvent-ils croître plus vite que l’économie ?

\begin{itemize}
\item A. Lorsque la productivité diminue fortement.
\item B. Lorsque les entreprises subissent une hausse forte de leurs coûts.
\item C. Lorsque la production réelle stagne totalement.
\item D. Lorsque les entreprises améliorent leurs marges.
\end{itemize}

\textbf{Réponse : D}

\item Pourquoi une économie en croissance peut-elle malgré tout connaître une faible progression des profits ?

\begin{itemize}
\item A. Parce que la production augmente trop rapidement.
\item B. Parce que les marges peuvent être réduites par la hausse des coûts (salaires, énergie, matières premières).
\item C. Parce que les entreprises vendent toujours moins lorsque l’économie croît.
\item D. Parce que le PIB réel ne mesure jamais correctement l’activité.
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}
''',
  r'''
\subsection{QCM - Productivité et capital : idée de modèle}

\begin{enumerate}

\item Dans la fonction de production agrégée
\[
Y = A\,F(K,L),
\]
que représente la variable $A$ ?

\begin{itemize}
\item A. Le niveau des salaires dans l’économie
\item B. La productivité globale des facteurs
\item C. Le taux d’inflation
\item D. Le niveau des dépenses publiques
\end{itemize}

\textbf{Réponse : B}

\item Parmi les éléments suivants, lequel contribue directement à l’amélioration de la productivité globale des facteurs ?

\begin{itemize}
\item A. Le progrès technologique
\item B. L’augmentation des impôts
\item C. La hausse des taux d’intérêt
\item D. La diminution des exportations
\end{itemize}

\textbf{Réponse : A}

\item Selon ce cadre théorique, quelles sont les trois sources principales de la croissance économique ?

\begin{itemize}
\item A. Inflation, dette publique et taux de change
\item B. Consommation, dépenses publiques et exportations
\item C. Accumulation du capital, augmentation du travail et amélioration de la productivité
\item D. Salaires, profits et impôts
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi la productivité joue-t-elle un rôle central dans la croissance à long terme ?

\begin{itemize}
\item A. Parce qu’elle réduit automatiquement les taux d’intérêt
\item B. Parce qu’elle augmente la population active
\item C. Parce qu’elle détermine directement les politiques publiques
\item D. Parce qu’elle permet de produire davantage avec les mêmes ressources
\end{itemize}

\textbf{Réponse : D}

\item Pourquoi les actions dites « growth » sont-elles particulièrement sensibles aux taux d’intérêt ?

\begin{itemize}
\item A. Parce que leurs profits attendus sont souvent éloignés dans le futur et donc fortement affectés par l’actualisation
\item B. Parce qu’elles versent toujours des dividendes fixes
\item C. Parce qu’elles dépendent uniquement des exportations
\item D. Parce qu’elles sont principalement détenues par les banques centrales
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}

\section{QCM - Cycle économique : expansions, récessions et primes de risque}

\subsection{QCM - Output gap et cycle}

\begin{enumerate}

\item Que représente le \textbf{PIB potentiel} ($Y^*$) ?

\begin{itemize}
\item A. Le niveau de production maximal atteint pendant une crise économique
\item B. Le niveau de production qu’une économie peut soutenir durablement sans générer de tensions inflationnistes
\item C. La valeur totale des exportations d’un pays
\item D. Le niveau de consommation des ménages
\end{itemize}

\textbf{Réponse : B}

\item Le \textbf{PIB effectif} ($Y$) correspond :

\begin{itemize}
\item A. À la production réellement observée dans l’économie à un moment donné
\item B. Au niveau de production théorique déterminé par les économistes
\item C. Au revenu total des ménages
\item D. Au niveau maximal de production possible
\end{itemize}

\textbf{Réponse : A}

\item Comment se calcule l’\textbf{output gap} ?

\begin{itemize}
\item A. $\displaystyle \frac{Y^*-Y}{Y}$
\item B. $\displaystyle \frac{Y}{Y^*}$
\item C. $\displaystyle \frac{Y-Y^*}{Y^*}$
\item D. $Y - Y^*$
\end{itemize}

\textbf{Réponse : C}

\item Si le PIB observé est inférieur au PIB potentiel ($Y < Y^*$), cela signifie généralement que :

\begin{itemize}
\item A. L’économie est en surchauffe
\item B. L’inflation est très élevée
\item C. Les capacités de production sont entièrement utilisées
\item D. L’économie fonctionne en dessous de ses capacités et le chômage tend à être plus élevé
\end{itemize}

\textbf{Réponse : D}

\item Que suggère un \textbf{output gap positif} ?

\begin{itemize}
\item A. Une situation de sous-utilisation des capacités de production
\item B. Une économie en surchauffe avec des tensions possibles sur les prix et les salaires
\item C. Une baisse automatique des taux d’intérêt
\item D. Une diminution des investissements des entreprises
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}

\subsection{QCM - Lien avec les marchés}

\begin{enumerate}

\item Pourquoi le cycle économique est-il central pour la finance ?

\begin{itemize}
\item A. Parce qu’il détermine directement les politiques commerciales
\item B. Parce qu’il influence les bénéfices, le risque de défaut et la trajectoire des taux
\item C. Parce qu’il détermine uniquement le taux de change
\item D. Parce qu’il fixe le niveau des impôts
\end{itemize}

\textbf{Réponse : B}

\item Que se passe-t-il généralement pour les bénéfices des entreprises en phase d’expansion économique ?

\begin{itemize}
\item A. La demande et les ventes augmentent, ce qui soutient les profits
\item B. Les ventes diminuent fortement
\item C. Les entreprises cessent d’investir
\item D. Les marges disparaissent automatiquement
\end{itemize}

\textbf{Réponse : A}

\item Pourquoi les spreads de crédit ont-ils tendance à s’élargir lors d’un ralentissement économique ?

\begin{itemize}
\item A. Parce que les banques centrales augmentent automatiquement les taux
\item B. Parce que les entreprises émettent davantage d’actions
\item C. Parce que les entreprises fragiles ont plus de difficultés à refinancer leur dette
\item D. Parce que les profits augmentent rapidement
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi une hausse de la prime de risque peut-elle faire baisser les valorisations des actifs risqués ?

\begin{itemize}
\item A. Parce que les entreprises produisent moins
\item B. Parce que les bénéfices disparaissent immédiatement
\item C. Parce que les investisseurs vendent toujours leurs obligations
\item D. Parce que l’augmentation de l’aversion au risque réduit la valeur actuelle des flux futurs
\end{itemize}

\textbf{Réponse : D}

\end{enumerate}

\section{QCM - Marché du travail, chômage et courbe de Phillips}

\subsection{QCM - Chômage : notion macroéconomique}

\begin{enumerate}

\item Pourquoi le chômage est-il considéré comme un indicateur macroéconomique important ?

\begin{itemize}
\item A. Parce qu’il mesure uniquement les inégalités sociales
\item B. Parce qu’il indique comment l’économie utilise sa principale ressource productive : le travail
\item C. Parce qu’il détermine directement les taux de change
\item D. Parce qu’il mesure uniquement les revenus des ménages
\end{itemize}

\textbf{Réponse : B}

\item Que se passe-t-il généralement pour le chômage lorsque l’activité économique est forte ?

\begin{itemize}
\item A. Il augmente fortement
\item B. Il reste toujours stable
\item C. Il diminue car les entreprises embauchent davantage
\item D. Il disparaît totalement
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi le taux de chômage renseigne-t-il sur la position cyclique de l’économie ?

\begin{itemize}
\item A. Parce qu’il varie avec les phases d’expansion et de ralentissement économique
\item B. Parce qu’il dépend uniquement des politiques fiscales
\item C. Parce qu’il est constant dans le temps
\item D. Parce qu’il mesure directement le PIB potentiel
\end{itemize}

\textbf{Réponse : A}

\item Que suggère un marché du travail très tendu (faible chômage) ?

\begin{itemize}
\item A. Les entreprises licencient massivement
\item B. Les entreprises ont plus de difficultés à recruter
\item C. Les salaires diminuent automatiquement
\item D. La production industrielle chute
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi les banques centrales surveillent-elles attentivement le marché du travail ?

\begin{itemize}
\item A. Parce qu’il détermine les exportations
\item B. Parce qu’il fixe directement les taux de change
\item C. Parce qu’il permet d’anticiper les fluctuations boursières
\item D. Parce que les tensions salariales peuvent alimenter l’inflation
\end{itemize}

\textbf{Réponse : D}

\end{enumerate}

\subsection{QCM - Courbe de Phillips : intuition}

\begin{enumerate}

\item Que cherche à décrire la courbe de Phillips ?

\begin{itemize}
\item A. La relation entre croissance économique et productivité
\item B. La relation entre chômage et inflation
\item C. La relation entre consommation et investissement
\item D. La relation entre dette publique et taux d’intérêt
\end{itemize}

\textbf{Réponse : B}

\item Dans la formulation moderne de la courbe de Phillips, quel rôle jouent les anticipations d’inflation $\pi_t^e$ ?

\begin{itemize}
\item A. Elles n’ont aucun impact sur l’inflation observée
\item B. Elles déterminent uniquement le taux de chômage
\item C. Elles influencent directement le niveau d’inflation observé
\item D. Elles mesurent les profits des entreprises
\end{itemize}

\textbf{Réponse : C}

\item Que représente le taux de chômage $u^*$ dans l’équation de la courbe de Phillips ?

\begin{itemize}
\item A. Le taux de chômage observé dans l’économie
\item B. Le taux de chômage maximal
\item C. Le taux de chômage lié uniquement aux cycles économiques
\item D. Le taux de chômage « naturel » compatible avec une inflation stable
\end{itemize}

\textbf{Réponse : D}

\item Que se passe-t-il généralement lorsque le taux de chômage observé est inférieur au taux naturel ($u_t < u^*$) ?

\begin{itemize}
\item A. Le marché du travail est tendu et les pressions inflationnistes augmentent
\item B. L’économie entre automatiquement en récession
\item C. Les prix baissent rapidement
\item D. Les salaires diminuent fortement
\end{itemize}

\textbf{Réponse : A}

\item Quel est l’effet probable lorsque le taux de chômage observé est supérieur au taux naturel ($u_t > u^*$) ?

\begin{itemize}
\item A. Les entreprises augmentent fortement leurs prix
\item B. Les pressions salariales et inflationnistes tendent à diminuer
\item C. L’inflation augmente automatiquement
\item D. Les taux d’intérêt disparaissent
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}

\subsection{QCM - Schéma : Phillips (relation inverse stylisée)}

\begin{enumerate}

\item Dans le schéma de la courbe de Phillips, quelles sont les deux variables représentées sur les axes ?

\begin{itemize}
\item A. Inflation et croissance du PIB
\item B. Chômage et inflation
\item C. Taux d’intérêt et inflation
\item D. Consommation et investissement
\end{itemize}

\textbf{Réponse : B}

\item Quelle relation stylisée la courbe de Phillips met-elle en évidence ?

\begin{itemize}
\item A. Une relation positive entre chômage et inflation
\item B. Une relation sans lien entre chômage et inflation
\item C. Une relation inverse entre chômage et inflation
\item D. Une relation stable entre inflation et taux d’intérêt
\end{itemize}

\textbf{Réponse : C}

\item Que représente la ligne verticale marquée $u^*$ dans le schéma ?

\begin{itemize}
\item A. Le niveau maximal de chômage possible
\item B. Le taux de chômage observé dans l’économie
\item C. Le taux de chômage naturel compatible avec une inflation stable
\item D. Le taux de participation au marché du travail
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi les données du marché du travail sont-elles particulièrement suivies par les investisseurs ?

\begin{itemize}
\item A. Parce qu’elles permettent d’anticiper l’évolution de l’inflation et de la politique monétaire
\item B. Parce qu’elles déterminent directement les profits des entreprises
\item C. Parce qu’elles fixent le niveau du PIB potentiel
\item D. Parce qu’elles déterminent la balance commerciale
\end{itemize}

\textbf{Réponse : A}

\item Quel effet une hausse anticipée des taux d’intérêt a-t-elle généralement sur le prix des obligations ?

\begin{itemize}
\item A. Elle augmente automatiquement le prix des obligations
\item B. Elle n’a aucun effet sur les obligations
\item C. Elle tend à faire baisser le prix des obligations
\item D. Elle supprime le marché obligataire
\end{itemize}

\textbf{Réponse : C}

\end{enumerate}

\section{QCM - Monnaie, banques et création monétaire}

\subsection{QCM - Pourquoi la monnaie est au cœur des marchés}

\begin{enumerate}

\item Que désigne la \textbf{liquidité} sur les marchés financiers ?

\begin{itemize}
\item A. La capacité d’un actif à générer des dividendes élevés
\item B. La capacité d’acheter ou de vendre rapidement un actif sans provoquer de forte variation de son prix
\item C. Le niveau de profit des entreprises
\item D. Le volume total des échanges internationaux
\end{itemize}

\textbf{Réponse : B}

\item Quelle fonction de la monnaie consiste à exprimer la valeur des biens, services et actifs financiers ?

\begin{itemize}
\item A. Réserve de valeur
\item B. Moyen de paiement
\item C. Unité de compte
\item D. Instrument de politique monétaire
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi la monnaie est-elle considérée comme l’actif le plus liquide du système économique ?

\begin{itemize}
\item A. Parce qu’elle génère toujours un rendement élevé
\item B. Parce qu’elle ne peut jamais perdre de valeur
\item C. Parce qu’elle peut être immédiatement utilisée pour effectuer des transactions
\item D. Parce qu’elle est uniquement détenue par les banques centrales
\end{itemize}

\textbf{Réponse : C}

\item Quel rôle jouent les banques dans le système financier ?

\begin{itemize}
\item A. Elles transforment les dépôts en crédits pour financer l’économie
\item B. Elles fixent directement les prix des actions
\item C. Elles déterminent le niveau du PIB
\item D. Elles contrôlent toutes les transactions commerciales
\end{itemize}

\textbf{Réponse : A}

\item Quel peut être l’effet d’une contraction du crédit dans l’économie ?

\begin{itemize}
\item A. Une augmentation automatique des exportations
\item B. Un ralentissement possible de l’activité économique
\item C. Une hausse immédiate de l’inflation
\item D. Une disparition du système bancaire
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}

\subsection{QCM - Base monétaire, monnaie, multiplicateur : idée simple}

\begin{enumerate}

\item Que désigne la \textbf{base monétaire} dans l’économie ?

\begin{itemize}
\item A. L’ensemble des crédits accordés par les banques
\item B. La monnaie créée par la banque centrale (billets en circulation et réserves des banques)
\item C. Le total des dépôts des ménages uniquement
\item D. La somme des investissements réalisés par les entreprises
\end{itemize}

\textbf{Réponse : B}

\item Que comprennent généralement les \textbf{agrégats monétaires} au sens large ?

\begin{itemize}
\item A. Les billets en circulation uniquement
\item B. Les réserves des banques centrales uniquement
\item C. Les dépôts bancaires détenus par les ménages et les entreprises en plus de la monnaie centrale
\item D. Les actions cotées en bourse
\end{itemize}

\textbf{Réponse : C}

\item Quelle relation simple relie la quantité totale de monnaie à la base monétaire ?

\begin{itemize}
\item A. $M = B + m$
\item B. $M = \dfrac{B}{m}$
\item C. $M = m \cdot B$
\item D. $M = B - m$
\end{itemize}

\textbf{Réponse : C}

\item De quoi dépend principalement le multiplicateur monétaire $m$ ?

\begin{itemize}
\item A. Du taux de change uniquement
\item B. Du niveau des exportations
\item C. Des réserves bancaires, des préférences pour la liquidité et de la régulation bancaire
\item D. Du niveau du PIB potentiel
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi la création monétaire est-elle étroitement liée au crédit bancaire ?

\begin{itemize}
\item A. Parce que les prêts accordés par les banques augmentent les dépôts dans l’économie
\item B. Parce que les crédits réduisent automatiquement la quantité de monnaie
\item C. Parce que les banques centrales interdisent la création de dépôts
\item D. Parce que le crédit supprime les billets en circulation
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}

\section{QCM - Banque centrale : politique monétaire, taux directeurs et transmission}

\subsection{QCM - Objectifs typiques}

\begin{enumerate}

\item Quel est le rôle général d’une banque centrale dans l’économie ?

\begin{itemize}
\item A. Réguler les conditions monétaires afin de favoriser la stabilité économique
\item B. Déterminer directement les profits des entreprises
\item C. Fixer les salaires dans l’économie
\item D. Contrôler les exportations et les importations
\end{itemize}

\textbf{Réponse : A}

\item Quels sont les deux objectifs principaux poursuivis par la plupart des banques centrales ?

\begin{itemize}
\item A. Maximiser les profits des banques et stabiliser les exportations
\item B. Stabiliser les prix et soutenir l’activité économique et la stabilité financière
\item C. Réduire les impôts et augmenter les dépenses publiques
\item D. Augmenter les salaires et diminuer les taux de change
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi la stabilité des prix est-elle souvent considérée comme l’objectif prioritaire ?

\begin{itemize}
\item A. Parce qu’elle détermine directement la croissance démographique
\item B. Parce qu’une inflation instable perturbe les décisions économiques et la confiance dans la monnaie
\item C. Parce qu’elle garantit une hausse permanente des salaires
\item D. Parce qu’elle supprime les cycles économiques
\end{itemize}

\textbf{Réponse : B}

\item Quelle est la cible d’inflation souvent adoptée par de nombreuses banques centrales ?

\begin{itemize}
\item A. Environ 10\% par an
\item B. Environ 0\% par an
\item C. Environ 2\% par an
\item D. Environ 5\% par an
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi les banques centrales surveillent-elles également la stabilité financière ?

\begin{itemize}
\item A. Parce que des cycles économiques instables peuvent conduire à des crises bancaires ou des récessions
\item B. Parce qu’elles doivent contrôler les profits des entreprises
\item C. Parce qu’elles doivent fixer les prix des actifs financiers
\item D. Parce qu’elles doivent déterminer les salaires dans l’économie
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}
''',
  r'''
\subsection{QCM - Le taux directeur : prix du temps et de la liquidité}

\begin{enumerate}

\item Qu’est-ce que le \textbf{taux directeur} d’une banque centrale ?

\begin{itemize}
\item A. Le taux auquel la banque centrale prête des liquidités à court terme aux banques
\item B. Le taux d’intérêt appliqué aux dépôts des ménages
\item C. Le taux de croissance de l’économie
\item D. Le taux d’inflation cible de la banque centrale
\end{itemize}

\textbf{Réponse : A}

\item Pourquoi le taux directeur est-il souvent décrit comme le « prix du temps et de la liquidité » ?

\begin{itemize}
\item A. Parce qu’il fixe le prix des actions
\item B. Parce qu’il influence le coût auquel les banques peuvent se refinancer
\item C. Parce qu’il détermine les salaires dans l’économie
\item D. Parce qu’il détermine le niveau du PIB potentiel
\end{itemize}

\textbf{Réponse : B}

\item Quelle variable financière est directement influencée par les variations du taux directeur ?

\begin{itemize}
\item A. Les taux d’intérêt à court terme sur les marchés monétaires
\item B. Les exportations de biens industriels
\item C. Le nombre d’entreprises cotées en bourse
\item D. La population active
\end{itemize}

\textbf{Réponse : A}

\item Comment une hausse du taux directeur affecte-t-elle généralement l’économie ?

\begin{itemize}
\item A. Elle rend le crédit moins coûteux
\item B. Elle stimule immédiatement la consommation
\item C. Elle augmente automatiquement les salaires
\item D. Elle rend le crédit plus coûteux et peut freiner la consommation et l’investissement
\end{itemize}

\textbf{Réponse : D}

\item Pourquoi les taux d’intérêt sont-ils importants dans les modèles de valorisation financière ?

\begin{itemize}
\item A. Parce qu’ils déterminent directement les profits des entreprises
\item B. Parce qu’ils servent à actualiser les flux financiers futurs
\item C. Parce qu’ils fixent le niveau des exportations
\item D. Parce qu’ils déterminent les dépenses publiques
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}

\subsection{QCM - Règle de Taylor (forme simple)}

\begin{enumerate}

\item Quel est l’objectif principal de la règle de Taylor en macroéconomie ?

\begin{itemize}
\item A. Déterminer automatiquement le niveau du PIB potentiel
\item B. Décrire de manière stylisée comment une banque centrale ajuste son taux directeur
\item C. Fixer le niveau optimal de la dette publique
\item D. Mesurer la croissance de la productivité
\end{itemize}

\textbf{Réponse : B}

\item Dans l’équation de la règle de Taylor, que représente la variable $i_t$ ?

\begin{itemize}
\item A. Le taux directeur fixé par la banque centrale
\item B. Le taux d’inflation cible
\item C. Le niveau de production potentielle
\item D. Le taux de chômage naturel
\end{itemize}

\textbf{Réponse : A}

\item Dans la règle de Taylor, que signifie l’expression 
$\frac{Y_t - Y_t^*}{Y_t^*}$ ?

\begin{itemize}
\item A. Le niveau d’inflation observé
\item B. Le taux d’intérêt réel d’équilibre
\item C. L’output gap (écart entre l’activité observée et le PIB potentiel)
\item D. Le niveau des dépenses publiques
\end{itemize}

\textbf{Réponse : C}

\item Selon l’intuition de la règle de Taylor, que fait généralement la banque centrale si l’inflation dépasse sa cible ?

\begin{itemize}
\item A. Elle réduit immédiatement les impôts
\item B. Elle diminue les taux directeurs
\item C. Elle augmente les dépenses publiques
\item D. Elle augmente les taux directeurs pour freiner l’économie
\end{itemize}

\textbf{Réponse : D}

\item Pourquoi les marchés financiers réagissent-ils fortement aux surprises sur l’inflation ou l’activité ?

\begin{itemize}
\item A. Parce que ces informations modifient les anticipations concernant la trajectoire future des taux directeurs
\item B. Parce qu’elles déterminent directement les profits des entreprises
\item C. Parce qu’elles fixent les salaires dans l’économie
\item D. Parce qu’elles changent automatiquement la politique budgétaire
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}

\section{QCM - Taux d’intérêt et obligations : prix, duration, courbe des taux}

\subsection{QCM - Prix d’une obligation (rappel intertemporel)}

\begin{enumerate}

\item Que représente une obligation du point de vue financier ?

\begin{itemize}
\item A. Un titre qui donne un droit de propriété dans l’entreprise
\item B. Un contrat qui promet une série de paiements futurs (coupons et remboursement du principal)
\item C. Un instrument qui sert uniquement à fixer les taux d’intérêt
\item D. Un actif qui ne génère aucun flux financier
\end{itemize}

\textbf{Réponse : B}

\item Quels sont les deux principaux flux versés par une obligation ?

\begin{itemize}
\item A. Les dividendes et les gains en capital
\item B. Les coupons et le remboursement du principal
\item C. Les salaires et les profits
\item D. Les impôts et les transferts
\end{itemize}

\textbf{Réponse : B}

\item Dans la formule du prix d’une obligation, que représente la variable $y$ ?

\begin{itemize}
\item A. Le taux d’inflation
\item B. Le taux de croissance économique
\item C. Le taux actuariel (yield) exigé par le marché
\item D. Le niveau de la dette publique
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi le prix d’une obligation baisse-t-il généralement lorsque les taux d’intérêt augmentent ?

\begin{itemize}
\item A. Parce que les coupons disparaissent
\item B. Parce que les obligations deviennent illégales
\item C. Parce que les flux futurs sont actualisés à un taux plus élevé
\item D. Parce que les entreprises paient moins d’impôts
\end{itemize}

\textbf{Réponse : C}

\item Quelle idée fondamentale de la finance est illustrée par la formule du prix d’une obligation ?

\begin{itemize}
\item A. La valeur d’un actif dépend uniquement de son prix passé
\item B. Les prix financiers sont fixés par les banques centrales
\item C. Les profits déterminent toujours les prix des obligations
\item D. La valeur d’un actif correspond à la valeur actualisée de ses flux futurs
\end{itemize}

\textbf{Réponse : D}

\end{enumerate}

\subsection{QCM - Duration : sensibilité au taux}

\begin{enumerate}

\item Que mesure principalement la \textbf{duration} d’une obligation ?

\begin{itemize}
\item A. Le montant total des coupons versés
\item B. La sensibilité du prix de l’obligation aux variations des taux d’intérêt
\item C. La probabilité de défaut de l’émetteur
\item D. Le niveau d’inflation anticipé
\end{itemize}

\textbf{Réponse : B}

\item Dans l’approximation
\[
\frac{\Delta P}{P} \approx -D\,\Delta y,
\]
que représente $\Delta y$ ?

\begin{itemize}
\item A. La variation du taux d’intérêt
\item B. La durée de vie de l’obligation
\item C. Le niveau des coupons
\item D. Le prix initial de l’obligation
\end{itemize}

\textbf{Réponse : A}

\item Que signifie le signe négatif dans la relation entre le prix d’une obligation et les taux d’intérêt ?

\begin{itemize}
\item A. Le prix d’une obligation ne dépend pas des taux
\item B. Les taux et les prix évoluent toujours dans la même direction
\item C. Les obligations perdent toute valeur lorsque les taux changent
\item D. Les taux et les prix évoluent en sens inverse
\end{itemize}

\textbf{Réponse : D}

\item Quelles obligations ont généralement une duration plus élevée ?

\begin{itemize}
\item A. Les obligations à courte maturité
\item B. Les obligations indexées sur l’inflation
\item C. Les obligations à longue maturité
\item D. Les obligations émises par les banques centrales
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi les obligations avec des coupons faibles sont-elles plus sensibles aux variations de taux ?

\begin{itemize}
\item A. Parce qu’une plus grande partie de leur valeur dépend de paiements éloignés dans le temps
\item B. Parce qu’elles sont toujours émises par des États
\item C. Parce que leurs prix ne varient jamais
\item D. Parce qu’elles versent plus de coupons
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}

\subsection{QCM - Courbe des taux : information macro condensée}

\begin{enumerate}

\item Que représente la \textbf{courbe des taux} ?

\begin{itemize}
\item A. La relation entre la maturité d’un emprunt et le taux d’intérêt associé
\item B. La relation entre inflation et chômage
\item C. La relation entre profits et croissance économique
\item D. La relation entre dépenses publiques et impôts
\end{itemize}

\textbf{Réponse : A}

\item Pourquoi la courbe des taux est-elle importante en macro-finance ?

\begin{itemize}
\item A. Parce qu’elle fixe directement les profits des entreprises
\item B. Parce qu’elle synthétise les anticipations macroéconomiques des investisseurs
\item C. Parce qu’elle détermine la quantité de monnaie
\item D. Parce qu’elle mesure la croissance du PIB
\end{itemize}

\textbf{Réponse : B}

\item Quels sont les deux éléments principaux qui déterminent la forme de la courbe des taux ?

\begin{itemize}
\item A. Les impôts et les dépenses publiques
\item B. Les exportations et les importations
\item C. Les anticipations de taux courts futurs et la prime de terme
\item D. La croissance démographique et la productivité
\end{itemize}

\textbf{Réponse : C}

\item Que signifie généralement une \textbf{courbe des taux normale} ?

\begin{itemize}
\item A. Les taux courts sont plus élevés que les taux longs
\item B. Les taux longs sont plus élevés que les taux courts
\item C. Les taux sont identiques pour toutes les maturités
\item D. Les taux sont toujours négatifs
\end{itemize}

\textbf{Réponse : B}

\item Comment les investisseurs interprètent-ils souvent une \textbf{courbe des taux inversée} ?

\begin{itemize}
\item A. Comme un signal possible de ralentissement économique futur
\item B. Comme un signe d’expansion économique forte
\item C. Comme une preuve que l’inflation disparaît définitivement
\item D. Comme une indication que les marchés actions vont toujours monter
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}
''',
  r'''
\section{QCM - Demande globale et offre globale : un cadre simple pour comprendre les régimes}

\subsection{QCM - AD-AS (version simplifiée)}

\begin{enumerate}

\item Que cherche à expliquer le modèle \textbf{AD-AS} en macroéconomie ?

\begin{itemize}
\item A. La formation des salaires uniquement
\item B. La détermination du taux de change
\item C. La détermination du niveau d’activité économique et du niveau général des prix
\item D. La structure du système bancaire
\end{itemize}

\textbf{Réponse : C}

\item Que représente la \textbf{demande globale (AD)} ?

\begin{itemize}
\item A. La demande totale adressée aux entreprises dans l’économie
\item B. La quantité de monnaie en circulation
\item C. La production maximale possible dans l’économie
\item D. Le volume des exportations uniquement
\end{itemize}

\textbf{Réponse : A}

\item Quelle identité macroéconomique représente la demande globale ?

\begin{itemize}
\item A. $Y = W + \Pi$
\item B. $Y = C + I + G + (X - M)$
\item C. $Y = K + L$
\item D. $Y = T - G$
\end{itemize}

\textbf{Réponse : B}

\item De quoi dépend principalement l’\textbf{offre globale (AS)} ?

\begin{itemize}
\item A. Des préférences de consommation des ménages uniquement
\item B. Du niveau des taux d’intérêt uniquement
\item C. Des capacités productives et des coûts de production
\item D. Du niveau des exportations uniquement
\end{itemize}

\textbf{Réponse : C}

\item Quel événement correspond à un \textbf{choc de demande} dans le modèle AD-AS ?

\begin{itemize}
\item A. Une hausse du prix de l’énergie
\item B. Une perturbation des chaînes d’approvisionnement
\item C. Une innovation technologique
\item D. Une baisse des taux d’intérêt qui stimule la consommation et l’investissement
\end{itemize}

\textbf{Réponse : D}

\end{enumerate}

\subsection{QCM - AD-AS et inflation}

\begin{enumerate}

\item Dans le schéma AD-AS, que représente l’axe horizontal ?

\begin{itemize}
\item A. Le niveau des salaires
\item B. Le niveau d’inflation
\item C. La production ou niveau d’activité économique ($Y$)
\item D. Le taux d’intérêt
\end{itemize}

\textbf{Réponse : C}

\item Que représente l’axe vertical dans le schéma ?

\begin{itemize}
\item A. Le niveau des prix ($P$)
\item B. Le taux de chômage
\item C. Le niveau de la dette publique
\item D. Le taux d’intérêt réel
\end{itemize}

\textbf{Réponse : A}

\item Que représente le déplacement de AD$_0$ vers AD$_1$ dans le graphique ?

\begin{itemize}
\item A. Une contraction de la demande globale
\item B. Une hausse de la demande globale
\item C. Une baisse des capacités productives
\item D. Une hausse des impôts
\end{itemize}

\textbf{Réponse : B}

\item Selon le schéma, quel est l’effet d’un choc positif de demande sur l’équilibre économique ?

\begin{itemize}
\item A. Baisse de la production et baisse des prix
\item B. Hausse de la production uniquement
\item C. Hausse des prix uniquement
\item D. Hausse de la production et du niveau des prix
\end{itemize}

\textbf{Réponse : D}

\item Pourquoi un choc de demande positif peut-il peser sur les obligations ?

\begin{itemize}
\item A. Parce qu’il réduit les profits des entreprises
\item B. Parce qu’il diminue les salaires
\item C. Parce qu’il peut entraîner des anticipations de hausse des taux d’intérêt
\item D. Parce qu’il réduit la liquidité bancaire
\end{itemize}

\textbf{Réponse : C}

\end{enumerate}

\section{QCM - IS-LM : intuition finance (taux, investissement, activité)}

\subsection{QCM - IS : équilibre sur le marché des biens}

\begin{enumerate}

\item Que représente la courbe \textbf{IS} dans le modèle macroéconomique ?

\begin{itemize}
\item A. Les combinaisons de revenu $Y$ et de taux d’intérêt $i$ pour lesquelles le marché des biens est à l’équilibre
\item B. La relation entre inflation et chômage
\item C. L’équilibre sur le marché du travail
\item D. L’évolution de la productivité dans l’économie
\end{itemize}

\textbf{Réponse : A}

\item Dans le cadre de la courbe IS, que signifie l’équilibre sur le marché des biens ?

\begin{itemize}
\item A. Les exportations sont égales aux importations
\item B. L’épargne est égale à l’investissement public
\item C. La production totale est égale à la demande globale
\item D. Les entreprises réalisent un profit nul
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi l’investissement est-il particulièrement sensible au taux d’intérêt ?

\begin{itemize}
\item A. Parce que le taux d’intérêt représente le coût du capital
\item B. Parce qu’il détermine le niveau des salaires
\item C. Parce qu’il fixe le niveau des exportations
\item D. Parce qu’il détermine la population active
\end{itemize}

\textbf{Réponse : A}

\item Que se passe-t-il généralement lorsque les taux d’intérêt augmentent ?

\begin{itemize}
\item A. L’investissement augmente fortement
\item B. L’investissement peut diminuer car le financement devient plus coûteux
\item C. Les dépenses publiques augmentent automatiquement
\item D. Les exportations augmentent toujours
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi la courbe IS est-elle généralement représentée comme \textbf{décroissante} ?

\begin{itemize}
\item A. Parce que des taux plus élevés sont associés à un niveau d’activité plus faible
\item B. Parce que la production dépend uniquement des salaires
\item C. Parce que les exportations diminuent toujours avec le revenu
\item D. Parce que les banques centrales fixent directement le PIB
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}

\subsection{QCM - LM : équilibre monétaire (version pédagogique)}

\begin{enumerate}

\item Que représente la courbe \textbf{LM} dans le modèle macroéconomique ?

\begin{itemize}
\item A. Les combinaisons de revenu $Y$ et de taux d’intérêt $i$ pour lesquelles le marché de la monnaie est à l’équilibre
\item B. La relation entre inflation et chômage
\item C. L’équilibre entre exportations et importations
\item D. L’évolution de la productivité dans l’économie
\end{itemize}

\textbf{Réponse : A}

\item Dans le cadre de la courbe LM, que signifie l’équilibre monétaire ?

\begin{itemize}
\item A. L’offre de monnaie est supérieure à la demande
\item B. La demande de monnaie est égale à l’offre de monnaie
\item C. Les taux d’intérêt sont fixés par le gouvernement
\item D. La production est égale aux dépenses publiques
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi la demande de monnaie augmente-t-elle lorsque le revenu $Y$ augmente ?

\begin{itemize}
\item A. Parce que les ménages épargnent moins
\item B. Parce que les entreprises investissent davantage
\item C. Parce que les agents réalisent davantage de transactions économiques
\item D. Parce que les taux d’intérêt diminuent automatiquement
\end{itemize}

\textbf{Réponse : C}

\item Que se passe-t-il généralement si la demande de monnaie augmente alors que l’offre de monnaie reste fixe ?

\begin{itemize}
\item A. Les taux d’intérêt augmentent
\item B. Les taux d’intérêt diminuent
\item C. Les prix diminuent immédiatement
\item D. Les salaires augmentent automatiquement
\end{itemize}

\textbf{Réponse : A}

\item Pourquoi la courbe LM est-elle généralement représentée comme \textbf{croissante} ?

\begin{itemize}
\item A. Parce que la monnaie dépend uniquement de la croissance économique
\item B. Parce que des niveaux d’activité plus élevés sont associés à des taux d’intérêt plus élevés pour maintenir l’équilibre monétaire
\item C. Parce que les banques centrales fixent directement la production
\item D. Parce que les exportations augmentent toujours avec le revenu
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}

\subsection{QCM - IS-LM et choc monétaire}

\begin{enumerate}

\item Dans le graphique IS-LM, que représente l’axe horizontal ?

\begin{itemize}
\item A. Le niveau d’inflation
\item B. Le revenu ou niveau d’activité économique ($Y$)
\item C. Le niveau de la dette publique
\item D. La masse monétaire
\end{itemize}

\textbf{Réponse : B}

\item Que représente l’axe vertical dans le schéma ?

\begin{itemize}
\item A. Le taux d’intérêt ($i$)
\item B. Le niveau des prix
\item C. Le taux de chômage
\item D. Le niveau de consommation
\end{itemize}

\textbf{Réponse : A}

\item Que signifie le déplacement de LM$_0$ vers LM$_1$ dans le schéma ?

\begin{itemize}
\item A. Un resserrement de la politique budgétaire
\item B. Une hausse des impôts
\item C. Un assouplissement de la politique monétaire
\item D. Une baisse de la productivité
\end{itemize}

\textbf{Réponse : C}

\item Selon le schéma, quel est l’effet d’un assouplissement monétaire sur l’équilibre macroéconomique ?

\begin{itemize}
\item A. Hausse du taux d’intérêt et baisse de l’activité
\item B. Baisse du taux d’intérêt et hausse du niveau d’activité
\item C. Baisse de la production et hausse de l’inflation
\item D. Aucun changement dans l’économie
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi un assouplissement monétaire peut-il soutenir les marchés financiers ?

\begin{itemize}
\item A. Parce qu’il augmente directement les profits des entreprises
\item B. Parce qu’il supprime les cycles économiques
\item C. Parce qu’il réduit les impôts
\item D. Parce que des taux plus faibles augmentent la valeur actuelle des flux futurs
\end{itemize}

\textbf{Réponse : D}

\end{enumerate}

\section{QCM - Économie ouverte : taux de change, balance des paiements, flux de capitaux}

\subsection{QCM - Taux de change et actifs}

\begin{enumerate}

\item Qu’est-ce que le \textbf{taux de change} ?

\begin{itemize}
\item A. Le taux d’intérêt fixé par la banque centrale
\item B. Le prix d’une devise exprimé dans une autre devise
\item C. Le taux d’inflation entre deux pays
\item D. Le niveau des exportations d’un pays
\end{itemize}

\textbf{Réponse : B}

\item Quel effet une \textbf{dépréciation} de la monnaie nationale peut-elle avoir sur les exportations ?

\begin{itemize}
\item A. Les exportations deviennent généralement plus compétitives
\item B. Les exportations disparaissent
\item C. Les exportations deviennent plus chères à l’étranger
\item D. Les exportations n’ont aucun lien avec le taux de change
\end{itemize}

\textbf{Réponse : A}

\item Pourquoi une dépréciation de la monnaie peut-elle générer de l’\textbf{inflation importée} ?

\begin{itemize}
\item A. Parce que les salaires augmentent automatiquement
\item B. Parce que les exportations deviennent plus élevées
\item C. Parce que les biens importés deviennent plus coûteux
\item D. Parce que la production nationale diminue
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi les fluctuations du taux de change affectent-elles les entreprises multinationales ?

\begin{itemize}
\item A. Parce qu’elles modifient la valeur en monnaie domestique des revenus réalisés à l’étranger
\item B. Parce qu’elles déterminent directement les salaires
\item C. Parce qu’elles fixent le niveau des impôts
\item D. Parce qu’elles déterminent le niveau du PIB potentiel
\end{itemize}

\textbf{Réponse : A}

\item À quel type de risque un investisseur est-il exposé lorsqu’il détient des actifs étrangers ?

\begin{itemize}
\item A. Uniquement au risque de défaut
\item B. Uniquement au risque d’inflation
\item C. Uniquement au risque de liquidité
\item D. Au risque de variation du prix de l’actif et au risque de change
\end{itemize}

\textbf{Réponse : D}

\end{enumerate}

\subsection{QCM - Parité non couverte des taux d’intérêt (UIP) : idée}

\begin{enumerate}

\item Que cherche à expliquer la \textbf{parité non couverte des taux d’intérêt (UIP)} ?

\begin{itemize}
\item A. La relation entre chômage et inflation
\item B. La relation entre taux d’intérêt et taux de change
\item C. La relation entre croissance économique et productivité
\item D. La relation entre dette publique et inflation
\end{itemize}

\textbf{Réponse : B}

\item Dans l’équation de la UIP, que représente $S_t$ ?

\begin{itemize}
\item A. Le taux d’intérêt domestique
\item B. Le taux d’inflation anticipé
\item C. Le taux de change actuel (prix de la devise étrangère en monnaie domestique)
\item D. Le niveau de production de l’économie
\end{itemize}

\textbf{Réponse : C}

\item Dans cette relation, que représente $i^*$ ?

\begin{itemize}
\item A. Le taux d’intérêt étranger
\item B. Le taux d’inflation domestique
\item C. Le taux de croissance économique
\item D. Le taux de chômage naturel
\end{itemize}

\textbf{Réponse : A}

\item Pourquoi les investisseurs internationaux comparent-ils les taux d’intérêt entre pays ?

\begin{itemize}
\item A. Pour déterminer la politique budgétaire
\item B. Pour arbitrer entre les rendements offerts par différents marchés financiers
\item C. Pour déterminer la croissance démographique
\item D. Pour fixer les salaires dans l’économie
\end{itemize}

\textbf{Réponse : B}

\item Selon l’intuition de la UIP, que peut-il se produire si les taux d’intérêt domestiques deviennent plus élevés que les taux étrangers ?

\begin{itemize}
\item A. Les capitaux peuvent affluer vers ce pays et la devise domestique peut s’apprécier
\item B. Les exportations disparaissent immédiatement
\item C. Les salaires augmentent automatiquement
\item D. Les banques centrales perdent tout contrôle sur la monnaie
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}

\subsection{QCM - Marché des changes (offre/demande de devise)}

\begin{enumerate}

\item Dans le schéma du marché des changes, que représente l’axe vertical ?

\begin{itemize}
\item A. Le taux d’intérêt
\item B. Le niveau des prix
\item C. Le taux de change $S$
\item D. Le niveau de production
\end{itemize}

\textbf{Réponse : C}

\item Que représente l’axe horizontal dans ce graphique ?

\begin{itemize}
\item A. La quantité de devise étrangère échangée
\item B. Le niveau des exportations
\item C. Le taux d’inflation
\item D. Le niveau des investissements
\end{itemize}

\textbf{Réponse : A}

\item Qui est à l’origine de la \textbf{demande de devises étrangères} sur le marché des changes ?

\begin{itemize}
\item A. Les exportateurs uniquement
\item B. Les importateurs et les investisseurs souhaitant acheter des actifs étrangers
\item C. Les banques centrales uniquement
\item D. Les ménages qui épargnent
\end{itemize}

\textbf{Réponse : B}

\item Qui contribue généralement à l’\textbf{offre de devises étrangères} ?

\begin{itemize}
\item A. Les exportateurs et les investisseurs étrangers qui achètent des actifs domestiques
\item B. Les consommateurs domestiques
\item C. Les banques commerciales uniquement
\item D. Les salariés
\end{itemize}

\textbf{Réponse : A}

\item Dans ce marché, que représente le point d’intersection entre les courbes d’offre et de demande ?

\begin{itemize}
\item A. Le niveau maximal du taux de change
\item B. Le niveau minimal des exportations
\item C. Le taux de change auquel la demande dépasse l’offre
\item D. Le taux de change d’équilibre où la quantité offerte est égale à la quantité demandée
\end{itemize}

\textbf{Réponse : D}

\end{enumerate}
''',
  r'''
\section{QCM - Politique budgétaire : déficit, dette et effets sur les marchés}

\subsection{QCM - Déficit et dette : définitions}

\begin{enumerate}

\item Quelle est la différence fondamentale entre un \textbf{déficit public} et la \textbf{dette publique} ?

\begin{itemize}
\item A. Le déficit est un stock alors que la dette est un flux annuel
\item B. Le déficit correspond uniquement aux dépenses publiques
\item C. Le déficit est un flux annuel tandis que la dette est un stock accumulé
\item D. La dette correspond uniquement aux intérêts payés par l’État
\end{itemize}

\textbf{Réponse : C}

\item Quand apparaît un \textbf{déficit public} ?

\begin{itemize}
\item A. Lorsque les dépenses publiques sont inférieures aux recettes fiscales
\item B. Lorsque les dépenses publiques dépassent les recettes fiscales
\item C. Lorsque la dette publique diminue
\item D. Lorsque l’inflation augmente
\end{itemize}

\textbf{Réponse : B}

\item Que représente le ratio $b_t$ dans l’équation de dynamique de la dette ?

\begin{itemize}
\item A. Le taux d’inflation
\item B. Le ratio dette publique / PIB
\item C. Le niveau des dépenses publiques
\item D. Le taux de chômage
\end{itemize}

\textbf{Réponse : B}

\item Dans l’équation
\[
b_{t+1} \approx \frac{1+r}{1+g} b_t + d_t
\]
que représente $d_t$ ?

\begin{itemize}
\item A. Le déficit primaire exprimé en pourcentage du PIB
\item B. Le niveau total de la dette
\item C. Le taux de croissance de l’économie
\item D. Le taux d’intérêt nominal
\end{itemize}

\textbf{Réponse : A}

\item Selon l’interprétation macroéconomique, que se passe-t-il lorsque la croissance économique $g$ est supérieure au taux d’intérêt réel $r$ ?

\begin{itemize}
\item A. La dette publique augmente toujours plus rapidement
\item B. Le déficit disparaît automatiquement
\item C. Le ratio dette/PIB peut se stabiliser plus facilement
\item D. Les taux d’intérêt deviennent négatifs
\end{itemize}

\textbf{Réponse : C}

\end{enumerate}


\subsection{QCM - Lien finance : souverain, taux, spreads}

\begin{enumerate}

\item Comment les États financent-ils principalement leur dette sur les marchés financiers ?

\begin{itemize}
\item A. En émettant des obligations souveraines
\item B. En vendant directement des actions
\item C. En augmentant automatiquement les impôts
\item D. En imprimant de la monnaie
\end{itemize}

\textbf{Réponse : A}

\item Parmi les éléments suivants, lequel influence l’évaluation du risque souverain par les investisseurs ?

\begin{itemize}
\item A. La soutenabilité de la dette publique
\item B. Le nombre de banques commerciales
\item C. Le nombre d’entreprises cotées
\item D. Le volume des exportations mondiales
\end{itemize}

\textbf{Réponse : A}

\item Qu’est-ce que le \textbf{risque de refinancement} pour un État ?

\begin{itemize}
\item A. Le risque que les taux d’intérêt deviennent négatifs
\item B. Le risque lié à la nécessité de renouveler les emprunts arrivant à maturité
\item C. Le risque que l’inflation disparaisse
\item D. Le risque de baisse des exportations
\end{itemize}

\textbf{Réponse : B}

\item Que signifie le terme \textbf{spread} sur les marchés obligataires ?

\begin{itemize}
\item A. La différence entre les dépenses publiques et les recettes fiscales
\item B. Le taux d’inflation anticipé
\item C. L’écart de taux entre l’obligation d’un État et celle d’un émetteur de référence plus sûr
\item D. Le rendement total d’une obligation
\end{itemize}

\textbf{Réponse : C}

\item Selon le schéma présenté, que se passe-t-il généralement lorsque le risque perçu d’un État augmente ?

\begin{itemize}
\item A. Le spread diminue automatiquement
\item B. Le taux d’intérêt devient nul
\item C. La dette publique disparaît
\item D. Le spread de taux augmente
\end{itemize}

\textbf{Réponse : D}

\end{enumerate}

\section{QCM - Stabilité financière : levier, crises et contagion}

\subsection{QCM - Pourquoi les crises sont macro-financières}

\begin{enumerate}

\item Qu’est-ce qui caractérise principalement une \textbf{crise financière} selon cette analyse ?

\begin{itemize}
\item A. Une simple baisse temporaire des prix sur les marchés
\item B. Une hausse rapide de l’inflation
\item C. Un dysfonctionnement du système financier qui perturbe l’intermédiation entre épargne et investissement
\item D. Une augmentation des exportations
\end{itemize}

\textbf{Réponse : C}

\item Quel rôle jouent les banques et les marchés financiers dans une économie moderne ?

\begin{itemize}
\item A. Ils transforment l’épargne des ménages en financement pour l’économie
\item B. Ils déterminent directement le niveau du PIB
\item C. Ils fixent les salaires dans l’économie
\item D. Ils déterminent les impôts
\end{itemize}

\textbf{Réponse : A}

\item Qu’est-ce qui peut provoquer un blocage du système financier lors d’une crise ?

\begin{itemize}
\item A. Une hausse des exportations
\item B. Un manque de confiance, un manque de liquidité ou une crainte de défaut
\item C. Une augmentation de la population active
\item D. Une baisse du taux de chômage
\end{itemize}

\textbf{Réponse : B}

\item Quel peut être l’effet macroéconomique d’une contraction du crédit ?

\begin{itemize}
\item A. Une augmentation immédiate de la croissance économique
\item B. Une hausse automatique de l’investissement
\item C. Une augmentation du commerce extérieur
\item D. Une baisse de l’investissement et de la consommation
\end{itemize}

\textbf{Réponse : D}

\item Pourquoi parle-t-on de \textbf{crises macro-financières} ?

\begin{itemize}
\item A. Parce qu’elles concernent uniquement les marchés boursiers
\item B. Parce qu’elles résultent de l’interaction entre les marchés financiers, le système bancaire et l’économie réelle
\item C. Parce qu’elles affectent uniquement la politique monétaire
\item D. Parce qu’elles sont toujours causées par l’inflation
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}

\subsection{QCM - Levier et ventes forcées}

\begin{enumerate}

\item Que signifie l’utilisation du \textbf{levier financier} ?

\begin{itemize}
\item A. Financer l’achat d’actifs en utilisant de l’endettement
\item B. Investir uniquement avec ses fonds propres
\item C. Acheter uniquement des obligations d’État
\item D. Réduire la taille de son portefeuille
\end{itemize}

\textbf{Réponse : A}

\item Quel est l’effet principal du levier financier sur les rendements d’un investissement ?

\begin{itemize}
\item A. Il réduit toujours le risque
\item B. Il amplifie à la fois les gains potentiels et les pertes
\item C. Il supprime les fluctuations de prix
\item D. Il garantit un rendement positif
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi les investisseurs peuvent-ils être contraints de réduire leurs positions lorsque les prix des actifs baissent ?

\begin{itemize}
\item A. Parce que les dividendes disparaissent
\item B. Parce que les exportations diminuent
\item C. Parce qu’ils doivent respecter des limites de levier ou répondre à des appels de marge
\item D. Parce que les banques centrales l’exigent
\end{itemize}

\textbf{Réponse : C}

\item Que sont les \textbf{ventes forcées} sur les marchés financiers ?

\begin{itemize}
\item A. Des ventes réalisées pour réduire l’exposition ou satisfaire des contraintes financières
\item B. Des ventes décidées uniquement pour réaliser un profit
\item C. Des ventes imposées par les gouvernements
\item D. Des ventes liées uniquement à l’inflation
\end{itemize}

\textbf{Réponse : A}

\item Pourquoi les ventes forcées peuvent-elles amplifier les mouvements de marché ?

\begin{itemize}
\item A. Parce qu’elles augmentent automatiquement les dividendes
\item B. Parce qu’elles créent une boucle de rétroaction où la baisse des prix entraîne de nouvelles ventes
\item C. Parce qu’elles réduisent la liquidité des banques centrales
\item D. Parce qu’elles stabilisent les prix
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}

\subsection{QCM - Boucle de rétroaction}

\begin{enumerate}

\item Dans le schéma, quel événement déclenche généralement la dynamique de crise ?

\begin{itemize}
\item A. Une hausse des prix d’actifs
\item B. Une baisse des prix d’actifs
\item C. Une hausse des salaires
\item D. Une baisse des taux d’intérêt
\end{itemize}

\textbf{Réponse : B}

\item Que provoque la baisse initiale des prix d’actifs pour les investisseurs ?

\begin{itemize}
\item A. Une hausse automatique des profits
\item B. Une augmentation de la liquidité
\item C. Des pertes financières
\item D. Une augmentation des dividendes
\end{itemize}

\textbf{Réponse : C}

\item Selon le schéma, pourquoi les investisseurs peuvent-ils être amenés à vendre des actifs ?

\begin{itemize}
\item A. Pour augmenter leurs investissements
\item B. Parce qu’ils doivent respecter des contraintes de levier ou répondre à des appels de marge
\item C. Parce que les prix augmentent
\item D. Parce que les banques centrales l’exigent
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi les ventes forcées peuvent-elles amplifier la crise ?

\begin{itemize}
\item A. Parce qu’elles augmentent les salaires
\item B. Parce qu’elles réduisent les profits des entreprises
\item C. Parce qu’elles entraînent une pression vendeuse supplémentaire sur les prix
\item D. Parce qu’elles augmentent la croissance économique
\end{itemize}

\textbf{Réponse : C}

\item Quel phénomène est souvent observé sur les marchés financiers lors des crises ?

\begin{itemize}
\item A. Une baisse de la volatilité
\item B. Une diminution des corrélations entre actifs
\item C. Une disparition des spreads de crédit
\item D. Une hausse de la volatilité et un élargissement des spreads de crédit
\end{itemize}

\textbf{Réponse : D}

\end{enumerate}
''',
  r'''
\section{QCM - Macroéconomie et valorisation : taux, bénéfices, primes}

\subsection{QCM - Deux moteurs des prix d’actifs}

\begin{enumerate}

\item Selon l’intuition présentée, de quoi dépend principalement le prix d’un actif financier ?

\begin{itemize}
\item A. Des anticipations de cash-flows futurs et du facteur d’actualisation
\item B. Uniquement du niveau de la dette publique
\item C. Du nombre d’entreprises sur le marché
\item D. Uniquement du taux de change
\end{itemize}

\textbf{Réponse : A}

\item Que représentent les \textbf{cash-flows} dans la valorisation d’un actif ?

\begin{itemize}
\item A. Les dépenses publiques futures
\item B. Les flux futurs attendus par l’investisseur (dividendes, profits, croissance)
\item C. Les impôts payés par les entreprises
\item D. Les taux d’intérêt fixés par la banque centrale
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi les cash-flows sont-ils sensibles à la situation macroéconomique ?

\begin{itemize}
\item A. Parce qu’ils dépendent de la croissance économique, du cycle et des marges des entreprises
\item B. Parce qu’ils sont fixés par les banques centrales
\item C. Parce qu’ils dépendent uniquement du taux de change
\item D. Parce qu’ils sont indépendants de l’économie réelle
\end{itemize}

\textbf{Réponse : A}

\item Que signifie le processus d’\textbf{actualisation} des flux futurs ?

\begin{itemize}
\item A. Transformer les flux futurs en valeur présente
\item B. Augmenter automatiquement les profits futurs
\item C. Fixer les prix des actifs par décision publique
\item D. Réduire les dividendes des entreprises
\end{itemize}

\textbf{Réponse : A}

\item Quel effet une hausse des taux d’intérêt a-t-elle généralement sur les prix des actifs ?

\begin{itemize}
\item A. Elle augmente toujours leur valeur
\item B. Elle n’a aucun effet
\item C. Elle réduit la valeur actuelle des flux futurs
\item D. Elle supprime les primes de risque
\end{itemize}

\textbf{Réponse : C}

\end{enumerate}

\subsection{QCM - Prime de risque (macro-finance)}

\begin{enumerate}

\item Qu’est-ce que la \textbf{prime de risque} en finance ?

\begin{itemize}
\item A. Le rendement garanti d’un actif sans risque
\item B. La rémunération supplémentaire exigée par les investisseurs pour détenir un actif risqué
\item C. Le taux d’inflation anticipé
\item D. Le niveau de la dette publique
\end{itemize}

\textbf{Réponse : B}

\item Dans l’équation 
\[
\mathbb{E}[R] = R_f + \text{prime de risque},
\]
que représente $R_f$ ?

\begin{itemize}
\item A. Le taux sans risque
\item B. Le taux d’inflation
\item C. Le rendement moyen des actions
\item D. Le taux de croissance économique
\end{itemize}

\textbf{Réponse : A}

\item Pourquoi les investisseurs exigent-ils une prime de risque ?

\begin{itemize}
\item A. Pour compenser l’incertitude associée aux actifs risqués
\item B. Pour réduire les impôts
\item C. Pour stabiliser l’inflation
\item D. Pour financer les dépenses publiques
\end{itemize}

\textbf{Réponse : A}

\item Comment évolue généralement la prime de risque en période d’incertitude économique ou financière élevée ?

\begin{itemize}
\item A. Elle disparaît
\item B. Elle diminue fortement
\item C. Elle augmente
\item D. Elle reste toujours constante
\end{itemize}

\textbf{Réponse : C}

\item Que se passe-t-il généralement pour les valorisations d’actifs lorsque la prime de risque diminue ?

\begin{itemize}
\item A. Les valorisations peuvent augmenter pour un même niveau de flux futurs
\item B. Les prix des actifs deviennent nuls
\item C. Les taux d’intérêt disparaissent
\item D. Les marchés financiers ferment
\end{itemize}

\textbf{Réponse : A}

\end{enumerate}

\subsection{QCM - « bonnes nouvelles » vs « mauvaises nouvelles » selon le régime}

\begin{enumerate}

\item Dans le schéma, que représente l’axe horizontal ?

\begin{itemize}
\item A. La variation du taux de change
\item B. La surprise macroéconomique (activité ou inflation)
\item C. Le niveau des dépenses publiques
\item D. Le niveau de la dette publique
\end{itemize}

\textbf{Réponse : B}

\item Que représente l’axe vertical dans ce graphique ?

\begin{itemize}
\item A. La réaction des actifs risqués
\item B. Le taux de chômage
\item C. Le niveau d’inflation
\item D. Le taux d’intérêt réel
\end{itemize}

\textbf{Réponse : A}

\item Dans un \textbf{régime de croissance}, comment les marchés réagissent-ils généralement à une surprise positive sur l’activité économique ?

\begin{itemize}
\item A. Les actifs risqués ont tendance à monter
\item B. Les marchés obligataires disparaissent
\item C. Les taux d’intérêt deviennent négatifs
\item D. Les actions chutent toujours
\end{itemize}

\textbf{Réponse : A}

\item Dans un \textbf{régime dominé par l’inflation et les taux}, comment une forte surprise d’activité peut-elle être interprétée ?

\begin{itemize}
\item A. Comme un signal d’augmentation des dépenses publiques
\item B. Comme un signal de baisse de l’inflation
\item C. Comme un signal possible de hausse future des taux d’intérêt
\item D. Comme un signal de baisse du chômage uniquement
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi la même nouvelle macroéconomique peut-elle produire des réactions différentes sur les marchés ?

\begin{itemize}
\item A. Parce que les investisseurs réagissent toujours de manière aléatoire
\item B. Parce que la réaction dépend du régime macroéconomique dominant
\item C. Parce que les marchés ne regardent pas les données économiques
\item D. Parce que les banques centrales fixent les prix des actifs
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}

\section{QCM - Indicateurs macro utiles pour l'investisseur}

\begin{enumerate}

\item Pourquoi les investisseurs suivent-ils les indicateurs macroéconomiques ?

\begin{itemize}
\item A. Pour déterminer directement les profits des entreprises
\item B. Parce qu’ils permettent d’évaluer l’activité économique, l’inflation et les politiques économiques
\item C. Pour fixer les salaires dans l’économie
\item D. Parce qu’ils remplacent les analyses financières
\end{itemize}

\textbf{Réponse : B}

\item Quel indicateur appartient principalement à la catégorie des indicateurs d’\textbf{activité économique} ?

\begin{itemize}
\item A. Le taux de chômage
\item B. Le PIB
\item C. Le taux de change
\item D. Les spreads de crédit
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi les investisseurs observent-ils attentivement les indicateurs d’\textbf{emploi} ?

\begin{itemize}
\item A. Parce qu’ils permettent d’estimer les exportations
\item B. Parce qu’ils mesurent uniquement la politique budgétaire
\item C. Parce qu’un marché du travail tendu peut signaler des pressions inflationnistes
\item D. Parce qu’ils déterminent les taux de change
\end{itemize}

\textbf{Réponse : C}

\item Quelle caractéristique distingue souvent l’\textbf{inflation sous-jacente} de l’inflation totale ?

\begin{itemize}
\item A. Elle inclut les prix de l’énergie
\item B. Elle exclut souvent les prix volatils comme l’énergie et l’alimentation
\item C. Elle mesure uniquement les prix des actifs financiers
\item D. Elle mesure uniquement les salaires
\end{itemize}

\textbf{Réponse : B}

\item Parmi les éléments suivants, lequel appartient aux indicateurs de \textbf{conditions financières} ?

\begin{itemize}
\item A. Les ventes au détail
\item B. Le taux de chômage
\item C. Les spreads de crédit
\item D. La production industrielle
\end{itemize}

\textbf{Réponse : C}

\item Pourquoi les variables \textbf{internationales} sont-elles importantes pour les investisseurs ?

\begin{itemize}
\item A. Parce qu’elles influencent la compétitivité, les flux de capitaux et les rendements internationaux
\item B. Parce qu’elles déterminent uniquement les impôts
\item C. Parce qu’elles fixent les salaires dans chaque pays
\item D. Parce qu’elles déterminent directement la croissance démographique
\end{itemize}

\textbf{Réponse : A}

\item Selon le texte, quelle est la bonne approche de l’analyse macro-financière ?

\begin{itemize}
\item A. Réagir uniquement à chaque chiffre publié
\item B. Se concentrer uniquement sur les marchés actions
\item C. Identifier les régimes macroéconomiques (croissance, inflation, politique monétaire)
\item D. Ignorer les indicateurs internationaux
\end{itemize}

\textbf{Réponse : C}

\end{enumerate}
''',
  r'''
\section{QCM - Synthèse : une grille macro-finance cohérente}

\begin{enumerate}

\item Dans le schéma, quel est le premier élément de la chaîne macro-financière ?

\begin{itemize}
\item A. Les prix d’actifs
\item B. Les chocs macroéconomiques
\item C. Les conditions financières
\item D. Les profits des entreprises
\end{itemize}

\textbf{Réponse : B}

\item Après un choc macroéconomique, quelle est généralement la réaction suivante dans la chaîne décrite ?

\begin{itemize}
\item A. Les prix d’actifs changent immédiatement
\item B. Les politiques économiques s’ajustent
\item C. Les entreprises modifient leurs salaires
\item D. Les exportations augmentent
\end{itemize}

\textbf{Réponse : B}

\item Que représentent les \textbf{conditions financières} dans ce cadre ?

\begin{itemize}
\item A. Les niveaux de salaires et d’emplois
\item B. Les taux d’intérêt, le crédit et la liquidité du système financier
\item C. Les exportations et importations
\item D. Les politiques commerciales
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi les conditions financières influencent-elles les prix d’actifs ?

\begin{itemize}
\item A. Parce qu’elles déterminent directement la croissance démographique
\item B. Parce qu’elles affectent les profits futurs et les taux d’actualisation
\item C. Parce qu’elles fixent les prix des matières premières
\item D. Parce qu’elles remplacent les politiques économiques
\end{itemize}

\textbf{Réponse : B}

\item Que signifie l’idée de \textbf{boucle de rétroaction} entre finance et économie réelle ?

\begin{itemize}
\item A. Les prix d’actifs n’ont aucun impact sur l’économie
\item B. Les prix d’actifs influencent l’économie via la richesse, la confiance et le crédit
\item C. Les marchés financiers déterminent directement le PIB
\item D. Les politiques économiques disparaissent
\end{itemize}

\textbf{Réponse : B}

\item Comment peut-on résumer le rôle de la macroéconomie pour les marchés financiers ?

\begin{itemize}
\item A. Elle fixe directement les prix des actions
\item B. Elle explique uniquement les taux d’intérêt
\item C. Elle constitue la « météo structurelle » des marchés
\item D. Elle détermine uniquement les salaires
\end{itemize}

\textbf{Réponse : C}

\end{enumerate}

\section{QCM - Approfondissement mathématique : inflation, taux réels et valorisation}

\subsection{QCM - Actualisation en présence d'inflation}

\begin{enumerate}

\item Que signifie l’opération d’\textbf{actualisation} en finance ?

\begin{itemize}
\item A. Transformer des flux futurs en valeur présente
\item B. Augmenter automatiquement les flux futurs
\item C. Convertir les flux réels en flux nominaux
\item D. Calculer le niveau d’inflation
\end{itemize}

\textbf{Réponse : A}

\item Dans la formule
\[
PV = \frac{X_t^{nom}}{(1+i)^t},
\]
que représente $i$ ?

\begin{itemize}
\item A. Le taux d’inflation réel
\item B. Le taux d’intérêt nominal observé sur les marchés
\item C. Le taux de croissance économique
\item D. Le taux de chômage
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi les économistes utilisent-ils parfois des flux \textbf{réels} plutôt que nominaux ?

\begin{itemize}
\item A. Pour éliminer l’effet de l’inflation sur les flux
\item B. Pour augmenter artificiellement les profits
\item C. Pour réduire les taux d’intérêt
\item D. Pour calculer la dette publique
\end{itemize}

\textbf{Réponse : A}

\item Selon l’approximation de Fisher, quelle relation relie le taux nominal, le taux réel et l’inflation anticipée ?

\begin{itemize}
\item A. $i \approx r - \mathbb{E}[\pi]$
\item B. $i \approx r + \mathbb{E}[\pi]$
\item C. $i \approx r \times \mathbb{E}[\pi]$
\item D. $i \approx \frac{r}{\mathbb{E}[\pi]}$
\end{itemize}

\textbf{Réponse : B}

\item Pourquoi une hausse inattendue de l’inflation peut-elle faire baisser le prix des obligations à taux fixe ?

\begin{itemize}
\item A. Parce qu’elle réduit la liquidité bancaire
\item B. Parce qu’elle augmente les flux futurs
\item C. Parce qu’elle entraîne généralement une hausse des taux nominaux
\item D. Parce qu’elle réduit les profits des entreprises
\end{itemize}

\textbf{Réponse : C}

\end{enumerate}

\subsection{QCM - Sensibilité des actions aux taux : intuition}

\begin{enumerate}

\item Comment peut-on interpréter le prix d’une action en finance ?

\begin{itemize}
\item A. Comme la valeur actuelle des flux futurs attendus (dividendes ou bénéfices)
\item B. Comme la valeur totale des actifs physiques de l’entreprise
\item C. Comme le montant de la dette de l’entreprise
\item D. Comme le niveau des ventes de l’entreprise
\end{itemize}

\textbf{Réponse : A}

\item Pourquoi les actions dont les flux sont très éloignés dans le futur sont-elles sensibles aux taux d’intérêt ?

\begin{itemize}
\item A. Parce que les entreprises à croissance élevée versent peu de dividendes
\item B. Parce que leur valeur actuelle dépend fortement du taux d’actualisation
\item C. Parce que les banques centrales fixent directement leurs prix
\item D. Parce que leurs ventes sont instables
\end{itemize}

\textbf{Réponse : B}

\item Que signifie l’idée de \textbf{duration des actions} ?

\begin{itemize}
\item A. La durée de vie juridique d’une entreprise
\item B. La période pendant laquelle une action verse des dividendes
\item C. La sensibilité de la valorisation de l’action aux variations des taux d’intérêt
\item D. La durée moyenne des cycles économiques
\end{itemize}

\textbf{Réponse : C}

\item Quelles entreprises ont généralement une \textbf{duration élevée} ?

\begin{itemize}
\item A. Les entreprises matures distribuant des flux immédiats
\item B. Les entreprises publiques
\item C. Les banques centrales
\item D. Les entreprises à forte croissance dont les flux sont attendus loin dans le futur
\end{itemize}

\textbf{Réponse : D}

\item Pourquoi les actions de croissance sont-elles souvent plus sensibles aux hausses de taux ?

\begin{itemize}
\item A. Parce que leurs profits actuels sont très faibles
\item B. Parce que leurs flux futurs sont éloignés et donc fortement affectés par l’actualisation
\item C. Parce qu’elles dépendent uniquement des exportations
\item D. Parce qu’elles sont soutenues par les banques centrales
\end{itemize}

\textbf{Réponse : B}

\end{enumerate}
''',
];

String get _chapter4QuizLatex => _chapter4QuizLatexChunks.join('\n');
