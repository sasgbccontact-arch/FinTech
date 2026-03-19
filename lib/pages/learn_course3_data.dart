import 'learn_course3_quiz_data.dart';

Map<String, dynamic> _lesson(String title, String content) => {
  'lesson_title': title,
  'content': content,
};

Map<String, dynamic> _chapter(
  String title, {
  List<Map<String, dynamic>> lessons = const [],
  List<Map<String, dynamic>> subChapters = const [],
}) => {
  'chapter_title': title,
  if (lessons.isNotEmpty) 'lessons': lessons,
  if (subChapters.isNotEmpty) 'sub_chapters': subChapters,
};

const String _figOffreDemande = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (6.4,0);
\draw[arrow] (0,0) -- (0,5.3);
\draw[] (1,1) -- (5.2,4.1);
\draw[] (1,4.1) -- (5.1,1.3);
\draw[dashed] (1,4.7) -- (5.4,1.9);
\node[anchor=west] at (5.25,4.1) {Offre};
\node[anchor=west] at (5.15,1.3) {D0};
\node[anchor=west] at (5.45,1.9) {D1};
\node[anchor=west] at (6.0,-0.2) {Quantité};
\node[anchor=east] at (-0.1,5.1) {Prix};
\end{tikzpicture}
\caption{Hausse de la demande et nouveau prix d'équilibre}
\end{figure}''';

const String _figRisqueRendement = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (6.2,0);
\draw[arrow] (0,0) -- (0,5.3);
\draw[] (0.8,1.0) -- (5.6,4.5);
\draw[dashed] (0.8,4.4) -- (5.6,1.4);
\node[anchor=west] at (5.65,4.5) {Relation réelle};
\node[anchor=west] at (5.65,1.4) {Relation souhaitée};
\node[anchor=west] at (6.0,-0.2) {Risque};
\node[anchor=east] at (-0.1,5.1) {Rendement};
\end{tikzpicture}
\caption{Compromis rendement-risque}
\end{figure}''';

const String _figDiversification = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (6.2,0);
\draw[arrow] (0,0) -- (0,5.3);
\draw[] (0.9,1.0) -- (5.8,4.6);
\draw[dashed] (0.9,1.0) -- (2.0,2.0) -- (3.4,3.0) -- (5.8,4.6);
\draw[dashed] (0.9,1.0) -- (2.2,2.5) -- (3.7,3.6) -- (5.8,4.6);
\node[anchor=west] at (5.85,4.6) {Corrélation forte};
\node[anchor=west] at (4.4,3.2) {Diversification};
\node[anchor=west] at (4.1,4.0) {Corrélation faible};
\node[anchor=west] at (6.0,-0.2) {Risque};
\node[anchor=east] at (-0.1,5.1) {Rendement};
\end{tikzpicture}
\caption{La corrélation modifie la frontière rendement-risque}
\end{figure}''';

const String _figArbitrage = r'''\begin{figure}
\begin{tikzpicture}
\draw[] (0.5,1.0) rectangle (3.0,2.0);
\draw[] (4.4,1.0) rectangle (6.9,2.0);
\draw[arrow] (3.0,1.7) -- (4.4,1.7);
\draw[arrow] (4.4,1.3) -- (3.0,1.3);
\node[] at (1.75,1.5) {Actif X : 98€};
\node[] at (5.65,1.5) {Actif X : 102€};
\node[] at (3.7,1.95) {achat};
\node[] at (3.7,1.05) {vente};
\end{tikzpicture}
\caption{Arbitrage entre deux marchés}
\end{figure}''';

const String _figAsymetrie = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (6.1,0);
\draw[arrow] (0,0) -- (0,5.1);
\draw[] (1.0,1.0) -- (5.2,4.0);
\draw[dashed] (1.0,1.0) -- (5.2,3.0);
\draw[dashed] (5.2,3.0) -- (5.2,4.0);
\node[anchor=west] at (5.25,4.0) {Valeur réelle};
\node[anchor=west] at (5.25,3.0) {Prix offert};
\node[anchor=west] at (5.35,3.5) {Décote};
\node[anchor=west] at (5.9,-0.2) {Qualité};
\node[anchor=east] at (-0.1,4.9) {Prix};
\end{tikzpicture}
\caption{Décote liée à l'information imparfaite}
\end{figure}''';

const String _figBulle = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (6.7,0);
\draw[arrow] (0,0) -- (0,5.1);
\draw[dashed] (0.6,2.0) -- (5.8,2.5);
\draw[] (0.6,2.0) -- (2.2,2.6) -- (3.8,4.2) -- (4.8,4.7) -- (5.5,1.8);
\node[anchor=west] at (5.85,2.5) {Valeur fondamentale};
\node[anchor=west] at (4.95,4.7) {Bulle};
\node[anchor=west] at (5.55,1.8) {Éclatement};
\node[anchor=west] at (6.45,-0.2) {Temps};
\node[anchor=east] at (-0.1,4.9) {Prix};
\end{tikzpicture}
\caption{Hausse spéculative puis correction brutale}
\end{figure}''';

const String _figActualisation = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7.6,0);
\draw[] (1.2,0.1) -- (1.2,-0.1);
\draw[] (3.0,0.1) -- (3.0,-0.1);
\draw[] (4.8,0.1) -- (4.8,-0.1);
\draw[] (6.6,0.1) -- (6.6,-0.1);
\draw[arrow] (1.2,0.9) -- (0.2,0.2);
\draw[arrow] (3.0,0.9) -- (0.2,0.2);
\draw[arrow] (4.8,0.9) -- (0.2,0.2);
\draw[arrow] (6.6,0.9) -- (0.2,0.2);
\node[] at (0.15,1.0) {P0};
\node[] at (1.2,1.0) {D1};
\node[] at (3.0,1.0) {D2};
\node[] at (4.8,1.0) {D3};
\node[] at (6.6,1.0) {D4};
\node[] at (1.2,-0.35) {t1};
\node[] at (3.0,-0.35) {t2};
\node[] at (4.8,-0.35) {t3};
\node[] at (6.6,-0.35) {t4};
\node[anchor=west] at (7.25,-0.1) {Temps};
\end{tikzpicture}
\caption{Actualisation des flux futurs}
\end{figure}''';

const String _figCapm = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (6.1,0);
\draw[arrow] (0,0) -- (0,5.1);
\draw[] (0.2,1.0) -- (5.2,4.0);
\node[anchor=east] at (-0.1,1.0) {Rf};
\node[anchor=west] at (5.25,4.0) {Marché};
\node[] at (3.2,2.7) {Actif i};
\node[anchor=west] at (5.9,-0.2) {β};
\node[anchor=east] at (-0.1,4.9) {Rendement};
\end{tikzpicture}
\caption{Droite du marché des titres}
\end{figure}''';

const String _figBidAsk = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7.5,0);
\draw[] (2.0,0.15) -- (2.0,-0.15);
\draw[] (5.7,0.15) -- (5.7,-0.15);
\draw[] (2.0,0.8) -- (5.7,0.8);
\node[] at (2.0,-0.4) {Bid};
\node[] at (5.7,-0.4) {Ask};
\node[] at (3.85,1.1) {Spread};
\node[anchor=west] at (7.2,-0.1) {Prix};
\end{tikzpicture}
\caption{Le spread entre meilleur acheteur et meilleur vendeur}
\end{figure}''';

const String _figProspect = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (-3.8,0) -- (3.8,0);
\draw[arrow] (0,-3.0) -- (0,3.0);
\draw[] (0.0,0.0) -- (1.0,0.8) -- (2.0,1.4) -- (3.0,1.8);
\draw[] (0.0,0.0) -- (-1.0,-1.3) -- (-2.0,-2.1) -- (-3.0,-2.6);
\node[] at (2.4,2.3) {Gains};
\node[] at (-2.3,-2.8) {Pertes};
\node[anchor=west] at (3.4,-0.1) {Résultat};
\node[anchor=east] at (-0.1,2.8) {Valeur};
\end{tikzpicture}
\caption{Aversion aux pertes dans la théorie des perspectives}
\end{figure}''';

final Map<String, dynamic> chapter3CourseData = {
  'course_title': 'Microéconomie et marchés financiers',
  'author': 'Cours de Microéconomie',
  'chapters': [
    _chapter(
      'Pourquoi la microéconomie est essentielle pour comprendre la finance',
      lessons: [
        _lesson(
          'Microéconomie et finance : le même langage',
          r'''La finance n'est pas une discipline isolée. Elle applique directement les outils de la microéconomie à un objet particulier : l'incertitude sur l'avenir.

Quand on observe la bourse, on voit des prix qui bougent, des investisseurs qui achètent et vendent, des entreprises qui lèvent des capitaux. Derrière ces phénomènes, on retrouve toujours les mêmes mécanismes : l'offre et la demande, le choix sous contrainte, l'aversion au risque, l'asymétrie d'information et les interactions stratégiques.

Un marché financier est un marché au sens strict. Des offreurs et des demandeurs s'y rencontrent, sauf que le bien échangé n'est pas un bien de consommation : c'est un actif financier, c'est-à-dire un droit sur des flux futurs.

**Idée-clé**
Comprendre la finance revient à appliquer rigoureusement les outils microéconomiques à la décision sous incertitude.''',
        ),
      ],
    ),
    _chapter(
      'Offre, demande et formation du prix d\'une action',
      subChapters: [
        _chapter(
          'Le mécanisme d\'équilibre',
          lessons: [
            _lesson(
              'Comprendre l\'équilibre sur un marché financier',
              r'''En microéconomie, le prix d'équilibre est déterminé par l'égalité entre la quantité demandée et la quantité offerte.

\[
Qd(P*) = Qo(P*)
\]

Ce mécanisme s'applique aussi aux marchés financiers. À chaque instant, certains investisseurs veulent acheter une action, d'autres veulent la vendre. Le prix s'ajuste jusqu'à équilibrer ces intentions.

La différence essentielle avec un marché de biens ordinaires est la suivante : la demande d'une action dépend peu de son utilité immédiate. Elle dépend surtout des anticipations de profits futurs.

**Lecture économique**
Le prix boursier n'est pas seulement un prix courant, c'est déjà un jugement sur l'avenir.''',
            ),
          ],
        ),
        _chapter(
          'Anticipations et déplacement de la demande',
          lessons: [
            _lesson(
              'Pourquoi le prix réagit avant les résultats',
              r'''Si les investisseurs apprennent qu'une entreprise a développé une innovation prometteuse, ils anticipent une hausse future des bénéfices. La courbe de demande se déplace alors vers la droite et le prix monte immédiatement.

Le point pédagogique crucial est simple : le prix d'une action ne reflète pas seulement le présent, il reflète d'abord l'anticipation du futur.

''' +
                  _figOffreDemande,
            ),
          ],
        ),
      ],
    ),
    _chapter(
      'Risque, rendement et fonction d\'utilité',
      subChapters: [
        _chapter(
          'La fonction d\'utilité en finance',
          lessons: [
            _lesson(
              'De la consommation certaine à la richesse incertaine',
              r'''En microéconomie, la fonction d'utilité classe des situations selon les préférences d'un individu. Elle ne mesure pas un bonheur psychologique ; elle traduit un ordre de préférence cohérent.

Dans un cadre certain, on peut écrire :

\[
U = U(C)
\]

En finance, l'investisseur ne choisit pas une consommation certaine, mais une distribution de richesse future. On représente alors ses préférences par une fonction de rendement espéré et de risque :

\[
U = U(E(R), σ)
\]

Économiquement, cela signifie qu'un investisseur apprécie un rendement élevé mais n'apprécie pas l'incertitude qui l'accompagne.

\[
\frac{\mathrm{d}U}{\mathrm{d}E(R)} > 0
\qquad
\frac{\mathrm{d}U}{\mathrm{d}σ} < 0
\]

À rendement égal, un investisseur préfère donc moins de risque.''',
            ),
          ],
        ),
        _chapter(
          'Le compromis rendement-risque',
          lessons: [
            _lesson(
              'Pourquoi le marché impose une pente croissante',
              r'''Dans le monde réel, le rendement espéré augmente avec le risque. Cette relation n'est pas arbitraire : elle résulte d'un équilibre de marché.

Si un actif risqué offrait le même rendement qu'un actif sûr, personne ne voudrait le détenir. Son prix baisserait jusqu'à ce que son rendement attendu augmente.

À l'inverse, l'investisseur rêverait d'une relation décroissante : plus de rendement pour moins de risque. Cette situation est impossible en équilibre concurrentiel, car tous les investisseurs se rueraient immédiatement vers ces actifs dominants.

''' +
                  _figRisqueRendement,
            ),
          ],
        ),
        _chapter(
          'Interprétation microéconomique du choix optimal',
          lessons: [
            _lesson(
              'Choisir sous contrainte dans un monde incertain',
              r'''La tension entre préférences individuelles et contrainte de marché explique une grande partie de la finance moderne.

**Fonction d'utilité**
La fonction d'utilité représente les préférences de l'investisseur.

**Frontière rendement-risque**
La frontière rendement-risque représente la contrainte économique imposée par le marché.

**Choix optimal**
Le choix optimal correspond au meilleur compromis possible compte tenu de cette contrainte.

**À retenir**
L'investisseur ne choisit pas ce qu'il voudrait idéalement ; il choisit le meilleur portefeuille compatible avec la réalité du marché.''',
            ),
          ],
        ),
        _chapter(
          'La diversification : un principe microéconomique approfondi',
          lessons: [
            _lesson(
              'Pourquoi diversifier augmente l\'utilité',
              r'''La diversification n'est pas une astuce pratique : c'est une conséquence directe du comportement rationnel sous incertitude.

Quand un agent fait face à plusieurs sources d'aléa, il cherche à réduire la variabilité globale de son résultat sans sacrifier inutilement son espérance de gain. Cette logique est exactement celle du choix microéconomique sous contrainte.''',
            ),
          ],
          subChapters: [
            _chapter(
              'Construction mathématique du portefeuille',
              lessons: [
                _lesson(
                  'Portefeuille à deux actifs risqués',
                  r'''Considérons deux actifs risqués de rendements aléatoires R1 et R2. On note w1 et w2 les parts du capital investies dans chacun d'eux, avec :

\[
w1 + w2 = 1
\]

Le rendement du portefeuille est alors :

\[
Rp = w1 R1 + w2 R2
\]

L'espérance du portefeuille est une moyenne pondérée :

\[
E(Rp) = w1 E(R1) + w2 E(R2)
\]

Jusqu'ici, rien de surprenant : les rendements moyens s'additionnent proportionnellement aux poids.''',
                ),
              ],
            ),
            _chapter(
              'La variance du portefeuille',
              lessons: [
                _lesson(
                  'Le rôle central de la covariance',
                  r'''Le risque du portefeuille est mesuré par sa variance :

\[
σp^2 = Var(Rp)
\]

En utilisant les propriétés d'une combinaison linéaire, on obtient :

\[
σp^2 = w1^2 σ1^2 + w2^2 σ2^2 + 2 w1 w2 Cov(R1,R2)
\]

Le troisième terme est crucial. La covariance mesure la manière dont les rendements évoluent ensemble.

\[
Cov(R1,R2) = E[(R1 - E(R1))(R2 - E(R2))]
\]

Elle est positive si les deux actifs montent et baissent ensemble, négative s'ils évoluent en sens opposé, et proche de zéro s'ils sont presque indépendants.''',
                ),
              ],
            ),
            _chapter(
              'Pourquoi la diversification réduit le risque',
              lessons: [
                _lesson(
                  'Corrélation, réduction du risque et cas extrêmes',
                  r'''Si la corrélation est inférieure à 1, le risque du portefeuille est inférieur à celui d'une simple concentration sur un seul actif.

Les cas limites sont utiles :
* si ρ = 1, il n'y a pratiquement pas de gain de diversification ;
* si ρ < 1, une partie du risque est réduite ;
* si ρ = -1, il devient théoriquement possible d'éliminer entièrement le risque.

''' +
                      _figDiversification,
                ),
              ],
            ),
            _chapter(
              'Lecture microéconomique profonde de la diversification',
              lessons: [
                _lesson(
                  'Combiner des risques imparfaitement corrélés',
                  r'''La diversification applique un principe microéconomique général :

**Principe**
Combiner des sources d'incertitude imparfaitement corrélées permet d'améliorer l'utilité.

C'est analogue à la diversification d'un producteur qui ne dépend pas d'un seul fournisseur, ou d'un consommateur qui ne dépend pas d'un seul revenu.

La covariance devient donc la clé de lecture : elle mesure la capacité des actifs à se compenser mutuellement. Plus la corrélation baisse, plus la frontière rendement-risque devient favorable.''',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    _chapter(
      'Arbitrage et discipline des marchés',
      lessons: [
        _lesson(
          'La loi du prix unique',
          r'''La loi du prix unique affirme que deux actifs procurant exactement les mêmes flux futurs dans tous les états du monde doivent avoir le même prix aujourd'hui.

Sinon, une opportunité d'arbitrage apparaît. Un investisseur peut acheter l'actif sous-évalué et vendre simultanément l'actif surévalué, réalisant un gain certain sans risque.

Si un même actif X est coté 98€ sur un marché et 102€ sur un autre, le profit immédiat est de 4€.

''' +
              _figArbitrage +
              r'''

L'arbitrage a une conséquence fondamentale : il élimine rapidement les écarts de prix. L'achat sur le marché le moins cher fait monter le prix, la vente sur le marché le plus cher le fait baisser. Les prix convergent.

**Lecture économique**
L'arbitrage n'est pas seulement une stratégie individuelle ; c'est un mécanisme de discipline qui assure la cohérence globale des prix.''',
        ),
      ],
    ),
    _chapter(
      'Risque, aversion et prime de risque',
      lessons: [
        _lesson(
          'Pourquoi un actif risqué doit rémunérer davantage',
          r'''Un individu est avers au risque lorsqu'il préfère une situation certaine à une situation incertaine ayant pourtant la même espérance mathématique.

En finance, cela implique qu'un investisseur exige un rendement espéré supérieur pour accepter de détenir un actif risqué.

\[
\boxed{Prime de risque = E(Ri) - Rf}
\]

La prime de risque représente la compensation nécessaire pour supporter l'incertitude. Plus la variabilité des rendements est élevée, plus la prime exigée augmente.

Il ne s'agit pas d'une récompense morale. C'est le résultat d'un équilibre entre investisseurs avers au risque et entreprises qui cherchent à se financer.''',
        ),
      ],
    ),
    _chapter(
      'Asymétrie d\'information',
      lessons: [
        _lesson(
          'Sélection adverse et décote informationnelle',
          r'''Les marchés financiers sont souvent marqués par une asymétrie d'information. Les dirigeants connaissent mieux la situation réelle de leur entreprise que les investisseurs extérieurs.

Les investisseurs savent qu'ils sont moins informés. Ils intègrent donc une prudence supplémentaire dans le prix qu'ils sont prêts à payer.

Ce mécanisme peut conduire à la sélection adverse : si les investisseurs pensent que les actifs proposés sont, en moyenne, de qualité incertaine, ils paient un prix inférieur à la valeur réelle des meilleurs actifs.

Les entreprises de haute qualité peuvent alors refuser d'émettre à ce prix, ce qui réduit la présence des bons projets sur le marché.

''' +
              _figAsymetrie +
              r'''

**Conséquence**
L'asymétrie d'information réduit l'efficacité du marché, car certains bons projets peuvent ne pas être financés.''',
        ),
      ],
    ),
    _chapter(
      'Interactions stratégiques et bulles',
      lessons: [
        _lesson(
          'Quand les anticipations deviennent auto-réalisatrices',
          r'''Les choix des investisseurs sont interdépendants. Chacun observe non seulement la valeur fondamentale d'un actif, mais aussi le comportement anticipé des autres participants du marché.

Si un grand nombre d'investisseurs pensent que le prix va monter parce que d'autres vont acheter, ils achètent eux-mêmes dès maintenant. Ce comportement collectif peut faire monter effectivement le prix, indépendamment des fondamentaux.

Une bulle spéculative apparaît lorsque le prix d'un actif s'écarte durablement de sa valeur fondamentale. La hausse est alors alimentée par l'espoir de revendre plus cher plus tard.

''' +
              _figBulle +
              r'''

Ces dynamiques restent fragiles. Si les anticipations se retournent, les ventes se multiplient et l'éclatement peut être brutal.''',
        ),
      ],
    ),
    _chapter(
      'Décision intertemporelle et valorisation des actifs',
      subChapters: [
        _chapter(
          'Le choix entre présent et futur',
          lessons: [
            _lesson(
              'La contrainte budgétaire intertemporelle',
              r'''La finance repose sur une idée microéconomique simple : les individus arbitrent entre consommation présente et consommation future.

Un agent choisit C0 et C1 afin de maximiser son utilité sous la contrainte :

\[
C0 + \frac{C1}{(1+r)} = Y0 + \frac{Y1}{(1+r)}
\]

La consommation future est actualisée, car un euro reçu demain vaut moins qu'un euro disponible aujourd'hui. Acheter une action revient donc à renoncer à une consommation présente en échange d'une richesse future incertaine.''',
            ),
          ],
        ),
        _chapter(
          'Actualisation et valeur fondamentale',
          lessons: [
            _lesson(
              'La valeur présente des flux futurs',
              r'''La valeur d'un actif correspond à la valeur actualisée de ses flux futurs attendus. Dans un cadre simple, on peut écrire :

\[
P0 = \frac{E(D1)}{(1+r)} + \frac{E(D2)}{(1+r)^2} + \frac{E(D3)}{(1+r)^3} + ...
\]

Chaque dividende attendu est ramené à sa valeur d'aujourd'hui. Plus le flux est éloigné dans le temps, plus sa valeur actuelle est faible.

''' +
                  _figActualisation +
                  r'''

**Lecture économique**
Le prix d'un actif est la somme actualisée des revenus futurs qu'il est susceptible de générer.''',
            ),
          ],
        ),
      ],
    ),
    _chapter(
      'Équilibre du marché des actifs et CAPM',
      subChapters: [
        _chapter(
          'Du comportement individuel à l\'équilibre général',
          lessons: [
            _lesson(
              'Comment les prix émergent des choix agrégés',
              r'''Les prix observés sur les marchés ne résultent pas d'une seule décision. Ils proviennent de l'agrégation des comportements de l'ensemble des investisseurs.

Chaque agent choisit un portefeuille en fonction de ses préférences et des prix observés. L'équilibre du marché correspond à une situation où tous ces choix sont compatibles entre eux.''',
            ),
          ],
        ),
        _chapter(
          'Risque systématique et diversification',
          lessons: [
            _lesson(
              'Pourquoi seul le risque non diversifiable est rémunéré',
              r'''La diversification élimine une grande partie du risque spécifique à une entreprise. En revanche, les chocs qui touchent l'ensemble de l'économie ne peuvent pas être éliminés.

Le CAPM affirme que seul ce risque systématique est rémunéré :

\[
E(Ri) = Rf + βi (E(Rm) - Rf)
\]

Ici, βi mesure la sensibilité de l'actif i aux fluctuations du marché.

Le message microéconomique est fort : dans un monde où les investisseurs diversifient, seul le risque qui ne peut pas être neutralisé par l'échange reçoit une rémunération.''',
            ),
          ],
        ),
        _chapter(
          'Lecture visuelle de la droite du marché des titres',
          lessons: [
            _lesson(
              'Lire la Security Market Line',
              r'''La droite du marché des titres relie rendement espéré et risque systématique.

''' +
                  _figCapm +
                  r'''

Un actif avec un β élevé réagit fortement aux variations du marché. Un actif avec un β plus faible contribue moins au risque agrégé et exige donc une rémunération moindre.''',
            ),
          ],
        ),
      ],
    ),
    _chapter(
      'Microéconomie des contrats financiers',
      subChapters: [
        _chapter(
          'Relation principal-agent',
          lessons: [
            _lesson(
              'Le contrat comme outil d\'incitation',
              r'''Lorsqu'un investisseur finance une entreprise, une relation contractuelle s'établit entre un principal et un agent.

Le principal fournit les ressources et souhaite maximiser la valeur de l'entreprise.
L'agent prend les décisions quotidiennes mais ses intérêts peuvent diverger de ceux des actionnaires.

Le problème économique consiste à concevoir un contrat qui aligne les incitations :

\[
max\_{contrat} \ E(π) \quad \text{sous contrainte d'incitation}
\]

L'idée de fond est simple : le contrat doit pousser le dirigeant à choisir les actions souhaitées par les investisseurs.''',
            ),
          ],
        ),
        _chapter(
          'Structure du capital',
          lessons: [
            _lesson(
              'Dette ou actions : un arbitrage microéconomique',
              r'''Une entreprise peut se financer par actions ou par dette.

**Financement par actions**
Le financement par actions partage le risque avec les investisseurs.

**Financement par dette**
La dette impose des paiements fixes et introduit une discipline plus forte.

La structure du capital résulte donc d'un arbitrage entre partage du risque, incitations managériales et coûts de difficulté financière.

**À retenir**
La finance d'entreprise prolonge directement la microéconomie des contrats et des incitations.''',
            ),
          ],
        ),
      ],
    ),
    _chapter(
      'Microstructure des marchés financiers',
      subChapters: [
        _chapter(
          'Le carnet d\'ordres et le spread',
          lessons: [
            _lesson(
              'Bid, ask et coût de transaction',
              r'''Sur les marchés modernes, le prix d'un actif résulte de la confrontation directe entre ordres d'achat et ordres de vente.

Le meilleur prix d'achat est le bid. Le meilleur prix de vente est l'ask. Leur différence s'appelle le spread :

\[
Spread = Ask - Bid
\]

Le spread rémunère plusieurs éléments : le risque de détenir l'actif, les coûts de transaction et le risque d'échanger avec des agents mieux informés.

''' +
                  _figBidAsk,
            ),
          ],
        ),
        _chapter(
          'Exemple simplifié d\'un carnet d\'ordres',
          lessons: [
            _lesson(
              'Lire un mini carnet d\'ordres',
              r'''Imaginons les ordres suivants :
* ordre d'achat à 99 ;
* ordre d'achat à 98 ;
* ordre de vente à 101 ;
* ordre de vente à 102.

Le meilleur bid vaut 99 et le meilleur ask vaut 101. Le spread est donc égal à 2.

Microéconomiquement, ce petit écart représente le prix des frictions du marché : liquidité imparfaite, coût de tenue de position et asymétrie d'information.''',
            ),
          ],
        ),
      ],
    ),
    _chapter(
      'Comportements et rationalité limitée',
      lessons: [
        _lesson(
          'Quand la rationalité parfaite devient insuffisante',
          r'''La microéconomie standard suppose des agents rationnels. Pourtant, les marchés financiers révèlent régulièrement des écarts à cette hypothèse.

Les investisseurs peuvent être affectés par :
* l'excès de confiance ;
* le mimétisme ;
* l'aversion aux pertes ;
* la sur-réaction à certaines nouvelles.

Ces comportements n'annulent pas la logique microéconomique. Ils conduisent plutôt à enrichir la fonction d'utilité et à mieux comprendre certains écarts entre modèle théorique et marchés réels.''',
        ),
      ],
    ),
    _chapter(
      'Synthèse générale du cadre microéconomique appliqué à la finance',
      lessons: [
        _lesson(
          'Relier tous les mécanismes ensemble',
          r'''Le prix d'un actif se forme par la rencontre entre offre et demande. Cette demande dépend des anticipations sur les flux futurs, eux-mêmes actualisés pour être comparés au présent.

Les investisseurs exigent un rendement d'autant plus élevé que le risque non diversifiable est important. Les contrats financiers introduisent des problèmes d'incitation, tandis que l'information imparfaite et les interactions stratégiques compliquent encore le fonctionnement des marchés.

**Synthèse**
La finance peut être lue comme une application directe de la microéconomie à un environnement dominé par le temps, l'incertitude et l'information imparfaite.''',
        ),
      ],
    ),
    _chapter(
      'Étude mathématique avancée : de l\'optimisation individuelle au prix des actifs',
      subChapters: [
        _chapter(
          'Utilité espérée et aversion au risque',
          lessons: [
            _lesson(
              'Préférences, concavité et richesse finale',
              r'''Dans un cadre standard, un investisseur évalue une richesse finale aléatoire via l'utilité espérée :

\[
max \ E[u(W)]
\]

La fonction u est croissante, car plus de richesse est préférable, et concave, car les agents sont avers au risque.

Deux mesures sont souvent utilisées :

\[
A(W) = - \frac{u''(W)}{u'(W)}
\qquad
R(W) = - W \frac{u''(W)}{u'(W)}
\]

Ces mesures influencent directement la quantité de risque qu'un agent accepte de porter.''',
            ),
          ],
        ),
        _chapter(
          'Choix de portefeuille et condition marginale',
          lessons: [
            _lesson(
              'L\'égalité marginale au coeur du choix optimal',
              r'''Supposons n actifs risqués et éventuellement un actif sans risque au taux Rf.

Si wi représente la part investie dans l'actif i, la richesse finale peut s'écrire comme une combinaison des rendements des actifs.

À l'optimum, déplacer une petite unité de richesse d'un actif vers un autre ne doit plus améliorer l'utilité espérée. Dans un cadre différentiable, cela conduit à une condition du type :

\[
E[u'(W1)(Ri - Rf)] = 0
\]

Cette relation exprime déjà une idée moderne : le rendement excédentaire d'un actif doit être évalué à travers sa contribution au bien-être marginal dans les différents états du monde.''',
            ),
          ],
        ),
        _chapter(
          'Le noyau stochastique et le principe du pricing',
          lessons: [
            _lesson(
              'Le SDF comme prix de la rareté marginale',
              r'''On définit souvent un facteur d'actualisation stochastique M. Son intuition est simple : M est élevé dans les états du monde où l'utilité marginale est élevée, c'est-à-dire dans les états difficiles.

La relation fondamentale de pricing prend la forme :

\[
P0 = E(M X1)
\]

où X1 est le flux futur de l'actif.

**Interprétation**
Un flux payé dans un état difficile vaut plus qu'un flux payé dans un état favorable, parce qu'il apporte davantage de consommation au moment où elle est la plus précieuse.''',
            ),
          ],
        ),
      ],
    ),
    _chapter(
      'Équilibre général à la Arrow-Debreu',
      subChapters: [
        _chapter(
          'Pourquoi l\'équilibre général est la bonne langue de la finance',
          lessons: [
            _lesson(
              'Biens contingents et états du monde',
              r'''La finance s'inscrit naturellement dans l'équilibre général, car un actif financier est une promesse conditionnelle à un état futur du monde.

Le modèle Arrow-Debreu remplace l'idée d'un bien abstrait par celle d'un bien contingent : une unité de consommation livrée seulement si un certain état se réalise.''',
            ),
          ],
        ),
        _chapter(
          'Biens contingents et prix d\'état',
          lessons: [
            _lesson(
              'Les prix d\'état condensent probabilité et rareté',
              r'''S'il existe plusieurs états possibles à la date 1, un titre Arrow-Debreu paie 1 dans un état donné et 0 dans les autres.

Si πs est son prix aujourd'hui, alors πs résume deux dimensions :
* la probabilité de l'état ;
* la valeur marginale de la consommation dans cet état.

Les états rares et douloureux se paient cher en prix d'état.''',
            ),
          ],
        ),
        _chapter(
          'Répliquer un actif avec Arrow-Debreu',
          lessons: [
            _lesson(
              'Décomposer un payoff état par état',
              r'''Tout actif versant X(s) selon l'état s a une valeur égale à la somme de ses payoffs pondérés par les prix d'état.

Dans un monde à quelques états, on peut écrire l'idée sous forme simple :

\[
P0 = π1 X(1) + π2 X(2) + ... + πS X(S)
\]

L'absence d'arbitrage impose ici une cohérence très forte : un portefeuille qui paie zéro dans tous les états doit avoir un prix nul aujourd'hui.''',
            ),
          ],
        ),
      ],
    ),
    _chapter(
      'Approfondissement : CAPM, interprétation microéconomique et dérivation',
      subChapters: [
        _chapter(
          'De l\'optimum individuel à la rémunération du risque',
          lessons: [
            _lesson(
              'Quel risque est vraiment payé ?',
              r'''Le CAPM ne dit pas simplement « plus de risque, plus de rendement ». Il dit que parmi tous les risques, seul celui qui co-varie avec la richesse agrégée est rémunéré.

Si un actif rapporte surtout quand tout le monde va bien, il aide peu au moment où l'utilité marginale est forte. En revanche, un actif qui protège pendant les crises rend un service d'assurance et peut être très demandé malgré un rendement espéré plus faible.''',
            ),
          ],
        ),
        _chapter(
          'Lecture économique de β',
          lessons: [
            _lesson(
              'β comme mesure du risque non diversifiable',
              r'''Dans le CAPM :

\[
βi = \frac{Cov(Ri,Rm)}{Var(Rm)}
\]

β mesure la part de risque d'un actif qui reste liée au marché même après diversification.

En langage microéconomique, c'est la composante du risque de l'actif qui ne peut pas être neutralisée par l'échange et la composition du portefeuille.''',
            ),
          ],
        ),
        _chapter(
          'Une dérivation intuitive du CAPM',
          lessons: [
            _lesson(
              'Du SDF à la covariance avec le marché',
              r'''À l'équilibre, les investisseurs détiennent le portefeuille de marché. La condition d'optimalité peut se résumer par :

\[
E[M(1+Ri)] = 1
\]

Le pont vers le CAPM vient du fait que M augmente lorsque le marché va mal. Un actif est donc rémunéré s'il paie surtout dans les mauvais états, ou au contraire pénalisé s'il rend la situation encore plus difficile quand l'économie est déjà en crise.

**Message central**
Le rendement attendu d'un actif dépend de sa covariance avec le risque agrégé, pas seulement de sa volatilité propre.''',
            ),
          ],
        ),
      ],
    ),
    _chapter(
      'Contrats, incitations et gouvernance',
      subChapters: [
        _chapter(
          'Le problème principal-agent dans l\'entreprise cotée',
          lessons: [
            _lesson(
              'Pourquoi le dirigeant ne choisit pas toujours l\'effort optimal',
              r'''Lorsque l'actionnariat est dispersé, le dirigeant ne supporte pas directement toute la conséquence de ses décisions. Son effort e influence la distribution des profits mais cet effort lui coûte.

Le problème consiste à choisir une rémunération w(π) qui aligne les intérêts du dirigeant et des actionnaires :

\[
max \ E[π - w(π)]
\]

Le contrat doit satisfaire une contrainte de participation et une contrainte d'incitation.''',
            ),
          ],
        ),
        _chapter(
          'Pourquoi stock-options, bonus et dette coexistent',
          lessons: [
            _lesson(
              'Arbitrer entre incitation, discipline et risque',
              r'''Un contrat indexé sur la performance aligne partiellement les intérêts, mais il peut aussi inciter à prendre trop de risque.

La dette apporte une discipline différente, car elle impose des paiements fixes. En revanche, elle peut amplifier les difficultés lors d'un choc défavorable.

La structure optimale du capital et de la rémunération est donc un compromis entre :
* partage du risque ;
* discipline ;
* coûts de faillite ;
* qualité des incitations.''',
            ),
          ],
        ),
      ],
    ),
    _chapter(
      'Économie comportementale',
      subChapters: [
        _chapter(
          'Pourquoi la rationalité parfaite est parfois insuffisante',
          lessons: [
            _lesson(
              'Bulles, paniques et anomalies de comportement',
              r'''Les marchés financiers révèlent des régularités difficiles à expliquer avec une rationalité parfaite : sur-réaction aux nouvelles, paniques, refus de vendre une perte ou encore emballements spéculatifs.

L'objectif de l'économie comportementale n'est pas d'abandonner la théorie, mais d'enrichir le modèle de décision.''',
            ),
          ],
        ),
        _chapter(
          'Théorie des perspectives et aversion aux pertes',
          lessons: [
            _lesson(
              'Modifier la fonction de valeur autour d\'un point de référence',
              r'''La théorie des perspectives donne un poids plus fort aux pertes qu'aux gains autour d'un point de référence.

Cela aide à comprendre pourquoi certains investisseurs conservent trop longtemps des positions perdantes, ou pourquoi des murs de liquidité apparaissent à certains niveaux de prix.

''' +
                  _figProspect +
                  r'''

**Effet clé**
Une perte ressentie est souvent psychologiquement plus forte qu'un gain de même montant, ce qui modifie les décisions observées sur le marché.''',
            ),
          ],
        ),
      ],
    ),
  ],
};

final Map<String, dynamic> chapter3QuizData = buildChapter3QuizData(
  chapter3CourseData,
);
