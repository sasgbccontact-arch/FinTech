import 'learn_course5_quiz_data.dart';

Map<String, dynamic> _lesson5(String title, String content) => {
  'lesson_title': title,
  'content': content,
};

Map<String, dynamic> _chapter5(
  String title, {
  List<Map<String, dynamic>> lessons = const [],
  List<Map<String, dynamic>> subChapters = const [],
}) => {
  'chapter_title': title,
  if (lessons.isNotEmpty) 'lessons': lessons,
  if (subChapters.isNotEmpty) 'sub_chapters': subChapters,
};

const String _figLivretA = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7.2,0);
\draw[arrow] (0,0) -- (0,5.8);
\draw[] (0.6,1.8) -- (1.4,4.2) -- (2.2,5.1) -- (3.0,2.7) -- (3.9,2.5) -- (4.8,1.9) -- (5.6,1.0) -- (6.3,2.0) -- (6.9,0.8);
\node[anchor=west] at (7.0,-0.2) {Temps};
\node[anchor=east] at (-0.1,5.5) {Taux %};
\node[] at (0.6,-0.35) {1967};
\node[] at (1.4,-0.35) {1975};
\node[] at (2.2,-0.35) {1982};
\node[] at (3.0,-0.35) {1990};
\node[] at (3.9,-0.35) {2000};
\node[] at (4.8,-0.35) {2010};
\node[] at (5.6,-0.35) {2020};
\node[] at (6.9,-0.35) {2026};
\node[anchor=west] at (4.0,5.2) {Évolution simplifiée du taux du livret A};
\end{tikzpicture}
\caption{Baisse de long terme du taux du livret A avec quelques phases de remontée}
\end{figure}''';

const String _figLongShort = r'''\begin{figure}
\begin{tikzpicture}
\draw[] (0.5,1.0) rectangle (3.4,2.2);
\draw[] (4.4,1.0) rectangle (7.3,2.2);
\node[] at (1.95,1.6) {Position longue : gain si hausse};
\node[] at (5.85,1.6) {Position courte : gain si baisse};
\draw[arrow] (1.95,2.2) -- (1.95,3.6);
\draw[arrow] (5.85,3.6) -- (5.85,2.2);
\end{tikzpicture}
\caption{Deux façons d'exprimer un scénario de marché}
\end{figure}''';

const String _figStructured = r'''\begin{figure}
\begin{tikzpicture}
\draw[] (0.5,1.0) rectangle (3.0,2.2);
\draw[] (4.0,1.0) rectangle (6.5,2.2);
\draw[] (2.4,3.1) rectangle (4.7,4.3);
\node[] at (1.75,1.6) {Obligation};
\node[] at (5.25,1.6) {Produit dérivé};
\node[] at (3.55,3.7) {Produit structuré};
\draw[arrow] (1.9,2.2) -- (3.0,3.1);
\draw[arrow] (4.9,2.2) -- (4.0,3.1);
\end{tikzpicture}
\caption{Un produit structuré combine souvent une brique obligataire et une brique optionnelle}
\end{figure}''';

const String _figCommodity = r'''\begin{figure}
\begin{tikzpicture}
\draw[arrow] (0,0) -- (7,0);
\draw[arrow] (0,0) -- (0,5.5);
\draw[] (1.0,1.0) -- (6.0,5.0);
\draw[] (1.0,5.0) -- (6.0,1.0);
\draw[dashed] (3.5,0) -- (3.5,3.0);
\draw[dashed] (0,3.0) -- (3.5,3.0);
\node[anchor=west] at (6.1,5.0) {Offre mondiale};
\node[anchor=west] at (6.1,1.0) {Demande économique};
\node[anchor=west] at (6.7,-0.2) {Quantité};
\node[anchor=east] at (-0.1,5.3) {Prix};
\end{tikzpicture}
\caption{Le prix d'une matière première résulte d'un équilibre global}
\end{figure}''';

final Map<String, dynamic> chapter5CourseData = {
  'course_title': 'Les actifs financiers',
  'author': 'Paulo Lgrt',
  'chapters': [
    _chapter5(
      'Définition',
      lessons: [
        _lesson5(
          'Qu’est-ce qu’un actif ou produit financier ?',
          r'''Après avoir compris comment fonctionne le marché et comment analyser les entreprises, il faut connaître les instruments dans lesquels il est possible d'investir.

Un **produit financier** est un support permettant de placer son épargne dans l'objectif d'obtenir un rendement, de protéger son capital ou de se couvrir contre un risque.

Ils se distinguent par :
* leur niveau de risque ;
* leur rendement espéré ;
* leur liquidité ;
* leur horizon d'investissement.

On peut les classer du plus simple au plus complexe. Ce chapitre présente une large gamme de produits disponibles dans l'économie.''',
        ),
      ],
    ),
    _chapter5(
      'Exemples de produits financiers',
      subChapters: [
        _chapter5(
          'Les produits financiers classiques',
          lessons: [
            _lesson5(
              'Actions, obligations et ETF',
              r'''Durant le début de l'apprentissage, plusieurs produits financiers classiques ont déjà été rencontrés. Voici un rappel rapide.

**Action**
Une **action** représente une part de propriété d'une entreprise. Son rendement total peut se résumer par :

\[
\text{Rendement total} = \text{plus-value} + \text{dividendes}
\]

Le risque principal d'une action est la baisse du cours, voire la faillite de l'entreprise.

**Obligation**
Une **obligation** est un prêt accordé à un État ou à une entreprise. L'investisseur devient créancier et non propriétaire. L'émetteur s'engage à verser un coupon et à rembourser le capital à l'échéance.

\[
\boxed{\text{Prix obligation} ≈ \frac{1}{\text{taux d'interet}}}
\]

Les principaux risques sont :
* le risque de défaut ;
* le risque de taux.

**ETF**
Un **ETF** est un fonds coté qui permet une diversification immédiate, à moindre frais et facile d'accès. On distingue notamment des ETF indiciels, sectoriels, obligataires ou matières premières, avec réplication physique ou synthétique.''',
            ),
          ],
        ),
        _chapter5(
          'Les livrets d’épargne : la base sans risque',
          lessons: [
            _lesson5(
              'Pourquoi les livrets sont la référence de départ',
              r'''Avant d'investir sur les marchés, beaucoup d'épargnants commencent par un livret.

Un livret est un compte bancaire rémunéré permettant de déposer et retirer de l'argent à tout moment sans risque de perte en capital.

\[
Capital \ garanti \Rightarrow Aucun \ risque \ de \ perte
\]

Le livret sert de référence théorique pour les autres placements : un investissement risqué doit offrir un rendement supérieur pour être justifié.

Dans la théorie financière, le livret joue le rôle d'actif **sans risque**.''',
            ),
            _lesson5(
              'Livret A, LDDS, LEP et pouvoir d’achat',
              r'''Le **Livret A** est accessible à tous, plafonné pour les particuliers, et ses intérêts sont exonérés d'impôts. Son taux a fortement baissé sur longue période, malgré plusieurs phases de remontée.

''' +
                  _figLivretA +
                  r'''

Le **LDDS** fonctionne sur une logique proche, avec le même taux que le Livret A, et finance en partie la transition énergétique et l'économie solidaire.

Le **LEP** est réservé aux ménages sous condition de revenus. Son taux est en général supérieur à celui du Livret A afin de mieux protéger l'épargne des ménages modestes contre l'inflation.

Le point décisif est le rendement réel :

\[
Rendement \ réel = Rendement \ nominal - Inflation
\]

Un livret peut donc rapporter en nominal tout en faisant perdre du pouvoir d'achat. Dans une stratégie patrimoniale, il sert surtout à sécuriser l'épargne de précaution.

\[
Securite \ -> \ Investissement \ -> \ Performance
\]

Il est indispensable, mais insuffisant pour construire du patrimoine à long terme.''',
            ),
          ],
        ),
        _chapter5(
          'Les comptes à terme : rémunérer l’immobilisation du capital',
          lessons: [
            _lesson5(
              'Plus de rendement, moins de liquidité',
              r'''Le compte à terme est un placement bancaire sécurisé dans lequel l'épargnant immobilise son argent pendant une durée définie en échange d'une rémunération plus élevée.

À l'échéance, la banque rembourse :

\[
Capital \ + \ Interets
\]

Le rendement est connu dès le départ. Il n'y a aucune incertitude sur le taux promis.

**Les avantages**
* capital garanti ;
* peu ou pas de frais ;
* rémunération souvent supérieure aux livrets ;
* visibilité parfaite sur le gain final.

**Les limites**
* argent bloqué pendant la durée du placement ;
* impossibilité d'alimenter progressivement le compte ;
* fiscalité sur les intérêts ;
* pénalité possible en cas de sortie anticipée.

Le compte à terme illustre un principe simple :

\[
Rendement = Temps + Risque
\]

Sans accepter plus de risque, la seule façon d'améliorer le rendement consiste souvent à accepter moins de liquidité.''',
            ),
          ],
        ),
        _chapter5(
          'Les OPCVM : Organismes de Placement Collectif en Valeurs Mobilières',
          lessons: [
            _lesson5(
              'Mutualiser l’épargne et déléguer la gestion',
              r'''Un OPCVM permet à plusieurs investisseurs de mettre leur argent en commun afin qu'il soit géré par un professionnel.

\[
Investisseurs \ -> \ Fonds \ -> \ Portefeuille \ d'actifs
\]

Chaque investisseur détient des parts du fonds proportionnelles à son investissement.

Deux grandes familles existent :
* **SICAV** : l'investisseur devient actionnaire du véhicule ;
* **FCP** : l'investisseur est porteur de parts d'une copropriété d'actifs.

En pratique, la différence est surtout juridique.

L'OPCVM peut être géré activement, avec l'objectif de battre le marché, ou plus passivement, en cherchant à suivre une allocation ou un indice. Historiquement, les frais peuvent réduire fortement la performance nette de l'épargnant : frais d'entrée, frais de gestion annuels et parfois frais de surperformance.

Les OPCVM restent utiles pour les investisseurs souhaitant déléguer totalement la gestion, mais ils ont perdu une partie de leur attrait face aux ETF pour les investisseurs autonomes.''',
            ),
          ],
        ),
        _chapter5(
          'Les produits dérivés',
          subChapters: [
            _chapter5(
              'Définition',
              lessons: [
                _lesson5(
                  'Un actif dont la valeur dépend d’un sous-jacent',
                  r'''Un produit dérivé est un instrument financier dont la valeur dépend d'un autre actif appelé **sous-jacent**.

\[
Valeur \ du \ derive = f(prix \ du \ sous-jacent)
\]

Le sous-jacent peut être une action, un indice, une matière première ou une devise.

Contrairement à une action ou à une obligation, l'investisseur ne possède pas directement l'actif : il prend une position sur son évolution. Les dérivés servent principalement à spéculer, se couvrir contre un risque ou amplifier une exposition.''',
                ),
              ],
            ),
            _chapter5(
              'Le levier et les positions de marché',
              lessons: [
                _lesson5(
                  'Amplifier les mouvements et choisir un sens',
                  r'''Le levier permet d'obtenir une exposition supérieure au capital investi.

\[
Variation \ du \ produit \approx Levier \times Variation \ du \ marche
\]

Par exemple, avec un levier 10, un mouvement de +1 % du marché peut produire environ +10 % sur le produit. L'inverse est aussi vrai : les pertes sont amplifiées.

Selon l'anticipation de marché, on adopte :
* une **position longue** si l'on anticipe une hausse ;
* une **position courte** si l'on anticipe une baisse.

''' +
                      _figLongShort +
                      r'''

Les dérivés permettent donc de gagner potentiellement dans un marché haussier comme baissier, mais au prix d'un risque bien plus élevé.''',
                ),
              ],
            ),
            _chapter5(
              'Les options',
              lessons: [
                _lesson5(
                  'Le droit d’acheter ou de vendre',
                  r'''Une option est un contrat donnant un **droit**, mais jamais une obligation, d'effectuer une transaction à un prix fixé à l'avance pendant une période donnée.

On distingue :
* le **call**, droit d'acheter ;
* le **put**, droit de vendre.

Pour obtenir ce droit, l'acheteur paie une **prime** au vendeur.

Le prix d'une option dépend notamment de la probabilité que ce droit devienne avantageux :

\[
Prix \ de \ l'option \approx Probabilite \ d'etre \ profitable
\]

En pratique, de nombreux produits destinés au grand public ne sont que des combinaisons d'options assemblées différemment.''',
                ),
              ],
            ),
            _chapter5(
              'Les warrants',
              lessons: [
                _lesson5(
                  'Des options standardisées pour le grand public',
                  r'''Les warrants sont des produits dérivés cotés en bourse, souvent émis par une banque, et conçus pour être accessibles aux investisseurs particuliers.

* le **call warrant** permet de profiter d'une hausse ;
* le **put warrant** permet de profiter d'une baisse.

Chaque warrant possède une échéance. Si le scénario de marché n'est pas favorable à cette date, le produit peut expirer sans valeur et la prime investie est perdue.

La logique économique est la même qu'une option, mais sous une forme plus standardisée et généralement plus chargée en marge émetteur.''',
                ),
              ],
            ),
            _chapter5(
              'Les turbos',
              lessons: [
                _lesson5(
                  'Le levier avec barrière désactivante',
                  r'''Les turbos sont des produits à fort effet de levier avec une **barrière désactivante**.

* si la barrière est touchée, le turbo s'éteint et peut devenir sans valeur ;
* si la barrière n'est pas touchée, le turbo suit de façon assez linéaire le sous-jacent avec un fort levier.

Contrairement aux warrants, la valeur d'un turbo dépend surtout du mouvement direct du marché et moins du temps ou de la volatilité implicite. Ils sont souvent plus simples à lire, mais aussi plus brutaux en cas de mauvais scénario.''',
                ),
              ],
            ),
            _chapter5(
              'Produits cappés, floorés, bonus et discount',
              lessons: [
                _lesson5(
                  'Encadrer un scénario plutôt que viser une hausse illimitée',
                  r'''Les produits **cappés** ou **floorés** encadrent la performance entre deux bornes prédéfinies. Le gain maximal est connu à l'avance si le sous-jacent reste dans la zone prévue.

Les produits **Bonus** ou **Stability** rémunèrent surtout un scénario de marché relativement stable. Tant qu'une barrière n'est pas franchie, un rendement prédéfini peut être versé.

Le produit **Discount** permet d'investir avec une décote à l'achat, mais en contrepartie d'un gain plafonné :

\[
Rendement = Decote - Plafonnement \ du \ gain
\]

Dans tous les cas, ces produits ne cherchent pas à prévoir toute la trajectoire du marché, mais à monétiser un scénario de probabilité encadré.''',
                ),
              ],
            ),
            _chapter5(
              'Risque et utilisation des dérivés',
              lessons: [
                _lesson5(
                  'Des instruments de scénario, pas de détention passive',
                  r'''**Caractéristiques communes des produits dérivés**
* leur valeur est souvent sensible au temps ;
* une perte totale est possible ;
* leur comportement dépend de nombreux paramètres : temps, volatilité, barrières, distance au prix.

\[
Temps \Rightarrow Ennemi \ du \ speculateur
\]

Ils ne sont donc pas conçus pour investir passivement, mais pour exprimer un scénario précis :
* hausse marquée ;
* baisse ;
* stagnation ;
* forte ou faible volatilité.

Leur usage exige prudence, compréhension technique et discipline stricte de gestion du capital.''',
                ),
              ],
            ),
          ],
        ),
        _chapter5(
          'Les produits structurés',
          lessons: [
            _lesson5(
              'Combiner protection et exposition conditionnelle',
              r'''Un produit structuré est un placement conçu pour offrir un profil rendement/risque prédéfini.

Il combine généralement plusieurs briques :

\[
Obligation \ + \ Produit \ derive
\]

Une partie du capital sert à bâtir une protection à l'échéance, l'autre finance une exposition conditionnelle via des options.

\[
Capital = Protection + Exposition \ conditionnelle
\]

La performance dépend souvent d'une ou plusieurs barrières. Tant que le scénario prévu est respecté, un rendement fixé à l'avance peut être versé. Si la barrière est franchie dans le mauvais sens, la protection disparaît partiellement ou totalement.

''' +
                  _figStructured +
                  r'''

Ces produits offrent de la visibilité, mais aussi plusieurs limites :
* complexité technique ;
* liquidité souvent réduite ;
* performance plafonnée ;
* risque de contrepartie lié à l'émetteur.

\[
Incertitude \ -> \ Conditions \ predefinies
\]

Ils occupent donc une place intermédiaire entre épargne sécurisée et investissement en actions.''',
            ),
          ],
        ),
        _chapter5(
          'Les matières premières',
          subChapters: [
            _chapter5(
              'Investir dans les ressources réelles',
              lessons: [
                _lesson5(
                  'Une classe d’actifs liée à la conjoncture mondiale',
                  r'''Les matières premières, ou commodities, sont des ressources physiques indispensables à l'économie mondiale : énergie, métaux, produits agricoles.

Contrairement aux actions ou aux obligations, elles ne représentent ni une entreprise ni une dette.

\[
Prix = Offre \ mondiale \ <-> \ Demande \ economique
\]

Leur prix reflète surtout la rareté, l'utilité et la conjoncture macroéconomique.''',
                ),
              ],
            ),
            _chapter5(
              'Formation des prix et grandes catégories',
              lessons: [
                _lesson5(
                  'Énergie, métaux et produits agricoles',
                  r'''Le prix d'une matière première dépend :
* des capacités d'extraction ou de production ;
* des stocks disponibles ;
* des conditions climatiques ;
* de la croissance économique et de la demande industrielle ;
* des tensions géopolitiques.

On distingue notamment :
* l'énergie : pétrole, gaz ;
* les métaux industriels : cuivre, aluminium, nickel ;
* les métaux précieux : or, argent, platine ;
* les produits agricoles : blé, maïs, café.

''' +
                      _figCommodity,
                ),
              ],
            ),
            _chapter5(
              'Absence de revenu intrinsèque et rôle des futures',
              lessons: [
                _lesson5(
                  'Un rendement qui vient uniquement du prix',
                  r'''Une matière première ne verse ni dividende ni coupon.

\[
Rendement = Variation \ du \ prix
\]

L'exposition se fait souvent via des ETF, des futures ou des actions de producteurs.

Les marchés à terme sont centraux pour cette classe d'actifs :

\[
Prix \ futur = Prix \ spot + Cout \ de \ stockage + Anticipations
\]

Lorsque le prix futur est supérieur au spot, on parle de contango. Lorsqu'il est inférieur, on parle de backwardation. Cette structure influence fortement la performance des véhicules qui roulent leurs contrats à terme.''',
                ),
              ],
            ),
            _chapter5(
              'Rôle dans un portefeuille',
              lessons: [
                _lesson5(
                  'Diversification et couverture macro',
                  r'''Les matières premières apportent une diversification utile, car leur comportement diffère souvent de celui des actions et obligations.

Elles peuvent jouer un rôle de couverture partielle contre certains risques macroéconomiques, notamment l'inflation ou les tensions sur l'énergie.

\[
Actions \ -> \ Microeconomie
\qquad
Matieres \ premieres \ -> \ Macroeconomie
\]

Elles ne visent pas à fournir un revenu régulier, mais à équilibrer un portefeuille face à certaines dynamiques globales.''',
                ),
              ],
            ),
          ],
        ),
        _chapter5(
          'Les crypto-actifs',
          subChapters: [
            _chapter5(
              'Des actifs numériques décentralisés',
              lessons: [
                _lesson5(
                  'Une nouvelle forme de rareté',
                  r'''Les crypto-actifs sont des actifs numériques reposant sur une blockchain. Ils ne représentent ni une entreprise, ni une dette, ni une ressource physique.

\[
Valeur = Confiance \ collective + Rarete \ numerique
\]

Ils reposent sur des règles informatiques et cryptographiques plutôt que sur une institution centrale.''',
                ),
              ],
            ),
            _chapter5(
              'Infrastructure, réseau et politique monétaire du protocole',
              lessons: [
                _lesson5(
                  'Le rôle de la blockchain et des clés privées',
                  r'''La blockchain est un registre distribué qui enregistre l'historique des transactions. Chaque participant peut en vérifier la cohérence.

Le contrôle d'un crypto-actif dépend de la détention d'une clé privée. Certains protocoles ont aussi une politique monétaire intégrée :

\[
Offre \ connue \ a \ l'avance
\]

L'émission dépend alors d'un algorithme et non d'une autorité politique ou bancaire.''',
                ),
              ],
            ),
            _chapter5(
              'Valorisation, usages et place dans un portefeuille',
              lessons: [
                _lesson5(
                  'Une exposition technologique et spéculative',
                  r'''Un crypto-actif ne produit aucun flux financier.

\[
Rendement = Variation \ du \ prix
\]

Sa valorisation dépend de l'adoption du réseau, de la confiance dans le protocole et de l'équilibre entre acheteurs et vendeurs.

Les risques spécifiques sont nombreux :
* perte définitive en cas de perte de clé privée ;
* piratage ou défaillance des plateformes ;
* évolution réglementaire ;
* volatilité extrême.

Dans un portefeuille, cette classe d'actifs est généralement considérée comme complémentaire et doit rester proportionnée au niveau de risque acceptable.

\[
Actif \ physique \ -> \ Actif \ financier \ -> \ Actif \ numerique
\]

Les crypto-actifs n'ont pas vocation à remplacer toutes les autres classes d'actifs, mais à introduire une nouvelle forme de valeur fondée sur la rareté numérique.''',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
};

final Map<String, dynamic> chapter5QuizData = buildChapter5QuizData(
  chapter5CourseData,
);
