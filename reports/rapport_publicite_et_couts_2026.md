# Rapport stratégique
## Publicité, revenus et coûts d'infrastructure
### FinHub - analyse au 15 mars 2026

## 1. Objet du rapport

Ce rapport a un objectif simple: expliquer à une personne extérieure au projet
comment FinHub peut monétiser proprement son audience, quels revenus
publicitaires sont plausibles selon plusieurs scénarios, et à quel moment
l'architecture Firestore actuelle commence à coûter plus cher qu'elle ne le
devrait.

Le fil rouge est le suivant:

- FinHub n'est pas une app de contenu passive. C'est une app d'apprentissage
  gamifié de la finance, avec un mélange de pédagogie, de boucles quotidiennes,
  d'économie virtuelle, de portefeuille simulé et de social.
- Cette nature hybride change complètement la stratégie pub. Les emplacements
  rentables ne sont pas les mêmes que dans un jeu mobile pur, et les endroits où
  une publicité détruit la confiance ne sont pas les mêmes que dans une app
  média.
- Côté coûts, Firestore reste globalement peu cher tant que les requêtes
  restent locales et bien bornées. En revanche, certaines écoutes temps réel
  sur des collections larges ou non limitées créent un risque de dérive
  économique à mesure que l'app grandit.
- Enfin, déplacer les workers GitHub Actions vers Cloud Functions / Cloud
  Scheduler peut simplifier l'exploitation et réduire un petit coût de compute,
  mais cela ne résout pas à lui seul les vrais postes de dépense. Le point
  critique reste la forme des requêtes Firestore.

## 2. Lecture produit: où l'app crée de la valeur, et donc où la pub est acceptable

FinHub repose aujourd'hui sur cinq surfaces principales:

- `Aujourd'hui`: hub quotidien, relance, actus, notifications, raccourcis.
- `Dashboard`: portefeuille et suivi de positions.
- `Apprendre`: cours, quiz, progression.
- `Game`: récompenses quotidiennes, simulation, quêtes, économie virtuelle.
- `Social`: communauté, forum, amis, duels, classements.

En termes de perception utilisateur, ces surfaces n'ont pas la même tolérance à
la publicité:

- Les zones de confiance forte sont `Dashboard`, `Apprendre`, les vues
  portefeuille et les écrans d'information financière. Ici, la pub intrusive
  détruit la crédibilité du produit.
- Les zones de boucle et de monnaie virtuelle sont `Game`, `Daily reward`,
  `Daily News`, `rerolls`, `bonus`, `quêtes`, `duels`. Ici, une pub
  récompensée peut être perçue comme un échange explicite et acceptable.
- Les zones de type feed sont `Aujourd'hui`, `Social`, `Forum`,
  `Notifications`. Ici, des formats natifs légers peuvent fonctionner s'ils
  restent visuellement propres et clairement marqués comme sponsorisés.

Conclusion produit:

- FinHub doit être monétisé en priorité par des formats `rewarded` optionnels.
- Les `native ads` ne sont acceptables que dans les surfaces feed / hub.
- Les `interstitials` doivent rester rares et placés uniquement sur des
  transitions naturelles de fin de session.
- Les bannières fixes ne sont pas recommandées: elles dégradent l'expérience
  plus qu'elles ne rapportent dans un produit de ce type.

## 3. Ce que le code montre aujourd'hui

L'audit du code confirme cette lecture produit mais montre aussi plusieurs
signaux de coût:

- Le hub `Aujourd'hui` écoute en temps réel plusieurs documents utiles, mais
  aussi deux collections entières: `metalsPrices` et `broadcasts`.
- L'onglet social charge un classement global à partir d'un listener sur toute
  la collection `users`, ce qui est acceptable à petite échelle mais dangereux
  à grande échelle.
- Plusieurs écrans cumulent des listeners imbriqués sur les mêmes documents
  utilisateur, ce qui augmente le nombre de reads initiaux.
- Le tracking d'activité écrit deux documents par événement tracké.
- Les jobs backend actuels tournent via GitHub Actions selon une cadence très
  fréquente, surtout pour les duels.

Repères techniques internes utilisés pour cette analyse:

