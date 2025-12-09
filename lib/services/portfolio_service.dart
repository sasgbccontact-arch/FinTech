import 'package:cloud_firestore/cloud_firestore.dart';

/// Service utilitaire pour gérer les portefeuilles utilisateurs dans Firestore.
class PortfolioService {
  const PortfolioService._();

  static CollectionReference<Map<String, dynamic>> _portfoliosCollection(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('portfolios');
  }

  /// Crée un portefeuille avec un identifiant basé sur le nom (slug) et renvoie son ID.
  static Future<String> createPortfolio({required String uid, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Portfolio name cannot be empty.');
    }

    final slug = _slugify(trimmed);
    final baseId = slug.isEmpty ? 'portfolio' : slug;
    var candidateId = baseId;
    var suffix = 1;
    final collection = _portfoliosCollection(uid);

    while (true) {
      final docRef = collection.doc(candidateId);
      final snap = await docRef.get();
      if (!snap.exists) {
        await docRef.set({
          'name': trimmed,
          'slug': candidateId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'positionsCount': 0,
        });
        return candidateId;
      }
      suffix += 1;
      candidateId = '$baseId-$suffix';
    }
  }

  /// Ajoute ou met à jour une position dans un portefeuille.
  static Future<void> addPosition({
    required String uid,
    required String portfolioId,
    required Map<String, dynamic> data,
  }) async {
    final symbol = (data['symbol'] as String?)?.trim();
    if (symbol == null || symbol.isEmpty) {
      throw ArgumentError('Position must include a non-empty symbol.');
    }

    final quantityValue = data['quantity'];
    final double? quantityOverride =
        quantityValue is num ? quantityValue.toDouble() : null;
    final costBasisValue = data['costBasis'];
    final double? costBasis =
        costBasisValue is num ? costBasisValue.toDouble() : null;

    final portfoliosRef = _portfoliosCollection(uid);
    final portfolioDoc = portfoliosRef.doc(portfolioId);
    final positionDoc = portfolioDoc.collection('positions').doc(symbol);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existingPosition = await transaction.get(positionDoc);

      final positionData = Map<String, dynamic>.from(data)
        ..['symbol'] = symbol
        ..['updatedAt'] = FieldValue.serverTimestamp()
        ..['lastRefreshed'] = FieldValue.serverTimestamp();

      if (quantityOverride != null) {
        positionData['quantity'] = quantityOverride;
      }

      if (!existingPosition.exists) {
        positionData['addedAt'] = FieldValue.serverTimestamp();
        positionData['quantity'] = quantityOverride ?? 1.0;
        positionData['costBasis'] = costBasis ?? data['regularMarketPrice'];
      } else if (costBasis != null) {
        positionData['costBasis'] = costBasis;
      }

      transaction.set(positionDoc, positionData, SetOptions(merge: true));

      final portfolioUpdate = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!existingPosition.exists) {
        portfolioUpdate['positionsCount'] = FieldValue.increment(1);
      }

      transaction.set(portfolioDoc, portfolioUpdate, SetOptions(merge: true));
    });
  }

  static String _slugify(String input) {
    final lower = input.trim().toLowerCase();
    final withoutDiacritics = lower
        .replaceAll(RegExp(r"[àáâãäå]"), 'a')
        .replaceAll(RegExp(r"[ç]"), 'c')
        .replaceAll(RegExp(r"[èéêë]"), 'e')
        .replaceAll(RegExp(r"[ìíîï]"), 'i')
        .replaceAll(RegExp(r"[ñ]"), 'n')
        .replaceAll(RegExp(r"[òóôõö]"), 'o')
        .replaceAll(RegExp(r"[ùúûü]"), 'u')
        .replaceAll(RegExp(r"[ýÿ]"), 'y');
    final sanitized = withoutDiacritics.replaceAll(RegExp(r"[^\w\s-]"), '');
    final collapsedSpaces = sanitized.replaceAll(RegExp(r"\s+"), '-');
    final collapsedHyphen = collapsedSpaces.replaceAll(RegExp(r"-+"), '-');
    return collapsedHyphen.replaceAll(RegExp(r"^-|-$"), '');
  }
}
