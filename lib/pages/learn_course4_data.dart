import 'learn_course4_quiz_data.dart';

Map<String, dynamic> _lesson4(String title, String content) => {
  'lesson_title': title,
  'content': content,
};

Map<String, dynamic> _chapter4(
  String title, {
  List<Map<String, dynamic>> lessons = const [],
  List<Map<String, dynamic>> subChapters = const [],
}) => {
  'chapter_title': title,
  if (lessons.isNotEmpty) 'lessons': lessons,
  if (subChapters.isNotEmpty) 'sub_chapters': subChapters,
};

const String _figCircuitMacro = r'''\begin{figure}
\begin{tikzpicture}
\draw[] (0.5,2.3) rectangle (3.2,3.5);
\draw[] (5.0,2.3) rectangle (7.7,3.5);
\draw[] (2.3,4.6) rectangle (5.9,5.8);
\draw[] (2.4,0.2) rectangle (5.8,1.4);
\node[] at (1.85,2.9) {Ménages};
\node[] at (6.35,2.9) {Entreprises};
\node[] at (4.1,5.2) {Système financier};
\node[] at (4.1,0.8) {État};
\draw[arrow] (3.2,3.1) -- (5.0,3.1);
\draw[arrow] (5.0,2.7) -- (3.2,2.7);
\draw[arrow] (1.7,2.3) -- (3.0,1.4);
\draw[arrow] (5.7,1.4) -- (6.7,2.3);
\draw[arrow] (2.4,4.6) -- (2.0,3.5);
\draw[arrow] (5.8,4.6) -- (6.2,3.5);
\draw[arrow] (4.1,1.4) -- (4.1,4.6);
\node[] at (4.1,3.45) {crédit};
\node[] at (4.1,4.15) {épargne};
\node[] at (4.1,2.1) {dette};
\end{tikzpicture}
\caption{Circuit macroéconomique simplifié}
\end{figure}''';

const String _figPhillips = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7,0);
\draw[arrow] (0,0) -- (0,5.5);
\draw[] (1.0,4.8) -- (2.2,4.1) -- (3.3,3.4) -- (4.5,2.7) -- (6.4,1.5);
\draw[dashed] (3.8,0) -- (3.8,3.1);
\node[anchor=west] at (6.75,-0.2) {Chômage u};
\node[anchor=east] at (-0.1,5.3) {Inflation π};
\node[anchor=west] at (6.45,1.5) {Phillips};
\node[] at (3.8,-0.35) {u*};
\end{tikzpicture}
\caption{Relation inverse stylisée entre chômage et inflation}
\end{figure}''';

const String _figYieldCurve = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7,0);
\draw[arrow] (0,0) -- (0,5.5);
\draw[] (0.8,1.2) -- (2.0,1.6) -- (3.6,2.3) -- (5.0,3.0) -- (6.4,3.6);
\draw[dashed] (0.8,2.7) -- (6.4,2.7);
\draw[dashed] (0.8,4.2) -- (2.0,3.8) -- (3.6,3.1) -- (5.0,2.5) -- (6.4,2.0);
\node[anchor=west] at (6.45,3.6) {Normale};
\node[anchor=west] at (6.45,2.7) {Plate};
\node[anchor=west] at (6.45,2.0) {Inversée};
\node[anchor=west] at (6.8,-0.2) {Maturité};
\node[anchor=east] at (-0.1,5.3) {Taux};
\end{tikzpicture}
\caption{Courbe des taux et information macro condensée}
\end{figure}''';

const String _figADAS = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7,0);
\draw[arrow] (0,0) -- (0,6);
\draw[] (2.0,1.0) -- (5.8,5.1);
\draw[] (1.2,5.0) -- (2.4,4.2) -- (3.8,3.2) -- (5.0,2.3) -- (6.3,1.6);
\draw[dashed] (1.2,5.5) -- (2.4,4.7) -- (3.8,3.7) -- (5.0,2.8) -- (6.3,2.1);
\draw[dashed] (3.9,0) -- (3.9,3.2);
\draw[dashed] (4.2,0) -- (4.2,3.5);
\node[anchor=west] at (5.85,5.1) {AS};
\node[anchor=west] at (6.35,1.6) {AD0};
\node[anchor=west] at (6.35,2.1) {AD1};
\node[] at (3.9,-0.35) {Y0};
\node[] at (4.2,-0.35) {Y1};
\node[anchor=west] at (6.75,-0.2) {Production Y};
\node[anchor=east] at (-0.1,5.7) {Prix P};
\end{tikzpicture}
\caption{Hausse de la demande globale et inflation}
\end{figure}''';

const String _figISLM = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7,0);
\draw[arrow] (0,0) -- (0,6);
\draw[] (1.2,5.2) -- (6.2,1.2);
\draw[] (1.8,1.0) -- (5.8,5.4);
\draw[dashed] (0.8,0.9) -- (4.8,5.4);
\node[anchor=west] at (6.25,1.2) {IS};
\node[anchor=west] at (4.7,5.55) {LM0};
\node[anchor=west] at (5.0,5.0) {LM1};
\node[] at (3.15,3.85) {E0};
\node[] at (3.8,3.35) {E1};
\node[anchor=west] at (6.75,-0.2) {Revenu Y};
\node[anchor=east] at (-0.1,5.7) {Taux i};
\end{tikzpicture}
\caption{Assouplissement monétaire et déplacement de LM}
\end{figure}''';