```text
Today page
- lib/pages/today_page.dart:202-207 -> listener users/{uid}
- lib/pages/today_page.dart:1730-1758 -> listeners progress, quests, dailyBenefits,
  metalsPrices/{today}, metalsPrices (collection entière), broadcasts (collection entière)

Social / leaderboard
- lib/features/social/social_spotlight_card.dart:87-88 -> collection('users').snapshots()
- lib/features/social/social_spotlight_card.dart:460-463 -> ce flux alimente le leaderboard

Notifications
- lib/features/notifications/notification_center_page.dart:309-332 -> 4 listeners principaux
- lib/features/notifications/notification_center_page.dart:766-840 -> listeners additionnels
  par item actionable

Tracking d'activité
- lib/services/activity_tracking_service.dart:44-68 -> 1 write sur users/{uid}/activity_daily
  + 1 write sur users/{uid} pour last_active_at

Workers planifiés
- .github/workflows/daily_metals.yml:4-8
- .github/workflows/weekly_leaderboard.yml:4-5
- .github/workflows/settle.yml:4-5

Leaderboard batch
- scripts/build_weekly_leaderboard.js:295-300 -> lecture de tous les users puis
  chargement d'activité par user
```

## 4. Scénarios publicitaires

### Principes de conception

Avant de parler chiffres, voici la règle de décision utilisée:

- On ne place pas de pub dans une étape où l'utilisateur est en train
  d'apprendre, de réfléchir ou de consulter son portefeuille.
- On place la pub là où l'utilisateur comprend immédiatement l'échange:
  "je regarde une pub, j'obtiens un bonus".
- On garde une fréquence capée et lisible pour éviter l'effet casino.
- On privilégie d'abord la rétention et la confiance; la monétisation vient
  ensuite.

### Scénario A - Conservateur

Positionnement:

- Bonus après le cadeau quotidien gratuit.
- Une session `Daily News` sponsorisée après l'entrée gratuite.
- Un bonus ponctuel sur une mécanique de reroll / double récompense dans `Game`.

Formats:

- `Rewarded ads` uniquement.

Impact UX:

- Gêne faible.
- Très bon respect de la promesse éducative.
- Monétisation plus lente mais saine.

Projection de revenu brut:

```text
Hypothèse de monétisation
- 0,35 impression rewarded / DAU / jour
- eCPM rewarded iOS Europe de l'Ouest: 8 $ à 12 $

Projection brute
- 1k DAU: 84 $ à 126 $ / mois
- 10k DAU: 840 $ à 1 260 $ / mois
- 50k DAU: 4 200 $ à 6 300 $ / mois
- 100k DAU: 8 400 $ à 12 600 $ / mois
```

### Scénario B - Equilibré et recommandé

Positionnement:

- Tout le scénario A.
- Une `native ad` dans le hub `Aujourd'hui`, sous le premier bloc utile.
- Une `native ad` dans l'espace `Social / Forum`.
- Un `interstitial` très rare, uniquement après la fin complète d'une session
  fermée: fin de run `Daily News`, fin de simulation, fin de séquence de duel
  consommée.

Formats:

- `Rewarded` en priorité.
- `Native` léger sur les surfaces feed.
- `Interstitial` capé très strictement.

Impact UX:

- Gêne faible à modérée.
- Bon compromis revenu / image produit.
- C'est le scénario qui semble le plus cohérent avec FinHub aujourd'hui.

Projection de revenu brut:

```text
Hypothèse de monétisation
- 0,45 rewarded / DAU / jour
- 1,20 native / DAU / jour
- 0,10 interstitial / DAU / jour
- eCPM rewarded: 8 $ à 12 $
- eCPM native: 1 $ à 2 $
- eCPM interstitial: 4 $ à 7 $

Projection brute
- 1k DAU: 156 $ à 255 $ / mois
- 10k DAU: 1 560 $ à 2 550 $ / mois
- 50k DAU: 7 800 $ à 12 750 $ / mois
- 100k DAU: 15 600 $ à 25 500 $ / mois
```

### Scénario C - Croissance plus agressive

Positionnement:

- Tout le scénario B.
- Un `app open ad` très doux au retour au foreground, pas au cold start.
- Plus de transitions monétisées autour des runs de jeu et des fins de session.

Formats:

- `Rewarded`
- `Native`
- `Interstitial`
- `App Open`

Impact UX:

- Gêne modérée.
- Augmentation sensible du risque de fatigue publicitaire.
- A réserver à un produit déjà très stable en rétention.

Projection de revenu brut:

