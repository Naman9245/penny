import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/quick_add.dart';
import 'package:penny/services/sms_parser.dart';

/// What the Add screen opens with: a fresh entry of [type], [editing] an
/// existing one, or an [sms] to review before it is saved.
@immutable
class AddTxnArgs {
  const AddTxnArgs.create(this.type) : editing = null, sms = null;

  AddTxnArgs.edit(Txn txn) : type = txn.type, editing = txn, sms = null;

  AddTxnArgs.fromSms(SmsTxn this.sms) : type = sms.type, editing = null;

  final TxnType type;
  final Txn? editing;

  /// An SMS already read and masked on the phone.
  final SmsTxn? sms;

  bool get isEditing => editing != null;

  // Keyed by which entry or SMS this is, not by its current field values.
  @override
  bool operator ==(Object other) =>
      other is AddTxnArgs &&
      other.type == type &&
      other.editing?.id == editing?.id &&
      other.sms?.dedupeKey == sms?.dedupeKey;

  @override
  int get hashCode => Object.hash(type, editing?.id, sms?.dedupeKey);
}

/// A bill shared with friends: what it came to, and how many ways.
typedef BillSplit = ({int totalPaise, int ways});

@immutable
class AddTxnState {
  const AddTxnState({
    required this.type,
    required this.amountText,
    required this.occurredAt,
    this.merchant,
    this.categoryId,
    this.tag,
    this.split,
  });

  final TxnType type;

  /// The keypad buffer, such as "249.5".
  final String amountText;

  /// How the amount was worked out, until the amount changes again.
  final BillSplit? split;
  final DateTime occurredAt;
  final String? merchant;

  /// The picked category. Nothing saves until ✓ is tapped.
  final String? categoryId;

  /// The user's own necessary-or-wasteful call on a spend; null leaves it
  /// to Penny.
  final TxnTag? tag;

  /// What was typed, added up.
  int get amountPaise => sumTextToPaise(amountText);

  /// What ✓ needs before it will save.
  bool get canSave => amountPaise > 0 && categoryId != null;

  static const _keep = Object();

  AddTxnState copyWith({
    TxnType? type,
    String? amountText,
    DateTime? occurredAt,
    Object? merchant = _keep,
    Object? categoryId = _keep,
    Object? tag = _keep,
    BillSplit? split,
  }) {
    return AddTxnState(
      type: type ?? this.type,
      amountText: amountText ?? this.amountText,
      occurredAt: occurredAt ?? this.occurredAt,
      merchant: identical(merchant, _keep)
          ? this.merchant
          : merchant as String?,
      categoryId: identical(categoryId, _keep)
          ? this.categoryId
          : categoryId as String?,
      tag: identical(tag, _keep) ? this.tag : tag as TxnTag?,
      // Any new amount drops the split, so only a split gives one.
      split: amountText == null ? this.split : split,
    );
  }
}

final addTxnControllerProvider = NotifierProvider.autoDispose
    .family<AddTxnController, AddTxnState, AddTxnArgs>(AddTxnController.new);

/// The entries of a kind the user logs again and again, from the last 60
/// days.
final usualEntriesProvider = StreamProvider.autoDispose
    .family<List<UsualEntry>, TxnType>((ref, type) {
      final today = ref.watch(todayProvider);
      return ref
          .watch(txnRepositoryProvider)
          .watchBetween(
            DateTime(today.year, today.month, today.day - 60),
            DateTime(today.year, today.month, today.day + 1),
          )
          .map((txns) => usualEntries(txns, type));
    });

class AddTxnController extends Notifier<AddTxnState> {
  AddTxnController(this.args);

  final AddTxnArgs args;

  @override
  AddTxnState build() {
    final sms = args.sms;
    if (sms != null) return _fromSms(sms);
    final txn = args.editing;
    if (txn == null) {
      return AddTxnState(
        type: args.type,
        amountText: '',
        occurredAt: DateTime.now(),
      );
    }
    return AddTxnState(
      type: txn.type,
      amountText: paiseToAmountText(txn.amountPaise),
      occurredAt: txn.occurredAt,
      merchant: txn.merchant,
      categoryId: txn.categoryId,
      tag: txn.tag,
    );
  }