const String _figForex = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7,0);
\draw[arrow] (0,0) -- (0,6);
\draw[] (1.0,1.0) -- (6.0,5.0);
\draw[] (1.0,5.0) -- (6.0,1.0);
\draw[dashed] (3.5,0) -- (3.5,3.0);
\draw[dashed] (0,3.0) -- (3.5,3.0);
\node[anchor=west] at (6.1,5.0) {Offre};
\node[anchor=west] at (6.1,1.0) {Demande};
\node[anchor=west] at (6.7,-0.2) {Quantité de devise};
\node[anchor=east] at (-0.1,5.7) {Taux S};
\end{tikzpicture}
\caption{Le change s'équilibre comme un marché}
\end{figure}''';

const String _figSpread = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7,0);
\draw[arrow] (0,0) -- (0,6);
\draw[] (1.0,1.2) -- (2.5,1.6) -- (4.0,2.6) -- (5.2,3.8) -- (6.5,5.2);
\node[anchor=west] at (6.55,5.2) {Spread};
\node[anchor=west] at (6.8,-0.2) {Risque perçu};
\node[anchor=east] at (-0.1,5.7) {Spread de taux};
\end{tikzpicture}
\caption{Plus le risque souverain perçu monte, plus le spread augmente}
\end{figure}''';

const String _figCrisisLoop = r'''\begin{figure}
\begin{tikzpicture}
\draw[] (0.5,2.4) rectangle (3.1,3.6);
\draw[] (4.5,2.4) rectangle (7.1,3.6);
\draw[] (2.5,0.3) rectangle (5.1,1.5);
\node[] at (1.8,3.0) {Baisse des prix};
\node[] at (5.8,3.0) {Contraintes de levier};
\node[] at (3.8,0.9) {Ventes forcées};
\draw[arrow] (3.1,3.0) -- (4.5,3.0);
\draw[arrow] (5.2,2.4) -- (4.2,1.5);
\draw[arrow] (2.9,1.5) -- (1.7,2.4);
\end{tikzpicture}
\caption{Boucle de rétroaction typique d'une crise}
\end{figure}''';

const String _figRegimes = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7,0);
\draw[arrow] (0,0) -- (0,6);
\draw[] (1.0,1.2) -- (2.2,2.0) -- (3.8,3.2) -- (5.0,4.2) -- (6.4,5.0);
\draw[dashed] (1.0,4.8) -- (2.2,4.0) -- (3.8,3.0) -- (5.0,2.2) -- (6.4,1.4);
\node[anchor=west] at (6.45,5.0) {Régime croissance};
\node[anchor=west] at (6.45,1.4) {Régime inflation/taux};
\node[anchor=west] at (6.9,-0.2) {Surprise macro};
\node[anchor=east] at (-0.1,5.7) {Réaction actifs risqués};
\end{tikzpicture}
\caption{Une même surprise macro peut être lue différemment selon le régime}
\end{figure}''';

const String _figMacroChain = r'''\begin{figure}
\begin{tikzpicture}
\draw[] (0.5,4.5) rectangle (4.2,5.5);
\draw[] (0.5,2.8) rectangle (4.2,3.8);
\draw[] (0.5,1.1) rectangle (4.2,2.1);
\draw[] (0.5,-0.6) rectangle (4.2,0.4);
\draw[] (5.5,2.0) rectangle (8.5,3.0);
\node[] at (2.35,5.0) {Chocs macro};
\node[] at (2.35,3.3) {Réaction des politiques};
\node[] at (2.35,1.6) {Taux, crédit, liquidité};
\node[] at (2.35,-0.1) {Prix d'actifs};
\node[] at (7.0,2.5) {Rétroactions};
\draw[arrow] (2.35,4.5) -- (2.35,3.8);
\draw[arrow] (2.35,2.8) -- (2.35,2.1);
\draw[arrow] (2.35,1.1) -- (2.35,0.4);
\draw[arrow] (4.2,-0.1) -- (5.5,2.5);
\draw[arrow] (5.5,2.5) -- (4.2,5.0);
\end{tikzpicture}
\caption{Macro, finance et boucles de rétroaction}
\end{figure}''';

final Map<String, dynamic> chapter4CourseData = {
  'course_title': 'Macroéconomie et marchés financiers',
  'author': 'Cours de Macroéconomie',
  'chapters': [
    _chapter4(
      'Pourquoi la macroéconomie est indispensable pour comprendre la finance',
      lessons: [
        _lesson4(
          'Pourquoi la macro encadre tous les marchés',
          r'''La microéconomie explique comment se forment les prix sur un marché donné. La macroéconomie explique dans quel environnement tous les marchés opèrent : croissance, inflation, chômage, taux d'intérêt, politique monétaire, politique budgétaire, change et crises.

Ces variables déterminent directement :
* le niveau des taux d'intérêt, donc l'actualisation des flux futurs ;
* les primes de risque, donc les valorisations actions et crédit ;
* les profits agrégés, donc les bénéfices des entreprises ;
* la stabilité financière, donc le risque systémique.

**Idée centrale orientée finance**
Les marchés financiers ne valorisent pas seulement des entreprises ; ils valorisent des flux futurs dans un environnement macroéconomique.''',
        ),
      ],
    ),
    _chapter4(
      'Comptabilité nationale',
      subChapters: [
        _chapter4(
          'Le langage de base de la macro',
          lessons: [
            _lesson4(
              'La grammaire des agrégats macro',
              r'''La comptabilité nationale est la grammaire de la macroéconomie. Elle décrit qui produit quoi, qui reçoit quoi et qui dépense quoi.

**Idée-clé**
En finance, c'est essentiel car les marchés réagissent aux surprises sur la croissance, l'inflation ou les déficits. Or ces surprises sont précisément mesurées via les agrégats macroéconomiques.''',
            ),
          ],
        ),
        _chapter4(
          'Le PIB : trois mesures pour une même réalité',
          lessons: [
            _lesson4(
              'Production, revenu et dépense',
              r'''Le PIB mesure la valeur de la production de biens et services finaux réalisée sur un territoire pendant une période donnée.

Le même objet peut être vu sous trois angles :
* approche production :
\[
Y = Σ \text{ valeur ajoutée } = Σ (\text{Production} - \text{Consommations intermédiaires})
\]
* approche revenu :
\[
Y = \text{Salaires} + \text{Profits} + \text{Impôts nets}
\]
* approche dépense :
\[
\boxed{Y = C + I + G + (X - M)}
\]

L'approche dépense est la plus utilisée en macro-finance, car elle relie immédiatement l'activité à des moteurs observables.

* C : consommation des ménages ;
* I : investissement, très sensible aux taux et aux anticipations ;
* G : dépenses publiques ;
* X - M : solde extérieur.''',
            ),
          ],
        ),
        _chapter4(
          'Du PIB au revenu disponible',
          lessons: [
            _lesson4(
              'Ce que les ménages peuvent vraiment dépenser',
              r'''Le PIB n'est pas exactement ce que les ménages peuvent consommer. Pour raisonner sur leur capacité de dépense, on utilise le revenu disponible :

\[
Y_d ≈ Y - T + \text{transferts}
\]

Cette relation explique pourquoi la croissance du PIB peut rester positive alors que la consommation stagne si les impôts montent ou si l'inflation réduit le pouvoir d'achat.''',
            ),
          ],
        ),
        _chapter4(
          'PIB nominal, PIB réel et déflateur',
          lessons: [
            _lesson4(
              'Distinguer quantités et prix',
              r'''Le PIB nominal augmente si les quantités produites augmentent et/ou si les prix augmentent. Pour isoler la croissance en volume, on raisonne en PIB réel.

\[
Y^{nom} = P · Y^{réel}
\]

\[
\boxed{\text{Déflateur du PIB} = \frac{Y^{nom}}{Y^{réel}}}
\]

Cette distinction est décisive en finance :
* les obligations nominales souffrent lorsque l'inflation anticipée monte ;
* les actions résistent mieux si les entreprises peuvent répercuter les hausses de prix ;
* les devises réagissent aux différentiels d'inflation et de taux.''',
            ),
          ],
        ),
        _chapter4(
          'Croissance nominale vs croissance réelle',
          lessons: [
            _lesson4(
              'Une approximation utile pour les marchés',
              r'''Une approximation très pratique est :

\[
\boxed{Δ \ln(Y^{nom}) ≈ Δ \ln(Y^{réel}) + π}
\]

Une forte croissance nominale peut donc venir d'une vraie hausse de la production ou simplement d'une inflation élevée. Les marchés cherchent précisément à séparer ces deux composantes, car leurs implications pour les taux et les profits sont très différentes.

''' +
                  _figCircuitMacro,
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Croissance économique',
      subChapters: [
        _chapter4(
          'Tendance de long terme et valorisation',
          lessons: [
            _lesson4(
              'Pourquoi la croissance structurelle compte pour les actifs',
              r'''La croissance économique est l'augmentation durable de la production réelle au cours du temps. Pour la macro-finance, elle est fondamentale car elle détermine à long terme l'évolution des revenus, des profits et donc des flux qui seront valorisés sur les marchés.

Quand les investisseurs valorisent une entreprise ou un marché actions, ils ne regardent jamais uniquement le présent : ils tentent d'anticiper la trajectoire future de l'économie.''',
            ),
          ],
        ),
        _chapter4(
          'Croissance et profits',
          lessons: [
            _lesson4(
              'Le lien entre PIB, marges et bénéfices',
              r'''À long terme, les profits agrégés et les revenus disponibles évoluent avec la capacité productive de l'économie.

Une approximation stylisée résume cette idée :

\[
Δ \ln(\text{profits}) ≈ Δ \ln(Y) + \text{effet marges}
\]

La croissance des profits dépend donc de deux blocs :
* la croissance de l'activité globale ;
* l'évolution des marges, donc de la capacité des entreprises à contrôler leurs coûts et leurs prix.''',
            ),
          ],
        ),
        _chapter4(
          'Productivité et capital',
          lessons: [
            _lesson4(
              'Une fonction de production agrégée simple',
              r'''Pour comprendre les sources profondes de la croissance, on utilise souvent une fonction de production agrégée :

\[
Y = A \, F(K,L)
\]

où A représente la productivité globale des facteurs.

La croissance peut venir :
* de l'accumulation de capital K ;
* de l'augmentation du travail L ;
* de l'amélioration de la productivité A.

La productivité joue un rôle central à long terme. C'est pourquoi les actions de croissance sont particulièrement sensibles aux anticipations de gains de productivité et aux taux d'actualisation.''',
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Cycle économique : expansions, récessions et primes de risque',
      subChapters: [
        _chapter4(
          'Output gap et cycle',
          lessons: [
            _lesson4(
              'Comparer le PIB effectif au PIB potentiel',
              r'''La macroéconomie distingue le PIB potentiel Y* et le PIB effectif Y. Pour mesurer la position cyclique de l'économie, on regarde l'output gap :

\[
\boxed{\text{Gap} = \frac{Y - Y^*}{Y^*}}
\]

* si Y < Y*, le gap est négatif : l'économie tourne sous ses capacités ;
* si Y > Y*, le gap est positif : l'économie est en surchauffe.

Ce simple écart donne des informations sur le chômage, les capacités inutilisées et les pressions inflationnistes.''',
            ),
          ],
        ),
        _chapter4(
          'Lien avec les marchés',
          lessons: [
            _lesson4(
              'Pourquoi les primes de risque sont cycliques',
              r'''Le cycle agit sur trois blocs décisifs pour les marchés :

**Bénéfices**
En expansion, les ventes et les profits progressent plus facilement.

**Risque de défaut**
En ralentissement, les entreprises fragiles refinancent plus difficilement leur dette.

**Trajectoire des taux**
Un gap négatif alimente souvent l'idée de politique monétaire plus accommodante.

Les primes de risque ne sont donc pas constantes. En période de stress macro-financier, l'incertitude et l'aversion au risque montent, ce qui réduit les valorisations des actifs risqués.''',
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Marché du travail, chômage et courbe de Phillips',
      subChapters: [
        _chapter4(
          'Chômage : notion macroéconomique',
          lessons: [
            _lesson4(
              'Le marché du travail comme indicateur cyclique',
              r'''Le chômage n'est pas seulement une statistique sociale ; c'est un indicateur central de la dynamique macroéconomique.

Quand l'activité est forte, les entreprises embauchent davantage et le chômage baisse. Quand la croissance ralentit, l'emploi se dégrade. Un marché du travail très tendu signale souvent des pressions salariales qui peuvent ensuite se transmettre aux prix.''',
            ),
          ],
        ),
        _chapter4(
          'Courbe de Phillips : intuition',
          lessons: [
            _lesson4(
              'Inflation, anticipations et chômage naturel',
              r'''La courbe de Phillips relie inflation, anticipations et situation du marché du travail :

\[
π_t ≈ π_t^e - α (u_t - u^*) + ε_t
\]

où :
* π_t est l'inflation observée ;
* π_t^e l'inflation anticipée ;
* u_t le taux de chômage observé ;
* u* le chômage d'équilibre ;
* ε_t un choc imprévu.

Si u_t < u*, le marché du travail est tendu, les salaires accélèrent et les pressions inflationnistes montent. Si u_t > u*, les pressions sur les prix s'atténuent.

''' +
                  _figPhillips +
                  r'''

**Lien avec les marchés**
Les statistiques d'emploi sont parmi les publications les plus suivies, car elles peuvent changer les anticipations de taux directeurs.''',
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Monnaie, banques et création monétaire',
      subChapters: [
        _chapter4(
          'Pourquoi la monnaie est au coeur des marchés',
          lessons: [
            _lesson4(
              'Liquidité, dépôts et crédit',
              r'''Les marchés sont des marchés de prix, mais aussi des marchés de liquidité. La monnaie remplit trois fonctions :

**Unité de compte**
Elle permet de mesurer et comparer la valeur des biens et services.

**Moyen de paiement**
Elle facilite les échanges économiques.

**Réserve de valeur**
Elle permet de conserver du pouvoir d'achat dans le temps.

Le système bancaire transforme des dépôts très liquides en crédits qui financent l'économie. Quand le crédit se développe, l'activité est soutenue. Quand il se contracte, le cycle ralentit.''',
            ),
          ],
        ),
        _chapter4(
          'Base monétaire, monnaie et multiplicateur',
          lessons: [
            _lesson4(
              'Une représentation simple de la création monétaire',
              r'''On distingue la base monétaire créée par la banque centrale et des agrégats monétaires plus larges qui incluent les dépôts.

Une relation pédagogique simple est :

\[
M = m · B
\]

où B est la base monétaire, M la monnaie au sens large et m le multiplicateur.

Dans les économies modernes, la monnaie est profondément liée au crédit bancaire. Ce n'est pas seulement un instrument de transaction ; c'est un rouage central des fluctuations macroéconomiques.''',
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Banque centrale : politique monétaire, taux directeurs et transmission',
      subChapters: [
        _chapter4(
          'Objectifs typiques',
          lessons: [
            _lesson4(
              'Stabilité des prix et stabilité financière',
              r'''Les banques centrales cherchent généralement à assurer :
* la stabilité des prix ;
* la stabilité de l'activité et du système financier.

La stabilité des prix est souvent prioritaire, car une inflation instable perturbe les décisions d'investissement, la lisibilité des prix et la confiance dans la monnaie.''',
            ),
          ],
        ),
        _chapter4(
          'Le taux directeur : prix du temps et de la liquidité',
          lessons: [
            _lesson4(
              'Le principal levier de la politique monétaire',
              r'''Le taux directeur est le taux auquel la banque centrale prête des liquidités à court terme au système bancaire.

Il influence :
* les taux courts de marché ;
* les conditions de crédit ;
* la demande globale ;
* les valorisations financières via l'actualisation des flux futurs.

Quand la banque centrale augmente ses taux, le crédit devient plus coûteux. Quand elle les baisse, le financement devient plus accessible et l'activité est soutenue.''',
            ),
          ],
        ),
        _chapter4(
          'Règle de Taylor (forme simple)',
          lessons: [
            _lesson4(
              'Une lecture stylisée des réactions de la banque centrale',
              r'''Une forme simple de la règle de Taylor est :

\[
\boxed{i_t = r^* + π_t + a(π_t - π^*) + b\left(\frac{Y_t - Y_t^*}{Y_t^*}\right)}
\]

Cette formule traduit l'intuition suivante :
* si l'inflation dépasse la cible, la banque centrale a tendance à monter les taux ;
* si l'activité est faible, elle peut au contraire les réduire.

Une grande partie de la volatilité des marchés vient précisément des surprises qui modifient la trajectoire anticipée de cette fonction de réaction.''',
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Taux d’intérêt et obligations : prix, duration, courbe des taux',
      subChapters: [
        _chapter4(
          'Prix d’une obligation',
          lessons: [
            _lesson4(
              'Actualiser coupons et principal',
              r'''Une obligation promet une série de coupons C et le remboursement du principal N à l'échéance T.

Son prix correspond à la valeur actuelle de ces flux :

\[
P = \frac{C}{(1+y)} + \frac{C}{(1+y)^2} + ... + \frac{C + N}{(1+y)^T}
\]

Quand le taux actuariel y augmente, la valeur actuelle des flux baisse. Le prix de l'obligation recule donc.''',
            ),
          ],
        ),
        _chapter4(
          'Duration : sensibilité au taux',
          lessons: [
            _lesson4(
              'Pourquoi certaines obligations bougent plus que d’autres',
              r'''La sensibilité du prix d'une obligation aux variations de taux est résumée par la duration :

\[
\frac{Δ P}{P} ≈ - D · Δ y
\]

Plus la duration D est élevée, plus l'obligation réagit fortement aux variations de taux. En pratique, les obligations longues et peu couponnées sont les plus sensibles.''',
            ),
          ],
        ),
        _chapter4(
          'Courbe des taux : information macro condensée',
          lessons: [
            _lesson4(
              'Normale, plate ou inversée',
              r'''La courbe des taux synthétise :
* les anticipations de taux courts futurs ;
* une prime de terme exigée pour détenir des obligations longues.

Une courbe normale est souvent associée à une économie en expansion. Une courbe inversée est souvent lue comme un signal de ralentissement futur.

''' +
                  _figYieldCurve,
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Demande globale et offre globale : un cadre simple pour comprendre les régimes',
      subChapters: [
        _chapter4(
          'AD-AS (version simplifiée)',
          lessons: [
            _lesson4(
              'Chocs de demande et chocs d’offre',
              r'''Le cadre AD-AS relie deux forces :
* AD, la demande globale, qui dépend notamment de
\[
Y = C + I + G + (X - M)
\]
* AS, l'offre globale, qui dépend des capacités de production et des coûts.

Un choc de demande déplace AD. Un choc d'offre déplace AS. Ce cadre permet d'identifier si une hausse des prix provient d'une économie en surchauffe ou d'un choc de coûts.''',
            ),
          ],
        ),
        _chapter4(
          'Schéma AD-AS et inflation',
          lessons: [
            _lesson4(
              'Lire un déplacement de la demande globale',
              r'''Quand AD se déplace vers la droite, la production augmente mais le niveau des prix aussi.

''' +
                  _figADAS +
                  r'''

Pour les marchés :
* un choc de demande positif soutient l'activité mais peut faire monter les anticipations de taux ;
* un choc d'offre négatif peut produire plus d'inflation et moins de croissance à la fois, ce qui est souvent plus difficile pour les actifs risqués.''',
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'IS-LM : intuition finance (taux, investissement, activité)',
      subChapters: [
        _chapter4(
          'IS : équilibre sur le marché des biens',
          lessons: [
            _lesson4(
              'Pourquoi des taux plus élevés pèsent sur l’activité',
              r'''La courbe IS rassemble les couples de revenu Y et de taux i pour lesquels le marché des biens est à l'équilibre.

L'investissement est particulièrement sensible au taux d'intérêt, car le taux représente le coût du capital. Quand i monte, certains projets deviennent moins rentables et la demande globale ralentit. La courbe IS est donc décroissante.''',
            ),
          ],
        ),
        _chapter4(
          'LM : équilibre monétaire',
          lessons: [
            _lesson4(
              'Quand plus d’activité réclame plus de liquidité',
              r'''La courbe LM décrit les couples de revenu Y et de taux i pour lesquels l'offre de monnaie est égale à la demande de monnaie.

Quand le revenu augmente, les agents ont besoin de davantage de liquidité pour effectuer leurs transactions. Si l'offre de monnaie ne change pas, le taux d'intérêt tend à monter. C'est pourquoi LM est généralement croissante.''',
            ),
          ],
        ),
        _chapter4(
          'Schéma IS-LM et choc monétaire',
          lessons: [
            _lesson4(
              'Comment un assouplissement déplace l’équilibre',
              r'''Un assouplissement monétaire déplace la courbe LM vers la droite. Le nouvel équilibre combine généralement un taux plus faible et un niveau d'activité plus élevé.

''' +
                  _figISLM +
                  r'''

**Lien marchés**
Des taux plus faibles augmentent la valeur actuelle des flux futurs et soutiennent souvent les actifs risqués. Mais un assouplissement prolongé peut aussi encourager une prise de risque excessive.''',
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Économie ouverte : taux de change, balance des paiements, flux de capitaux',
      subChapters: [
        _chapter4(
          'Taux de change et actifs',
          lessons: [
            _lesson4(
              'Compétitivité, inflation importée et performance financière',
              r'''Le taux de change influence :
* la compétitivité internationale ;
* l'inflation importée ;
* les revenus des multinationales ;
* le rendement des investisseurs internationaux.

Une variation de change affecte donc à la fois l'économie réelle et la performance des actifs financiers.''',
            ),
          ],
        ),
        _chapter4(
          'Parité non couverte des taux d’intérêt',
          lessons: [
            _lesson4(
              'Comparer rendements et change anticipé',
              r'''Une relation stylisée de parité non couverte des taux est :

\[
(1+i) ≈ (1+i^*) \frac{E[S_{t+1}]}{S_t}
\]

Les investisseurs comparent les rendements offerts dans différents pays, mais ils doivent aussi tenir compte du mouvement anticipé du taux de change. Une devise offrant des taux plus élevés peut être anticipée comme se dépréciant ensuite.''',
            ),
          ],
        ),
        _chapter4(
          'Schéma : marché des changes',
          lessons: [
            _lesson4(
              'Le change comme prix d’équilibre',
              r'''Sur le marché des changes, le taux de change se détermine par la rencontre entre offre et demande de devises.

''' +
                  _figForex +
                  r'''

La demande de devise étrangère vient par exemple des importateurs ou des investisseurs qui achètent des actifs étrangers. L'offre provient des exportateurs et des investisseurs étrangers qui achètent des actifs domestiques.''',
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Politique budgétaire : déficit, dette et effets sur les marchés',
      subChapters: [
        _chapter4(
          'Déficit et dette : définitions',
          lessons: [
            _lesson4(
              'Flux annuel contre stock accumulé',
              r'''Le déficit est un flux annuel : il apparaît lorsque les dépenses publiques dépassent les recettes sur une période.

La dette est un stock : elle correspond à l'accumulation des déficits passés.

Une relation stylisée pour la dynamique de dette est :

\[
\boxed{b_{t+1} ≈ \frac{1+r}{1+g} b_t + d_t}
\]

où b_t est le ratio dette/PIB, r le taux réel payé sur la dette, g la croissance réelle et d_t le déficit primaire.

Si g > r, le ratio dette/PIB est plus facile à stabiliser. Si r > g, la dette tend à devenir plus lourde.''',
            ),
          ],
        ),
        _chapter4(
          'Lien finance : souverain, taux et spreads',
          lessons: [
            _lesson4(
              'Pourquoi le risque souverain se reflète dans les spreads',
              r'''Les investisseurs évaluent la soutenabilité de la dette publique, le risque d'inflation, le risque de refinancement et la crédibilité des institutions.

Lorsque le risque perçu augmente, ils exigent une rémunération supplémentaire pour détenir cette dette. Cette rémunération supplémentaire est le spread souverain.

''' +
                  _figSpread,
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Stabilité financière : levier, crises et contagion',
      subChapters: [
        _chapter4(
          'Pourquoi les crises sont macro-financières',
          lessons: [
            _lesson4(
              'Quand l’intermédiation se bloque',
              r'''Une crise financière n'est pas seulement une baisse de prix. C'est souvent un dysfonctionnement du système qui transforme l'épargne en financement pour l'économie réelle.

Quand la confiance, la liquidité ou le crédit se contractent, l'investissement et la consommation ralentissent. C'est pourquoi les crises financières deviennent rapidement des crises macroéconomiques.''',
            ),
          ],
        ),
        _chapter4(
          'Levier et ventes forcées',
          lessons: [
            _lesson4(
              'Comment une baisse initiale peut s’auto-amplifier',
              r'''Le levier amplifie les gains quand les prix montent, mais il amplifie aussi les pertes quand les prix baissent.

Des investisseurs très endettés peuvent alors être forcés de vendre pour respecter des contraintes de marge ou de liquidité. Ces ventes provoquent une pression vendeuse supplémentaire, ce qui déprime encore davantage les prix.''',
            ),
          ],
        ),
        _chapter4(
          'Schéma : boucle de rétroaction',
          lessons: [
            _lesson4(
              'Une crise comme dynamique endogène',
              r'''Les crises sont souvent des dynamiques endogènes : endettement, contraintes de marge, ventes forcées et pertes se renforcent mutuellement.

''' +
                  _figCrisisLoop +
                  r'''

Lors des épisodes de stress, la volatilité augmente, les corrélations se rapprochent et les spreads de crédit s'élargissent. Les investisseurs se réfugient alors vers les actifs les plus sûrs.''',
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Macroéconomie et valorisation : taux, bénéfices, primes',
      subChapters: [
        _chapter4(
          'Deux moteurs des prix d’actifs',
          lessons: [
            _lesson4(
              'Cash-flows attendus et facteur d’actualisation',
              r'''On peut résumer la valorisation d'un actif de façon intuitive :

\[
\text{Prix} ≈ \text{anticipations de cash-flows} × \text{facteur d'actualisation}
\]

Les cash-flows dépendent de la croissance, du cycle et des marges.
Le facteur d'actualisation dépend des taux réels, de l'inflation anticipée et de la prime de risque.''',
            ),
          ],
        ),
        _chapter4(
          'Prime de risque (macro-finance)',
          lessons: [
            _lesson4(
              'Une prime qui varie avec le régime macro',
              r'''Le rendement espéré d'un actif peut être résumé par :

\[
\boxed{E[R] = R_f + \text{prime de risque}}
\]

Cette prime n'est pas constante. En période d'incertitude élevée, d'aversion au risque ou de tensions financières, elle augmente. À l'inverse, elle se compresse lorsque la confiance et la liquidité sont abondantes.''',
            ),
          ],
        ),
        _chapter4(
          'Schéma : bonnes nouvelles vs mauvaises nouvelles',
          lessons: [
            _lesson4(
              'La réaction dépend du régime macro dominant',
              r'''Une même surprise macro peut être bonne ou mauvaise selon le régime en place.

''' +
                  _figRegimes +
                  r'''

En régime croissance, une surprise positive sur l'activité soutient souvent les bénéfices et les actifs risqués.
En régime inflation/taux, la même surprise peut faire craindre une hausse des taux et donc peser sur les valorisations.''',
            ),
          ],
        ),
      ],
    ),
    _chapter4(
      'Indicateurs macro utiles pour l’investisseur',
      lessons: [
        _lesson4(
          'Quels blocs d’indicateurs suivre',
          r'''Quelques grandes familles d'indicateurs structurent la lecture macro-financière :
* activité : PIB, ventes au détail, production industrielle, PMI ;
* emploi : chômage, créations d'emplois, salaires ;
* prix : inflation totale, inflation sous-jacente, énergie ;
* conditions financières : spreads de crédit, taux réels, courbe des taux, liquidité ;
* international : balance courante, flux de capitaux, taux de change.

**Comment mettre en relief tous ces indicateurs ?**
L'analyse macro-financière consiste moins à réagir à un chiffre isolé qu'à identifier un régime : croissance forte ou ralentissement, inflation en hausse ou stabilisation, politique monétaire en durcissement ou en assouplissement, stabilité ou stress financier.''',
        ),
      ],
    ),
    _chapter4(
      'Synthèse : une grille macro-finance cohérente',
      lessons: [
        _lesson4(
          'Relier chocs macro, politiques et prix d’actifs',
          r'''Les chocs macroéconomiques modifient les perspectives de croissance et d'inflation. Les banques centrales et les gouvernements réagissent, ce qui change ensuite les conditions financières : taux, crédit et liquidité.

Ces conditions financières influencent à leur tour la valorisation des actifs financiers, en agissant sur les profits attendus et sur le taux d'actualisation.

''' +
              _figMacroChain +
              r'''

**Ainsi**
La macroéconomie donne la météo structurelle des marchés. La microéconomie explique comment les prix se forment à l'intérieur de ce contexte. La finance moderne combine les deux.''',
        ),
      ],
    ),
    _chapter4(
      'Approfondissement mathématique : inflation, taux réels et valorisation',
      subChapters: [
        _chapter4(
          'Actualisation en présence d’inflation',
          lessons: [
            _lesson4(
              'Taux nominaux, taux réels et approximation de Fisher',
              r'''Si un flux nominal X_t^{nom} est reçu à la date t, sa valeur actuelle est :

\[
PV = \frac{X_t^{nom}}{(1+i)^t}
\]

Pour raisonner en termes réels :

\[
PV^{réel} = \frac{X_t^{réel}}{(1+r)^t}
\]

Le lien entre taux nominal, taux réel et inflation anticipée est donné par l'approximation de Fisher :

\[
i ≈ r + E[π]
\]

Une hausse d'inflation anticipée tend à faire monter les taux nominaux et à réduire le prix des actifs dont les flux sont fixés en nominal.''',
            ),
          ],
        ),
        _chapter4(
          'Sensibilité des actions aux taux',
          lessons: [
            _lesson4(
              'Pourquoi les flux lointains sont les plus vulnérables',
              r'''Les actions sont elles aussi valorisées par actualisation des flux futurs attendus.

Quand ces flux sont situés loin dans le temps, leur valeur actuelle dépend fortement du taux réel. Les entreprises de croissance ont donc une duration élevée : elles sont particulièrement sensibles aux hausses de taux.

\[
\text{Plus les flux sont lointains, plus l'effet d'une hausse des taux est fort.}
\]

C'est l'une des raisons pour lesquelles les valeurs de croissance souffrent souvent davantage lorsque les taux réels montent rapidement.''',
            ),
          ],
        ),
      ],
    ),
  ],
};

final Map<String, dynamic> chapter4QuizData = buildChapter4QuizData(
  chapter4CourseData,
);