```text
Hypothèse de monétisation
- 0,65 rewarded / DAU / jour
- 1,60 native / DAU / jour
- 0,22 interstitial / DAU / jour
- 0,20 app open / DAU / jour
- eCPM rewarded: 8 $ à 12 $
- eCPM native: 1 $ à 2,2 $
- eCPM interstitial: 4 $ à 7 $
- eCPM app open: 3 $ à 6 $

Projection brute
- 1k DAU: 248 $ à 422 $ / mois
- 10k DAU: 2 484 $ à 4 218 $ / mois
- 50k DAU: 12 420 $ à 21 090 $ / mois
- 100k DAU: 24 840 $ à 42 180 $ / mois
```

### Recommandation publicitaire

La meilleure trajectoire n'est pas le scénario le plus agressif.

La recommandation est:

- court terme: Scénario A si l'objectif principal est de préserver la qualité
  produit et de valider la mécanique rewarded;
- trajectoire recommandée: Scénario B, parce qu'il monétise les surfaces
  "naturellement sponsorisables" sans fragiliser les surfaces de confiance;
- éviter le scénario C tant que la rétention, les caps de fréquence et la
  mesure de churn post-pub ne sont pas solides.

## 5. Modèle de coût Firestore

### Ce que facture Firestore

Sur la base des tarifs standard Firestore cités dans la documentation Firebase,
le modèle utilisé dans ce rapport est:

```text
Prix unitaires utilisés
- Read:   0,06 $ / 100 000 reads
- Write:  0,18 $ / 100 000 writes
- Delete: 0,02 $ / 100 000 deletes

Soit en coût unitaire
- 1 read   = 0,0000006 $
- 1 write  = 0,0000018 $
- 1 delete = 0,0000002 $
```

Important:

- Les listeners temps réel sont facturés à l'initialisation puis à chaque
  document ajouté, modifié ou retiré du résultat.
- Si un listener se reconnecte après une coupure suffisamment longue, Firestore
  le refacture comme une nouvelle requête.
- La documentation officielle recommande explicitement de garder les datasets
  écoutés en temps réel petits.

### Hypothèse de modélisation

Ce rapport ne s'appuie pas sur des analytics de production. Il s'appuie sur le
code actuel et sur des hypothèses d'usage plausibles.

J'utilise donc trois profils de "journée utilisateur":

- `léger`: ouvre l'app, consulte le hub, récupère un bonus, fait peu d'actions;
- `standard`: utilise le hub, le jeu, une partie apprentissage, quelques
  récompenses et écrit un peu de progression;
- `intense`: utilise plusieurs surfaces, plus de quêtes, plus de tracking,
  plus de navigation, plus de social.

Projection Firestore du coût mensuel, hors stockage et bande passante:

```text
Profil léger
- 250 reads / jour / utilisateur
- 12 writes / jour / utilisateur
- 0,2 delete / jour / utilisateur

Projection mensuelle
- 1k DAU:    5,15 $ / mois
- 10k DAU:  51,49 $ / mois
- 50k DAU: 257,46 $ / mois
- 100k DAU: 514,92 $ / mois

Profil standard
- 650 reads / jour / utilisateur
- 20 writes / jour / utilisateur
- 0,4 delete / jour / utilisateur

Projection mensuelle
- 1k DAU:    12,78 $ / mois
- 10k DAU:  127,82 $ / mois
- 50k DAU:  639,12 $ / mois
- 100k DAU: 1 278,24 $ / mois

Profil intense
- 1 500 reads / jour / utilisateur
- 35 writes / jour / utilisateur
- 1 delete / jour / utilisateur

Projection mensuelle
- 1k DAU:    28,90 $ / mois
- 10k DAU:  288,96 $ / mois
- 50k DAU: 1 444,80 $ / mois
- 100k DAU: 2 889,60 $ / mois
```

Lecture importante:

- A petite et moyenne échelle, Firestore n'est pas le problème principal de
  FinHub.
- Le coût variable pur par utilisateur est bas.
- Le vrai danger n'est pas "Firestore est cher"; le vrai danger est
  "certaines requêtes ont une forme qui devient chère quand la taille des
  collections augmente".

## 6. Les points de dérive à grande échelle

### 6.1 Hub `Aujourd'hui`: écoute de collections entières

Aujourd'hui, le hub écoute:

- le document du jour sur `metalsPrices/{today}`;
- mais aussi toute la collection `metalsPrices`;
- et toute la collection `broadcasts`.

