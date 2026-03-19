import 'dart:math';

String _normalizeChapter5QuizKey(String value) {
  return value
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('--', '-')
      .replaceAll(RegExp(r'^QCM\s*-\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const Map<String, String> _chapter5QuizLessonByPath = {
  'Définition': 'Qu’est-ce qu’un actif ou produit financier ?',
  "Exemples de produits financiers > Les produits financiers 'classiques'":
      'Actions, obligations et ETF',
  "Exemples de produits financiers > Les livrets d'épargne : la base sans risque":
      'Pourquoi les livrets sont la référence de départ',
  "Exemples de produits financiers > Les comptes à terme : rémunérer l'immobilisation du capital":
      'Plus de rendement, moins de liquidité',
  'Exemples de produits financiers > Les OPCVM : Organismes de Placement Collectif en Valeurs Mobilières':
      'Mutualiser l’épargne et déléguer la gestion',
  'Exemples de produits financiers > Les produits dérivés > Définition':
      'Un actif dont la valeur dépend d’un sous-jacent',
  'Exemples de produits financiers > Les produits dérivés > Le levier':
      'Amplifier les mouvements et choisir un sens',
  'Exemples de produits financiers > Les produits dérivés > Les options':
      'Le droit d’acheter ou de vendre',
  'Exemples de produits financiers > Les produits dérivés > Les warrants':
      'Des options standardisées pour le grand public',
  'Exemples de produits financiers > Les produits dérivés > Les turbos':
      'Le levier avec barrière désactivante',
  'Exemples de produits financiers > Les produits dérivés > Produits cappés / floorés':
      'Encadrer un scénario plutôt que viser une hausse illimitée',
  'Exemples de produits financiers > Les produits dérivés > Bonus et stability':
      'Encadrer un scénario plutôt que viser une hausse illimitée',
  'Exemples de produits financiers > Les produits dérivés > Discount':
      'Encadrer un scénario plutôt que viser une hausse illimitée',
  'Exemples de produits financiers > Risque et utilisation des produits dérivés':
      'Des instruments de scénario, pas de détention passive',
  'Exemples de produits financiers > Les produits structurés > Combiner sécurité et performance':
      'Combiner protection et exposition conditionnelle',
  'Exemples de produits financiers > Les produits structurés > Architecture et mécanisme de fonctionnement':
      'Combiner protection et exposition conditionnelle',
  'Exemples de produits financiers > Les produits structurés > Conditions de performance et notion de barrière':
      'Combiner protection et exposition conditionnelle',
  'Exemples de produits financiers > Les produits structurés > Durée, risques et rôle dans un portefeuille':
      'Combiner protection et exposition conditionnelle',
  'Exemples de produits financiers > Les matières premières > Investir dans les ressources réelles':
      'Une classe d’actifs liée à la conjoncture mondiale',
  'Exemples de produits financiers > Les matières premières > Formation des prix':
      'Énergie, métaux et produits agricoles',
  'Exemples de produits financiers > Les matières premières > Grandes catégories':
      'Énergie, métaux et produits agricoles',
  'Exemples de produits financiers > Les matières premières > Absence de revenu intrinsèque':
      'Un rendement qui vient uniquement du prix',
  'Exemples de produits financiers > Les matières premières > Le rôle des marchés à terme':
      'Un rendement qui vient uniquement du prix',
  'Exemples de produits financiers > Les matières premières > Lien avec l’inflation et le cycle économique':
      'Diversification et couverture macro',
  'Exemples de produits financiers > Les matières premières > Rôle dans un portefeuille':
      'Diversification et couverture macro',
  'Exemples de produits financiers > Les crypto-actifs > Des actifs numériques décentralisés':
      'Une nouvelle forme de rareté',
  'Exemples de produits financiers > Les crypto-actifs > Infrastructure et fonctionnement du réseau':
      'Le rôle de la blockchain et des clés privées',
  'Exemples de produits financiers > Les crypto-actifs > Valorisation et dynamique de marché':
      'Une exposition technologique et spéculative',
  'Exemples de produits financiers > Les crypto-actifs > Usages, risques et place dans un portefeuille':
      'Une exposition technologique et spéculative',
};

class _Chapter5QuizToken {
  const _Chapter5QuizToken.heading(this.offset, this.level, this.value)
    : question = null,
      optionsBlock = null,
      answer = null;

  const _Chapter5QuizToken.question(
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

int _stableChapter5QuizSeed(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String _unwrapChapter5LatexCommand(String text, String command) {
  final pattern = RegExp('\\\\$command\\{([^{}]*)\\}');
  var result = text;
  while (pattern.hasMatch(result)) {
    result = result.replaceAllMapped(pattern, (match) => match.group(1) ?? '');
  }
  return result;
}

String _replaceChapter5Fractions(String text) {
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

String _cleanChapter5QuizText(String value) {
  var text = value.replaceAll('\r', ' ').replaceAll('\n', ' ');
  text = text.replaceAll(r'\%', '%');
  text = text.replaceAll(r'\approx', '≈');
  text = text.replaceAll(r'\Rightarrow', '⇒');
  text = text.replaceAll(r'\to', '→');
  text = text.replaceAll(r'\times', '×');
  text = text.replaceAll(r'\leftrightarrow', '↔');
  text = text.replaceAll(r'\textbf', '');
  text = text.replaceAll(r'\textit', '');
  text = _replaceChapter5Fractions(text);
  for (final command in ['textit', 'textbf', 'boxed']) {
    text = _unwrapChapter5LatexCommand(text, command);
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

String _chapter5PathKey(
  String? section,
  String? subsection,
  String? subsubsection,
) {
  return [section, subsection, subsubsection]
      .whereType<String>()
      .map(_normalizeChapter5QuizKey)
      .where((part) {
        return part.isNotEmpty;
      })
      .join(' > ');
}

String? _resolveChapter5LessonTitle(
  String? section,
  String? subsection,
  String? subsubsection,
) {
  final fullPath = _chapter5PathKey(section, subsection, subsubsection);
  if (_chapter5QuizLessonByPath.containsKey(fullPath)) {
    return _chapter5QuizLessonByPath[fullPath];
  }

  final sectionSubsectionPath = _chapter5PathKey(section, subsection, null);
  if (_chapter5QuizLessonByPath.containsKey(sectionSubsectionPath)) {
    return _chapter5QuizLessonByPath[sectionSubsectionPath];
  }

  final fallbackKey = _normalizeChapter5QuizKey(
    subsubsection ?? subsection ?? section ?? '',
  );
  return _chapter5QuizLessonByPath[fallbackKey];
}

Map<String, dynamic> _buildChapter5Question(
  String question,
  List<String> options,
  int correctIndex,
) {
  final indexedOptions = List.generate(
    options.length,
    (index) => MapEntry(index, options[index]),
  );
  final random = Random(
    _stableChapter5QuizSeed('$question|${options.join('|')}|$correctIndex'),
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

Map<String, List<String>> _collectChapter5LessonsByTopChapter(
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

Map<String, List<Map<String, dynamic>>> _parseChapter5QuizQuestions() {
  final tokens = <_Chapter5QuizToken>[];
  final headingPattern = RegExp(
    r'\\(section|subsection|subsubsection)\{([^}]*)\}',
  );
  final questionPattern = RegExp(
    r'\\textbf\{Q\d+\.\s*(.*?)\}\s*\\begin\{itemize\}(.*?)\\end\{itemize\}\s*\\textbf\{Réponse\s*:\s*([A-D])\}',
    dotAll: true,
  );

  for (final match in headingPattern.allMatches(_chapter5QuizLatex)) {
    tokens.add(
      _Chapter5QuizToken.heading(match.start, match.group(1)!, match.group(2)!),
    );
  }

  for (final match in questionPattern.allMatches(_chapter5QuizLatex)) {
    tokens.add(
      _Chapter5QuizToken.question(
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
  String? subsubsection;
  final lessonQuestions = <String, List<Map<String, dynamic>>>{};
  final optionPattern = RegExp(
    r'\\item\[([A-D])\.\]\s+(.*?)(?=(?:\n\s*\\item\[[A-D]\.\]\s)|$)',
    dotAll: true,
  );

  for (final token in tokens) {
    if (token.isHeading) {
      switch (token.level) {
        case 'section':
          section = token.value;
          subsection = null;
          subsubsection = null;
          break;
        case 'subsection':
          subsection = token.value;
          subsubsection = null;
          break;
        case 'subsubsection':
          subsubsection = token.value;
          break;
      }
      continue;
    }

    final lessonTitle = _resolveChapter5LessonTitle(
      section,
      subsection,
      subsubsection,
    );
    if (lessonTitle == null) {
      continue;
    }

    final matches = optionPattern.allMatches(token.optionsBlock ?? '').toList();
    if (matches.isEmpty) {
      continue;
    }

    final options = <String>[];
    var correctIndex = -1;
    for (final match in matches) {
      final optionLabel = match.group(1);
      final optionText = _cleanChapter5QuizText(match.group(2) ?? '');
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
      _buildChapter5Question(
        _cleanChapter5QuizText(token.question ?? ''),
        options,
        correctIndex,
      ),
    );
  }

  return lessonQuestions;
}

final Map<String, List<Map<String, dynamic>>>
_chapter5SupplementalQuestions = <String, List<Map<String, dynamic>>>{
  'Livret A, LDDS, LEP et pouvoir d’achat': <Map<String, dynamic>>[
    _buildChapter5Question(
      'Quel livret est en général accessible à tous et exonéré d’impôts sur les intérêts ?',
      <String>[
        'Le Livret A.',
        'Le compte-titres ordinaire.',
        'Le warrant call.',
        'Le compte à terme obligataire.',
      ],
      0,
    ),
    _buildChapter5Question(
      'Pourquoi le LEP propose-t-il en général un taux supérieur à celui du Livret A ?',
      <String>[
        'Parce qu’il sert surtout à spéculer sur les marchés.',
        'Parce qu’il vise à mieux protéger le pouvoir d’achat des ménages modestes.',
        'Parce qu’il est réservé aux entreprises cotées.',
        'Parce qu’il suit automatiquement la performance des actions.',
      ],
      1,
    ),
    _buildChapter5Question(
      'Que signifie la relation rendement réel = rendement nominal - inflation ?',
      <String>[
        'Qu’un placement peut rapporter en nominal tout en faisant perdre du pouvoir d’achat.',
        'Qu’un livret bat toujours l’inflation sur longue période.',
        'Que l’inflation augmente automatiquement les intérêts versés.',
        'Que le rendement réel est forcément positif si le capital est garanti.',
      ],
      0,
    ),
    _buildChapter5Question(
      'Dans une stratégie patrimoniale, quel rôle joue surtout ce type de livret réglementé ?',
      <String>[
        'Remplacer totalement les actions et obligations.',
        'Servir d’épargne de précaution avant la recherche de performance.',
        'Fournir un levier pour amplifier les gains boursiers.',
        'Garantir le meilleur rendement du portefeuille.',
      ],
      1,
    ),
  ],
};

Map<String, dynamic> buildChapter5QuizData(Map<String, dynamic> courseData) {
  final lessonsByTopChapter = _collectChapter5LessonsByTopChapter(courseData);
  final lessonQuestions = _parseChapter5QuizQuestions();
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
        ...?_chapter5SupplementalQuestions[lessonTitle],
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

  return {'course_title': 'Les actifs financiers : QCM', 'chapters': chapters};
}

const String _chapter5QuizLatex = r'''
\section{QCM - Définition}

\textbf{Q1. Qu’est-ce qu’un produit financier ?}
\begin{itemize}
    \item[A.] Un document comptable utilisé par les entreprises
    \item[B.] Un support permettant de placer son épargne
    \item[C.] Un impôt prélevé sur les investisseurs
    \item[D.] Une obligation légale d’investir en bourse
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Quel peut être l’objectif principal d’un produit financier ?}
\begin{itemize}
    \item[A.] Uniquement payer moins d’impôts
    \item[B.] Obtenir un rendement, protéger son capital ou couvrir un risque
    \item[C.] Acheter des biens immobiliers uniquement
    \item[D.] Garantir un profit sans risque
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Lequel des éléments suivants n’est PAS un critère de distinction des produits financiers ?}
\begin{itemize}
    \item[A.] Leur niveau de risque
    \item[B.] Leur rendement espéré
    \item[C.] Leur couleur
    \item[D.] Leur liquidité
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Les produits financiers peuvent être classés :}
\begin{itemize}
    \item[A.] Selon leur popularité
    \item[B.] Du plus simple au plus complexe
    \item[C.] Selon la taille de l’entreprise
    \item[D.] Selon le nombre d’investisseurs
\end{itemize}
\textbf{Réponse : B}

\section{QCM - Exemples de produits financiers}

\subsection{QCM - Les produits financiers 'classiques'}

\textbf{Q1. Que représente une action ?}
\begin{itemize}
    \item[A.] Un prêt accordé à une entreprise
    \item[B.] Une part de propriété d’une entreprise
    \item[C.] Un produit dérivé basé sur un indice
    \item[D.] Un compte d’épargne bancaire
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Le rendement total d’une action correspond à :}
\begin{itemize}
    \item[A.] Coupon + taux d’intérêt
    \item[B.] Plus-value + dividendes
    \item[C.] Dividendes uniquement
    \item[D.] Inflation + dividendes
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Quelle relation existe entre le prix d’une obligation et les taux d’intérêt ?}
\begin{itemize}
    \item[A.] Ils augmentent ensemble
    \item[B.] Ils sont indépendants
    \item[C.] Le prix est inversement proportionnel aux taux
    \item[D.] Le prix dépend uniquement de l’inflation
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Quel est l’avantage principal d’un ETF ?}
\begin{itemize}
    \item[A.] Garantir un rendement fixe
    \item[B.] Permettre une diversification immédiate à moindre frais
    \item[C.] Éviter tout risque de marché
    \item[D.] Remplacer un compte courant
\end{itemize}
\textbf{Réponse : B}

\subsection{QCM - Les livrets d’épargne : la base sans risque}

\textbf{Q1. Quelle est la principale caractéristique d’un livret d’épargne ?}
\begin{itemize}
    \item[A.] Capital garanti sans risque de perte
    \item[B.] Rendement élevé garanti
    \item[C.] Blocage des fonds pendant 5 ans
    \item[D.] Exposition aux marchés financiers
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q2. Pourquoi le livret est-il considéré comme un actif sans risque en théorie financière ?}
\begin{itemize}
    \item[A.] Parce qu’il offre toujours le meilleur rendement
    \item[B.] Parce que son capital est garanti
    \item[C.] Parce qu’il dépend des actions en bourse
    \item[D.] Parce qu’il suit l’inflation automatiquement
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Que signifie le rendement réel d’un placement ?}
\begin{itemize}
    \item[A.] Rendement nominal + inflation
    \item[B.] Rendement nominal – inflation
    \item[C.] Inflation – rendement nominal
    \item[D.] Dividendes – impôts
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q4. Quel est le rôle principal du livret dans une stratégie d’investissement ?}
\begin{itemize}
    \item[A.] Générer une forte performance sur le long terme
    \item[B.] Spéculer sur les marchés financiers
    \item[C.] Sécuriser l’épargne et constituer une réserve de précaution
    \item[D.] Remplacer les actions et obligations
\end{itemize}
\textbf{Réponse : C}

\subsection{QCM - Les comptes à terme : rémunérer l’immobilisation du capital}

\textbf{Q1. Quelle est la caractéristique principale d’un compte à terme (CAT) ?}
\begin{itemize}
    \item[A.] Argent disponible à tout moment
    \item[B.] Argent investi en actions
    \item[C.] Argent immobilisé pendant une durée déterminée
    \item[D.] Rendement variable selon la bourse
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q2. Que reçoit l’investisseur à l’échéance du compte à terme ?}
\begin{itemize}
    \item[A.] Capital uniquement
    \item[B.] Intérêts uniquement
    \item[C.] Capital + intérêts
    \item[D.] Dividendes
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q3. Pourquoi le rendement d’un compte à terme est-il connu à l’avance ?}
\begin{itemize}
    \item[A.] Il dépend de la bourse
    \item[B.] Le taux est fixe dès la souscription
    \item[C.] Il suit l’inflation
    \item[D.] Il dépend des dividendes
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q4. Quel principe financier illustre le compte à terme ?}
\begin{itemize}
    \item[A.] Plus de liquidité = plus de rendement
    \item[B.] Rendement = Temps + Risque
    \item[C.] Rendement = Inflation + Dividendes
    \item[D.] Rendement indépendant de la durée
\end{itemize}
\textbf{Réponse : B}

\subsection{QCM - Les OPCVM : Organismes de Placement Collectif en Valeurs Mobilières}

\textbf{Q1. Quel est le principe d’un OPCVM ?}
\begin{itemize}
    \item[A.] Investir seul sur les marchés financiers
    \item[B.] Mettre en commun l’argent de plusieurs investisseurs géré par un professionnel
    \item[C.] Acheter uniquement des obligations d’État
    \item[D.] Garantir un rendement fixe
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Quelle est la différence principale entre une SICAV et un FCP ?}
\begin{itemize}
    \item[A.] La SICAV investit en actions uniquement
    \item[B.] Le FCP est garanti par l’État
    \item[C.] Dans une SICAV l’investisseur est actionnaire, dans un FCP il détient des parts
    \item[D.] Le FCP offre un rendement fixe
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q3. Que signifie la gestion active dans un OPCVM ?}
\begin{itemize}
    \item[A.] Reproduire exactement la performance d’un indice
    \item[B.] Battre le marché en sélectionnant des titres
    \item[C.] Investir uniquement dans des obligations
    \item[D.] Ne pas modifier le portefeuille
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q4. Quel élément peut réduire la performance pour l’investisseur dans un OPCVM ?}
\begin{itemize}
    \item[A.] L’absence de diversification
    \item[B.] Les frais d’entrée et de gestion
    \item[C.] Le nombre d’investisseurs
    \item[D.] La taille du fonds
\end{itemize}
\textbf{Réponse : B}

\subsection{QCM - Les produits dérivés}

\subsubsection{QCM - Définition}

\textbf{Q1. Qu’est-ce qu’un produit dérivé ?}
\begin{itemize}
    \item[A.] Un produit bancaire garanti
    \item[B.] Un instrument financier dont la valeur dépend d’un autre actif
    \item[C.] Une obligation d’État
    \item[D.] Une action internationale
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Comment appelle-t-on l’actif dont dépend la valeur du produit dérivé ?}
\begin{itemize}
    \item[A.] Le capital
    \item[B.] Le support
    \item[C.] Le sous-jacent
    \item[D.] Le dividende
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q3. Que possède réellement l’investisseur lorsqu’il achète un produit dérivé ?}
\begin{itemize}
    \item[A.] L’actif réel
    \item[B.] Une part de l’entreprise
    \item[C.] Une position sur l’évolution du prix
    \item[D.] Un taux d’intérêt fixe
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Quel est un objectif principal des produits dérivés ?}
\begin{itemize}
    \item[A.] Garantir un rendement sans risque
    \item[B.] Spéculer ou se couvrir contre un risque
    \item[C.] Remplacer un livret d’épargne
    \item[D.] Éviter l’inflation automatiquement
\end{itemize}
\textbf{Réponse : B}

\subsubsection{QCM - Le levier}

\textbf{Q1. Que permet le levier financier ?}
\begin{itemize}
    \item[A.] Réduire le risque
    \item[B.] Obtenir une exposition supérieure au capital investi
    \item[C.] Garantir un rendement fixe
    \item[D.] Éviter toute perte
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Avec un levier 10, si le marché monte de 1\%, la variation approximative du produit est :}
\begin{itemize}
    \item[A.] +1\%
    \item[B.] +5\%
    \item[C.] +10\%
    \item[D.] +0,1\%
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q3. Quel est le principal risque du levier ?}
\begin{itemize}
    \item[A.] Baisse de la liquidité
    \item[B.] Perte amplifiée pouvant aller jusqu’à la totalité du capital
    \item[C.] Absence de rendement
    \item[D.] Blocage des fonds
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q4. Que signifie prendre une position courte (short) ?}
\begin{itemize}
    \item[A.] Acheter un actif pour profiter de sa hausse
    \item[B.] Vendre un actif emprunté pour profiter de sa baisse
    \item[C.] Acheter une obligation
    \item[D.] Détenir un livret d’épargne
\end{itemize}
\textbf{Réponse : B}

\subsubsection{QCM - Les options}

\textbf{Q1. Une option donne à son détenteur :}
\begin{itemize}
    \item[A.] L’obligation d’acheter un actif
    \item[B.] Le droit d’effectuer une transaction à un prix fixé à l’avance
    \item[C.] Une action gratuite
    \item[D.] Un rendement garanti
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Quelle est la différence entre un call et un put ?}
\begin{itemize}
    \item[A.] Le call vend et le put achète
    \item[B.] Le call achète et le put vend
    \item[C.] Le call donne le droit d’acheter et le put le droit de vendre
    \item[D.] Il n’y a aucune différence
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q3. Comment s’appelle le montant payé pour obtenir une option ?}
\begin{itemize}
    \item[A.] Le coupon
    \item[B.] La prime
    \item[C.] Le dividende
    \item[D.] La marge
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q4. De quoi dépend principalement le prix d’une option ?}
\begin{itemize}
    \item[A.] Du chiffre d’affaires de l’entreprise
    \item[B.] De la probabilité qu’elle devienne profitable
    \item[C.] Du taux du livret A
    \item[D.] Du nombre d’investisseurs
\end{itemize}
\textbf{Réponse : B}

\subsubsection{QCM - Les warrants}

\textbf{Q1. Qu’est-ce qu’un warrant ?}
\begin{itemize}
    \item[A.] Une obligation d’État
    \item[B.] Une option standardisée émise par une banque
    \item[C.] Une action d’entreprise
    \item[D.] Un livret bancaire
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Que permet un call warrant ?}
\begin{itemize}
    \item[A.] Profiter d’une baisse du marché
    \item[B.] Obtenir un rendement fixe
    \item[C.] Profiter d’une hausse du prix de l’actif
    \item[D.] Acheter obligatoirement l’actif
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q3. Que se passe-t-il si le marché évolue défavorablement à la maturité ?}
\begin{itemize}
    \item[A.] Le capital est garanti
    \item[B.] Le warrant devient sans valeur
    \item[C.] L’investisseur reçoit un dividende
    \item[D.] La banque rembourse automatiquement
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q4. Quelle est une particularité des warrants par rapport aux options classiques ?}
\begin{itemize}
    \item[A.] Ils sont gratuits
    \item[B.] Ils sont émis par une banque agissant comme contrepartie
    \item[C.] Ils garantissent un profit
    \item[D.] Ils ne possèdent pas de date d’expiration
\end{itemize}
\textbf{Réponse : B}

\subsubsection{QCM - Les turbos}

\textbf{Q1. Quelle est la caractéristique principale des turbos ?}
\begin{itemize}
    \item[A.] Rendement fixe garanti
    \item[B.] Effet de levier élevé répliquant les variations du sous-jacent
    \item[C.] Capital protégé
    \item[D.] Absence de risque
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Qu’est-ce que la barrière désactivante ?}
\begin{itemize}
    \item[A.] Un niveau de rendement minimum
    \item[B.] Un niveau de prix qui met fin immédiatement au produit
    \item[C.] Une commission bancaire
    \item[D.] Une durée minimale de détention
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Que se passe-t-il si la barrière est touchée ?}
\begin{itemize}
    \item[A.] Le produit continue normalement
    \item[B.] Le rendement devient fixe
    \item[C.] Le turbo est désactivé et la valeur devient nulle
    \item[D.] L’investisseur reçoit des intérêts
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Par rapport aux warrants, les turbos dépendent principalement :}
\begin{itemize}
    \item[A.] Du temps et de la volatilité
    \item[B.] Du mouvement direct du marché
    \item[C.] Du taux du livret A
    \item[D.] Des dividendes uniquement
\end{itemize}
\textbf{Réponse : B}

\subsubsection{QCM - Produits cappés / floorés}

\textbf{Q1. Quelle est la caractéristique principale des produits cappés/floorés ?}
\begin{itemize}
    \item[A.] Rendement illimité
    \item[B.] Performance encadrée entre deux niveaux prédéfinis
    \item[C.] Capital garanti sans condition
    \item[D.] Investissement uniquement obligataire
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Que se passe-t-il si le prix du sous-jacent reste dans l’intervalle jusqu’à l’échéance ?}
\begin{itemize}
    \item[A.] Aucun gain
    \item[B.] Gain maximal prévu versé
    \item[C.] Perte totale
    \item[D.] Remboursement du capital uniquement
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Quel est le risque principal pour l’investisseur ?}
\begin{itemize}
    \item[A.] Une perte immédiate garantie
    \item[B.] Une perte limitée tant que les bornes ne sont pas franchies défavorablement
    \item[C.] Une perte supérieure au capital
    \item[D.] Aucun risque
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q4. Quel est l’objectif de ces produits ?}
\begin{itemize}
    \item[A.] Prévoir parfaitement le marché
    \item[B.] Transformer une évolution incertaine en scénario probabiliste
    \item[C.] Copier un indice boursier
    \item[D.] Garantir un rendement fixe
\end{itemize}
\textbf{Réponse : B}

\subsubsection{QCM - Bonus et stability}

\textbf{Q1. Sur quel scénario de marché reposent les produits Bonus et Stability ?}
\begin{itemize}
    \item[A.] Forte hausse du marché
    \item[B.] Forte baisse du marché
    \item[C.] Stabilité ou faible variation du sous-jacent
    \item[D.] Inflation élevée
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q2. Que se passe-t-il si le prix reste dans la zone prévue jusqu’à l’échéance ?}
\begin{itemize}
    \item[A.] Aucun rendement
    \item[B.] Un rendement prédéfini (bonus) est versé
    \item[C.] Le capital est doublé automatiquement
    \item[D.] Le produit est annulé
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Que se passe-t-il si une barrière est franchie défavorablement ?}
\begin{itemize}
    \item[A.] Le rendement augmente
    \item[B.] Le capital est garanti
    \item[C.] La protection disparaît et le produit suit la baisse du sous-jacent
    \item[D.] Le produit devient un livret d’épargne
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Quel est l’avantage principal de ces produits ?}
\begin{itemize}
    \item[A.] Profiter de l’absence de mouvement important du marché
    \item[B.] Garantir un rendement illimité
    \item[C.] Supprimer tout risque
    \item[D.] Suivre exactement un indice
\end{itemize}
\textbf{Réponse : A}

\subsubsection{QCM - Discount}

\textbf{Q1. Quel est le principe du produit Discount ?}
\begin{itemize}
    \item[A.] Acheter un actif plus cher que son prix actuel
    \item[B.] Investir avec un rendement garanti
    \item[C.] Acheter un actif avec une décote
    \item[D.] Obtenir un effet de levier élevé
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q2. Quel est l’avantage principal de la décote ?}
\begin{itemize}
    \item[A.] Elle garantit un gain illimité
    \item[B.] Elle protège partiellement contre une baisse modérée
    \item[C.] Elle supprime tout risque
    \item[D.] Elle augmente le levier
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Quelle est la contrepartie du produit Discount ?}
\begin{itemize}
    \item[A.] Une durée bloquée
    \item[B.] Une fiscalité plus élevée
    \item[C.] Un gain plafonné
    \item[D.] Une perte automatique
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Que se passe-t-il en cas de forte hausse du sous-jacent ?}
\begin{itemize}
    \item[A.] Le gain devient illimité
    \item[B.] La performance reste limitée
    \item[C.] La décote disparaît rétroactivement
    \item[D.] Le produit est annulé
\end{itemize}
\textbf{Réponse : B}

\subsection{QCM - Risque et utilisation des produits dérivés}

\textbf{Q1. Quelle caractéristique distingue les produits dérivés d’un investissement classique ?}
\begin{itemize}
    \item[A.] Capital garanti
    \item[B.] Sensibilité au temps qui réduit la valeur
    \item[C.] Rendement fixe
    \item[D.] Absence de risque
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Que peut entraîner une évolution défavorable du marché ?}
\begin{itemize}
    \item[A.] Une perte limitée à 1\%
    \item[B.] Une perte totale de la valeur du produit
    \item[C.] Une hausse automatique
    \item[D.] Une garantie de remboursement
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. À quoi servent principalement les produits dérivés ?}
\begin{itemize}
    \item[A.] Investir passivement sur le long terme
    \item[B.] Exprimer un scénario précis de marché
    \item[C.] Remplacer un livret d’épargne
    \item[D.] Garantir un rendement stable
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q4. Quelle précaution est nécessaire pour utiliser ces produits ?}
\begin{itemize}
    \item[A.] Aucune connaissance particulière
    \item[B.] Prudence et gestion stricte du capital
    \item[C.] Uniquement un capital important
    \item[D.] Investir sur plusieurs années sans suivi
\end{itemize}
\textbf{Réponse : B}

\subsection{QCM - Les produits structurés}

\subsubsection{QCM - Combiner sécurité et performance}

\textbf{Q1. Qu’est-ce qu’un produit structuré ?}
\begin{itemize}
    \item[A.] Un compte bancaire réglementé
    \item[B.] Un placement avec rendement garanti par l’État
    \item[C.] Un placement combinant plusieurs instruments financiers
    \item[D.] Une action internationale
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q2. Quelle est la structure générale d’un produit structuré ?}
\begin{itemize}
    \item[A.] Action + dividende
    \item[B.] Obligation + produit dérivé
    \item[C.] Livret + assurance
    \item[D.] Devise + inflation
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Quel est l’objectif principal d’un produit structuré ?}
\begin{itemize}
    \item[A.] Obtenir uniquement la sécurité sans rendement
    \item[B.] Obtenir uniquement un rendement maximal sans risque
    \item[C.] Remplacer totalement les actions
    \item[D.] Chercher une performance supérieure avec protection partielle
\end{itemize}
\textbf{Réponse : D}

\bigskip

\textbf{Q4. Quelle forme peut prendre la protection du capital ?}
\begin{itemize}
    \item[A.] Totale et obligatoire
    \item[B.] Partielle ou conditionnelle
    \item[C.] Impossible dans tous les cas
    \item[D.] Basée uniquement sur l’inflation
\end{itemize}
\textbf{Réponse : B}

\subsubsection{QCM - Architecture et mécanisme de fonctionnement}

\textbf{Q1. Comment est réparti le capital dans ce type de produit ?}
\begin{itemize}
    \item[A.] Actions uniquement
    \item[B.] Protection + exposition conditionnelle
    \item[C.] Obligations uniquement
    \item[D.] Liquidités uniquement
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Quel est le rôle de la partie obligataire ou monétaire ?}
\begin{itemize}
    \item[A.] Augmenter fortement le rendement
    \item[B.] Spéculer sur la volatilité
    \item[C.] Constituer un socle de protection à l’échéance
    \item[D.] Garantir une hausse du marché
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q3. À quoi sert la partie investie en produits dérivés ?}
\begin{itemize}
    \item[A.] Assurer la liquidité
    \item[B.] Payer les frais de gestion
    \item[C.] Couvrir l’inflation
    \item[D.] Fournir une exposition à un actif dynamique
\end{itemize}
\textbf{Réponse : D}

\bigskip

\textbf{Q4. Que permet la combinaison de ces mécanismes financiers ?}
\begin{itemize}
    \item[A.] Transformer un marché incertain en scénario encadré
    \item[B.] Supprimer tout risque financier
    \item[C.] Garantir un rendement illimité
    \item[D.] Remplacer les ETF
\end{itemize}
\textbf{Réponse : A}

\subsubsection{QCM - Conditions de performance et notion de barrière}

\textbf{Q1. De quoi dépend la performance d’un produit structuré ?}
\begin{itemize}
    \item[A.] Uniquement des taux d’intérêt
    \item[B.] D’une ou plusieurs conditions de marché
    \item[C.] Du nombre d’investisseurs
    \item[D.] Du prix de l’or
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Qu’est-ce qu’une barrière dans un produit structuré ?}
\begin{itemize}
    \item[A.] Un niveau technique déclenchant ou annulant la protection
    \item[B.] Une commission bancaire
    \item[C.] Une date d’échéance
    \item[D.] Une garantie d’État
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q3. Que se passe-t-il si la barrière est franchie défavorablement ?}
\begin{itemize}
    \item[A.] Le rendement augmente
    \item[B.] Le capital est automatiquement garanti
    \item[C.] La protection peut disparaître et l’investisseur subit la baisse
    \item[D.] Le produit est prolongé
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Comment est le rendement d’un produit structuré ?}
\begin{itemize}
    \item[A.] Illimité
    \item[B.] Fixe indépendamment du marché
    \item[C.] Basé uniquement sur les dividendes
    \item[D.] Plafonné et conditionnel
\end{itemize}
\textbf{Réponse : D}

\subsubsection{QCM - Durée, risques et rôle dans un portefeuille}

\textbf{Q1. Que peut entraîner une sortie anticipée d’un produit structuré ?}
\begin{itemize}
    \item[A.] Aucun impact sur le rendement
    \item[B.] Un remboursement garanti du capital
    \item[C.] Une perte possible liée au prix de marché
    \item[D.] Une augmentation automatique du gain
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q2. La protection du capital est valable :}
\begin{itemize}
    \item[A.] À tout moment
    \item[B.] Uniquement à l’échéance et si l’émetteur est solvable
    \item[C.] Seulement pendant la première année
    \item[D.] Indépendamment de l’émetteur
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Quel risque spécifique s’ajoute au risque de marché ?}
\begin{itemize}
    \item[A.] Risque climatique
    \item[B.] Risque de liquidité bancaire
    \item[C.] Risque de change
    \item[D.] Risque de contrepartie
\end{itemize}
\textbf{Réponse : D}

\bigskip

\textbf{Q4. Quel est le rôle d’un produit structuré dans un portefeuille ?}
\begin{itemize}
    \item[A.] Remplacer totalement les actions
    \item[B.] Offrir uniquement de la sécurité
    \item[C.] Servir d’épargne de précaution
    \item[D.] Constituer un compromis entre protection et performance
\end{itemize}
\textbf{Réponse : D}

\subsection{QCM - Les matières premières}

\subsubsection{QCM - Investir dans les ressources réelles}

\textbf{Q1. Que représentent les matières premières (commodities) ?}
\begin{itemize}
    \item[A.] Une dette d’État
    \item[B.] Une part d’entreprise
    \item[C.] Des ressources physiques indispensables à l’économie
    \item[D.] Un produit bancaire garanti
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q2. Contrairement aux actions et obligations, les matières premières représentent :}
\begin{itemize}
    \item[A.] Une entreprise
    \item[B.] Une dette
    \item[C.] Un dividende
    \item[D.] Ni entreprise ni dette
\end{itemize}
\textbf{Réponse : D}

\bigskip

\textbf{Q3. De quoi dépend principalement le prix des matières premières ?}
\begin{itemize}
    \item[A.] De l’offre mondiale et de la demande économique
    \item[B.] Du nombre d’investisseurs particuliers
    \item[C.] Du taux du livret A
    \item[D.] Des dividendes
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q4. Quel type d’actif représentent les matières premières ?}
\begin{itemize}
    \item[A.] Actif virtuel
    \item[B.] Actif tangible lié à la conjoncture macroéconomique
    \item[C.] Actif obligataire
    \item[D.] Produit structuré
\end{itemize}
\textbf{Réponse : B}

\subsubsection{QCM - Formation des prix}

\textbf{Q1. Le prix d’une matière première dépend principalement :}
\begin{itemize}
    \item[A.] Du marketing des entreprises
    \item[B.] D’un équilibre global entre offre et demande
    \item[C.] Du taux d’intérêt bancaire
    \item[D.] Du nombre de traders particuliers
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Quel facteur influence l’offre de matières premières ?}
\begin{itemize}
    \item[A.] Les capacités d’extraction
    \item[B.] Les dividendes boursiers
    \item[C.] La fiscalité personnelle
    \item[D.] Les taux immobiliers
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q3. Quel élément influence principalement la demande ?}
\begin{itemize}
    \item[A.] La couleur des métaux
    \item[B.] La croissance économique et l’activité industrielle
    \item[C.] Le nombre de banques centrales
    \item[D.] Les comptes d’épargne
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q4. Quel événement peut provoquer des variations rapides des prix ?}
\begin{itemize}
    \item[A.] Une modification comptable
    \item[B.] Un changement de logo d’entreprise
    \item[C.] Les tensions internationales ou le climat
    \item[D.] Une baisse des frais bancaires
\end{itemize}
\textbf{Réponse : C}

\subsubsection{QCM - Grandes catégories}

\textbf{Q1. Quelle matière première appartient à la catégorie énergie ?}
\begin{itemize}
    \item[A.] Le pétrole
    \item[B.] Le cuivre
    \item[C.] L’or
    \item[D.] Le blé
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q2. Les métaux industriels sont principalement liés :}
\begin{itemize}
    \item[A.] Aux politiques monétaires
    \item[B.] À l’activité industrielle et aux infrastructures
    \item[C.] Aux comptes d’épargne
    \item[D.] Aux assurances
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Pourquoi l’or est-il considéré comme une valeur refuge ?}
\begin{itemize}
    \item[A.] Il dépend du climat
    \item[B.] Il garantit un rendement fixe
    \item[C.] Il est recherché en période d’incertitude
    \item[D.] Il est uniquement industriel
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Quel facteur influence fortement les produits agricoles ?}
\begin{itemize}
    \item[A.] Les taux d’intérêt
    \item[B.] Les conditions climatiques
    \item[C.] La fiscalité boursière
    \item[D.] Les dividendes
\end{itemize}
\textbf{Réponse : B}

\subsubsection{QCM - Absence de revenu intrinsèque}

\textbf{Q1. Une matière première génère :}
\begin{itemize}
    \item[A.] Des dividendes réguliers
    \item[B.] Des intérêts fixes
    \item[C.] Aucun flux financier régulier
    \item[D.] Un coupon garanti
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q2. Le rendement d’une matière première provient :}
\begin{itemize}
    \item[A.] Des loyers perçus
    \item[B.] De la variation de son prix
    \item[C.] Des impôts réduits
    \item[D.] D’un taux garanti
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Contrairement à une action, une matière première ne verse pas :}
\begin{itemize}
    \item[A.] De dividendes
    \item[B.] De frais
    \item[C.] De commissions
    \item[D.] De taxes
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q4. La performance d’une matière première dépend exclusivement :}
\begin{itemize}
    \item[A.] Des taux d’intérêt
    \item[B.] De l’inflation
    \item[C.] Du volume échangé
    \item[D.] De l’évolution du cours
\end{itemize}
\textbf{Réponse : D}

\subsubsection{QCM - Lien avec l’inflation et le cycle économique}

\textbf{Q1. Quel effet a généralement l’inflation sur les matières premières ?}
\begin{itemize}
    \item[A.] Elle tend à soutenir leurs prix
    \item[B.] Elle les rend sans valeur
    \item[C.] Elle garantit leur baisse
    \item[D.] Elle n’a aucun impact
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q2. Que provoque généralement un ralentissement économique ?}
\begin{itemize}
    \item[A.] Une hausse de la demande industrielle
    \item[B.] Une pression baissière sur les prix
    \item[C.] Une stabilité totale
    \item[D.] Une hausse automatique du pétrole
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Pourquoi les matières premières sont-elles utilisées dans un portefeuille ?}
\begin{itemize}
    \item[A.] Pour garantir un revenu fixe
    \item[B.] Comme couverture macroéconomique
    \item[C.] Pour remplacer les obligations d’État
    \item[D.] Pour réduire la fiscalité
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q4. Comment un investisseur particulier s’expose-t-il généralement aux matières premières ?}
\begin{itemize}
    \item[A.] En stockant physiquement la ressource
    \item[B.] En ouvrant un livret bancaire
    \item[C.] Via ETF, futures ou actions d’entreprises productrices
    \item[D.] Uniquement par des obligations
\end{itemize}
\textbf{Réponse : C}

\subsubsection{QCM - Le rôle des marchés à terme}

\textbf{Q1. Comment sont majoritairement échangées les matières premières ?}
\begin{itemize}
    \item[A.] Par actions en bourse
    \item[B.] Via des contrats futurs
    \item[C.] Par comptes d’épargne
    \item[D.] Par obligations d’État
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Le prix futur d’une matière première dépend notamment :}
\begin{itemize}
    \item[A.] Du prix spot, du stockage et des anticipations
    \item[B.] Uniquement du prix spot
    \item[C.] Du nombre d’investisseurs particuliers
    \item[D.] Des dividendes versés
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q3. Que signifie le contango ?}
\begin{itemize}
    \item[A.] Prix futur inférieur au prix spot
    \item[B.] Prix futur égal au prix spot
    \item[C.] Prix futur supérieur au prix spot
    \item[D.] Absence de marché
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Quelle structure peut affecter la performance des ETF matières premières ?}
\begin{itemize}
    \item[A.] Les dividendes
    \item[B.] La fiscalité
    \item[C.] La volatilité bancaire
    \item[D.] La structure contango/backwardation
\end{itemize}
\textbf{Réponse : D}

\subsubsection{QCM - Rôle dans un portefeuille}

\textbf{Q1. Pourquoi les matières premières améliorent-elles la diversification ?}
\begin{itemize}
    \item[A.] Elles suivent exactement les actions
    \item[B.] Elles ont un comportement différent des actions et obligations
    \item[C.] Elles garantissent un rendement
    \item[D.] Elles sont sans volatilité
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Quel rôle macroéconomique peuvent-elles jouer ?}
\begin{itemize}
    \item[A.] Protection partielle contre l’inflation
    \item[B.] Paiement de dividendes
    \item[C.] Réduction des impôts
    \item[D.] Garantie du capital
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q3. Quel est l’objectif principal des matières premières dans un portefeuille ?}
\begin{itemize}
    \item[A.] Générer un revenu régulier
    \item[B.] Spéculer uniquement à court terme
    \item[C.] Équilibrer face aux risques macroéconomiques
    \item[D.] Remplacer les obligations
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Les matières premières réagissent principalement :}
\begin{itemize}
    \item[A.] Aux performances d’une entreprise
    \item[B.] Aux décisions d’un PDG
    \item[C.] Aux dividendes
    \item[D.] Aux dynamiques économiques globales
\end{itemize}
\textbf{Réponse : D}

\subsection{QCM - Les crypto-actifs}

\subsubsection{QCM - Des actifs numériques décentralisés}

\textbf{Q1. Sur quoi reposent les crypto-actifs ?}
\begin{itemize}
    \item[A.] Un compte bancaire central
    \item[B.] Une blockchain
    \item[C.] Une banque centrale
    \item[D.] Un contrat papier
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Contrairement aux actifs traditionnels, les crypto-actifs représentent :}
\begin{itemize}
    \item[A.] Une entreprise
    \item[B.] Une dette d’État
    \item[C.] Une ressource physique
    \item[D.] Aucun de ces éléments
\end{itemize}
\textbf{Réponse : D}

\bigskip

\textbf{Q3. De quoi provient principalement la valeur d’un crypto-actif ?}
\begin{itemize}
    \item[A.] De la confiance collective et de la rareté numérique
    \item[B.] Des dividendes versés
    \item[C.] Des taux d’intérêt
    \item[D.] Des loyers
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q4. Les crypto-actifs constituent :}
\begin{itemize}
    \item[A.] Une dette bancaire
    \item[B.] Une action numérique
    \item[C.] Une nouvelle classe d’actifs basée sur des règles mathématiques
    \item[D.] Une obligation garantie
\end{itemize}
\textbf{Réponse : C}

\subsubsection{QCM - Infrastructure et fonctionnement du réseau}

\textbf{Q1. Qu’est-ce qu’une blockchain ?}
\begin{itemize}
    \item[A.] Un registre public distribué de transactions
    \item[B.] Une base de données privée bancaire
    \item[C.] Un serveur central unique
    \item[D.] Un logiciel de trading
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q2. Comment la blockchain remplace-t-elle l’autorité centrale ?}
\begin{itemize}
    \item[A.] Par un contrôle gouvernemental
    \item[B.] Chaque participant vérifie et conserve une copie du registre
    \item[C.] Par une banque principale
    \item[D.] Par un notaire numérique
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q3. Qui peut contrôler un crypto-actif ?}
\begin{itemize}
    \item[A.] Toute personne connaissant le mot de passe du site
    \item[B.] Uniquement la banque
    \item[C.] Le détenteur de la clé privée
    \item[D.] Les autorités publiques
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Comment est déterminée l’émission de certains crypto-actifs ?}
\begin{itemize}
    \item[A.] Par une décision politique
    \item[B.] Par une banque centrale
    \item[C.] Par le marché boursier
    \item[D.] Par un algorithme prédéfini
\end{itemize}
\textbf{Réponse : D}

\subsubsection{QCM - Valorisation et dynamique de marché}

\textbf{Q1. Un crypto-actif verse généralement :}
\begin{itemize}
    \item[A.] Des dividendes
    \item[B.] Des intérêts
    \item[C.] Aucun flux financier
    \item[D.] Un coupon garanti
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q2. De quoi dépend principalement sa valorisation ?}
\begin{itemize}
    \item[A.] De l’équilibre entre acheteurs et vendeurs
    \item[B.] D’un taux fixé par l’État
    \item[C.] Des loyers
    \item[D.] D’un rendement minimum garanti
\end{itemize}
\textbf{Réponse : A}

\bigskip

\textbf{Q3. Pourquoi le marché crypto est-il très volatil ?}
\begin{itemize}
    \item[A.] Parce qu’il est totalement stable
    \item[B.] À cause des dividendes irréguliers
    \item[C.] En raison de l’innovation, de l’usage et des anticipations
    \item[D.] À cause des frais bancaires
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q4. Le rendement d’un crypto-actif provient :}
\begin{itemize}
    \item[A.] D’un intérêt annuel
    \item[B.] D’un coupon obligataire
    \item[C.] D’une décision politique
    \item[D.] De la variation du prix
\end{itemize}
\textbf{Réponse : D}

\subsubsection{QCM - Usages, risques et place dans un portefeuille}

\textbf{Q1. Quelle fonction peuvent remplir les crypto-actifs ?}
\begin{itemize}
    \item[A.] Paiement d’intérêts obligatoires
    \item[B.] Transfert de valeur sans intermédiaire
    \item[C.] Garantie d’un revenu mensuel
    \item[D.] Assurance bancaire
\end{itemize}
\textbf{Réponse : B}

\bigskip

\textbf{Q2. Quel risque spécifique existe en cas de perte de clé privée ?}
\begin{itemize}
    \item[A.] Blocage temporaire
    \item[B.] Frais supplémentaires
    \item[C.] Perte définitive des fonds
    \item[D.] Remboursement automatique
\end{itemize}
\textbf{Réponse : C}

\bigskip

\textbf{Q3. Comment sont généralement considérés les crypto-actifs dans un portefeuille ?}
\begin{itemize}
    \item[A.] Comme actif principal obligatoire
    \item[B.] Comme remplacement total des actions
    \item[C.] Comme épargne sécurisée
    \item[D.] Comme composante complémentaire proportionnée au risque
\end{itemize}
\textbf{Réponse : D}

\bigskip

\textbf{Q4. Quelle caractéristique décrit le mieux leur exposition ?}
\begin{itemize}
    \item[A.] Principalement immobilière
    \item[B.] Principalement technologique et spéculative
    \item[C.] Garantit par l’État
    \item[D.] Indexée sur l’inflation
\end{itemize}
\textbf{Réponse : B}
''';
