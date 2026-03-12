import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/features/duel/duel_models.dart';
import 'package:fintech/features/duel/duel_service.dart';
import 'package:fintech/pages/info_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  bool _syncing = true;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshProfile());
  }

  Future<void> _refreshProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _syncing = true;
      _syncError = null;
    });
    try {
      await DuelService.syncCurrentUserProfile(uid: uid, bumpActivity: true);
    } catch (error) {
      if (mounted) {
        setState(() => _syncError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Connecte-toi pour lancer un duel communautaire.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Duel hebdo',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _refreshProfile,
            tooltip: 'Rafraîchir',
            icon:
                _syncing
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                    : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: detailsColor1,
          onRefresh: _refreshProfile,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: DuelService.watchProfile(user.uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData && _syncing) {
                return const _DuelPageSkeleton();
              }

              final profile = DuelProfile.fromDoc(
                snapshot.data,
                fallbackUid: user.uid,
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _DuelHeroBanner(profile: profile),
                  if (_syncError != null) ...[
                    const SizedBox(height: 12),
                    _StatusInfoCard(
                      title: 'Synchronisation incomplète',
                      subtitle: _syncError!,
                      tone: _CardTone.warning,
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (profile.currentDuelId != null &&
                      profile.currentDuelId!.isNotEmpty)
                    _CurrentDuelSection(
                      uid: user.uid,
                      duelId: profile.currentDuelId!,
                      onRefreshProfile: _refreshProfile,
                    )
                  else if (profile.currentRequestId != null &&
                      profile.currentRequestId!.isNotEmpty)
                    _CurrentRequestSection(
                      uid: user.uid,
                      requestId: profile.currentRequestId!,
                      onRefreshProfile: _refreshProfile,
                    )
                  else
                    _IdleMatchmakingSection(
                      profile: profile,
                      onRefreshProfile: _refreshProfile,
                    ),
                  const SizedBox(height: 16),
                  const _RulesCard(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DuelHeroBanner extends StatelessWidget {
  const _DuelHeroBanner({required this.profile});

  final DuelProfile profile;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (profile.state) {
      'pending_sent' => 'Invitation envoyée',
      'pending_received' => 'Invitation reçue',
      'active_duel' => 'Duel actif',
      _ => profile.eligible ? 'Prêt à matcher' : 'Préparation requise',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [detailsColor1, detailsColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Un seul duel. Une seule semaine. Un vrai face-à-face.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.96),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Valeur portefeuille jeu: ${_formatCoins(profile.holdingsValueEstimate)} · Réserve: ${_formatCoins(profile.reserveCoins)} · ${profile.positionsCount} ligne(s)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleMatchmakingSection extends StatefulWidget {
  const _IdleMatchmakingSection({
    required this.profile,
    required this.onRefreshProfile,
  });

  final DuelProfile profile;
  final Future<void> Function() onRefreshProfile;

  @override
  State<_IdleMatchmakingSection> createState() =>
      _IdleMatchmakingSectionState();
}

class _IdleMatchmakingSectionState extends State<_IdleMatchmakingSection> {
  bool _submitting = false;
  String? _message;

  Future<void> _start() async {
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      await DuelService.startMatchmaking();
      await widget.onRefreshProfile();
      if (!mounted) return;
      setState(() {
        _message = 'Adversaire trouvé. Attends maintenant sa réponse.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _message = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingValue =
        (DuelService.minEligibleHoldingsValue -
                widget.profile.holdingsValueEstimate)
            .clamp(0, DuelService.minEligibleHoldingsValue)
            .toDouble();
    final isEligible = widget.profile.eligible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isEligible)
          _StatusInfoCard(
            title: 'Portefeuille prêt pour le matchmaking',
            subtitle:
                'Le moteur cherche un adversaire proche de ta valeur de portefeuille, de ta réserve de coins et de ton niveau.',
            tone: _CardTone.success,
          )
        else
          _StatusInfoCard(
            title: 'Conditions non remplies',
            subtitle:
                widget.profile.positionsCount == 0
                    ? 'Ajoute au moins une ligne dans ton portefeuille de jeu, puis atteins 10k coins de valeur.'
                    : 'Il te manque encore ${_formatCoins(missingValue)} de valeur sur le portefeuille de jeu pour rejoindre la file.',
            tone: _CardTone.warning,
          ),
        const SizedBox(height: 14),
        _MatchmakingLaunchCard(
          enabled: isEligible && !_submitting,
          loading: _submitting,
          onTap: isEligible && !_submitting ? _start : null,
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          _StatusInfoCard(
            title: 'Retour du système',
            subtitle: _message!,
            tone: _CardTone.neutral,
          ),
        ],
      ],
    );
  }
}

class _CurrentRequestSection extends StatelessWidget {
  const _CurrentRequestSection({
    required this.uid,
    required this.requestId,
    required this.onRefreshProfile,
  });

  final String uid;
  final String requestId;
  final Future<void> Function() onRefreshProfile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DuelService.watchRequest(requestId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _StatusInfoCard(
            title: 'Invitation en cours',
            subtitle: 'Chargement du statut de la demande...',
            tone: _CardTone.neutral,
          );
        }

        if (!snapshot.data!.exists) {
          return _RecoveryCard(onRefresh: onRefreshProfile);
        }

        final request = DuelRequest.fromDoc(snapshot.data!);
        if (!request.isPendingResponse) {
          return _ResolvedRequestCard(
            request: request,
            onRefreshProfile: onRefreshProfile,
          );
        }

        final isTarget = request.targetUid == uid;
        return isTarget
            ? _IncomingRequestCard(
              uid: uid,
              request: request,
              onRefreshProfile: onRefreshProfile,
            )
            : _OutgoingRequestCard(
              request: request,
              onRefreshProfile: onRefreshProfile,
            );
      },
    );
  }
}

class _OutgoingRequestCard extends StatefulWidget {
  const _OutgoingRequestCard({
    required this.request,
    required this.onRefreshProfile,
  });

  final DuelRequest request;
  final Future<void> Function() onRefreshProfile;

  @override
  State<_OutgoingRequestCard> createState() => _OutgoingRequestCardState();
}

class _OutgoingRequestCardState extends State<_OutgoingRequestCard> {
  bool _cancelling = false;
  String? _feedback;

  @override
  Widget build(BuildContext context) {
    final target = widget.request.targetSnapshot;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adversaire trouvé',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${target['displayName'] ?? 'Adversaire'} a été trouvé. Il dispose maintenant de 48h pour accepter ou refuser.',
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 14),
          _OpponentPreview(snapshot: target),
          const SizedBox(height: 14),
          _DeadlinePill(deadline: widget.request.responseDeadline),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Text(
              _feedback!,
              style: const TextStyle(
                color: detailsColor2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _cancelling ? null : widget.onRefreshProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: detailsColor2.withValues(alpha: 0.10),
                    foregroundColor: detailsColor2,
                  ),
                  child: const Text('Actualiser le statut'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _cancelling
                          ? null
                          : () async {
                            setState(() {
                              _cancelling = true;
                              _feedback = null;
                            });
                            try {
                              await DuelService.cancelPendingRequest(
                                widget.request.id,
                              );
                              await widget.onRefreshProfile();
                              if (!mounted) return;
                              setState(() {
                                _feedback =
                                    'Matchmaking annulé. Tu peux relancer une recherche quand tu veux.';
                              });
                            } catch (error) {
                              if (!mounted) return;
                              setState(() {
                                _feedback = error.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                );
                              });
                            } finally {
                              if (mounted) {
                                setState(() => _cancelling = false);
                              }
                            }
                          },
                  child:
                      _cancelling
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                          : const Text('Annuler'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomingRequestCard extends StatefulWidget {
  const _IncomingRequestCard({
    required this.uid,
    required this.request,
    required this.onRefreshProfile,
  });

  final String uid;
  final DuelRequest request;
  final Future<void> Function() onRefreshProfile;

  @override
  State<_IncomingRequestCard> createState() => _IncomingRequestCardState();
}

class _IncomingRequestCardState extends State<_IncomingRequestCard> {
  bool _processing = false;
  String? _feedback;

  Future<void> _accept() async {
    setState(() {
      _processing = true;
      _feedback = null;
    });
    try {
      await DuelService.acceptRequest(widget.request.id);
      await widget.onRefreshProfile();
    } catch (error) {
      if (mounted) {
        setState(
          () => _feedback = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _refuse() async {
    setState(() {
      _processing = true;
      _feedback = null;
    });
    try {
      await DuelService.refuseRequest(widget.request.id);
      await widget.onRefreshProfile();
    } catch (error) {
      if (mounted) {
        setState(
          () => _feedback = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initiator = widget.request.initiatorSnapshot;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Défi reçu',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${initiator['displayName'] ?? 'Un joueur'} te provoque en duel hebdomadaire.',
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 14),
          _OpponentPreview(snapshot: initiator),
          const SizedBox(height: 14),
          _DeadlinePill(deadline: widget.request.responseDeadline),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Text(
              _feedback!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _processing ? null : _refuse,
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _processing ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child:
                      _processing
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Accepter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolvedRequestCard extends StatelessWidget {
  const _ResolvedRequestCard({
    required this.request,
    required this.onRefreshProfile,
  });

  final DuelRequest request;
  final Future<void> Function() onRefreshProfile;

  @override
  Widget build(BuildContext context) {
    final label = switch (request.status) {
      'refused' => 'Invitation refusée',
      'expired' => 'Invitation expirée',
      'cancelled' => 'Invitation annulée',
      'converted' => 'Duel lancé',
      _ => 'Statut mis à jour',
    };

    final subtitle = switch (request.status) {
      'refused' =>
        'Le duel a été refusé. Tu peux relancer un matchmaking quand tu veux.',
      'expired' =>
        'Le délai de 48h est dépassé. Tu peux relancer un matchmaking.',
      'cancelled' =>
        'L’initiateur a annulé ce matchmaking avant le départ du duel. Tu peux relancer une recherche.',
      'converted' => 'La demande est devenue un duel actif.',
      _ => 'Rafraîchis pour récupérer le dernier état.',
    };

    return _StatusInfoCard(
      title: label,
      subtitle: subtitle,
      tone: _CardTone.neutral,
      actionLabel: 'Rafraîchir',
      onAction: onRefreshProfile,
    );
  }
}

class _CurrentDuelSection extends StatelessWidget {
  const _CurrentDuelSection({
    required this.uid,
    required this.duelId,
    required this.onRefreshProfile,
  });

  final String uid;
  final String duelId;
  final Future<void> Function() onRefreshProfile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DuelService.watchDuel(duelId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _StatusInfoCard(
            title: 'Chargement du duel',
            subtitle: 'Préparation du dashboard...',
            tone: _CardTone.neutral,
          );
        }
        if (!snapshot.data!.exists) {
          return _RecoveryCard(onRefresh: onRefreshProfile);
        }

        final duel = DuelData.fromDoc(snapshot.data);
        if (duel.isSettled) {
          return _SettledDuelSection(
            uid: uid,
            duel: duel,
            onRefreshProfile: onRefreshProfile,
          );
        }

        return _ActiveDuelDashboard(
          uid: uid,
          duel: duel,
          onRefreshProfile: onRefreshProfile,
        );
      },
    );
  }
}

class _ActiveDuelDashboard extends StatefulWidget {
  const _ActiveDuelDashboard({
    required this.uid,
    required this.duel,
    required this.onRefreshProfile,
  });

  final String uid;
  final DuelData duel;
  final Future<void> Function() onRefreshProfile;

  @override
  State<_ActiveDuelDashboard> createState() => _ActiveDuelDashboardState();
}

class _ActiveDuelDashboardState extends State<_ActiveDuelDashboard> {
  Timer? _timer;
  late Future<_ActiveDuelPayload> _future;
  String? _intelAction;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted) return;
      setState(() => _future = _load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<_ActiveDuelPayload> _load() async {
    final metrics = await DuelService.refreshActiveDuelMetrics(
      duelId: widget.duel.id,
      uid: widget.uid,
    );
    final participantSnap =
        await FirebaseFirestore.instance
            .collection('duels')
            .doc(widget.duel.id)
            .collection('participants')
            .doc(widget.uid)
            .get();
    final participant = DuelParticipant.fromDoc(
      participantSnap,
      uid: widget.uid,
    );
    final opponentUid = widget.duel.participants.firstWhere(
      (candidate) => candidate != widget.uid,
      orElse: () => '',
    );
    final opponentProfileSnap =
        opponentUid.isEmpty
            ? null
            : await FirebaseFirestore.instance
                .collection('duel_profiles')
                .doc(opponentUid)
                .get();
    final opponentParticipantSnap =
        opponentUid.isEmpty
            ? null
            : await FirebaseFirestore.instance
                .collection('duels')
                .doc(widget.duel.id)
                .collection('participants')
                .doc(opponentUid)
                .get();
    final opponentProfile = DuelProfile.fromDoc(
      opponentProfileSnap,
      fallbackUid: opponentUid,
    );
    return _ActiveDuelPayload(
      participant: participant,
      metrics: metrics,
      opponentProfile: opponentProfile,
      opponentParticipant: DuelParticipant.fromDoc(
        opponentParticipantSnap,
        uid: opponentUid,
      ),
    );
  }

  Future<void> _openInfo(DuelHolding holding) async {
    if (!mounted) return;
    await showCupertinoModalBottomSheet<void>(
      context: context,
      expand: true,
      builder:
          (_) => InfoPage(
            ticker: holding.symbol,
            initialName: holding.displayName,
            initialExchange: holding.exchange,
            initialCurrency: holding.currency,
            initialQuoteType: holding.quoteType,
          ),
    );
    if (!mounted) return;
    setState(() => _future = _load());
    await widget.onRefreshProfile();
  }

  Future<void> _purchaseIntel({
    required String actionKey,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    setState(() => _intelAction = actionKey);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );
      setState(() => _future = _load());
      await widget.onRefreshProfile();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _intelAction = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ActiveDuelPayload>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _DuelContentSkeleton();
        }

        final payload = snapshot.data!;
        final metrics = payload.metrics;
        final remaining = widget.duel.endsAt?.difference(DateTime.now());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScoreHeroCard(
              title: 'Dashboard duel',
              score: metrics.score,
              returnPct: metrics.returnPct,
              subtitle:
                  remaining == null
                      ? 'Duel en cours'
                      : 'Temps restant: ${_formatRemaining(remaining)}',
              premium: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatMiniCard(
                    label: 'Portefeuille',
                    value: _formatCoins(metrics.holdingsValue),
                    caption: '${metrics.positionsCount} ligne(s)',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatMiniCard(
                    label: 'Réserve',
                    value: _formatCoins(metrics.reserveCoins),
                    caption: 'coins disponibles',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatMiniCard(
                    label: 'Bonus structure',
                    value: '+${metrics.structureBonus.toStringAsFixed(1)}',
                    caption: 'diversification',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatMiniCard(
                    label: 'Malus concentration',
                    value:
                        '-${metrics.concentrationPenalty.toStringAsFixed(1)}',
                    caption: 'risque de concentration',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _IntelDeck(
              duelId: widget.duel.id,
              ownParticipant: payload.participant,
              opponentParticipant: payload.opponentParticipant,
              opponentProfile: payload.opponentProfile,
              busyAction: _intelAction,
              onBuyPerformance:
                  () => _purchaseIntel(
                    actionKey: 'performance',
                    action:
                        () => DuelService.purchasePerformanceIntel(
                          duelId: widget.duel.id,
                          uid: widget.uid,
                        ),
                    successMessage:
                        'Fourchette de performance adverse affinée.',
                  ),
              onBuyPositions:
                  () => _purchaseIntel(
                    actionKey: 'positions',
                    action:
                        () => DuelService.purchasePositionsReveal(
                          duelId: widget.duel.id,
                          uid: widget.uid,
                        ),
                    successMessage:
                        'Le nombre de lignes adverses est maintenant visible.',
                  ),
              onBuyLine:
                  () => _purchaseIntel(
                    actionKey: 'line',
                    action:
                        () => DuelService.purchaseLineReveal(
                          duelId: widget.duel.id,
                          uid: widget.uid,
                        ),
                    successMessage:
                        'Une ligne adverse a été révélée dans ton radar.',
                  ),
            ),
            const SizedBox(height: 14),
            _SectionLabel(
              title: 'Mes lignes',
              subtitle:
                  'Tes trades restent autorisés, mais la dernière ligne ne peut pas être vendue pendant le duel.',
            ),
            const SizedBox(height: 10),
            if (metrics.holdings.isEmpty)
              const _StatusInfoCard(
                title: 'Portefeuille de jeu vide',
                subtitle:
                    'Cet état ne devrait pas arriver pendant un duel actif. Ouvre une fiche action pour rééquilibrer.',
                tone: _CardTone.warning,
              )
            else
              ...metrics.holdings.map(
                (holding) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HoldingRow(
                    holding: holding,
                    onTap: () => _openInfo(holding),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SettledDuelSection extends StatefulWidget {
  const _SettledDuelSection({
    required this.uid,
    required this.duel,
    required this.onRefreshProfile,
  });

  final String uid;
  final DuelData duel;
  final Future<void> Function() onRefreshProfile;

  @override
  State<_SettledDuelSection> createState() => _SettledDuelSectionState();
}

class _SettledDuelSectionState extends State<_SettledDuelSection> {
  bool _closing = false;
  bool _claiming = false;
  int _phase = 0;
  Timer? _showdownTimer;

  @override
  void dispose() {
    _showdownTimer?.cancel();
    super.dispose();
  }

  Future<_SettledPayload> _load() async {
    final ownSnap =
        await FirebaseFirestore.instance
            .collection('duels')
            .doc(widget.duel.id)
            .collection('participants')
            .doc(widget.uid)
            .get();
    final own = DuelParticipant.fromDoc(ownSnap, uid: widget.uid);
    final opponentUid = widget.duel.participants.firstWhere(
      (candidate) => candidate != widget.uid,
      orElse: () => '',
    );
    final opponentSnap =
        await FirebaseFirestore.instance
            .collection('duels')
            .doc(widget.duel.id)
            .collection('participants')
            .doc(opponentUid)
            .get();
    final opponent = DuelParticipant.fromDoc(opponentSnap, uid: opponentUid);
    final winnerName = await _loadPlayerName(widget.duel.winnerUid ?? '');
    final loserName = await _loadPlayerName(widget.duel.loserUid ?? '');
    return _SettledPayload(
      own: own,
      opponent: opponent,
      winnerName: winnerName,
      loserName: loserName,
    );
  }

  Future<String> _loadPlayerName(String uid) async {
    if (uid.isEmpty) return 'Inconnu';
    final doc =
        await FirebaseFirestore.instance
            .collection('duel_profiles')
            .doc(uid)
            .get();
    return (doc.data()?['displayName'] as String? ?? 'Joueur').trim();
  }

  void _startShowdown() {
    setState(() => _phase = 1);
    _showdownTimer?.cancel();
    _showdownTimer = Timer(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      setState(() => _phase = 2);
    });
  }

  Future<void> _claimReward() async {
    setState(() => _claiming = true);
    try {
      await DuelService.revealWinnerResult(
        duelId: widget.duel.id,
        uid: widget.uid,
      );
      if (mounted) {
        setState(() => _phase = 3);
      }
    } finally {
      if (mounted) {
        setState(() => _claiming = false);
      }
    }
  }

  void _openLossRecap() {
    setState(() => _phase = 3);
  }

  Future<void> _close() async {
    setState(() => _closing = true);
    try {
      await DuelService.closeSettledDuel(
        duelId: widget.duel.id,
        uid: widget.uid,
      );
      await widget.onRefreshProfile();
    } finally {
      if (mounted) {
        setState(() => _closing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SettledPayload>(
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _DuelContentSkeleton();
        }
        final payload = snapshot.data!;
        final own = payload.own;
        final opponent = payload.opponent;
        final isWinner = own.isWinner;
        final effectivePhase = own.rewardClaimedAt != null ? 3 : _phase;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child:
              effectivePhase == 0
                  ? _ResultSummaryCard(
                    own: own,
                    opponent: opponent,
                    winnerName: payload.winnerName,
                    loserName: payload.loserName,
                    isWinner: isWinner,
                    onPrimaryTap: _startShowdown,
                  )
                  : effectivePhase == 1
                  ? _ResultShowdownCard(
                    own: own,
                    opponent: opponent,
                    winnerName: payload.winnerName,
                    loserName: payload.loserName,
                    isWinner: isWinner,
                  )
                  : effectivePhase == 2
                  ? _ResultDecisionCard(
                    own: own,
                    opponent: opponent,
                    winnerName: payload.winnerName,
                    loserName: payload.loserName,
                    isWinner: isWinner,
                    claiming: _claiming,
                    onPrimaryTap: isWinner ? _claimReward : _openLossRecap,
                  )
                  : _ResultRewardCard(
                    isWinner: isWinner,
                    winnerName: payload.winnerName,
                    own: own,
                    closing: _closing,
                    onClose: _close,
                  ),
        );
      },
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({
    required this.own,
    required this.opponent,
    required this.winnerName,
    required this.loserName,
    required this.isWinner,
    required this.onPrimaryTap,
  });

  final DuelParticipant own;
  final DuelParticipant opponent;
  final String winnerName;
  final String loserName;
  final bool isWinner;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('result-summary'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isWinner ? 'Victoire validée' : 'Défi terminé',
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gagnant: $winnerName · Perdant: $loserName',
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FinalScorePanel(
                  label: 'Ton score',
                  score: own.finalScore ?? own.currentScoreCache ?? 0,
                  returnPct:
                      own.finalReturnPct ?? own.currentReturnPctCache ?? 0,
                  highlight: isWinner,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FinalScorePanel(
                  label: 'Score adverse',
                  score: opponent.finalScore ?? opponent.currentScoreCache ?? 0,
                  returnPct:
                      opponent.finalReturnPct ??
                      opponent.currentReturnPctCache ??
                      0,
                  highlight: !isWinner,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onPrimaryTap,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Afficher le verdict'),
          ),
        ],
      ),
    );
  }
}

class _ResultShowdownCard extends StatelessWidget {
  const _ResultShowdownCard({
    required this.own,
    required this.opponent,
    required this.winnerName,
    required this.loserName,
    required this.isWinner,
  });

  final DuelParticipant own;
  final DuelParticipant opponent;
  final String winnerName;
  final String loserName;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final winnerScore =
        isWinner
            ? own.finalScore ?? own.currentScoreCache ?? 0
            : opponent.finalScore ?? opponent.currentScoreCache ?? 0;
    final loserScore =
        isWinner
            ? opponent.finalScore ?? opponent.currentScoreCache ?? 0
            : own.finalScore ?? own.currentScoreCache ?? 0;
    final winnerReturn =
        isWinner
            ? own.finalReturnPct ?? own.currentReturnPctCache ?? 0
            : opponent.finalReturnPct ?? opponent.currentReturnPctCache ?? 0;
    final loserReturn =
        isWinner
            ? opponent.finalReturnPct ?? opponent.currentReturnPctCache ?? 0
            : own.finalReturnPct ?? own.currentReturnPctCache ?? 0;

    return Container(
      key: const ValueKey<String>('result-showdown'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7F2DF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1900),
        curve: Curves.easeInOutCubic,
        builder: (context, value, _) {
          final loserOffset = Offset(-1.4 * value, 0);
          final winnerScale = 1 + (0.12 * value);
          final flareOpacity = (value * 1.15).clamp(0.0, 1.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Résultat du duel',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Le score gagnant prend le dessus et pousse le perdant hors de l’arène.',
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 274,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 4,
                      right: 6,
                      child: Opacity(
                        opacity: flareOpacity,
                        child: Transform.scale(
                          scale: 0.75 + (value * 0.35),
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  detailsColor1.withValues(alpha: 0.34),
                                  detailsColor1.withValues(alpha: 0.02),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 18,
                      left: 0,
                      right: 0,
                      child: Align(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: detailsColor1.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            '${isWinner ? winnerName : loserName} prend l’ascendant',
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 36,
                      top: 74,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 1500),
                        offset: loserOffset,
                        curve: Curves.easeInOutCubic,
                        child: Opacity(
                          opacity: 1 - value.clamp(0, 1),
                          child: _FinalScorePanel(
                            label: isWinner ? loserName : winnerName,
                            score: loserScore,
                            returnPct: loserReturn,
                            highlight: false,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 0,
                      bottom: 0,
                      child: Transform.scale(
                        scale: winnerScale,
                        alignment: Alignment.center,
                        child: _FinalScorePanel(
                          label: isWinner ? winnerName : loserName,
                          score: winnerScore,
                          returnPct: winnerReturn,
                          highlight: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultDecisionCard extends StatelessWidget {
  const _ResultDecisionCard({
    required this.own,
    required this.opponent,
    required this.winnerName,
    required this.loserName,
    required this.isWinner,
    required this.claiming,
    required this.onPrimaryTap,
  });

  final DuelParticipant own;
  final DuelParticipant opponent;
  final String winnerName;
  final String loserName;
  final bool isWinner;
  final bool claiming;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    final winnerScore =
        isWinner
            ? own.finalScore ?? own.currentScoreCache ?? 0
            : opponent.finalScore ?? opponent.currentScoreCache ?? 0;

    return Container(
      key: const ValueKey<String>('result-decision'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isWinner
                  ? [detailsColor1.withValues(alpha: 0.18), Colors.white]
                  : [const Color(0xFFFCE7E4), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isWinner
                      ? detailsColor1.withValues(alpha: 0.18)
                      : const Color(0xFFFFE2DB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isWinner ? 'Récompense prête' : 'Bilan du défi',
              style: TextStyle(
                color: isWinner ? detailsColor2 : const Color(0xFF9E3E32),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isWinner ? winnerName : loserName,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isWinner
                ? 'Le score gagnant écrase désormais l’arène.'
                : '$winnerName remporte officiellement ce duel.',
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          _FinalScorePanel(
            label: 'Score gagnant',
            score: winnerScore,
            returnPct:
                isWinner
                    ? own.finalReturnPct ?? own.currentReturnPctCache ?? 0
                    : opponent.finalReturnPct ??
                        opponent.currentReturnPctCache ??
                        0,
            highlight: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: claiming ? null : onPrimaryTap,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child:
                claiming
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                    : Text(
                      isWinner
                          ? 'Récupérer récompense'
                          : 'Voir ce que tu as perdu',
                    ),
          ),
        ],
      ),
    );
  }
}

class _ResultRewardCard extends StatelessWidget {
  const _ResultRewardCard({
    required this.isWinner,
    required this.winnerName,
    required this.own,
    required this.closing,
    required this.onClose,
  });

  final bool isWinner;
  final String winnerName;
  final DuelParticipant own;
  final bool closing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final payload = isWinner ? own.rewardPosition : own.lossPosition;
    final title = isWinner ? 'Ligne récupérée' : 'Ligne perdue';
    final headline =
        isWinner
            ? 'Bravo, $winnerName prend l’avantage.'
            : '$winnerName remporte ce duel.';
    final accent = isWinner ? detailsColor1 : const Color(0xFFDF6B57);

    return Container(
      key: const ValueKey<String>('result-reward'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isWinner
                  ? [detailsColor1.withValues(alpha: 0.20), Colors.white]
                  : [const Color(0xFFFCE7E4), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isWinner
                        ? Icons.workspace_premium_rounded
                        : Icons.layers_clear_rounded,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isWinner ? 'Récompense capturée' : 'Ligne retirée',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            headline,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (payload != null)
            _RewardPositionCard(payload: payload, accent: accent)
          else
            const Text(
              'Aucune ligne détaillée n’a pu être affichée. Le transfert a déjà été traité côté backend.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: closing ? null : onClose,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: accent.withValues(alpha: 0.28)),
            ),
            child:
                closing
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                    : const Text('Retour à l’espace social'),
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Règles de la V1',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          SizedBox(height: 10),
          _RuleLine(
            text:
                'Matchmaking sur valeur portefeuille, réserve coins et niveau.',
          ),
          _RuleLine(
            text:
                'Invitation valable 48h, un seul slot duel/invitation par joueur.',
          ),
          _RuleLine(text: 'Durée fixe: 7 jours à partir de l’acceptation.'),
          _RuleLine(
            text:
                'Score hybride: performance + bonus de structure - malus de concentration.',
          ),
          _RuleLine(
            text:
                'Pendant le duel, la dernière ligne du portefeuille de jeu ne peut pas être vendue.',
          ),
          _RuleLine(
            text:
                'Le gagnant récupère une ligne aléatoire du portefeuille du perdant.',
          ),
          _RuleLine(
            text:
                'Espionnage V2: perf 250/500/900 coins, nombre de lignes 650 coins, ligne révélée 1400 coins.',
          ),
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.fiber_manual_record_rounded,
              size: 12,
              color: detailsColor2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchmakingLaunchCard extends StatelessWidget {
  const _MatchmakingLaunchCard({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback? onTap;

  static const String _duelSvg = '''
<svg viewBox="0 0 340 220" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#2A0F45"/>
    </linearGradient>
  </defs>
  <rect x="16" y="20" width="128" height="78" rx="24" fill="url(#g1)" opacity="0.95"/>
  <rect x="196" y="122" width="128" height="78" rx="24" fill="url(#g1)" opacity="0.95"/>
  <circle cx="96" cy="60" r="18" fill="white" opacity="0.9"/>
  <circle cx="244" cy="160" r="18" fill="white" opacity="0.9"/>
  <path d="M130 74 C170 90 180 120 210 138" stroke="white" stroke-width="8" fill="none" stroke-linecap="round"/>
  <path d="M190 92 L214 96 L204 115" fill="none" stroke="white" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M54 142 C92 108 136 108 170 126" stroke="white" stroke-width="7" fill="none" opacity="0.55" stroke-linecap="round"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.97, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.62,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE6E8EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        detailsColor1.withValues(alpha: 0.12),
                        detailsColor2.withValues(alpha: 0.07),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      Positioned.fill(child: SvgPicture.string(_duelSvg)),
                      Align(
                        alignment: Alignment.topRight,
                        child:
                            loading
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                  ),
                                )
                                : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    '1 semaine',
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Lancer un duel',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  enabled
                      ? 'Recherche un adversaire au profil de portefeuille proche du tien.'
                      : 'Le matchmaking se débloque dès que ton portefeuille de jeu vaut au moins 10k coins avec 1 ligne minimum.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(
                    loading ? 'Recherche...' : 'Démarrer le matchmaking',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpponentPreview extends StatelessWidget {
  const _OpponentPreview({required this.snapshot});

  final Map<String, dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: detailsColor2.withValues(alpha: 0.14),
            child: const Icon(Icons.person_rounded, color: detailsColor2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (snapshot['displayName'] as String? ?? 'Joueur').trim(),
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Niveau ${(snapshot['level'] as num?)?.toInt() ?? 1} · Valeur ${_formatCoins((snapshot['holdingsValueEstimate'] as num?)?.toDouble() ?? 0)}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredOpponentCard extends StatelessWidget {
  const _BlurredOpponentCard({
    required this.profile,
    required this.teaserLine,
    required this.performanceTier,
  });

  final DuelProfile profile;
  final Map<String, dynamic>? teaserLine;
  final int performanceTier;

  static const String _radarSvg = '''
<svg viewBox="0 0 360 140" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="radarGrad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#D4AF37" stop-opacity="0.9"/>
      <stop offset="100%" stop-color="#2A0F45" stop-opacity="0.95"/>
    </linearGradient>
  </defs>
  <rect x="12" y="18" width="128" height="86" rx="22" fill="url(#radarGrad)" opacity="0.9"/>
  <rect x="220" y="30" width="110" height="62" rx="18" fill="#FFFFFF" opacity="0.92"/>
  <circle cx="74" cy="60" r="18" fill="#FFFFFF" opacity="0.92"/>
  <path d="M56 88 C82 76 100 62 128 44" stroke="#FFFFFF" stroke-width="7" fill="none" stroke-linecap="round"/>
  <path d="M232 72 C248 54 264 56 278 64 C292 72 304 72 320 48" stroke="#2A0F45" stroke-width="6" fill="none" stroke-linecap="round"/>
  <circle cx="246" cy="70" r="4" fill="#D4AF37"/>
  <circle cx="282" cy="64" r="4" fill="#D4AF37"/>
  <circle cx="320" cy="48" r="5" fill="#D4AF37"/>
  <rect x="222" y="98" width="36" height="8" rx="4" fill="#2A0F45" opacity="0.25"/>
  <rect x="264" y="98" width="54" height="8" rx="4" fill="#2A0F45" opacity="0.15"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    final teaserLabel = _teaserLineLabel(teaserLine);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9F5E8), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [detailsColor1, detailsColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.visibility_off_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName.isEmpty
                          ? 'Adversaire verrouillé'
                          : profile.displayName,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Radar actif · ${performanceTier.clamp(0, 3)}/3 reveals perf',
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                builder: (context, value, _) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: detailsColor1.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: detailsColor1.withValues(alpha: 0.45),
                            blurRadius: 16,
                            spreadRadius: value * 3,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 112,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9DDB2)),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: SvgPicture.string(_radarSvg)),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List<Widget>.generate(
                      3,
                      (index) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              index < performanceTier
                                  ? detailsColor2
                                  : detailsColor2.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Perf ${index + 1}',
                          style: TextStyle(
                            color:
                                index < performanceTier
                                    ? Colors.white
                                    : detailsColor2,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering_rounded, color: detailsColor2),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    teaserLabel,
                    style: const TextStyle(
                      color: Colors.black87,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelDeck extends StatelessWidget {
  const _IntelDeck({
    required this.duelId,
    required this.ownParticipant,
    required this.opponentParticipant,
    required this.opponentProfile,
    required this.busyAction,
    required this.onBuyPerformance,
    required this.onBuyPositions,
    required this.onBuyLine,
  });

  final String duelId;
  final DuelParticipant ownParticipant;
  final DuelParticipant opponentParticipant;
  final DuelProfile opponentProfile;
  final String? busyAction;
  final VoidCallback onBuyPerformance;
  final VoidCallback onBuyPositions;
  final VoidCallback onBuyLine;

  @override
  Widget build(BuildContext context) {
    final nextPerformanceCost = DuelService.nextPerformanceRevealCost(
      ownParticipant.performanceRevealTier,
    );
    final performanceLabel = _performanceRevealLabel(
      tier: ownParticipant.performanceRevealTier,
      value: opponentParticipant.currentReturnPctCache,
    );
    final positionsCount =
        opponentParticipant.currentPositionsCountCache ??
        opponentProfile.positionsCount;
    final linesLabel =
        ownParticipant.hasUnlockedPositionsCount
            ? '$positionsCount ligne(s) détectée(s)'
            : 'Nombre de lignes encore flouté';
    final revealedLine = ownParticipant.revealedLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BlurredOpponentCard(
          profile: opponentProfile,
          teaserLine: opponentParticipant.teaserLine,
          performanceTier: ownParticipant.performanceRevealTier,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF7F2DF), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6E8EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.radar_rounded, color: detailsColor2, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Espionnage tactique',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Affûte ta lecture adverse avec des reveals progressifs. Dépense totale: ${_formatCoins(ownParticipant.spyCoinsSpent)} coins.',
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _IntelMetricCard(
                      label: 'Fourchette perf',
                      value: performanceLabel,
                      accent: detailsColor2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _IntelMetricCard(
                      label: 'Lignes adverses',
                      value: linesLabel,
                      accent: detailsColor1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _IntelActionButton(
                      title:
                          nextPerformanceCost == null
                              ? 'Performance max'
                              : 'Affiner la perf',
                      subtitle:
                          nextPerformanceCost == null
                              ? 'Fourchette minimale atteinte'
                              : '$nextPerformanceCost coins',
                      enabled: nextPerformanceCost != null,
                      loading: busyAction == 'performance',
                      onTap: onBuyPerformance,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _IntelActionButton(
                      title:
                          ownParticipant.hasUnlockedPositionsCount
                              ? 'Lignes révélées'
                              : 'Révéler les lignes',
                      subtitle:
                          ownParticipant.hasUnlockedPositionsCount
                              ? 'Achat déjà effectué'
                              : '${DuelService.positionsRevealCost} coins',
                      enabled: !ownParticipant.hasUnlockedPositionsCount,
                      loading: busyAction == 'positions',
                      onTap: onBuyPositions,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _IntelActionButton(
                title:
                    revealedLine == null
                        ? 'Révéler une ligne'
                        : 'Ligne adverse détectée',
                subtitle:
                    revealedLine == null
                        ? '${DuelService.lineRevealCost} coins'
                        : '${revealedLine['displayName'] ?? revealedLine['symbol'] ?? 'Ligne'}',
                enabled: revealedLine == null,
                loading: busyAction == 'line',
                onTap: onBuyLine,
                fullWidth: true,
              ),
              if (revealedLine != null) ...[
                const SizedBox(height: 12),
                _RewardPositionCard(
                  payload: revealedLine,
                  accent: detailsColor2,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IntelMetricCard extends StatelessWidget {
  const _IntelMetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelActionButton extends StatelessWidget {
  const _IntelActionButton({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.loading,
    required this.onTap,
    this.fullWidth = false,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled && !loading ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.62,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              loading
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                  : Icon(
                    enabled ? Icons.lock_open_rounded : Icons.check_rounded,
                    color: Colors.white,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

String _performanceRevealLabel({required int tier, required double? value}) {
  if (value == null) {
    return tier == 0 ? 'Donnée masquée' : 'Synchronisation en attente';
  }

  if (tier <= 0) return 'Donnée masquée';
  final widths = <double>[6.0, 3.0, 1.2];
  final clampedTier = tier.clamp(1, widths.length);
  final width = widths[clampedTier - 1];
  final lower = value - width;
  final upper = value + width;
  return '${lower >= 0 ? '+' : ''}${lower.toStringAsFixed(1)}% → ${upper >= 0 ? '+' : ''}${upper.toStringAsFixed(1)}%';
}

String _teaserLineLabel(Map<String, dynamic>? teaserLine) {
  if (teaserLine == null) {
    return 'Signal faible: la lecture adverse reste brouillée tant qu’aucun reveal n’a été acheté.';
  }

  final displayName =
      (teaserLine['displayName'] as String? ??
              teaserLine['symbol'] as String? ??
              'Actif')
          .trim();
  final quoteType = (teaserLine['quoteType'] as String? ?? '').trim();
  final symbol = (teaserLine['symbol'] as String? ?? '').trim();
  final maskedName =
      displayName.length <= 3
          ? displayName.toUpperCase()
          : '${displayName.substring(0, 3).toUpperCase()}•••';
  final maskedSymbol =
      symbol.isEmpty
          ? ''
          : ' · ${symbol.characters.take(1).toString().toUpperCase()}••';
  final typeLabel = quoteType.isEmpty ? 'signal marché' : quoteType;
  return 'Signal capté: $maskedName$maskedSymbol · $typeLabel';
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding, required this.onTap});

  final DuelHolding holding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pnlPct =
        holding.averagePrice <= 0
            ? 0
            : ((holding.marketPrice - holding.averagePrice) /
                    holding.averagePrice) *
                100;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E8EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [detailsColor1, detailsColor2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                holding.symbol.characters.take(3).toString().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holding.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${holding.quantity.toStringAsFixed(2)} titres · PRU ${holding.averagePrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCoins(holding.marketValue),
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: pnlPct >= 0 ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardPositionCard extends StatelessWidget {
  const _RewardPositionCard({required this.payload, required this.accent});

  final Map<String, dynamic> payload;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final displayName =
        (payload['displayName'] as String? ??
                payload['symbol'] as String? ??
                'Ligne')
            .trim();
    final symbol = (payload['symbol'] as String? ?? '').trim();
    final quantity = (payload['quantity'] as num?)?.toDouble() ?? 0;
    final averagePrice = (payload['averagePrice'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            symbol,
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RewardMetric(
                  label: 'Quantité',
                  value: quantity.toStringAsFixed(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RewardMetric(
                  label: 'PRU',
                  value: averagePrice.toStringAsFixed(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardMetric extends StatelessWidget {
  const _RewardMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalScorePanel extends StatelessWidget {
  const _FinalScorePanel({
    required this.label,
    required this.score,
    required this.returnPct,
    required this.highlight,
  });

  final String label;
  final double score;
  final double returnPct;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            highlight
                ? detailsColor1.withValues(alpha: 0.12)
                : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              highlight
                  ? detailsColor2.withValues(alpha: 0.16)
                  : const Color(0xFFE6E8EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score.toStringAsFixed(2),
            style: const TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${returnPct >= 0 ? '+' : ''}${returnPct.toStringAsFixed(2)}%',
            style: TextStyle(
              color: returnPct >= 0 ? Colors.green : Colors.redAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlinePill extends StatelessWidget {
  const _DeadlinePill({required this.deadline});

  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final remaining = deadline?.difference(DateTime.now());
    final label =
        remaining == null
            ? 'Échéance inconnue'
            : remaining.isNegative
            ? 'Réponse expirée'
            : 'Réponse attendue sous ${_formatRemaining(remaining)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: detailsColor1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: detailsColor2, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreHeroCard extends StatelessWidget {
  const _ScoreHeroCard({
    required this.title,
    required this.score,
    required this.returnPct,
    required this.subtitle,
    this.premium = false,
  });

  final String title;
  final double score;
  final double returnPct;
  final String subtitle;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              premium
                  ? const [Color(0xFFF2CE63), detailsColor2]
                  : const [detailsColor1, detailsColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow:
            premium
                ? [
                  BoxShadow(
                    color: detailsColor1.withValues(alpha: 0.22),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            score.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${returnPct >= 0 ? '+' : ''}${returnPct.toStringAsFixed(2)}%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.black54, height: 1.4),
        ),
      ],
    );
  }
}

enum _CardTone { success, warning, neutral }

class _StatusInfoCard extends StatelessWidget {
  const _StatusInfoCard({
    required this.title,
    required this.subtitle,
    required this.tone,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final _CardTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (background, icon, iconColor) = switch (tone) {
      _CardTone.success => (
        const Color(0xFFF3FAF5),
        Icons.verified_rounded,
        const Color(0xFF2E8B57),
      ),
      _CardTone.warning => (
        const Color(0xFFFFF8EB),
        Icons.warning_amber_rounded,
        const Color(0xFFC28A17),
      ),
      _CardTone.neutral => (
        const Color(0xFFF7F8FA),
        Icons.info_outline_rounded,
        detailsColor2,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, height: 1.4),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _StatusInfoCard(
      title: 'État duel introuvable',
      subtitle:
          'Le document lié au duel ou à la demande est introuvable. Rafraîchis le profil pour resynchroniser l’état.',
      tone: _CardTone.warning,
      actionLabel: 'Resynchroniser',
      onAction: () {
        unawaited(onRefresh());
      },
    );
  }
}

class _DuelPageSkeleton extends StatelessWidget {
  const _DuelPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        _SkeletonBlock(height: 110),
        SizedBox(height: 14),
        _SkeletonBlock(height: 280),
        SizedBox(height: 14),
        _SkeletonBlock(height: 190),
      ],
    );
  }
}

class _DuelContentSkeleton extends StatelessWidget {
  const _DuelContentSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SkeletonBlock(height: 140),
        SizedBox(height: 12),
        _SkeletonBlock(height: 92),
        SizedBox(height: 12),
        _SkeletonBlock(height: 92),
        SizedBox(height: 12),
        _SkeletonBlock(height: 120),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
    );
  }
}

class _ActiveDuelPayload {
  const _ActiveDuelPayload({
    required this.participant,
    required this.metrics,
    required this.opponentProfile,
    required this.opponentParticipant,
  });

  final DuelParticipant participant;
  final DuelLiveMetrics metrics;
  final DuelProfile opponentProfile;
  final DuelParticipant opponentParticipant;
}

class _SettledPayload {
  const _SettledPayload({
    required this.own,
    required this.opponent,
    required this.winnerName,
    required this.loserName,
  });

  final DuelParticipant own;
  final DuelParticipant opponent;
  final String winnerName;
  final String loserName;
}

String _formatCoins(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}

String _formatRemaining(Duration duration) {
  if (duration.isNegative) return 'Terminé';
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  if (days > 0) return '${days}j ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}min';
  return '${minutes}min';
}