Ce design fonctionne au début, mais sa facture augmente avec la taille de
chaque collection.

Hypothèse utilisée pour illustrer le risque:

- `metalsPrices`: 365 documents d'historique;
- `broadcasts`: 80 documents, car le script de notification les prune à 80;
- 2 sessions utilisateur par jour qui déclenchent un snapshot initial.

Impact mensuel des seuls listeners "historique + broadcasts":

```text
Coût mensuel additionnel estimé
- 10k DAU:   160,20 $ / mois
- 50k DAU:   801,00 $ / mois
- 100k DAU: 1 602,00 $ / mois
```

Ce n'est pas dramatique à 10k DAU, mais cela devient un coût inutile parce que
la valeur produit n'exige pas de relire l'intégralité de l'historique pour
afficher le hub du jour.

### 6.2 Social leaderboard: listener global sur `users`

C'est le point le plus risqué du code actuel.

Le leaderboard du social repose aujourd'hui sur un listener temps réel sur toute
la collection `users`. Tant que la base reste petite, cela passe. Dès que le
produit grossit, on se retrouve avec un coût proportionnel à:

`nombre de visites social par jour x nombre total d'utilisateurs stockés`

Projection illustrative:

- 10k utilisateurs totaux, 10k DAU, 20% ouvrent le social chaque jour;
- 50k utilisateurs totaux, 50k DAU, 15% ouvrent le social chaque jour;
- 100k utilisateurs totaux, 100k DAU, 10% ouvrent le social chaque jour.

```text
Coût mensuel estimé du seul listener global users
- 10k users / 10k DAU / 20% social:    360 $ / mois
- 50k users / 50k DAU / 15% social:  6 750 $ / mois
- 100k users / 100k DAU / 10% social: 18 000 $ / mois
```

Ce point change complètement l'analyse économique du produit:

- sans correction, un très bon usage social peut détruire une grande partie de
  la marge publicitaire;
- avec correction, Firestore redevient un coût très raisonnable.

### 6.3 Tracking d'activité: petit coût unitaire, gros volume cumulé

Chaque événement tracké écrit:

- un document journalier `users/{uid}/activity_daily/{date}`;
- puis met à jour `users/{uid}.last_active_at`.

Un seul événement coûte peu. Mais sur une app gamifiée, les événements s'empilent
vite. Le tracking n'est pas le plus gros risque actuel, mais il devient un
accélérateur de writes à mesure que les mini-boucles se multiplient.

## 7. Projection après optimisation des requêtes

Si l'on garde le produit tel quel mais qu'on fait seulement une "hygiène de
requêtes", le coût chute vite:

- remplacer les listeners globaux par des requêtes limitées / paginées;
- pré-calculer les classements affichés dans le social;
- écouter `broadcasts` avec `orderBy(createdAt desc).limit(20)`;
- écouter `metalsPrices` avec une fenêtre bornée ou un document de synthèse;
- dédupliquer certains listeners utilisateur redondants.

Modèle optimisé retenu:

```text
Profil standard optimisé
- 150 reads / jour / utilisateur
- 18 writes / jour / utilisateur
- 0,4 delete / jour / utilisateur

Projection mensuelle
- 1k DAU:    3,67 $ / mois
- 10k DAU:  36,74 $ / mois
- 50k DAU: 183,72 $ / mois
- 100k DAU: 367,44 $ / mois

Profil intense optimisé
- 300 reads / jour / utilisateur
- 30 writes / jour / utilisateur
- 1 delete / jour / utilisateur

Projection mensuelle
- 1k DAU:    7,03 $ / mois
- 10k DAU:  70,26 $ / mois
- 50k DAU: 351,30 $ / mois
- 100k DAU: 702,60 $ / mois
```

Lecture business:

- A 10k DAU, la différence entre état actuel standard et état optimisé reste
  faible en valeur absolue.
- A 50k ou 100k DAU, l'optimisation devient structurelle parce qu'elle protège
  la marge.
- L'optimisation la plus urgente n'est pas une micro-optimisation; c'est la
  suppression des listeners non bornés.

## 8. GitHub Actions aujourd'hui, Cloud Functions demain

### Ce qui tourne actuellement

Aujourd'hui, trois familles de jobs planifiés existent:

```text
Cadence observée
- Daily metals:            24 runs / jour
- Weekly leaderboard:       1 run / jour
- Duel worker settle:     144 runs / jour

Total estimé: 169 runs / jour
Total estimé: 5 070 runs / mois
```