  AddTxnState _fromSms(SmsTxn sms) {
    final now = DateTime.now();
    final at = sms.occurredAt;
    // A date without a time takes the current time of day; today's date
    // simply means now.
    final occurredAt = switch (at) {
      null => now,
      _ when sms.hasTime => at,
      _ when dayStart(at) == dayStart(now) => now,
      _ => onDay(at, now),
    };
    return AddTxnState(
      type: sms.type,
      amountText: paiseToAmountText(sms.amountPaise),
      occurredAt: occurredAt,
      merchant: sms.payee,
      categoryId: sms.suggestedCategoryId,
    );
  }

  void press(String key) =>
      state = state.copyWith(amountText: applySumKey(state.amountText, key));

  void backspace() =>
      state = state.copyWith(amountText: dropAmountKey(state.amountText));

  void clear() => state = state.copyWith(amountText: '');

  /// Splits what was typed [ways] ways, like a bill shared with friends:
  /// the sum is worked out first, then divided, to the paisa.
  void split(int ways) {
    final total = state.amountPaise;
    final share = (total / ways).round();
    if (share <= 0) return;
    state = state.copyWith(
      amountText: paiseToAmountText(share),
      split: (totalPaise: total, ways: ways),
    );
  }

  /// Fills in one of the user's usual entries; ✓ still saves it.
  void useUsual(UsualEntry entry) => state = state.copyWith(
    amountText: paiseToAmountText(entry.amountPaise),
    categoryId: entry.categoryId,
    merchant: entry.place,
  );

  /// Fills in an entry typed in one go, like "240 swiggy". Its category
  /// only goes in when none is picked yet.
  void useTyped(TypedEntry entry) => state = state.copyWith(
    amountText: paiseToAmountText(entry.amountPaise),
    merchant: entry.place,
    categoryId: state.categoryId ?? entry.categoryId,
  );

  /// Switching between Spent and Got drops a category of the other kind, and
  /// any tag, since only spends have one.
  void setType(TxnType type) {
    if (type != state.type) {
      state = state.copyWith(type: type, categoryId: null, tag: null);
    }
  }

  /// Null hands the call back to Penny.
  void setTag(TxnTag? tag) => state = state.copyWith(tag: tag);

  void setDay(DateTime day) =>
      state = state.copyWith(occurredAt: onDay(day, state.occurredAt));

  void setMerchant(String text) {
    final trimmed = text.trim();
    state = state.copyWith(merchant: trimmed.isEmpty ? null : trimmed);
  }

  void selectCategory(String categoryId) =>
      state = state.copyWith(categoryId: categoryId);

  /// Adds the entry, or updates the one being edited, and returns its id.
  /// Call only when [AddTxnState.canSave].
  Future<String> save() async {
    final repo = ref.read(txnRepositoryProvider);
    final editing = args.editing;
    final sms = args.sms;
    if (editing == null) {
      // The review screen already checked; this covers a second copy of the
      // app importing the same SMS at the same moment.
      final existing = sms == null
          ? null
          : await repo.findByDedupeKey(sms.dedupeKey);
      if (existing != null) return existing.id;
      return repo.add(
        amountPaise: state.amountPaise,
        type: state.type,
        categoryId: state.categoryId!,
        occurredAt: state.occurredAt,
        merchant: state.merchant,
        source: sms == null ? TxnSource.manual : TxnSource.share,
        dedupeKey: sms?.dedupeKey,
        payeeIsPerson: sms == null
            ? null
            : _payeeIsPerson(
                wasPerson: sms.payeeIsPerson,
                renamed: state.merchant != sms.payee,
              ),
      );
    }
    await repo.update(
      editing.id,
      amountPaise: state.amountPaise,
      type: state.type,
      categoryId: state.categoryId!,
      occurredAt: state.occurredAt,
      merchant: state.merchant,
      tag: state.type == TxnType.debit ? state.tag : null,
      payeeIsPerson: switch (editing.payeeIsPerson) {
        null => null,
        final bool wasPerson => _payeeIsPerson(
          wasPerson: wasPerson,
          renamed: state.merchant != editing.merchant,
        ),
      },
    );
    return editing.id;
  }

  /// Once a person, always a person: a renamed payee might still be one.
  /// A renamed shop becomes unknown, so its new name is checked again before
  /// anything reaches the AI.
  static bool? _payeeIsPerson({
    required bool wasPerson,
    required bool renamed,
  }) {
    if (wasPerson) return true;
    return renamed ? null : false;
  }
}
