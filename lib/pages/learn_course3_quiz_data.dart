import 'dart:math';

String _normalizeChapter3QuizKey(String value) {
  return value
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll(r'$', '')
      .replaceAll('--', '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const Map<String, String> _chapter3QuizLessonByHeading = {
  'Pourquoi la microéconomie est essentielle pour comprendre la finance':
      'Microéconomie et finance : le même langage',
  "Le mécanisme d'équilibre": "Comprendre l'équilibre sur un marché financier",
  "Qu'est-ce que la fonction d'utilité U ?":
      'De la consommation certaine à la richesse incertaine',
  'Le compromis rendement-risque : réalité économique':
      'Pourquoi le marché impose une pente croissante',
  'Interprétation microéconomique':
      'Choisir sous contrainte dans un monde incertain',
  'La diversification : un principe microéconomique approfondi':
      "Pourquoi diversifier augmente l'utilité",
  'Construction mathématique du portefeuille':
      'Portefeuille à deux actifs risqués',
  'La variance du portefeuille': 'Le rôle central de la covariance',
  'Pourquoi la diversification réduit le risque':
      'Corrélation, réduction du risque et cas extrêmes',
  'Lecture microéconomique profonde':
      'Combiner des risques imparfaitement corrélés',
  'Arbitrage et discipline des marchés': 'La loi du prix unique',
  'Risque, aversion et prime de risque':
      'Pourquoi un actif risqué doit rémunérer davantage',
  "Asymétrie d'information": 'Sélection adverse et décote informationnelle',
  'Interactions stratégiques et bulles':
      'Quand les anticipations deviennent auto-réalisatrices',
  'Décision intertemporelle et valorisation des actifs':
      'La contrainte budgétaire intertemporelle',
  'Actualisation et valeur fondamentale': 'La valeur présente des flux futurs',
  'Équilibre du marché des actifs et CAPM':
      'Comment les prix émergent des choix agrégés',
  'Risque systématique et diversification':
      'Pourquoi seul le risque non diversifiable est rémunéré',
  'Représentation de la droite du marché des titres':
      'Lire la Security Market Line',
  'Relation principal-agent': "Le contrat comme outil d'incitation",
  'Structure du capital': 'Dette ou actions : un arbitrage microéconomique',
  "Le carnet d'ordres et le spread": 'Bid, ask et coût de transaction',
  "Exemple simplifié d'un carnet d'ordres": "Lire un mini carnet d'ordres",
  'Comportements et rationalité limitée':
      'Quand la rationalité parfaite devient insuffisante',
  'Synthèse générale du cadre microéconomique appliqué à la finance':
      'Relier tous les mécanismes ensemble',
  'Préférences, utilité espérée et aversion au risque':
      'Préférences, concavité et richesse finale',
  'Choix de portefeuille : formulation générale et condition marginale':
      "L'égalité marginale au coeur du choix optimal",
  'Le noyau stochastique (SDF) et le principe du pricing':
      'Le SDF comme prix de la rareté marginale',
  'Pourquoi l\'équilibre général est la bonne "langue" de la finance':
      'Biens contingents et états du monde',
  "Biens contingents et prix d'état":
      "Les prix d'état condensent probabilité et rareté",
  'Schéma : espace des états et biens contingents':
      'Biens contingents et états du monde',
  'Répliquer un actif avec Arrow-Debreu': 'Décomposer un payoff état par état',
  "De l'optimum individuel à la rémunération du risque":
      'Quel risque est vraiment payé ?',
  'Droite du marché des titres : lecture économique':
      'β comme mesure du risque non diversifiable',
  'Une dérivation intuitive (sans lourdeur excessive)':
      'Du SDF à la covariance avec le marché',
  "Le problème principal-agent dans l'entreprise cotée":
      "Pourquoi le dirigeant ne choisit pas toujours l'effort optimal",
  'Lecture financière : pourquoi stock-options, bonus, dette':
      'Arbitrer entre incitation, discipline et risque',
  'Pourquoi la rationalité parfaite est parfois insuffisante':
      'Bulles, paniques et anomalies de comportement',
  'Théorie des perspectives : aversion aux pertes':
      "Modifier la fonction de valeur autour d'un point de référence",
};

class _Chapter3QuizToken {
  const _Chapter3QuizToken.heading(this.offset, this.level, this.value)
    : question = null,
      optionsBlock = null,
      answer = null;

  const _Chapter3QuizToken.question(
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

int _stableChapter3QuizSeed(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String _unwrapLatexCommand(String text, String command) {
  final pattern = RegExp('\\\\$command\\{([^{}]*)\\}');
  var result = text;
  while (pattern.hasMatch(result)) {
    result = result.replaceAllMapped(pattern, (match) => match.group(1) ?? '');
  }
  return result;
}

String _replaceFractions(String text) {
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

String _cleanChapter3QuizText(String value) {
  var text = value.replaceAll('\r', ' ').replaceAll('\n', ' ');
  text = text.replaceAll(r'\%', '%');
  text = text.replaceAll(r'\neq', '≠');
  text = text.replaceAll(r'\leq', '≤');
  text = text.replaceAll(r'\geq', '≥');
  text = text.replaceAll(r'\times', '×');
  text = text.replaceAll(r'\cdot', '·');
  text = text.replaceAll(r'\Rightarrow', '⇒');
  text = text.replaceAll(r'\to', '→');
  text = text.replaceAll(r'\mathbb{E}', 'E');
  text = text.replaceAll(r'\mathrm{Var}', 'Var');
  text = text.replaceAll(r'\mathrm{Cov}', 'Cov');
  text = text.replaceAll(r'\sigma', 'σ');
  text = text.replaceAll(r'\beta', 'β');
  text = text.replaceAll(r'\rho', 'ρ');
  text = text.replaceAll(r'\pi', 'π');
  text = text.replaceAll(r'\partial', '∂');
  text = text.replaceAll(r'\sum', 'Σ');
  text = _replaceFractions(text);
  for (final command in ['textit', 'textbf', 'boxed', 'mathrm']) {
    text = _unwrapLatexCommand(text, command);
  }
  text = text.replaceAll(RegExp(r'\\begin\{[^}]+\}'), ' ');
  text = text.replaceAll(RegExp(r'\\end\{[^}]+\}'), ' ');
  text = text.replaceAllMapped(
    RegExp(r'_\{([^}]*)\}'),
    (match) => " ${match.group(1) ?? ''}",
  );
  text = text.replaceAll(RegExp(r'\\[a-zA-Z]+\*?'), ' ');
  text = text.replaceAll(r'$', '');
  text = text.replaceAll('{', '');
  text = text.replaceAll('}', '');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

Map<String, dynamic> _buildChapter3Question(
  String question,
  List<String> options,
  int correctIndex,
) {
  final indexedOptions = List.generate(
    options.length,
    (index) => MapEntry(index, options[index]),
  );
  final random = Random(
    _stableChapter3QuizSeed('$question|${options.join('|')}|$correctIndex'),
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

Map<String, List<String>> _collectChapter3LessonsByTopChapter(
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

Map<String, List<Map<String, dynamic>>> _parseChapter3QuizQuestions() {
  final tokens = <_Chapter3QuizToken>[];
  final headingPattern = RegExp(
    r'\\(section|subsection|subsubsection)\*\{([^}]*)\}',
  );
  final questionPattern = RegExp(
    r'\\item\s+(.*?)\s+\\begin\{enumerate\}\[label=\\Alph\*\.\](.*?)\\end\{enumerate\}\s*\\textbf\{Réponse correcte\s*:?\s*([A-D])?\}\s*:?\s*([A-D])?',
    dotAll: true,
  );

  for (final match in headingPattern.allMatches(_chapter3QuizLatex)) {
    tokens.add(
      _Chapter3QuizToken.heading(match.start, match.group(1)!, match.group(2)!),
    );
  }

  for (final match in questionPattern.allMatches(_chapter3QuizLatex)) {
    final answer = match.group(3) ?? match.group(4);
    if (answer == null) {
      continue;
    }
    tokens.add(
      _Chapter3QuizToken.question(
        match.start,
        match.group(1)!,
        match.group(2)!,
        answer,
      ),
    );
  }

  tokens.sort((left, right) => left.offset.compareTo(right.offset));

  String? section;
  String? subsection;
  String? subsubsection;
  final lessonQuestions = <String, List<Map<String, dynamic>>>{};
  final optionPattern = RegExp(
    r'\\item\s+(.*?)(?=(?:\n\s*\\item\s+)|$)',
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

    final headingKey = _normalizeChapter3QuizKey(
      subsubsection ?? subsection ?? section ?? '',
    );
    final lessonTitle = _chapter3QuizLessonByHeading[headingKey];
    if (lessonTitle == null) {
      continue;
    }

    final options =
        optionPattern
            .allMatches(token.optionsBlock ?? '')
            .map((match) => _cleanChapter3QuizText(match.group(1) ?? ''))
            .where((option) => option.isNotEmpty)
            .toList();
    final correctIndex = 'ABCD'.indexOf(token.answer ?? '');
    if (options.length < 2 ||
        correctIndex < 0 ||
        correctIndex >= options.length) {
      continue;
    }

    lessonQuestions.putIfAbsent(lessonTitle, () => <Map<String, dynamic>>[]);
    lessonQuestions[lessonTitle]!.add(
      _buildChapter3Question(
        _cleanChapter3QuizText(token.question ?? ''),
        options,
        correctIndex,
      ),
    );
  }

  return lessonQuestions;
}

final Map<String, List<Map<String, dynamic>>>
_chapter3SupplementalQuestions = <String, List<Map<String, dynamic>>>{
  'Pourquoi le prix réagit avant les résultats': <Map<String, dynamic>>[
    _buildChapter3Question(
      "Quand une innovation prometteuse change les anticipations des investisseurs, quel mouvement décrit le mieux la demande d'actions ?",
      <String>[
        "La demande se déplace vers la droite et le prix peut monter immédiatement.",
        "La demande disparaît jusqu'à la publication des résultats comptables.",
        "L'offre se déplace automatiquement vers la gauche sans effet sur le prix.",
        "Le prix reste inchangé tant que les profits futurs ne sont pas réalisés.",
      ],
      0,
    ),
    _buildChapter3Question(
      "Pourquoi le prix d'une action peut-il réagir avant la publication effective des résultats ?",
      <String>[
        "Parce que la bourse interdit d'acheter après la publication des comptes.",
        "Parce que le prix reflète surtout l'anticipation des profits futurs.",
        "Parce que les dividendes sont obligatoirement payés en avance.",
        "Parce que le prix d'équilibre est fixé par les autorités de marché.",
      ],
      1,
    ),
    _buildChapter3Question(
      "Dans cette logique microéconomique, qu'évalue principalement le marché quand il revalorise une action aujourd'hui ?",
      <String>[
        "Le présent uniquement, sans lien avec les flux futurs.",
        "Le coût historique de production de l'entreprise.",
        "Le jugement collectif porté sur les revenus futurs attendus.",
        "Le nombre total d'actions déjà échangées dans la journée.",
      ],
      2,
    ),
  ],
};

Map<String, dynamic> buildChapter3QuizData(Map<String, dynamic> courseData) {
  final lessonsByTopChapter = _collectChapter3LessonsByTopChapter(courseData);
  final lessonQuestions = _parseChapter3QuizQuestions();
  final chapters = <Map<String, dynamic>>[];
  final courseChapters =
      (courseData['chapters'] as List).cast<Map<String, dynamic>>();

  for (final chapter in courseChapters) {
    final chapterTitle = chapter['chapter_title'] as String;
    final lessonTitles = lessonsByTopChapter[chapterTitle] ?? const <String>[];
    final quizzes = <Map<String, dynamic>>[];

    for (final lessonTitle in lessonTitles) {
      final questions =
          lessonQuestions[lessonTitle] ??
          _chapter3SupplementalQuestions[lessonTitle];
      if (questions == null || questions.isEmpty) {
        continue;
      }

      quizzes.add({'lesson_title': lessonTitle, 'questions': questions});
    }

    if (quizzes.isNotEmpty) {
      chapters.add({'chapter_title': chapterTitle, 'quizzes': quizzes});
    }
  }

  return {
    'course_title': 'Microéconomie et marchés financiers : QCM',
    'chapters': chapters,
  };
}

const List<String> _chapter3QuizLatexChunks = <String>[
  r'''
\section*{Pourquoi la microéconomie est essentielle pour comprendre la finance}

\begin{enumerate}
    \item Quelle est la relation fondamentale entre la finance et la microéconomie ?
    \begin{enumerate}[label=\Alph*.]
        \item La finance est une discipline totalement isolée de la microéconomie.
        \item La finance est une application directe des principes fondamentaux de la microéconomie.
        \item La microéconomie est une branche dérivée de la finance moderne.
        \item La finance remplace les outils de la microéconomie pour analyser les marchés.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Lequel de ces concepts n'est pas un mécanisme microéconomique fondamental expliquant le comportement des acteurs financiers ?
    \begin{enumerate}[label=\Alph*.]
        \item L'offre et la demande.
        \item L'aversion au risque.
        \item L'inflation galopante.
        \item L'asymétrie d'information.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quelle est la principale différence entre un marché financier et un marché de biens ordinaires ?
    \begin{enumerate}[label=\Alph*.]
        \item Le nombre d'acheteurs et de vendeurs présents sur le marché.
        \item La régulation et le contrôle par l'État.
        \item Le lieu physique où se déroulent les différents échanges.
        \item La nature du bien échangé, qui est ici un actif financier.
    \end{enumerate}
    \textbf{Réponse correcte :} D
    \vspace{0.5cm}

    \item En finance, comment définit-on techniquement un "actif financier" ?
    \begin{enumerate}[label=\Alph*.]
        \item Un bien matériel de très grande valeur.
        \item Une monnaie d'échange internationale reconnue.
        \item Un droit sur des flux futurs.
        \item Une entreprise qui cherche à lever des capitaux.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Lorsque l'on applique les outils microéconomiques à la finance, quel est l'objet particulier que l'on cherche à analyser ?
    \begin{enumerate}[label=\Alph*.]
        \item La certitude des rendements passés.
        \item L'incertitude sur l'avenir.
        \item La gestion des ressources humaines en entreprise.
        \item Les interactions stratégiques des banques centrales.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\section*{Offre, demande et formation du prix d'une action}

\subsection*{Le mécanisme d'équilibre}

\begin{enumerate}
    \item En microéconomie, comment le prix d'équilibre d'un bien est-il déterminé ?
    \begin{enumerate}[label=\Alph*.]
        \item Par la différence systématique entre l'offre et la demande.
        \item Par l'égalité entre la quantité offerte et la quantité demandée.
        \item Par l'intervention directe de l'État sur les marchés financiers.
        \item Par les décisions exclusives des investisseurs institutionnels.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quelle équation mathématique illustre le mécanisme d'équilibre sur un marché ?
    \begin{enumerate}[label=\Alph*.]
        \item $Q_{demandée}(P^*) > Q_{offerte}(P^*)$
        \item $Q_{demandée}(P^*) < Q_{offerte}(P^*)$
        \item $Q_{demandée}(P^*) = Q_{offerte}(P^*)$
        \item $Q_{demandée}(P^*) \neq Q_{offerte}(P^*)$
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Dans quelle mesure le mécanisme microéconomique d'équilibre s'applique-t-il aux marchés financiers ?
    \begin{enumerate}[label=\Alph*.]
        \item Il ne s'y applique pas du tout en raison de la complexité des actifs.
        \item Il s'y applique de manière partielle et uniquement en période de crise.
        \item Il s'applique parfaitement aux marchés financiers.
        \item Il s'applique uniquement si la demande surpasse l'offre.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}
    
    \item Sur les marchés financiers, quelle est la dynamique permanente concernant les intentions des acteurs ?
    \begin{enumerate}[label=\Alph*.]
        \item Tous les investisseurs souhaitent uniquement vendre leurs actions simultanément.
        \item Les transactions sont bloquées jusqu'à l'atteinte d'un prix plancher fixé à l'avance.
        \item L'ensemble des investisseurs souhaite uniquement acheter des actions.
        \item À chaque instant, des investisseurs souhaitent acheter tandis que d'autres souhaitent vendre.
    \end{enumerate}
    \textbf{Réponse correcte :} D
\end{enumerate}

\section*{Risque, rendement et fonction d'utilité}

\subsection*{Qu'est-ce que la fonction d'utilité $U$ ?}

\begin{enumerate}
    \item En microéconomie, que représente fondamentalement la fonction d'utilité ($U$) d'un individu ?
    \begin{enumerate}[label=\Alph*.]
        \item Une mesure psychologique précise de son niveau de bonheur quotidien.
        \item Une manière de classer différentes situations de façon cohérente selon ses préférences.
        \item La rentabilité financière exacte qu'il obtiendra de ses investissements.
        \item L'évolution globale de son pouvoir d'achat face à l'inflation.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item En finance, face à l'incertitude, comment modélise-t-on la fonction d'utilité d'un investisseur ?
    \begin{enumerate}[label=\Alph*.]
        \item $U = U(C)$ où $C$ est la consommation immédiate et certaine.
        \item $U = U(E(R), \sigma)$ où $E(R)$ est l'espérance de rendement et $\sigma$ la mesure du risque.
        \item $U = U(P, Q)$ où $P$ est le prix du marché et $Q$ la quantité d'actions.
        \item $U = U(t)$ où $t$ est la durée totale de l'investissement.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item En situation d'incertitude financière, sur quoi porte réellement le choix d'un investisseur ?
    \begin{enumerate}[label=\Alph*.]
        \item Sur un niveau de consommation certaine, immédiate et garantie.
        \item Sur le contrôle stratégique et opérationnel des entreprises cotées.
        \item Sur un taux d'intérêt fixe garanti de manière inconditionnelle par l'État.
        \item Sur une distribution de richesse future dont il ne peut former qu'une espérance.
    \end{enumerate}
    \textbf{Réponse correcte :} D
    \vspace{0.5cm}

    \item Que signifie économiquement l'hypothèse $\frac{\partial U}{\partial E(R)} > 0$ concernant un investisseur ?
    \begin{enumerate}[label=\Alph*.]
        \item L'investisseur est totalement indifférent à l'augmentation de son rendement espéré.
        \item L'utilité de l'investisseur diminue systématiquement lorsque le rendement espéré augmente.
        \item L'investisseur apprécie un rendement espéré plus élevé car cela augmente sa richesse future.
        \item L'investisseur exige que le rendement espéré soit toujours strictement égal à zéro.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Comment se traduit mathématiquement l'aversion au risque (le fait de ne pas apprécier l'incertitude) dans la fonction d'utilité ?
    \begin{enumerate}[label=\Alph*.]
        \item $\frac{\partial U}{\partial \sigma} > 0$
        \item $\frac{\partial U}{\partial \sigma} < 0$
        \item $\frac{\partial U}{\partial \sigma} = 0$
        \item $\frac{\partial U}{\partial \sigma} = 1$
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\subsection*{Le compromis rendement-risque : réalité économique}

\begin{enumerate}
    \item Quelle est la réalité de la relation entre le rendement espéré et le risque sur les marchés financiers ?
    \begin{enumerate}[label=\Alph*.]
        \item Elle est décroissante : plus de risque entraîne moins de rendement.
        \item Elle est aléatoire et dépend uniquement du comportement des banques centrales.
        \item Elle est croissante : plus le risque est élevé, plus le rendement exigé est élevé.
        \item Elle est parfaitement constante pour tous les types d'actifs.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Pourquoi un actif risqué ne peut-il pas offrir le même rendement espéré qu'un actif sûr dans un équilibre de marché ?
    \begin{enumerate}[label=\Alph*.]
        \item Parce que son prix s'effondrerait par manque d'acheteurs jusqu'à ce que son rendement attendu augmente.
        \item Parce que la loi interdit aux actifs risqués de s'aligner sur les rendements des actifs sûrs.
        \item Parce que cela attirerait trop d'investisseurs, ce qui ferait baisser son rendement de manière irréversible.
        \item Parce que l'État compenserait la différence en versant une prime de risque aux investisseurs.
    \end{enumerate}
    \textbf{Réponse correcte :} A
    \vspace{0.5cm}

    \item Intuitivement, quelle relation rendement-risque un individu souhaiterait-il idéalement obtenir ?
    \begin{enumerate}[label=\Alph*.]
        \item Une relation où le rendement et le risque sont systématiquement nuls.
        \item Une relation décroissante : obtenir plus de rendement tout en s'exposant à moins de risque.
        \item Une relation croissante : prendre toujours plus de risques pour espérer un rendement très élevé.
        \item Une relation strictement proportionnelle et garantie par les institutions financières.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Que se passerait-il en équilibre concurrentiel si des actifs offrant "plus de rendement pour moins de risque" existaient réellement ?
    \begin{enumerate}[label=\Alph*.]
        \item Les investisseurs les ignoreraient car ils sembleraient trop beaux pour être vrais.
        \item Leur prix baisserait immédiatement en raison d'un excès d'offre massif.
        \item Les investisseurs s'y rueraient, ce qui ferait immédiatement monter leur prix et baisser leur rendement attendu.
        \item Leur niveau de risque s'ajusterait automatiquement à la hausse pour compenser ce rendement anormalement élevé.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Sur une représentation graphique du compromis rendement-risque, que symbolisent respectivement la courbe croissante et la courbe décroissante ?
    \begin{enumerate}[label=\Alph*.]
        \item La courbe croissante symbolise le risque d'inflation, la décroissante le risque de déflation.
        \item La courbe croissante symbolise le désir intuitif de l'investisseur, la décroissante la réalité macroéconomique.
        \item La courbe croissante symbolise l'évolution temporelle des taux, la décroissante la stagnation.
        \item La courbe croissante symbolise la relation d'équilibre réelle, la décroissante le désir intuitif de l'investisseur.
    \end{enumerate}
    \textbf{Réponse correcte :} D
\end{enumerate}

\subsection*{Interprétation microéconomique}

\begin{enumerate}
    \item Dans le modèle de la finance moderne, que représentent respectivement la fonction d'utilité et la courbe réelle ?
    \begin{enumerate}[label=\Alph*.]
        \item La fonction d'utilité représente les contraintes de l'État et la courbe réelle les profits des banques.
        \item La fonction d'utilité représente le risque systémique et la courbe réelle l'inflation attendue.
        \item La fonction d'utilité représente les préférences individuelles et la courbe réelle la contrainte économique du marché.
        \item La fonction d'utilité représente les rendements garantis et la courbe réelle les pertes potentielles.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Graphiquement, où se situe techniquement le choix optimal d'un investisseur face au compromis rendement-risque ?
    \begin{enumerate}[label=\Alph*.]
        \item Au point où la courbe d'indifférence de l'investisseur est tangente à la frontière rendement-risque.
        \item Au point d'intersection entre la courbe d'offre des entreprises et l'axe des abscisses.
        \item Au sommet absolu de la courbe de la fonction d'utilité globale du marché.
        \item Au point le plus bas de la courbe réelle, permettant d'annuler totalement le risque.
    \end{enumerate}
    \textbf{Réponse correcte :} A
    \vspace{0.5cm}

    \item Quelle phrase décrit le mieux la philosophie du choix d'un investisseur sur les marchés financiers ?
    \begin{enumerate}[label=\Alph*.]
        \item L'investisseur choisit systématiquement l'option idéale qu'il désirait intuitivement sans se soucier du marché.
        \item L'investisseur s'oriente toujours vers l'actif offrant le rendement absolu le plus élevé possible.
        \item L'investisseur refuse toute transaction s'il ne peut pas éliminer l'intégralité du risque.
        \item L'investisseur ne choisit pas son idéal, mais le meilleur compromis possible compte tenu de la réalité du marché.
    \end{enumerate}
    \textbf{Réponse correcte :} D
    \vspace{0.5cm}

    \item À quelle logique microéconomique fondamentale correspond ce comportement d'investissement en finance ?
    \begin{enumerate}[label=\Alph*.]
        \item À la logique de la destruction créatrice de Schumpeter.
        \item À la logique du choix sous contrainte appliquée à l'incertitude.
        \item À la théorie des jeux à somme nulle.
        \item À l'équilibre monopolistique des marchés fermés.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\subsection*{La diversification : un principe microéconomique approfondi}

\begin{enumerate}
    \item En finance, quelle est la nature profonde de la diversification ?
    \begin{enumerate}[label=\Alph*.]
        \item Une simple règle pratique d'investissement sans fondement théorique réel.
        \item Une conséquence directe du comportement rationnel sous incertitude.
        \item Une obligation légale imposée à tous les investisseurs institutionnels.
        \item Un concept purement psychologique visant à rassurer l'investisseur.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item En microéconomie, quel est l'objectif principal d'un agent faisant face à plusieurs sources d'aléa ?
    \begin{enumerate}[label=\Alph*.]
        \item Réduire la variabilité globale de son résultat sans sacrifier inutilement son espérance de gain.
        \item Concentrer tout son capital sur l'option la plus risquée pour maximiser l'espérance de gain.
        \item Éliminer totalement toute forme d'incertitude de ses choix économiques.
        \item Ignorer l'aléa et se fier uniquement aux rendements passés.
    \end{enumerate}
    \textbf{Réponse correcte :} A
    \vspace{0.5cm}

    \item À quel autre comportement économique la logique de diversification financière est-elle directement comparée ?
    \begin{enumerate}[label=\Alph*.]
        \item Au comportement d'une entreprise cherchant à établir un monopole.
        \item À la fixation stratégique des taux d'intérêt par une banque centrale.
        \item Aux décisions de réduction de la dette publique par l'État.
        \item Au choix d'un consommateur répartissant son budget entre plusieurs biens face à des rendements incertains.
    \end{enumerate}
    \textbf{Réponse correcte :} D
\end{enumerate}
''',
  r'''
\subsubsection*{Construction mathématique du portefeuille}

\begin{enumerate}
    \item Dans la construction mathématique d'un portefeuille à deux actifs, que représentent les variables $w_1$ et $w_2$ ?
    \begin{enumerate}[label=\Alph*.]
        \item Les espérances de rendement aléatoire de chaque actif.
        \item La part du capital investie respectivement dans l'actif 1 et l'actif 2.
        \item La mesure du risque associé à chaque actif composant le portefeuille.
        \item Le rendement global garanti à l'issue de la période d'investissement.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quelle condition mathématique fondamentale lie les parts de capital investies ($w_1$ et $w_2$) dans un portefeuille à deux actifs ?
    \begin{enumerate}[label=\Alph*.]
        \item $w_1 \times w_2 = 1$
        \item $w_1 - w_2 = 0$
        \item $w_1 + w_2 = 1$
        \item $w_1 + w_2 = 100$
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Comment se calcule le rendement global d'un portefeuille ($R_p$) composé de deux actifs ?
    \begin{enumerate}[label=\Alph*.]
        \item Il s'agit d'une simple addition des deux rendements aléatoires bruts.
        \item Il s'agit d'une moyenne pondérée des rendements des deux actifs.
        \item Il correspond au rendement de l'actif ayant la plus grande proportion.
        \item Il est obtenu en multipliant les rendements des deux actifs entre eux.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Concernant l'espérance de rendement du portefeuille $E(R_p)$, quelle affirmation dérive directement de sa formule mathématique ?
    \begin{enumerate}[label=\Alph*.]
        \item Les rendements moyens s'additionnent proportionnellement aux poids investis.
        \item L'espérance du portefeuille est toujours inférieure à la moyenne pondérée des actifs.
        \item L'espérance du portefeuille dépend exclusivement de l'actif le moins risqué.
        \item Les poids investis n'ont aucun impact sur l'espérance de rendement final.
    \end{enumerate}
    \textbf{Réponse correcte :} A
\end{enumerate}

\subsubsection*{La variance du portefeuille}

\begin{enumerate}
    \item En finance, par quelle grandeur mathématique le risque d'un portefeuille est-il principalement mesuré ?
    \begin{enumerate}[label=\Alph*.]
        \item L'espérance mathématique des rendements.
        \item La variance (ou l'écart-type) des rendements.
        \item La moyenne arithmétique simple des investissements.
        \item La covariance exclusive des différents actifs.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item D'après les propriétés d'une combinaison linéaire, quelle est l'expression exacte de la variance d'un portefeuille ($\sigma_p^2$) composé de deux actifs ?
    \begin{enumerate}[label=\Alph*.]
        \item $\sigma_p^2 = w_1 \sigma_1^2 + w_2 \sigma_2^2$
        \item $\sigma_p^2 = w_1^2 \sigma_1^2 + w_2^2 \sigma_2^2 + w_1 w_2 \text{Cov}(R_1,R_2)$
        \item $\sigma_p^2 = w_1^2 \sigma_1^2 + w_2^2 \sigma_2^2 + 2w_1 w_2 \text{Cov}(R_1,R_2)$
        \item $\sigma_p^2 = (w_1 \sigma_1 + w_2 \sigma_2)^2$
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Dans la formule de la variance du portefeuille, que représente précisément le terme $w_1^2 \sigma_1^2$ ?
    \begin{enumerate}[label=\Alph*.]
        \item L'effet de diversification global entre les deux actifs.
        \item La rentabilité attendue et garantie du premier actif.
        \item Le risque systématique inhérent au marché financier.
        \item La contribution isolée au risque du premier actif.
    \end{enumerate}
    \textbf{Réponse correcte :} D
    \vspace{0.5cm}

    \item Quelle interprétation économique directe tire-t-on de la présence du carré ($w_1^2$) dans le calcul de la contribution au risque d'un actif ?
    \begin{enumerate}[label=\Alph*.]
        \item Le risque diminue mécaniquement à mesure que la concentration augmente.
        \item Le risque croît de manière strictement proportionnelle avec la concentration.
        \item Le risque croît plus que proportionnellement avec la concentration.
        \item La concentration d'un portefeuille n'a d'impact que sur le rendement espéré.
    \end{enumerate}
    \textbf{Réponse correcte :} C
\end{enumerate}

\subsubsection*{Pourquoi la diversification réduit le risque}

\begin{enumerate}
    \item À quelle condition mathématique la diversification permet-elle de réduire effectivement le risque d'un portefeuille ?
    \begin{enumerate}[label=\Alph*.]
        \item La corrélation entre les actifs doit être strictement supérieure à 1.
        \item La covariance doit être exactement égale au produit des variances.
        \item La corrélation entre les actifs doit être strictement inférieure à 1 ($\rho < 1$).
        \item Les actifs doivent obligatoirement avoir le même niveau de risque initial.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Que se passe-t-il concrètement si la corrélation entre deux actifs est parfaite ($\rho = 1$) ?
    \begin{enumerate}[label=\Alph*.]
        \item Le risque du portefeuille est totalement éliminé.
        \item Il n'y a aucune diversification possible, le risque n'est pas réduit.
        \item Le rendement espéré du portefeuille double automatiquement.
        \item La frontière des portefeuilles devient fortement convexe.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quel est l'effet d'une corrélation parfaitement négative ($\rho = -1$) entre deux actifs d'un portefeuille ?
    \begin{enumerate}[label=\Alph*.]
        \item Elle permet d'éliminer totalement le risque du portefeuille.
        \item Elle entraîne une perte financière certaine à l'échéance.
        \item Elle rend le calcul de la variance mathématiquement impossible.
        \item Elle multiplie le risque global par la somme des poids investis.
    \end{enumerate}
    \textbf{Réponse correcte :} A
    \vspace{0.5cm}

    \item Graphiquement, comment se traduit l'effet de la diversification lorsque la corrélation diminue ($\rho < 1$) ?
    \begin{enumerate}[label=\Alph*.]
        \item Le portefeuille se déplace le long d'une droite stricte sans aucune courbure.
        \item La frontière devient convexe, montrant que le risque peut être réduit pour un même niveau de rendement.
        \item Le graphique montre une corrélation qui tend systématiquement vers l'infini.
        \item La frontière devient concave, illustrant une augmentation systématique et incontrôlable du risque.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\subsubsection*{Lecture microéconomique profonde}

\begin{enumerate}
    \item Selon l'approche microéconomique, quel est l'avantage principal de combiner des sources d'incertitude imparfaitement corrélées ?
    \begin{enumerate}[label=\Alph*.]
        \item Cela permet d'éliminer totalement le besoin de capital.
        \item Cela permet d'améliorer l'utilité de l'agent.
        \item Cela garantit un rendement supérieur au taux sans risque.
        \item Cela simplifie la gestion comptable des actifs.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Dans ce contexte, que mesure précisément la covariance entre deux actifs ?
    \begin{enumerate}[label=\Alph*.]
        \item La rentabilité intrinsèque de chaque actif pris isolément.
        \item Le volume total des échanges sur le marché financier.
        \item La capacité des actifs à se compenser mutuellement.
        \item Le niveau de régulation imposé par les autorités de marché.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item À quel moment la réduction du risque au sein d'un portefeuille est-elle la plus significative ?
    \begin{enumerate}[label=\Alph*.]
        \item Lorsque les actifs sont parfaitement corrélés positivement.
        \item Lorsque l'investisseur choisit des actifs d'un même secteur géographique.
        \item Lorsque les actifs sont indépendants ou négativement corrélés.
        \item Lorsque la variance de chaque actif est strictement identique.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Que représente la "frontière efficiente" dans la théorie moderne du portefeuille ?
    \begin{enumerate}[label=\Alph*.]
        \item L'ensemble des portefeuilles dont le risque est maximal.
        \item L'ensemble des portefeuilles optimaux.
        \item La limite géographique des marchés financiers mondiaux.
        \item Le point où tous les actifs ont une covariance positive.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quelle est la caractéristique d'un portefeuille situé en dessous de la frontière efficiente ?
    \begin{enumerate}[label=\Alph*.]
        \item Il est considéré comme le plus sûr du marché.
        \item Il est dominé par au moins un portefeuille présentant une meilleure diversification.
        \item Il offre le rendement le plus élevé possible pour un risque donné.
        \item Il est mathématiquement impossible à constituer.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\section*{Arbitrage et discipline des marchés}

\begin{enumerate}
    \item Selon la « loi du prix unique », quelle condition doit être remplie pour que deux actifs aient le même prix aujourd'hui ?
    \begin{enumerate}[label=\Alph*.]
        \item Ils doivent appartenir au même secteur industriel.
        \item Ils doivent procurer exactement les mêmes flux futurs dans tous les états du monde.
        \item Ils doivent être échangés sur le même marché géographique.
        \item Ils doivent avoir été émis à la même date historique.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item En finance, comment définit-on une opération d'arbitrage sur un actif X ?
    \begin{enumerate}[label=\Alph*.]
        \item Acheter l'actif et le conserver à long terme en attendant une hausse des dividendes.
        \item Vendre l'actif à découvert sans intention de le racheter.
        \item Acheter l'actif là où il est moins cher et le vendre simultanément là où il est plus cher.
        \item Demander à une autorité de régulation de fixer un prix plafond pour l'actif.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quelle est la caractéristique principale du profit réalisé lors d'un arbitrage ?
    \begin{enumerate}[label=\Alph*.]
        \item C'est un profit incertain dépendant de la volatilité future.
        \item C'est un gain certain obtenu sans aucune exposition au risque.
        \item C'est un profit qui n'apparaît qu'après plusieurs années de détention.
        \item C'est un gain réservé exclusivement aux banques centrales.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quel est l'effet d'un arbitrage massif sur les prix d'un même actif coté différemment sur deux marchés ?
    \begin{enumerate}[label=\Alph*.]
        \item Les prix s'écartent davantage en raison de la spéculation.
        \item Les prix convergent jusqu'à ce que l'écart disparaisse.
        \item Le prix le plus bas chute à zéro tandis que le plus élevé s'envole.
        \item Les transactions s'arrêtent automatiquement pour protéger les investisseurs.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Au-delà du profit individuel, quel rôle fondamental l'arbitrage joue-t-il pour le marché ?
    \begin{enumerate}[label=\Alph*.]
        \item Il sert de mécanisme de discipline assurant la cohérence et l'efficience des prix.
        \item Il permet à l'État de taxer plus facilement les transactions financières.
        \item Il réduit le nombre d'investisseurs pour stabiliser la bourse.
        \item Il empêche les entreprises de lever des capitaux trop rapidement.
    \end{enumerate}
    \textbf{Réponse correcte :} A
\end{enumerate}
''',
  r'''
\section*{Risque, aversion et prime de risque}

\begin{enumerate}
    \item En microéconomie, comment définit-on précisément un individu « avers au risque » ?
    \begin{enumerate}[label=\Alph*.]
        \item Un individu qui refuse systématiquement tout investissement sur les marchés financiers.
        \item Un individu qui préfère une situation certaine à une situation incertaine ayant la même espérance mathématique.
        \item Un individu qui recherche activement la volatilité pour maximiser ses gains potentiels.
        \item Un individu qui n'investit que dans des actifs dont le rendement est strictement supérieur à 100\%.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quelle propriété de la fonction d'utilité explique mathématiquement l'aversion au risque chez un individu ?
    \begin{enumerate}[label=\Alph*.]
        \item La linéarité de la fonction, impliquant une utilité marginale constante.
        \item La convexité de la fonction, car l'utilité augmente plus vite que la richesse.
        \item La concavité de la fonction, traduisant une utilité marginale décroissante avec la richesse.
        \item L'absence totale de lien entre la richesse et l'utilité ressentie.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Comment se calcule mathématiquement la « prime de risque » d'un actif financier ?
    \begin{enumerate}[label=\Alph*.]
        \item C'est la somme du rendement espéré de l'actif risqué et du rendement sans risque ($E(R_i) + R_f$).
        \item C'est le ratio entre le risque total et le rendement sans risque.
        \item C'est la différence entre le rendement espéré de l'actif risqué et le rendement sans risque ($E(R_i) - R_f$).
        \item C'est la valeur absolue de la variance du portefeuille divisée par deux.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Que représente concrètement la prime de risque pour un investisseur ?
    \begin{enumerate}[label=\Alph*.]
        \item Une taxe imposée par le marché sur les transactions les plus volatiles.
        \item La compensation nécessaire exigée par l'investisseur pour accepter de supporter l'incertitude.
        \item Une récompense morale accordée par les entreprises aux actionnaires les plus fidèles.
        \item Le profit minimal garanti par l'État pour tout achat d'obligation.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Sur un marché en équilibre, que se passe-t-il si la prime de risque d'un actif est jugée insuffisante par les investisseurs ?
    \begin{enumerate}[label=\Alph*.]
        \item La demande augmente car l'actif devient plus accessible.
        \item Le prix de l'actif baisse, ce qui fait monter son rendement espéré jusqu'à l'équilibre.
        \item L'État intervient pour racheter l'intégralité des titres en circulation.
        \item Le risque de l'actif diminue automatiquement pour compenser le faible rendement.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\section*{Asymétrie d'information}

\begin{enumerate}
    \item Sur un marché financier, comment se définit concrètement l'asymétrie d'information ?
    \begin{enumerate}[label=\Alph*.]
        \item C'est une situation où tous les agents disposent exactement des mêmes données au même moment.
        \item C'est le fait que les autorités de régulation cachent des informations aux banques.
        \item C'est une situation où certaines parties (comme les dirigeants) détiennent des informations plus précises que d'autres (comme les investisseurs).
        \item C'est l'impossibilité mathématique de calculer le risque d'un actif futur.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Qu'est-ce que le phénomène de « sélection adverse » dans le contexte financier ?
    \begin{enumerate}[label=\Alph*.]
        \item Le processus par lequel les investisseurs choisissent uniquement les meilleurs projets.
        \item La crainte des investisseurs que les actifs proposés à la vente soient principalement de mauvaise qualité, les poussant à baisser les prix.
        \item L'obligation pour une entreprise de sélectionner ses actionnaires selon leur fortune.
        \item La décision d'un investisseur de ne choisir que des actifs sans risque.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quelle est la réaction typique des entreprises de « haute qualité » face à un marché marqué par une forte asymétrie d'information ?
    \begin{enumerate}[label=\Alph*.]
        \item Elles augmentent massivement leurs émissions d'actions pour profiter de la situation.
        \item Elles acceptent de vendre leurs titres à n'importe quel prix pour lever des fonds.
        \item Elles peuvent refuser d'émettre des actions si le prix proposé par le marché est jugé trop inférieur à leur valeur réelle.
        \item Elles cessent toute activité de production pour devenir des fonds de placement.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Comment définit-on la « décote informationnelle » sur le prix d'une action ?
    \begin{enumerate}[label=\Alph*.]
        \item C'est une taxe versée à l'État pour chaque transaction boursière.
        \item C'est l'écart entre la valeur réelle d'une entreprise et le prix plus bas que les investisseurs acceptent de payer par prudence.
        \item C'est la réduction des dividendes décidée par les dirigeants en fin d'année.
        \item C'est le profit réalisé par un arbitre lors d'une vente simultanée sur deux marchés.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quelle est la conséquence ultime de l'asymétrie d'information sur l'efficacité des marchés ?
    \begin{enumerate}[label=\Alph*.]
        \item Elle améliore l'efficacité en forçant les entreprises à être plus transparentes.
        \item Elle n'a aucun impact car les investisseurs finissent toujours par tout savoir.
        \item Elle peut empêcher le financement de bons projets car les investisseurs ne peuvent pas les distinguer des mauvais.
        \item Elle garantit que seules les entreprises les plus rentables restent cotées en bourse.
    \end{enumerate}
    \textbf{Réponse correcte :} C
\end{enumerate}

\section*{Interactions stratégiques et bulles}

\begin{enumerate}
    \item Quelle dimension stratégique, issue de la théorie des jeux, influence le choix d'un investisseur sur le marché ?
    \begin{enumerate}[label=\Alph*.]
        \item L'investisseur ignore totalement le comportement des autres pour rester rationnel.
        \item L'investisseur cherche à anticiper le comportement des autres participants avant de décider.
        \item L'investisseur se base uniquement sur les prix historiques d'il y a dix ans.
        \item Le choix est dicté par un algorithme centralisé imposé par l'État.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Comment se définit précisément une « bulle spéculative » selon le cours ?
    \begin{enumerate}[label=\Alph*.]
        \item Une période où tous les prix du marché stagnent durablement.
        \item Une situation où le prix d'un actif s'écarte durablement de sa valeur fondamentale.
        \item Une augmentation du nombre de transactions sans aucune variation de prix.
        \item Une chute brutale de la valeur de l'or par rapport aux actions.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Dans une dynamique de bulle, qu'est-ce qui alimente principalement la hausse des prix ?
    \begin{enumerate}[label=\Alph*.]
        \item Une amélioration soudaine et réelle de la qualité des produits de l'entreprise.
        \item L'augmentation massive des taux d'intérêt par les banques centrales.
        \item L'anticipation d'une revente à un prix plus élevé dans le futur.
        \item La réduction drastique des coûts de production à l'échelle mondiale.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Sur quoi repose la « valeur fondamentale » d'un actif financier ?
    \begin{enumerate}[label=\Alph*.]
        \item Uniquement sur le prix auquel le dernier acheteur a acquis l'actif.
        \item Sur les flux futurs attendus, tels que les dividendes ou les profits.
        \item Sur une décision arbitraire prise par le ministère de l'Économie.
        \item Sur la quantité physique de papier utilisé pour imprimer les titres.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Qu'est-ce qui provoque généralement « l'éclatement » d'une bulle spéculative ?
    \begin{enumerate}[label=\Alph*.]
        \item Un changement des anticipations incitant les investisseurs à vendre massivement.
        \item La décision de l'entreprise de distribuer des dividendes trop élevés.
        \item Le passage à une monnaie numérique internationale.
        \item Une stabilisation parfaite du prix de marché avec la valeur fondamentale.
    \end{enumerate}
    \textbf{Réponse correcte :} A
\end{enumerate}

\section*{Décision intertemporelle et valorisation des actifs}

\begin{enumerate}
    \item Sur quelle idée microéconomique simple repose fondamentalement la finance selon le cours ?
    \begin{enumerate}[label=\Alph*.]
        \item L'arbitrage entre le travail et le loisir.
        \item L'arbitrage entre la consommation présente et la consommation future.
        \item La maximisation de la production industrielle immédiate.
        \item La réduction systématique des taux d'intérêt par l'État.
    \end{enumerate}
    \textbf{Réponse correcte : B}
    \vspace{0.5cm}

    \item Dans la contrainte budgétaire intertemporelle $C_0 + \frac{C_1}{1+r} = Y_0 + \frac{Y_1}{1+r}$, que représente la variable $r$ ?
    \begin{enumerate}[label=\Alph*.]
        \item Le taux d'inflation annuel.
        \item Le taux de croissance du Produit Intérieur Brut.
        \item Le taux d'intérêt.
        \item Le coefficient d'aversion au risque de l'agent.
    \end{enumerate}
    \textbf{Réponse correcte : C}
    \vspace{0.5cm}

    \item Pourquoi dit-on qu'un euro reçu demain vaut moins qu'un euro reçu aujourd'hui ?
    \begin{enumerate}[label=\Alph*.]
        \item Parce que la consommation future est toujours jugée inutile par les agents.
        \item Parce que l'argent reçu aujourd'hui peut être placé et rapporter un intérêt.
        \item Parce que les revenus futurs sont systématiquement taxés à 100\%.
        \item Parce que la monnaie physique s'use avec le temps.
    \end{enumerate}
    \textbf{Réponse correcte : B}
    \vspace{0.5cm}

    \item Que signifie le terme $\frac{C_1}{1+r}$ dans l'équation de la consommation ?
    \begin{enumerate}[label=\Alph*.]
        \item Il représente la consommation future exprimée en valeur d'aujourd'hui (actualisée).
        \item Il représente l'épargne forcée imposée par le système bancaire.
        \item Il correspond au profit net réalisé après la vente d'une action.
        \item Il exprime la perte totale de pouvoir d'achat due à l'incertitude.
    \end{enumerate}
    \textbf{Réponse correcte : A}
    \vspace{0.5cm}

    \item Microéconomiquement, à quoi revient l'achat d'une action aujourd'hui ?
    \begin{enumerate}[label=\Alph*.]
        \item À augmenter sa consommation immédiate grâce à l'emprunt.
        \item À renoncer à une consommation présente pour obtenir une consommation future incertaine.
        \item À éliminer toute contrainte budgétaire pour les années à venir.
        \item À transformer un revenu futur certain en un revenu présent aléatoire.
    \end{enumerate}
    \textbf{Réponse correcte : B}
\end{enumerate}

\subsection*{Actualisation et valeur fondamentale}

\begin{enumerate}
    \item Selon le cours, à quoi correspond mathématiquement la valeur d'un actif financier aujourd'hui ($P_0$) ?
    \begin{enumerate}[label=\Alph*.]
        \item À la somme brute de tous les revenus perçus par l'entreprise par le passé.
        \item À la valeur actualisée de l'ensemble de ses flux futurs attendus.
        \item Au prix fixé par les autorités monétaires pour stabiliser l'économie.
        \item Uniquement à la valeur physique des actifs matériels de la société.
    \end{enumerate}
    \textbf{Réponse correcte : B}
    \vspace{0.5cm}

    \item Dans la formule $P_0 = \sum \frac{E(D_t)}{(1+r)^t}$, que représente précisément le terme $E(D_t)$ ?
    \begin{enumerate}[label=\Alph*.]
        \item L'épargne de précaution accumulée à la date $t$.
        \item Le taux d'endettement espéré à la période $t$.
        \item Le dividende (ou revenu) attendu par l'investisseur à la date $t$.
        \item L'erreur statistique de prévision du prix de marché.
    \end{enumerate}
    \textbf{Réponse correcte : C}
    \vspace{0.5cm}

    \item Quel est le rôle principal du facteur $(1+r)^t$ dans le calcul de la valeur d'un actif ?
    \begin{enumerate}[label=\Alph*.]
        \item Il sert à multiplier les gains futurs pour compenser l'inflation.
        \item Il permet de transformer un flux futur en sa valeur équivalente d'aujourd'hui (actualisation).
        \item Il représente le nombre total d'actions en circulation sur le marché.
        \item Il mesure la probabilité de faillite de l'entreprise émettrice.
    \end{enumerate}
    \textbf{Réponse correcte : B}
    \vspace{0.5cm}

    \item Comment la distance temporelle d'un flux financier affecte-t-elle sa valeur actuelle, selon le principe d'actualisation ?
    \begin{enumerate}[label=\Alph*.]
        \item Plus le flux est éloigné dans le temps ($t$ grand), plus sa valeur actuelle est réduite.
        \item Plus le flux est éloigné dans le temps, plus il prend de la valeur pour l'investisseur.
        \item Le temps n'a aucun impact sur la valeur actuelle d'un revenu futur.
        \item La valeur actuelle d'un flux futur devient infinie après dix ans.
    \end{enumerate}
    \textbf{Réponse correcte : A}
    \vspace{0.5cm}

    \item De quel concept microéconomique la formule de la valeur fondamentale est-elle l'application directe ?
    \begin{enumerate}[label=\Alph*.]
        \item De la loi des rendements décroissants.
        \item De la contrainte budgétaire intertemporelle.
        \item De l'équilibre de Nash en concurrence parfaite.
        \item Du principe de spécialisation de Ricardo.
    \end{enumerate}
    \textbf{Réponse correcte : B}
\end{enumerate}
''',
  r'''
\section*{Équilibre du marché des actifs et CAPM}

\begin{enumerate}
    \item Selon l'approche microéconomique, d'où proviennent les prix observés sur un marché financier ?
    \begin{enumerate}[label=\Alph*.]
        \item D'une décision unilatérale prise par les entreprises les plus puissantes.
        \item De l'agrégation de l'ensemble des comportements et décisions des agents économiques.
        \item Uniquement de la valeur comptable historique inscrite dans les bilans.
        \item D'une régulation algorithmique fixe imposée par les banques centrales.
    \end{enumerate}
    \textbf{Réponse correcte : B}
    \vspace{0.5cm}

    \item Comment définit-on l'équilibre du marché des actifs financiers ?
    \begin{enumerate}[label=\Alph*.]
        \item C'est une situation où tous les prix sont égaux à zéro.
        \item C'est une phase où l'offre d'actions est toujours supérieure à la demande.
        \item C'est une situation où les portefeuilles choisis par les investisseurs sont compatibles avec les prix observés.
        \item C'est le moment où les dividendes sont distribués de manière équitable à tous.
    \end{enumerate}
    \textbf{Réponse correcte : C}
    \vspace{0.5cm}

    \item Quel est le nom du modèle d'équilibre des actifs le plus célèbre cité dans le cours ?
    \begin{enumerate}[label=\Alph*.]
        \item Le modèle IS-LM (Investment Savings / Liquidity Money).
        \item Le modèle de croissance de Solow.
        \item Le CAPM (Capital Asset Pricing Model).
        \item La théorie des jeux à somme nulle.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quelle relation fondamentale le modèle CAPM établit-il précisément ?
    \begin{enumerate}[label=\Alph*.]
        \item La relation entre le rendement attendu d'un actif et le risque qu'il introduit dans un portefeuille diversifié.
        \item Le lien direct entre le prix de l'or et le taux de chômage.
        \item Le rapport de force entre les petits épargnants et les grands fonds de pension.
        \item La corrélation entre les profits passés et les investissements futurs en matériel.
    \end{enumerate}
    \textbf{Réponse correcte : A}
\end{enumerate}

\subsection*{Risque systématique et diversification}

\begin{enumerate}
    \item Comment appelle-t-on le type de risque qui peut être éliminé en combinant de nombreux actifs différents dans un portefeuille ?
    \begin{enumerate}[label=\Alph*.]
        \item Le risque systématique.
        \item Le risque de marché.
        \item Le risque spécifique (ou idiosyncratique).
        \item Le risque monétaire global.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quel type de risque affecte l'ensemble de l'économie (récession, crise financière) et ne peut pas être éliminé par la diversification ?
    \begin{enumerate}[label=\Alph*.]
        \item Le risque spécifique.
        \item Le risque systématique.
        \item Le risque opérationnel d'une entreprise.
        \item Le risque de mauvaise gestion individuelle.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Selon le modèle CAPM, quel type de risque est réellement rémunéré sur les marchés financiers ?
    \begin{enumerate}[label=\Alph*.]
        \item Uniquement les risques systématiques.
        \item Uniquement les risques spécifiques.
        \item La somme totale de tous les risques, quels qu'ils soient.
        \item Aucun risque n'est rémunéré, seul le capital investi compte.
    \end{enumerate}
    \textbf{Réponse correcte :} A
    \vspace{0.5cm}

    \item Dans l'équation du CAPM, que mesure précisément le coefficient Beta ($\beta_i$) ?
    \begin{enumerate}[label=\Alph*.]
        \item Le profit net réalisé par l'entreprise l'année précédente.
        \item La sensibilité de l'actif aux fluctuations du marché.
        \item Le montant total des dividendes versés aux actionnaires.
        \item Le taux d'intérêt sans risque fixé par l'État.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Que représente le terme $(E(R_m) - R_f)$ dans la relation fondamentale du modèle ?
    \begin{enumerate}[label=\Alph*.]
        \item Le rendement total espéré de l'actif individuel.
        \item Le taux d'inflation prévu pour l'année à venir.
        \item La prime de risque du marché.
        \item Le coût de transaction moyen par action.
    \end{enumerate}
    \textbf{Réponse correcte :} C
\end{enumerate}

\subsubsection*{Représentation de la droite du marché des titres}

\begin{enumerate}
    \item Comment appelle-t-on la droite qui représente graphiquement la relation entre le rendement exigé par les investisseurs et le risque systématique ($\beta$) ?
    \begin{enumerate}[label=\Alph*.]
        \item La droite d'isocoût.
        \item La droite du marché des titres (\textit{Security Market Line}).
        \item La courbe d'indifférence du risque.
        \item La frontière de production optimale.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Sur le graphique de la droite du marché des titres, que représente l'axe des abscisses (axe horizontal) ?
    \begin{enumerate}[label=\Alph*.]
        \item Le rendement espéré de l'actif.
        \item La variance totale du portefeuille.
        \item Le coefficient Beta ($\beta$), soit le risque systématique.
        \item Le temps restant avant l'échéance du titre.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item À quel niveau de rendement la droite du marché des titres coupe-t-elle l'axe des ordonnées (lorsque $\beta = 0$) ?
    \begin{enumerate}[label=\Alph*.]
        \item Au niveau du rendement espéré du marché $E(R_m)$.
        \item Au niveau de l'origine (zéro).
        \item Au niveau du taux de dividende moyen.
        \item Au niveau du taux de l'actif sans risque ($R_f$).
    \end{enumerate}
    \textbf{Réponse correcte :} D
    \vspace{0.5cm}

    \item Quelle idée microéconomique fondamentale est exprimée par la droite du marché des titres dans un marché concurrentiel ?
    \begin{enumerate}[label=\Alph*.]
        \item Seul le risque qui peut être éliminé par diversification est rémunéré.
        \item Seul le risque qui ne peut pas être éliminé par diversification (risque systématique) est rémunéré.
        \item Tous les actifs financiers doivent offrir le même rendement, quel que soit le risque.
        \item Le rendement d'un titre dépend uniquement de la qualité de la gestion interne de l'entreprise.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Que nous indique un point situé sur cette droite pour un actif $i$ donné ?
    \begin{enumerate}[label=\Alph*.]
        \item Le rendement que les investisseurs exigent pour le niveau de risque systématique de cet actif.
        \item Le prix maximal auquel l'État s'engage à racheter le titre.
        \item La probabilité que l'entreprise fasse faillite dans l'année.
        \item La part du capital que l'investisseur doit obligatoirement vendre.
    \end{enumerate}
    \textbf{Réponse correcte :} A
\end{enumerate}

\section*{Microéconomie des contrats financiers}

\subsection*{Relation principal-agent}

\begin{enumerate}
    \item Dans le cadre d'un contrat financier, qui occupe généralement le rôle de l'« agent » ?
    \begin{enumerate}[label=\Alph*.]
        \item L'investisseur ou l'actionnaire qui fournit les fonds.
        \item L'autorité de régulation des marchés financiers.
        \item Le dirigeant de l'entreprise qui prend les décisions opérationnelles.
        \item Le créancier qui prête de l'argent à taux fixe.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quel est le problème central identifié dans la relation principal-agent ?
    \begin{enumerate}[label=\Alph*.]
        \item L'impossibilité mathématique de générer des profits en période de crise.
        \item Le fait que les intérêts du dirigeant ne coïncident pas parfaitement avec ceux des investisseurs.
        \item La certitude absolue que le dirigeant agira toujours pour maximiser la valeur de l'entreprise.
        \item L'absence totale de risque lié aux projets d'investissement.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Pourquoi les investisseurs ne peuvent-ils pas simplement donner des ordres directs au dirigeant pour éviter les conflits d'intérêts ?
    \begin{enumerate}[label=\Alph*.]
        \item Parce que les investisseurs ne peuvent pas observer parfaitement l'effort ou les décisions internes du dirigeant.
        \item Parce que la loi interdit aux actionnaires de parler aux dirigeants.
        \item Parce que le profit attendu est toujours égal au profit réel.
        \item Parce que l'effort n'a aucun impact sur le résultat final de l'entreprise.
    \end{enumerate}
    \textbf{Réponse correcte :} A
    \vspace{0.5cm}

    \item Dans l'expression $\max_{contrat} E[\pi]$ sous contrainte d'incitation, que représente l'objectif des investisseurs ?
    \begin{enumerate}[label=\Alph*.]
        \item Maximiser la variance du risque spécifique de l'entreprise.
        \item Concevoir un contrat qui maximise le profit attendu tout en alignant les intérêts du dirigeant.
        \item Réduire le profit pour minimiser les impôts à payer.
        \item Garantir que le dirigeant n'ait aucun intérêt personnel dans l'entreprise.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Que signifie concrètement la « contrainte d'incitation » dans la rédaction d'un contrat ?
    \begin{enumerate}[label=\Alph*.]
        \item Elle oblige le dirigeant à travailler gratuitement en cas de perte.
        \item Elle impose un nombre fixe d'heures de travail hebdomadaires.
        \item Elle assure que le dirigeant a intérêt, selon ses propres objectifs, à adopter le comportement souhaité par le principal.
        \item Elle empêche les investisseurs de retirer leur capital avant dix ans.
    \end{enumerate}
    \textbf{Réponse correcte :} C
\end{enumerate}

\subsection*{Structure du capital}

\begin{enumerate}
    \item Que signifie concrètement le financement par actions pour un investisseur ?
    \begin{enumerate}[label=\Alph*.]
        \item Il devient créancier de l'entreprise avec un remboursement garanti.
        \item Il devient propriétaire d'une partie de l'entreprise et partage les profits futurs.
        \item Il prête de l'argent à l'État pour financer des projets publics.
        \item Il reçoit un salaire fixe indépendamment des résultats de la société.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quel est l'effet principal de la dette sur la gestion de l'entreprise par le dirigeant ?
    \begin{enumerate}[label=\Alph*.]
        \item Elle permet d'éliminer totalement le risque de faillite.
        \item Elle supprime l'obligation de générer des bénéfices.
        \item Elle crée une discipline en obligeant l'entreprise à générer des revenus pour rembourser ses engagements.
        \item Elle rend le dirigeant totalement indépendant des décisions des actionnaires.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Comment définit-on la « structure du capital » d'une entreprise ?
    \begin{enumerate}[label=\Alph*.]
        \item C'est la répartition géographique des usines de production.
        \item C'est l'organisation hiérarchique entre les ouvriers et les cadres.
        \item C'est le choix d'arbitrage entre le financement par dette et le financement par actions.
        \item C'est la somme totale des brevets déposés par l'entreprise.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Du point de vue microéconomique, quel est l'arbitrage fondamental derrière le choix de la structure du capital ?
    \begin{enumerate}[label=\Alph*.]
        \item Choisir entre le profit immédiat et la publicité à long terme.
        \item Équilibrer le partage du risque (actions) et le renforcement des incitations (dette).
        \item Arbitrer entre le recrutement de nouveaux agents et l'achat de machines.
        \item Maximiser les impôts payés pour améliorer l'image de marque.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}
''',
  r'''
\subsection*{Le carnet d’ordres et le spread}

\begin{enumerate}
    \item Sur les marchés financiers modernes, comment se définit techniquement le « carnet d'ordres » ?
    \begin{enumerate}[label=\Alph*.]
        \item Un registre historique des dividendes versés par une entreprise.
        \item L'ensemble des propositions d'achat (bid) et de vente (ask) pour un actif donné.
        \item Une liste de prix fixée chaque matin par les autorités monétaires.
        \item Un contrat d'assurance contre la faillite des banques.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Dans le mécanisme de confrontation des ordres, que représente le prix « Bid » ?
    \begin{enumerate}[label=\Alph*.]
        \item Le prix minimum qu'un vendeur accepte pour céder son titre.
        \item La commission fixe prélevée par l'intermédiaire financier.
        \item Le prix maximal qu'un acheteur est prêt à payer.
        \item La valeur comptable de l'actif inscrite au bilan.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item À quel moment précis une transaction peut-elle se réaliser sur le marché ?
    \begin{enumerate}[label=\Alph*.]
        \item Uniquement à la clôture de la bourse à 17h30.
        \item Lorsque les intentions d'achat et de vente se rencontrent.
        \item Dès qu'un ordre bid est déposé, quel que soit l'ask.
        \item Quand le spread devient strictement supérieur au prix bid.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Comment se calcule mathématiquement le « spread » sur un marché financier ?
    \begin{enumerate}[label=\Alph*.]
        \item $\text{Spread} = \text{Ask} + \text{Bid}$
        \item $\text{Spread} = \frac{\text{Ask}}{\text{Bid}}$
        \item $\text{Spread} = \text{Ask} - \text{Bid}$
        \item $\text{Spread} = \text{Bid} - \text{Ask}$
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Économiquement, quel est le rôle principal du spread selon le cours ?
    \begin{enumerate}[label=\Alph*.]
        \item Il sert uniquement à financer les taxes de l'État.
        \item Il rémunère le risque et les frictions, dont l'asymétrie d'information.
        \item Il garantit que le prix de l'actif ne variera jamais.
        \item Il permet aux acheteurs de payer moins cher que la valeur réelle.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\subsection*{Exemple simplifié d’un carnet d’ordres}

\begin{enumerate}
    \item Dans un carnet d'ordres, si le meilleur prix d'achat (Bid) est de 99 et le meilleur prix de vente (Ask) est de 101, quelle est la valeur du spread ?
    \begin{enumerate}[label=\Alph*.]
        \item 1 unité monétaire.
        \item 2 unités monétaires.
        \item 100 unités monétaires (la moyenne).
        \item 200 unités monétaires.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item D'un point de vue microéconomique, que reflète principalement le spread sur un marché financier ?
    \begin{enumerate}[label=\Alph*.]
        \item Uniquement la taxe imposée par le gouvernement sur les échanges.
        \item Le profit garanti des entreprises cotées en bourse.
        \item Divers coûts et risques, tels que les frais de transaction et l'asymétrie d'information.
        \item La valeur comptable des actifs immobiliers de la société.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Pourquoi les intermédiaires financiers ou les investisseurs exigent-ils une compensation via le spread ?
    \begin{enumerate}[label=\Alph*.]
        \item Pour le risque de détenir temporairement l'actif et le risque d'échanger avec des agents mieux informés.
        \item Pour augmenter artificiellement la volatilité du marché.
        \item Pour décourager les nouveaux acheteurs d'entrer sur le marché.
        \item Parce que la loi les oblige à maintenir un prix de vente toujours supérieur à 100.
    \end{enumerate}
    \textbf{Réponse correcte :} A
    \vspace{0.5cm}

    \item Dans un contexte d'asymétrie d'information, comment peut-on interpréter le spread ?
    \begin{enumerate}[label=\Alph*.]
        \item Comme une erreur de calcul du carnet d'ordres.
        \item Comme une forme de compensation pour l'incertitude associée aux transactions.
        \item Comme un dividende versé par anticipation aux acheteurs.
        \item Comme le signe d'un marché parfaitement transparent et sans risque.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\section*{Comportements et rationalité limitée}

\begin{enumerate}
    \item Sur quelle hypothèse fondamentale concernant le comportement des agents repose la microéconomie standard ?
    \begin{enumerate}[label=\Alph*.]
        \item L'hypothèse d'irrationalité impulsive.
        \item L'hypothèse de rationalité (utilisation de l'information pour maximiser l'utilité).
        \item L'hypothèse de comportement aléatoire dicté par le hasard.
        \item L'hypothèse d'altruisme pur envers les autres investisseurs.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Comment définit-on l'« excès de confiance » chez un investisseur financier ?
    \begin{enumerate}[label=\Alph*.]
        \item Le fait de suivre systématiquement les décisions de la majorité.
        \item La surestimation de sa propre capacité à prévoir les mouvements du marché.
        \item Le refus de croire que les prix peuvent baisser un jour.
        \item La confiance absolue dans les algorithmes de trading automatique.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Qu'est-ce que le « mimétisme » (ou comportement de troupeau) sur les marchés ?
    \begin{enumerate}[label=\Alph*.]
        \item Le fait de baser ses décisions uniquement sur une analyse personnelle approfondie.
        \item La tendance à suivre les décisions des autres plutôt qu'à suivre sa propre analyse.
        \item La vente systématique d'actifs dès que le prix dépasse la valeur fondamentale.
        \item L'achat d'actifs uniquement dans des secteurs d'activité liés à l'agriculture.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Selon le concept d'« aversion aux pertes », quelle est la réaction typique d'un investisseur ?
    \begin{enumerate}[label=\Alph*.]
        \item Il est totalement indifférent entre gagner ou perdre 100 euros.
        \item Il ressent plus fortement l'utilité d'un gain que la douleur d'une perte.
        \item Il ressent plus fortement une perte qu'un gain de même montant.
        \item Il cherche activement à perdre de l'argent pour obtenir des avantages fiscaux.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quel modèle propose de modifier la fonction d'utilité pour traiter différemment les gains et les pertes autour d'un point de référence ?
    \begin{enumerate}[label=\Alph*.]
        \item Le modèle de la main invisible.
        \item La loi des débouchés de Say.
        \item La théorie des perspectives.
        \item Le modèle de concurrence pure et parfaite.
    \end{enumerate}
    \textbf{Réponse correcte :} C
\end{enumerate}

\section*{Synthèse générale du cadre microéconomique appliqué à la finance}

\begin{enumerate}
    \item Selon la synthèse, quel mécanisme microéconomique permet initialement la formation du prix d'un actif ?
    \begin{enumerate}[label=\Alph*.]
        \item La fixation arbitraire par les instances de régulation.
        \item La rencontre entre l'offre et la demande sur le marché.
        \item Le calcul des coûts de production historiques de l'entreprise.
        \item Une décision unilatérale des actionnaires majoritaires.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item De quoi dépend la demande d'un actif de la part des investisseurs sur le marché ?
    \begin{enumerate}[label=\Alph*.]
        \item Uniquement du prestige social lié à la possession de l'actif.
        \item Des anticipations concernant les flux futurs (dividendes, gains en capital).
        \item De la quantité de monnaie physique disponible dans les banques.
        \item Du nombre de salariés employés par l'entreprise émettrice.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Pourquoi le rôle du temps et du taux d'intérêt est-il central dans l'analyse financière ?
    \begin{enumerate}[label=\Alph*.]
        \item Parce qu'il faut actualiser les flux futurs pour les comparer à des valeurs présentes.
        \item Parce que les marchés financiers ne fonctionnent que durant la journée.
        \item Parce que le taux d'intérêt remplace totalement le besoin d'offre et de demande.
        \item Parce que l'actualisation permet d'éliminer définitivement toute forme de risque.
    \end{enumerate}
    \textbf{Réponse correcte :} A
    \vspace{0.5cm}

    \item À quelle condition précise les investisseurs exigent-ils un rendement d'autant plus élevé ?
    \begin{enumerate}[label=\Alph*.]
        \item Lorsque le risque peut être totalement supprimé par diversification.
        \item Lorsque l'actif est garanti par l'État.
        \item Lorsque le risque associé à l'actif ne peut pas être éliminé par diversification.
        \item Lorsque les flux futurs sont connus avec une certitude absolue.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item En conclusion, comment peut-on définir la finance par rapport à la microéconomie ?
    \begin{enumerate}[label=\Alph*.]
        \item Comme une discipline totalement opposée aux lois de la microéconomie.
        \item Comme une application directe de la microéconomie à l'incertitude et au futur.
        \item Comme un outil purement comptable sans lien avec les comportements humains.
        \item Comme une branche de la géopolitique appliquée aux banques.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}
''',
  r'''
\section*{Étude mathématique avancée : de l'optimisation individuelle au prix des actifs}

\subsection*{Préférences, utilité espérée et aversion au risque}

\begin{enumerate}
    \item Dans un cadre microéconomique standard appliqué à la finance, quel est l'objectif principal d'un investisseur face à l'incertitude ?
    \begin{enumerate}[label=\Alph*.]
        \item Maximiser sa richesse finale brute sans considérer le risque.
        \item Minimiser systématiquement la variance de ses rendements.
        \item Maximiser son utilité espérée, notée $\mathbb{E}[u(W)]$.
        \item Éliminer toute forme de variable aléatoire de son portefeuille.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quelle propriété mathématique de la fonction d'utilité $u(W)$ caractérise l'aversion au risque d'un agent ?
    \begin{enumerate}[label=\Alph*.]
        \item La convexité de la fonction ($u'' > 0$).
        \item La concavité de la fonction ($u'' < 0$).
        \item La linéarité parfaite de la fonction ($u'' = 0$).
        \item La décroissance de la fonction ($u' < 0$).
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Comment interprète-t-on économiquement la concavité de la fonction d'utilité dans le cadre de l'aversion au risque ?
    \begin{enumerate}[label=\Alph*.]
        \item Gagner 100 euros procure plus de plaisir que perdre 100 euros n'en coûte.
        \item L'investisseur est indifférent entre un gain certain et un pari risqué.
        \item Perdre 100 euros "fait plus mal" que gagner 100 euros ne "fait plaisir".
        \item L'utilité marginale de la richesse est croissante.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quelle est l'expression de l'indice d'aversion \textbf{absolue} au risque d'Arrow-Pratt, noté $A(W)$ ?
    \begin{enumerate}[label=\Alph*.]
        \item $A(W) = \frac{u'(W)}{u''(W)}$
        \item $A(W) = -\frac{u''(W)}{u'(W)}$
        \item $A(W) = -W \frac{u''(W)}{u'(W)}$
        \item $A(W) = u''(W) \cdot u'(W)$
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quel rôle jouent les mesures d'aversion au risque ($A(W)$ et $R(W)$) dans l'équilibre des marchés financiers ?
    \begin{enumerate}[label=\Alph*.]
        \item Elles servent uniquement à calculer les taxes sur les dividendes.
        \item Elles déterminent la quantité de risque acceptée par l'agent, influençant ainsi la demande d'actifs et les prix d'équilibre.
        \item Elles permettent de prédire avec certitude les krachs boursiers.
        \item Elles remplacent totalement le besoin de modèles mathématiques pour fixer les prix.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\subsection*{Choix de portefeuille : formulation générale et condition marginale}

\begin{enumerate}
    \item Dans la formulation générale du portefeuille à $n$ actifs risqués, quelle condition mathématique doit être respectée par les poids d'investissement ($w_i$ et $w_f$) ?
    \begin{enumerate}[label=\Alph*.]
        \item La somme des poids doit être égale à zéro pour équilibrer le marché.
        \item La somme des poids doit être égale au taux sans risque $R_f$.
        \item La somme des poids doit être strictement supérieure à 1 pour inclure l'effet de levier.
        \item La somme des poids doit être égale à 1 ($w_f + \sum w_i = 1$).
    \end{enumerate}
    \textbf{Réponse correcte :} D
    \vspace{0.5cm}

    \item Quel est l'objectif mathématique de l'investisseur lors de la construction de son portefeuille de richesse finale $W_1$ ?
    \begin{enumerate}[label=\Alph*.]
        \item Maximiser l'espérance de son utilité, notée $\mathbb{E}[u(W_1)]$.
        \item Minimiser la valeur de sa richesse initiale $W_0$.
        \item Maximiser uniquement la somme brute des rendements $R_i$.
        \item Égaliser les poids $w_i$ pour tous les actifs risqués.
    \end{enumerate}
    \textbf{Réponse correcte :} A
    \vspace{0.5cm}

    \item À l'optimum, selon la condition marginale (ou condition "au bord"), que se passe-t-il si l'on déplace une unité de richesse d'un actif vers un autre ?
    \begin{enumerate}[label=\Alph*.]
        \item L'utilité espérée augmente de façon exponentielle.
        \item On n'améliore plus l'utilité espérée de l'agent.
        \item Le risque total du portefeuille tombe immédiatement à zéro.
        \item La richesse finale $W_1$ devient indépendante du taux sans risque.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quelle équation fondamentale définit l'optimum du portefeuille dans un cadre différentiable pour chaque actif $i$ ?
    \begin{enumerate}[label=\Alph*.]
        \item $\mathbb{E}[R_i - R_f] = 1$
        \item $\mathbb{E}[u'(W_1) \cdot (R_i - R_f)] = 0$
        \item $u(W_1) = R_i + R_f$
        \item $\sum w_i = R_f$
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Selon l'interprétation économique de la finance moderne, qu'est-ce qui est réellement rémunéré sur les marchés ?
    \begin{enumerate}[label=\Alph*.]
        \item Le rendement pur d'un actif, indépendamment du reste de l'économie.
        \item La quantité totale d'actions achetées par un investisseur.
        \item La contribution du rendement de l'actif au bien-être dans les différents états du monde.
        \item L'ancienneté de l'investisseur sur le marché financier.
    \end{enumerate}
    \textbf{Réponse correcte :} C
\end{enumerate}

\subsection*{Le noyau stochastique (SDF) et le principe du pricing}

\begin{enumerate}
    \item Comment définit-on économiquement le facteur d'actualisation stochastique (SDF), noté $M$ ?
    \begin{enumerate}[label=\Alph*.]
        \item C'est un taux d'intérêt fixe utilisé pour tous les types d'actifs.
        \item C'est un facteur qui pondère les revenus futurs en fonction de l'utilité marginale dans chaque état du monde.
        \item C'est une mesure de l'inflation attendue au cours de la période.
        \item C'est le montant total de la richesse détenue par le principal à la date 0.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Dans quel type de situation (ou "état du monde") le noyau stochastique $M$ prend-il une valeur élevée ?
    \begin{enumerate}[label=\Alph*.]
        \item Dans les états favorables où la richesse est abondante.
        \item Lorsque le taux sans risque $R_f$ tend vers l'infini.
        \item Dans les états "difficiles" où l'utilité marginale $u'(W_1)$ est élevée.
        \item Uniquement lorsque les dividendes versés sont égaux à zéro.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quelle est la relation mathématique fondamentale permettant de calculer le prix d'un actif aujourd'hui ($P_0$) avec le SDF ?
    \begin{enumerate}[label=\Alph*.]
        \item $P_0 = \mathbb{E}[X_1] + \mathbb{E}[M]$
        \item $P_0 = \frac{\mathbb{E}[X_1]}{1+M}$
        \item $P_0 = \mathbb{E}[M X_1]$
        \item $P_0 = \mathbb{E}[M] \cdot \mathbb{E}[X_1]$
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Selon le principe du pricing, pourquoi un euro reçu dans un "mauvais état" (état difficile) a-t-il plus de valeur qu'un euro reçu dans un "bon état" ?
    \begin{enumerate}[label=\Alph*.]
        \item Parce que les taxes sont plus faibles dans les états difficiles.
        \item Parce que la rareté marginale de la consommation augmente sa valeur (l'utilité marginale est plus grande).
        \item Parce que le taux sans risque devient automatiquement négatif.
        \item Parce que les investisseurs deviennent moins averses au risque durant les crises.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Que signifie le fait que le prix d'un actif est une "espérance pondérée" ?
    \begin{enumerate}[label=\Alph*.]
        \item Que le prix est une simple moyenne arithmétique de tous les prix passés.
        \item Que chaque flux futur est pondéré par sa probabilité d'occurrence uniquement.
        \item Que la pondération dépend de la rareté marginale (microéconomie) dans chaque état du monde via le SDF.
        \item Que le poids de chaque actif dans le portefeuille doit être égal au risque systématique.
    \end{enumerate}
    \textbf{Réponse correcte :} C
\end{enumerate}
''',
  r'''
\section*{Équilibre général à la Arrow--Debreu : la microéconomie au cœur de la finance}

\subsection*{Pourquoi l'équilibre général est la bonne "langue" de la finance}

\begin{enumerate}
    \item Au-delà de l'offre et de la demande sur un marché isolé, que cherche à comprendre la microéconomie dans le cadre de l'équilibre général ?
    \begin{enumerate}[label=\Alph*.]
        \item La régulation des prix par une autorité centrale.
        \item Comment tous les marchés s'articulent simultanément.
        \item L'histoire de la monnaie dans les sociétés anciennes.
        \item La réduction des coûts de production matérielle.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Dans le cadre de l'équilibre général, quelle est la définition microéconomique d'un actif financier ?
    \begin{enumerate}[label=\Alph*.]
        \item Un stock de métaux précieux conservé en banque.
        \item Un bien de consommation immédiat et certain.
        \item Une promesse conditionnelle à l'état du monde futur.
        \item Un contrat de travail à durée indéterminée.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Que formalise précisément le modèle Arrow--Debreu concernant la nature des biens échangés ?
    \begin{enumerate}[label=\Alph*.]
        \item L'interdiction de vendre des biens dont le prix est incertain.
        \item La possibilité de vendre des biens "contingents".
        \item L'obligation pour chaque individu de ne posséder qu'un seul type d'actif.
        \item La suppression totale des marchés futurs pour stabiliser l'économie.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Comment se définit un « bien contingent » dans la théorie d'Arrow--Debreu ?
    \begin{enumerate}[label=\Alph*.]
        \item Une unité de consommation livrée seulement si un certain état du monde se réalise.
        \item Un produit dont la qualité diminue avec le temps.
        \item Un actif financier dont le rendement est garanti par l'État quel que soit l'avenir.
        \item Un bien physique qui ne peut être échangé que contre de l'or.
    \end{enumerate}
    \textbf{Réponse correcte :} A
\end{enumerate}

\subsection*{Biens contingents et prix d'état}

\begin{enumerate}
    \item Comment définit-on précisément un « titre Arrow--Debreu » (ou \textit{state-contingent claim}) ?
    \begin{enumerate}[label=\Alph*.]
        \item Un titre qui garantit le paiement d'un dividende fixe chaque année.
        \item Un titre qui paye 1 unité de consommation dans un état $s$ précis et 0 dans tous les autres.
        \item Un contrat d'assurance couvrant l'intégralité des pertes de marché.
        \item Une obligation d'État dont le prix est indexé sur l'inflation.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Que désigne le terme $\pi_s$ dans le modèle d'équilibre général financier ?
    \begin{enumerate}[label=\Alph*.]
        \item Le taux d'intérêt moyen du marché mondial.
        \item La probabilité objective que l'entreprise fasse faillite.
        \item Le prix d'état, soit le prix aujourd'hui d'un titre payant 1 dans l'état $s$.
        \item Le montant total des impôts prélevés sur les plus-values.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quelles sont les deux dimensions agrégées par les prix d'état selon le cours ?
    \begin{enumerate}[label=\Alph*.]
        \item Le prix de l'or et le prix du pétrole.
        \item La probabilité de l'état et la valeur marginale de la consommation dans cet état.
        \item L'offre de monnaie et la demande de crédit bancaire.
        \item Le rendement passé et la volatilité historique de l'actif.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Pourquoi un état qualifié de « rare et douloureux » (faible richesse globale) se paye-t-il très cher en prix d'état ?
    \begin{enumerate}[label=\Alph*.]
        \item Parce que les investisseurs sont irrationnels durant les crises.
        \item Parce que la valeur marginale de la consommation y est très élevée.
        \item Parce que l'État impose une taxe sur la rareté des biens.
        \item Parce que ces états n'arrivent jamais en réalité.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\subsubsection*{Schéma : espace des états et biens contingents}

\begin{enumerate}
    \item Sur un graphique représentant l'espace des états pour des biens contingents, que représentent généralement les axes horizontal et vertical ?
    \begin{enumerate}[label=\Alph*.]
        \item Le prix de l'actif aujourd'hui et son prix demain.
        \item Les consommations futures dans deux états du monde différents (ex: État 1 et État 2).
        \item Le taux d'intérêt et le taux d'inflation.
        \item La quantité d'actions et la quantité d'obligations détenues.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Comment se lit l'analyse graphique du choix de biens contingents par rapport à la microéconomie traditionnelle ?
    \begin{enumerate}[label=\Alph*.]
        \item Comme un problème de production industrielle à court terme.
        \item Comme un problème standard de consommateur arbitrant entre deux biens.
        \item Comme une étude historique de la psychologie des foules.
        \item Comme un modèle de croissance macroéconomique nationale.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Que représente la droite reliant les deux axes dans le schéma de l'espace des états ?
    \begin{enumerate}[label=\Alph*.]
        \item La courbe d'utilité marginale croissante.
        \item La frontière budgétaire (ou contrainte budgétaire).
        \item L'évolution du prix de l'or sur dix ans.
        \item La limite de solvabilité de la banque centrale.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item À quoi correspond le point d'équilibre identifié sur le schéma par l'intersection des pointillés issus des axes ?
    \begin{enumerate}[label=\Alph*.]
        \item Au risque maximal que l'agent peut supporter.
        \item Au choix optimal de consommation dans les différents états.
        \item Au point où l'investisseur décide de quitter le marché.
        \item À la valeur fondamentale de l'entreprise en cas de faillite.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\subsection*{Répliquer un actif avec Arrow--Debreu}

\begin{enumerate}
    \item Quelle est la formule permettant de calculer la valeur d'un actif $P_0$ versant des flux $X(s)$ dans le cadre Arrow--Debreu ?
    \begin{enumerate}[label=\Alph*.]
        \item $P_0 = \sum_{s=1}^S \frac{\pi_s}{X(s)}$
        \item $P_0 = \sum_{s=1}^S \pi_s X(s)$
        \item $P_0 = \frac{\mathbb{E}[X(s)]}{1+r}$
        \item $P_0 = \prod_{s=1}^S \pi_s X(s)$
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Dans ce modèle, pour quelle raison une unité livrée dans un état du monde spécifique coûte-t-elle plus cher ?
    \begin{enumerate}[label=\Alph*.]
        \item Parce que l'état est très fréquent et la consommation y est abondante.
        \item Parce que l'État impose une taxe sur les profits réalisés dans cet état.
        \item Parce que cet état est rare et/ou que la consommation y est particulièrement précieuse.
        \item Parce que les flux $X(s)$ sont négatifs dans cet état.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quel principe microéconomique devient le « principe organisateur » de la cohérence des prix dans ce cadre ?
    \begin{enumerate}[label=\Alph*.]
        \item La loi de l'offre et de la demande brute.
        \item L'absence d'opportunité d'arbitrage.
        \item La maximisation de la production industrielle.
        \item La régulation des taux d'intérêt par les banques.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Si un portefeuille présente un payoff nul dans absolument tous les états du monde, quel doit être son prix selon le principe de cohérence ?
    \begin{enumerate}[label=\Alph*.]
        \item Son prix doit être égal au taux sans risque $R_f$.
        \item Son prix doit être strictement positif pour couvrir les frais de gestion.
        \item Son prix doit être nul.
        \item Son prix dépend uniquement de la probabilité de l'état le plus probable.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item À quelle autre relation fondamentale de la théorie des prix d'actifs la formule $P_0 = \sum \pi_s X(s)$ est-elle équivalente ?
    \begin{enumerate}[label=\Alph*.]
        \item À l'équation de la variance du portefeuille.
        \item À la relation utilisant le noyau stochastique $P_0 = \mathbb{E}[MX_1]$.
        \item À la contrainte budgétaire d'un consommateur en temps de crise.
        \item Au calcul du Beta ($\beta$) dans le modèle CAPM.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}
''',
  r'''
\section*{Approfondissement : CAPM, interprétation microéconomique et dérivation}

\subsection*{De l'optimum individuel à la rémunération du risque}

\begin{enumerate}
    \item Selon l'interprétation précise du CAPM, quel type de risque est réellement rémunéré sur les marchés financiers ?
    \begin{enumerate}[label=\Alph*.]
        \item Tous les risques pris par un investisseur, sans exception.
        \item Uniquement le risque qui co-varie avec la richesse agrégée (le marché).
        \item Le risque spécifique lié à la gestion interne d'une seule entreprise.
        \item Le risque de perte totale du capital investi initialement.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Pourquoi un actif qui rapporte beaucoup quand « tout le monde va bien » est-il considéré comme aidant peu l'investisseur ?
    \begin{enumerate}[label=\Alph*.]
        \item Parce que les taxes sur les profits sont plus élevées en période de croissance.
        \item Parce que son utilité marginale est faible au moment où la richesse est déjà abondante.
        \item Parce que le taux d'intérêt sans risque augmente systématiquement dans ce cas.
        \item Parce que les entreprises cessent de verser des dividendes en période faste.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quel service particulier rend un actif financier qui protège l'investisseur lors des crises ?
    \begin{enumerate}[label=\Alph*.]
        \item Un service de spéculation à haut rendement.
        \item Un service d'assurance.
        \item Une garantie de liquidité immédiate et sans frais.
        \item Une réduction automatique de la dette de l'investisseur.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quelle peut être la caractéristique d'un actif offrant un service d'assurance lors des crises économiques ?
    \begin{enumerate}[label=\Alph*.]
        \item Il est systématiquement rejeté par les investisseurs rationnels.
        \item Il doit obligatoirement offrir le rendement le plus élevé du marché.
        \item Il peut offrir un rendement espéré plus faible tout en étant très demandé.
        \item Son prix est fixé par l'État pour éviter la spéculation.
    \end{enumerate}
    \textbf{Réponse correcte :} C
\end{enumerate}

\subsection*{Droite du marché des titres : lecture économique}

\begin{enumerate}
    \item Que mesure précisément le coefficient Beta ($\beta_i$) d'un actif financier dans le modèle du CAPM ?
    \begin{enumerate}[label=\Alph*.]
        \item La rentabilité historique moyenne de l'entreprise sur les dix dernières années.
        \item La part de risque non diversifiable, c'est-à-dire le risque qui ne peut pas être neutralisé.
        \item Le montant total des dettes contractées par l'entreprise auprès des banques.
        \item La probabilité exacte que l'actif subisse une dépréciation brutale demain.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quelle est la formule mathématique correcte du Beta ($\beta_i$) d'un actif $i$ par rapport au marché $m$ ?
    \begin{enumerate}[label=\Alph*.]
        \item $\beta_i = \frac{\mathrm{Var}(R_m)}{\mathrm{Cov}(R_i,R_m)}$
        \item $\beta_i = \mathrm{Cov}(R_i,R_m) \times \mathrm{Var}(R_m)$
        \item $\beta_i = \frac{\mathrm{Cov}(R_i,R_m)}{\mathrm{Var}(R_m)}$
        \item $\beta_i = R_f + (E(R_m) - R_f)$
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Comment interprète-t-on économiquement le concept de « risque non diversifiable » ?
    \begin{enumerate}[label=\Alph*.]
        \item C'est un risque que l'investisseur peut supprimer en achetant des actions de secteurs différents.
        \item C'est la composante du risque qui ne peut être éliminée ni par l'échange, ni par la diversification.
        \item C'est un risque lié uniquement à une erreur de gestion interne propre à une seule société.
        \item C'est le risque de perdre son capital suite à une erreur de saisie informatique.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Graphiquement, que signifie un Beta ($\beta$) élevé pour un actif financier ?
    \begin{enumerate}[label=\Alph*.]
        \item L'actif évolue de manière totalement inverse par rapport aux mouvements du marché.
        \item L'actif est considéré comme un actif sans risque et sa valeur ne change jamais.
        \item L'actif suit fortement les mouvements du marché (co-mouvement important).
        \item L'actif a une espérance de rendement obligatoirement négative.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Dans la relation $E(R_i) = R_f + \beta_i(E(R_m)-R_f)$, quel terme représente la « prime de risque du marché » ?
    \begin{enumerate}[label=\Alph*.]
        \item $R_f$
        \item $\beta_i$
        \item $E(R_i)$
        \item $E(R_m) - R_f$
    \end{enumerate}
    \textbf{Réponse correcte :} D
\end{enumerate}

\subsection*{Une dérivation intuitive (sans lourdeur excessive)}

\begin{enumerate}
    \item Quelle est l'idée de départ fondamentale pour la dérivation intuitive du CAPM à l'équilibre ?
    \begin{enumerate}[label=\Alph*.]
        \item Les investisseurs évitent systématiquement le risque de marché.
        \item À l'équilibre, les investisseurs détiennent le portefeuille de marché $m$.
        \item L'État intervient pour fixer les rendements de chaque actif $i$.
        \item Chaque investisseur choisit un actif unique pour maximiser son profit brut.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Sous quelle forme s'écrit la condition d'optimalité pour tout actif $i$ en utilisant le noyau stochastique ($M$) ?
    \begin{enumerate}[label=\Alph*.]
        \item $\mathbb{E}[M] + \mathbb{E}[R_i] = 1$
        \item $\mathbb{E}[M(1+R_i)] = 1$
        \item $M = 1 + R_i$
        \item $\mathbb{E}[M / (1+R_i)] = 1$
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Comment se comporte le noyau stochastique ($M$) par rapport au rendement du marché dans ce cadre ?
    \begin{enumerate}[label=\Alph*.]
        \item C'est une fonction croissante : $M$ augmente quand le marché monte.
        \item Il est constant et égal au taux sans risque.
        \item C'est une fonction décroissante : $M$ augmente quand le marché va mal.
        \item Il varie de manière aléatoire sans lien avec la richesse agrégée.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Pourquoi le facteur d'actualisation stochastique ($M$) monte-t-il lorsque la richesse agrégée baisse ?
    \begin{enumerate}[label=\Alph*.]
        \item Parce que l'utilité marginale des agents augmente dans les états difficiles.
        \item Parce que les entreprises décident de verser plus de dividendes.
        \item Parce que le nombre d'investisseurs sur le marché diminue.
        \item Parce que l'inflation réduit la valeur réelle de la monnaie.
    \end{enumerate}
    \textbf{Réponse correcte :} A
    \vspace{0.5cm}

    \item Quel est le message économique clé concernant la rémunération d'un actif selon cette dérivation ?
    \begin{enumerate}[label=\Alph*.]
        \item Un actif est rémunéré s'il offre une performance stable et sans risque.
        \item Un actif est rémunéré s'il rend la vie plus difficile dans les mauvais états (co-variation défavorable avec le marché).
        \item Seuls les actifs qui ne varient jamais avec le marché sont rémunérés.
        \item La rémunération dépend exclusivement de la quantité d'informations publiées.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}
''',
  r'''
\section*{Contrats, incitations et gouvernance : une microéconomie de la finance}

\subsection*{Le problème principal--agent dans l'entreprise cotée}

\begin{enumerate}
    \item Quelle est la conséquence microéconomique majeure d'un actionnariat dispersé dans une entreprise cotée ?
    \begin{enumerate}[label=\Alph*.]
        \item Le dirigeant est obligé de détenir la majorité des actions pour rester en poste.
        \item Le dirigeant ne supporte pas directement toute la conséquence de ses décisions.
        \item Les profits sont systématiquement distribués de manière égale entre tous les salariés.
        \item L'entreprise ne peut plus contracter de dette auprès des banques.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Dans la modélisation de la relation principal-agent, comment l'effort ($e$) du dirigeant est-il perçu par les deux parties ?
    \begin{enumerate}[label=\Alph*.]
        \item Il est bénéfique pour le dirigeant et coûteux pour l'entreprise.
        \item Il est neutre pour le dirigeant et n'influence pas les profits.
        \item Il est coûteux pour le dirigeant mais bénéfique pour l'entreprise.
        \item Il est imposé par une loi mathématique indépendante de la volonté du dirigeant.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quel est l'objectif mathématique des actionnaires (le principal) lors de la conception du contrat de rémunération $w(\pi)$ ?
    \begin{enumerate}[label=\Alph*.]
        \item Maximiser le salaire fixe du dirigeant indépendamment des résultats.
        \item Maximiser le profit attendu net de la rémunération du dirigeant : $\mathbb{E}[\pi - w(\pi)]$.
        \item Minimiser la valeur totale de l'entreprise pour réduire les impôts.
        \item Maximiser l'effort $e$ sans jamais verser de rémunération $w$.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Que signifie la « contrainte de participation » dans le cadre de ce contrat financier ?
    \begin{enumerate}[label=\Alph*.]
        \item Que le dirigeant doit obligatoirement acheter des actions de l'entreprise.
        \item Que le contrat doit être suffisamment attractif pour que le dirigeant accepte de le signer.
        \item Que les actionnaires doivent participer aux décisions opérationnelles quotidiennes.
        \item Que l'État doit valider chaque clause du contrat de travail.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quel est le rôle de la « contrainte d'incitation » dans la relation contractuelle ?
    \begin{enumerate}[label=\Alph*.]
        \item Forcer le dirigeant à quitter l'entreprise en cas de profit nul.
        \item Garantir que les actionnaires ne puissent pas vendre leurs titres.
        \item S'assurer que le contrat est conçu pour que le dirigeant ait intérêt à choisir l'effort souhaité par les actionnaires.
        \item Limiter le nombre de contrats que le dirigeant peut signer avec d'autres firmes.
    \end{enumerate}
    \textbf{Réponse correcte :} C
\end{enumerate}

\subsection*{Lecture financière : pourquoi stock-options, bonus, dette}

\begin{enumerate}
    \item Quel est l'effet principal des contrats indexés sur la performance (comme les stock-options) sur le comportement des dirigeants ?
    \begin{enumerate}[label=\Alph*.]
        \item Ils garantissent une stabilité absolue des prix de l'action.
        \item Ils alignent totalement les intérêts sans créer de nouveaux problèmes.
        \item Ils alignent partiellement les intérêts mais peuvent inciter à une prise de risque excessive.
        \item Ils suppriment toute incitation à la performance à long terme.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Pourquoi la dette est-elle considérée comme un outil de discipline pour le dirigeant ?
    \begin{enumerate}[label=\Alph*.]
        \item Parce qu'elle permet d'éviter de payer des impôts sur les bénéfices.
        \item Parce qu'elle impose une contrainte de paiement fixe qui réduit les comportements opportunistes.
        \item Parce qu'elle donne au dirigeant le droit de vote majoritaire au conseil d'administration.
        \item Parce qu'elle garantit que les flux de trésorerie seront toujours positifs.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quel est le risque majeur associé à l'utilisation de la dette comme mode de financement ?
    \begin{enumerate}[label=\Alph*.]
        \item Elle dilue systématiquement la propriété des actionnaires existants.
        \item Elle peut amplifier les crises en cas de choc économique défavorable.
        \item Elle empêche le dirigeant de prendre la moindre décision d'investissement.
        \item Elle annule automatiquement tous les contrats de bonus et de stock-options.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Comment la microéconomie définit-elle le choix de la « structure du capital » (dette vs actions) ?
    \begin{enumerate}[label=\Alph*.]
        \item Comme une décision aléatoire dépendant de la météo des marchés.
        \item Comme un compromis entre le partage du risque, la discipline financière et les coûts de faillite.
        \item Comme une obligation légale d'avoir toujours 50\% de dette et 50\% d'actions.
        \item Comme un moyen d'éliminer définitivement tout conflit entre le principal et l'agent.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\section*{Économie comportementale}

\subsection*{Pourquoi la rationalité parfaite est parfois insuffisante}

\begin{enumerate}
    \item Que suppose la microéconomie standard concernant le comportement des agents économiques ?
    \begin{enumerate}[label=\Alph*.]
        \item Les agents agissent de manière impulsive sans calcul préalable.
        \item Les agents optimisent correctement leurs choix en fonction de l'information disponible.
        \item Les agents cherchent uniquement à imiter le comportement de la majorité.
        \item Les agents ignorent systématiquement les notions de risque et de rendement.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Parmi les phénomènes suivants, lequel est cité par le cours comme une régularité difficile à expliquer avec l'hypothèse de rationalité parfaite ?
    \begin{enumerate}[label=\Alph*.]
        \item La stabilité constante des indices boursiers sur le long terme.
        \item L'ajustement immédiat et sans erreur des prix à leur valeur fondamentale.
        \item La sur-réaction aux nouvelles et la formation de bulles.
        \item La diversification parfaite de tous les portefeuilles individuels.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Quel comportement spécifique concernant la gestion des actifs est mentionné comme une anomalie de marché ?
    \begin{enumerate}[label=\Alph*.]
        \item La tendance à vendre systématiquement ses actions au moindre profit.
        \item La tendance à conserver les pertes trop longtemps.
        \item Le refus catégorique d'acheter des titres dont le prix est en hausse.
        \item L'incapacité totale à percevoir les dividendes versés par les entreprises.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item En quoi consiste l'approche microéconomique moderne face aux comportements s'écartant du modèle standard ?
    \begin{enumerate}[label=\Alph*.]
        \item Elle consiste à renoncer définitivement à toute forme de théorie ou de modélisation.
        \item Elle consiste à enrichir le modèle d'utilité et de décision plutôt qu'à l'abandonner.
        \item Elle impose aux agents de suivre des formations obligatoires en mathématiques financières.
        \item Elle remplace l'analyse des prix par une étude purement historique des crises.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}

\subsection*{Théorie des perspectives : aversion aux pertes}

\begin{enumerate}
    \item Comment la théorie des perspectives modélise-t-elle mathématiquement la psychologie de l'investisseur face aux résultats ?
    \begin{enumerate}[label=\Alph*.]
        \item En supprimant totalement la notion d'utilité marginale.
        \item En donnant un poids plus fort aux pertes qu'aux gains dans la fonction objectif.
        \item En supposant que les gains sont toujours préférés aux pertes de manière linéaire.
        \item En ignorant les variations de richesse autour du point de référence.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quel est l'impact de la modification de la fonction objectif (utilité) sur le marché financier selon cette théorie ?
    \begin{enumerate}[label=\Alph*.]
        \item Cela n'a aucun impact car les prix dépendent uniquement de l'offre et de la demande brute.
        \item Cela modifie les demandes individuelles, ce qui influence l'équilibre global du marché.
        \item Cela garantit que tous les actifs seront vendus à leur valeur fondamentale.
        \item Cela empêche toute forme de transaction entre les agents.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Quel comportement concret des investisseurs est expliqué par l'aversion aux pertes ?
    \begin{enumerate}[label=\Alph*.]
        \item La vente immédiate de tous les titres dès qu'une perte de 1 \% apparaît.
        \item Le refus de vendre des actifs à perte, même si cela est économiquement justifié.
        \item L'achat massif d'actions uniquement lorsque les prix baissent.
        \item La diversification systématique sur des actifs sans risque uniquement.
    \end{enumerate}
    \textbf{Réponse correcte :} B
    \vspace{0.5cm}

    \item Sur un graphique de valeur subjective, quelle forme prend la courbe dans la zone des gains ?
    \begin{enumerate}[label=\Alph*.]
        \item Elle est convexe (pente croissante).
        \item Elle est parfaitement verticale.
        \item Elle est concave (utilité marginale décroissante).
        \item Elle est absente car les gains ne sont pas pris en compte.
    \end{enumerate}
    \textbf{Réponse correcte :} C
    \vspace{0.5cm}

    \item Qu'est-ce qu'un « mur » de liquidité (ou inertie) dans le contexte de l'aversion aux pertes ?
    \begin{enumerate}[label=\Alph*.]
        \item Une règle boursière qui interdit les ventes pendant 24 heures.
        \item Un niveau de prix où l'offre est bloquée car les investisseurs refusent de vendre en dessous de leur prix d'achat.
        \item Une situation où l'argent liquide disparaît totalement des banques centrales.
        \item Le moment où tous les investisseurs achètent simultanément le même actif.
    \end{enumerate}
    \textbf{Réponse correcte :} B
\end{enumerate}
''',
];

String get _chapter3QuizLatex => _chapter3QuizLatexChunks.join('\n');