### Coût GitHub Actions actuel

Le coût actuel dépend d'un point externe au repo:

- si le dépôt est public: les runners standards GitHub-hosted sont gratuits;
- si le dépôt est privé: le coût dépend du plan GitHub et des minutes incluses.

Repères officiels actuels:

- GitHub Free: 2 000 minutes / mois incluses;
- GitHub Pro / Team: 3 000 minutes / mois incluses;
- Linux 2-core standard runner: 0,006 $ / minute depuis le 1er janvier 2026.

Avec 5 070 runs / mois, le coût dépend donc surtout de la durée moyenne de
chaque job:

```text
Si le repo est privé et si les jobs utilisent un runner Linux 2-core

Durée moyenne 0,75 min / run
- 3k minutes incluses: ~ 4,82 $ / mois au-delà du quota

Durée moyenne 1,00 min / run
- 3k minutes incluses: ~ 12,42 $ / mois au-delà du quota

Durée moyenne 1,50 min / run
- 3k minutes incluses: ~ 27,63 $ / mois au-delà du quota
```

En clair:

- aujourd'hui, GitHub Actions ne représente probablement qu'un petit coût, ou
  même zéro si le repo est public;
- ce n'est pas le poste le plus important.

### Ce que change le passage à Cloud Functions / Cloud Scheduler

Si par "passer les actions git en CF" on entend "remplacer ces workers GitHub
Actions par des fonctions planifiées Firebase / Google Cloud", alors:

- `Cloud Scheduler`: les 3 premiers jobs sont inclus sans coût, puis 0,10 $ par
  job et par mois;
- `Cloud Functions`: 2M invocations / mois incluses au Blaze plan;
- `FCM`: toujours sans coût d'usage.

Avec les cadences actuelles:

- 5 070 invocations / mois est très loin du seuil gratuit de 2M invocations;
- 3 jobs planifiés tiennent dans l'allocation gratuite Cloud Scheduler;
- le coût direct de compute des jobs actuels serait donc probablement proche de
  zéro à ce stade, ou très faible.

### Le point clé

Déplacer ces workers vers Cloud Functions améliore:

- la fiabilité d'exploitation;
- la centralisation des secrets;
- la cohérence de la stack Firebase;
- la possibilité de brancher des triggers plus propres à terme.

Mais cela ne change pas la logique économique fondamentale:

- si un job lit beaucoup de documents Firestore, il les lira toujours en Cloud
  Functions;
- si un leaderboard charge tous les users, le coût Firestore restera lié au
  nombre de users, quelle que soit la plateforme d'exécution;
- migrer GitHub Actions vers Cloud Functions ne remplace donc pas l'optimisation
  des requêtes Firestore.

### Nuance de coût 2nd gen

Il faut cependant noter une subtilité officielle importante:

- en Cloud Functions 2nd gen, les petites fonctions low-memory ont par défaut
  1 CPU, ce qui peut rendre certaines fonctions plus chères qu'attendu si on les
  porte sans réglage fin.

Dans votre cas, cette nuance ne renverse pas la conclusion:

- à l'échelle actuelle, les workers resteront vraisemblablement dans les quotas
  gratuits ou très proches;
- à plus grande échelle, la vraie facture restera largement côté Firestore et
  non côté invocations de fonctions.

## 9. Lecture économique globale

Le point le plus intéressant du dossier est le suivant:

- dans une version disciplinée de FinHub, la pub peut largement couvrir les
  coûts Firestore;
- dans une version non optimisée avec listeners globaux, la marge peut être
  rongée inutilement à mesure que le social grossit.

Lecture synthétique:

```text
A 10k DAU
- Revenu pub scénario B:     1 560 $ à 2 550 $ / mois
- Firestore état standard:     128 $ / mois
- Firestore optimisé:           37 $ / mois

A 50k DAU
- Revenu pub scénario B:     7 800 $ à 12 750 $ / mois
- Firestore état standard:     639 $ / mois
- Firestore optimisé:          184 $ / mois
- Risque si leaderboard global users conservé: ~ 6 750 $ / mois à lui seul

A 100k DAU
- Revenu pub scénario B:    15 600 $ à 25 500 $ / mois
- Firestore état standard:   1 278 $ / mois
- Firestore optimisé:          367 $ / mois
- Risque si leaderboard global users conservé: ~ 18 000 $ / mois
```

