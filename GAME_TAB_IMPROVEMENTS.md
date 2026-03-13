# Game Tab Improvements

## Daily Reward

| Description | Complexité | Impact UX | Service/API requis |
| --- | --- | --- | --- |
| Ajouter un reveal animé de la récompense avec carte “avant/après” et compteur de gains | S | fort | Firestore |
| Afficher un timer précis avant le prochain claim au lieu d’un simple état binaire | S | moyen | Firestore |
| Introduire un bonus de streak hebdomadaire sur les claims quotidiens | M | fort | Firestore |
| Ajouter un historique des 7 derniers claims pour renforcer la rétention | M | moyen | Firestore |

## Quêtes & Achievements

| Description | Complexité | Impact UX | Service/API requis |
| --- | --- | --- | --- |
| Ajouter des quêtes multi-surfaces combinant quiz, trade et simulation | M | fort | Firestore |
| Montrer une timeline de progression hebdomadaire avec paliers intermédiaires | M | fort | Firestore |
| Introduire des succès cachés révélés par certaines actions de jeu | S | moyen | Firestore |
| Ajouter une file “récompenses à récupérer” globale visible sur l’onglet Game | S | fort | Firestore |

## Scénarios de simulation

| Description | Complexité | Impact UX | Service/API requis |
| --- | --- | --- | --- |
| Ajouter un score étoilé par scénario selon rendement, risque et vitesse d’exécution | M | fort | Firestore |
| Introduire des variantes daily seed pour rejouabilité sans créer de nouveaux assets | M | fort | Firestore |
| Afficher une fiche “débrief” comparative entre choix du joueur et trajectoire optimale | M | fort | Aucun |
| Ajouter un mode expert avec contraintes macro ou sectorielles supplémentaires | L | moyen | YahooFinanceService |

## Actu & Quiz

| Description | Complexité | Impact UX | Service/API requis |
| --- | --- | --- | --- |
| Ajouter une synthèse “ce que tu aurais dû retenir” après chaque session | S | fort | GDELT |
| Introduire une difficulté progressive selon le taux de bonnes réponses récent | M | fort | Firestore + GDELT |
| Ajouter un classement journalier sur score et vitesse de réponse | M | moyen | Firestore |
| Permettre de rejouer une session terminée en mode entraînement sans coût ni récompense | S | moyen | Firestore |

## Boutique

| Description | Complexité | Impact UX | Service/API requis |
| --- | --- | --- | --- |
| Ajouter des bundles thématiques liés aux mini-jeux actifs de la semaine | S | moyen | Firestore |
| Introduire un aperçu avant achat pour avatars et boosts actifs | S | fort | Aucun |
| Ajouter un journal économique simple des dépenses/récompenses du joueur | M | fort | Firestore |
| Créer des offres rotatives quotidiennes avec timer local et badge visuel | M | moyen | Firestore |

## Compte à terme

| Description | Complexité | Impact UX | Service/API requis |
| --- | --- | --- | --- |
| Montrer une courbe projetée du rendement par durée et par devise de jeu | S | fort | Aucun |
| Ajouter des paliers “liquidité vs rendement” avec pénalité de retrait anticipé | M | fort | Firestore |
| Introduire des dépôts événementiels limités dans le temps | M | moyen | Firestore |
| Ajouter un écran d’historique des dépôts clos avec TRI simplifié | M | moyen | Firestore |

## Stock Analyst

| Description | Complexité | Impact UX | Service/API requis |
| --- | --- | --- | --- |
| Ajouter un tableau d’historique personnel par ticker, diff moyen et meilleurs jackpots | M | fort | Firestore |
| Introduire un mode série de 3 tickers avec score cumulé et bonus de fin de run | L | fort | Firestore + YahooFinanceService |
| Ajouter une difficulté par secteur avec réglage automatique des attentes de score | L | moyen | YahooFinanceService |
| Afficher un “coach mode” optionnel qui explique pourquoi le moteur a sur/sous-noté le titre | M | fort | Aucun |

## Duel communautaire

| Description | Complexité | Impact UX | Service/API requis |
| --- | --- | --- | --- |
| Ajouter une salle de pré-duel avec scouting résumé avant validation du matchmaking | M | fort | Firestore + YahooFinanceService |
| Introduire des objectifs secondaires pendant le duel pour éviter les semaines passives | L | fort | Firestore |
| Afficher une courbe comparée live plus lisible avec points de bascule clés | M | fort | Firestore + YahooFinanceService |
| Ajouter des récompenses cosmétiques saisonnières liées au ratio de victoire | M | moyen | Firestore |

## Portefeuille de jeu

| Description | Complexité | Impact UX | Service/API requis |
| --- | --- | --- | --- |
| Ajouter une vue “journal de décisions” corrélant trades, scénarios et duels | M | fort | Firestore |
| Introduire un stress test rapide par scénario macro avec projections visuelles | L | fort | YahooFinanceService |
| Ajouter une heatmap de concentration sectorielle et géographique | M | fort | YahooFinanceService |
| Permettre d’épingler 3 KPI favoris en haut du dashboard | S | moyen | Firestore |
