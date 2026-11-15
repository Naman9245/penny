import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/needs/recent_shops.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/sliding_toggle.dart';
import 'package:penny/widgets/page_header.dart';

/// My needs: the user's own calls on what is necessary for their living and
/// what is wasteful, by category and by shop, and a note about their life
/// for Penny. Their calls always come before Penny's.
class NeedsScreen extends ConsumerWidget {
  const NeedsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(yourRulesProvider).value ?? YourRules.none;
    final shops = ref.watch(recentShopsProvider).value ?? const <ShopSeen>[];
    final repo = ref.read(rulesRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const PageHeader(
              title: 'My needs',
              subtitle: 'Your calls come first. Penny sorts the rest.',
            ),
            const SizedBox(height: 22),
            const Text('Categories', style: AppText.h2),
            const SizedBox(height: 4),
            const Text(
              'Rent, groceries, bills, health and education are usually '
              'needs.',
              style: AppText.small,
            ),
            const SizedBox(height: 12),
            _Rules(
              rows: [
                for (final category in spendCategories)
                  (
                    key: 'need-category-${category.id}',
                    label: '${category.emoji}  ${category.label}',
                    tag: rules.categories[category.id],
                    onChanged: (TxnTag? tag) =>
                        repo.set(RuleKind.category, category.id, tag),
                  ),
              ],
            ),
            if (shops.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Your shops', style: AppText.h2),
              const SizedBox(height: 4),
              const Text(
                'From the last three months. A shop beats its category.',
                style: AppText.small,
              ),
              const SizedBox(height: 12),
              _Rules(
                rows: [
                  for (final shop in shops)
                    (
                      key: 'need-shop-${shop.key}',
                      label: shop.name,
                      tag: rules.shops[shop.key],
                      onChanged: (TxnTag? tag) =>
                          repo.set(RuleKind.shop, shop.key, tag),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            const Text('A note for Penny', style: AppText.h2),
            const SizedBox(height: 12),
            const _NoteEditor(),
          ],
        ),
      ),
    );
  }
}

typedef _RuleRow = ({
  String key,
  String label,
  TxnTag? tag,
  ValueChanged<TxnTag?> onChanged,
});

/// A card of rows, each with its own Need, Penny or Wasteful slider.
class _Rules extends StatelessWidget {
  const _Rules({required this.rows});

  static const _options = <ToggleOption<TxnTag?>>[
    ToggleOption(value: TxnTag.necessary, label: 'Need', color: AppColors.mint),
    ToggleOption(value: null, label: 'Penny', color: AppColors.lavender),
    ToggleOption(
      value: TxnTag.wasteful,
      label: 'Wasteful',
      color: AppColors.pink,
    ),
  ];

  final List<_RuleRow> rows;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      padding: EdgeInsets.zero,
      clipChild: true,
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const RowDivider(),
            Padding(
              key: ValueKey(row.key),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.label, style: AppText.bodyStrong),
                  const SizedBox(height: 8),
                  // Shrinks rather than overflowing at large text sizes.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SlidingToggle<TxnTag?>(
                      options: _options,
                      value: row.tag,
                      onChanged: row.onChanged,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the user tells Penny about their life. It goes to Gemini with the
/// month, so it says not to write names or numbers.
class _NoteEditor extends ConsumerStatefulWidget {
  const _NoteEditor();

  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  final _text = TextEditingController();
  String? _saved;
  bool _loaded = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    await ref.read(prefsRepositoryProvider).setNote(_text.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Saved. Penny reads it next time.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(pennyNoteProvider);
    if (!_loaded && note.hasValue) {
      _loaded = true;
      _saved = note.value;
      _text.text = _saved ?? '';
    } else if (note.hasValue) {
      _saved = note.value;
    }
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: AppColors.ink, width: kBorderWidth),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('penny-note'),
          controller: _text,
          minLines: 2,
          maxLines: 5,
          maxLength: PrefsRepository.maxNoteLength,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          style: AppText.body,
          decoration: const InputDecoration(
            hintText:
                'Student in a PG in Bengaluru, metro to college every day, '
                'gym matters to me…',
            filled: true,
            fillColor: AppColors.white,
            contentPadding: EdgeInsets.all(14),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Penny reads this in your report and chats. It goes to Google '
          'Gemini with your month, so leave out names and numbers.',
          style: AppText.small,
        ),
        const SizedBox(height: 12),
        BrutalButton(
          key: const ValueKey('save-note'),
          label: 'Save note',
          expand: true,
          onPressed: _text.text.trim() == (_saved ?? '') ? null : _save,
        ),
      ],
    );
  }
}