La conclusion n'est donc pas "la pub financera forcément tout" ni "Firestore
est trop cher". La bonne conclusion est:

- le modèle peut être très rentable;
- mais cette rentabilité dépend fortement de deux ou trois décisions de requêtes
  qui paraissent anodines tant que la base est petite.

## 10. Recommandations concrètes

### Priorité 1 - Monétisation

Lancer d'abord le scénario B, pas le C:

- bonus rewarded après le cadeau quotidien;
- une session sponsorisée `Daily News`;
- une native dans `Aujourd'hui`;
- une native dans `Social / Forum`;
- un interstitial très rare à une vraie fin de session.

### Priorité 2 - Requêtes Firestore à corriger avant la vraie montée en charge

1. Remplacer le listener global `users` du social par:
   - un leaderboard matérialisé;
   - ou une collection dédiée `leaderboards/current`;
   - ou au minimum une requête `limit(10)` / pagination.

2. Remplacer les listeners entiers sur `metalsPrices` et `broadcasts` par:
   - un document de synthèse du jour;
   - ou une requête ordonnée et bornée.

3. Réduire les listeners imbriqués redondants sur `users/{uid}` dans `Game`,
   `Shop` et certaines cartes de hub.

### Priorité 3 - Backend ops

Migrer les jobs GitHub Actions vers Cloud Functions / Cloud Scheduler pour:

- simplifier l'exploitation;
- éviter la dépendance à GitHub pour des tâches produit;
- préparer des traitements backend plus proches du reste de l'architecture.

Mais ne pas vendre cette migration comme une économie massive:

- la vraie économie viendra surtout de l'hygiène Firestore.

## 11. Conclusion

FinHub a un profil très favorable à une monétisation publicitaire mesurée:

- la boucle quotidienne et les monnaies virtuelles se prêtent bien au rewarded;
- les surfaces feed se prêtent à quelques native ads;
- les surfaces de confiance doivent rester très peu polluées.

Le meilleur compromis, à ce stade, est un modèle `rewarded-first` complété par
un peu de `native`, avec très peu d'interstitiels.

Sur les coûts, le constat est rassurant mais exigeant:

- Firestore pur reste peu cher par utilisateur si les requêtes sont bien formées;
- l'architecture actuelle contient déjà un ou deux patterns qui ne passeront pas
  bien à grande échelle;
- corriger ces patterns avant d'accélérer l'acquisition est une décision de
  marge, pas seulement une décision d'ingénierie.

Autrement dit:

- Oui, la pub peut financer proprement l'app.
- Oui, passer les workers GitHub vers Cloud Functions a du sens.
- Non, il ne faut pas confondre migration d'exécution et vraie optimisation de
  coût.
- Le vrai levier économique prioritaire est la suppression des listeners non
  bornés et des lectures globales inutiles.

## 12. Sources

Sources officielles:

- Firebase pricing: https://firebase.google.com/pricing
- Cloud Firestore billing: https://firebase.google.com/docs/firestore/pricing
- Firestore realtime queries at scale:
  https://firebase.google.com/docs/firestore/real-time_queries_at_scale
- Scheduled functions / Cloud Scheduler cost note:
  https://firebase.google.com/docs/functions/schedule-functions
- Cloud Functions for Firebase:
  https://firebase.google.com/docs/functions/
- Cloud Functions manage functions:
  https://firebase.google.com/docs/functions/manage-functions
- GitHub Actions billing:
  https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions
- GitHub Actions runner pricing:
  https://docs.github.com/billing/reference/actions-runner-pricing

Benchmarks publicitaires utilisés comme base directionnelle:

- Appodeal Benchmarks / eCPM report:
  https://appodeal.com/blog/mobile-ecpm-report-app-ad-monetization-worldwide-performance/
- Appodeal Q4 2024 report teaser:
  https://appodeal.com/wp-content/uploads/2025/03/Quarterly_Mobile_eCPM_Report_-_Q4_2024.pdf

Note méthodologique:

- Les placements, taux d'impression et projections de revenu sont des
  modélisations internes construites à partir du produit, du code et des
  benchmarks publics; ce ne sont pas des revenus garantis.
- Les projections de coût Firestore sont des ordres de grandeur bâtis à partir
  des tarifs officiels et de scénarios d'usage plausibles, pas des exports de
  facturation de production.
