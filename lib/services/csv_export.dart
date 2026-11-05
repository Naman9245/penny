import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:share_plus/share_plus.dart';

// Entries as a spreadsheet file, sent where the user chooses.

const _columns = [
  'Date',
  'Time',
  'Kind',
  'Category',
  'Place',
  'Amount (₹)',
  'Your tag',
  'Added',
];

/// [txns] as a CSV, oldest first: one row each, amounts in rupees. It
/// starts with a byte-order mark, so Excel reads ₹ right.
String entriesCsv(Iterable<Txn> txns) {
  final sorted = txns.toList()
    ..sort((a, b) {
      final when = a.occurredAt.compareTo(b.occurredAt);
      return when != 0 ? when : a.createdAt.compareTo(b.createdAt);
    });
  final rows = [
    _columns,
    for (final txn in sorted)
      [
        DateFormat('yyyy-MM-dd').format(txn.occurredAt),
        DateFormat('HH:mm').format(txn.occurredAt),
        switch (txn.kind) {
          MoneyKind.spent => 'Spent',
          MoneyKind.got => 'Got',
          MoneyKind.paidBack => 'Paid back',
          MoneyKind.invested => 'Invested',
        },
        categoryById(txn.categoryId).label,
        txn.merchant ?? '',
        (txn.amountPaise / 100).toStringAsFixed(2),
        switch (txn.tag) {
          TxnTag.necessary => 'Necessary',
          TxnTag.wasteful => 'Wasteful',
          null => '',
        },
        switch (txn.source) {
          TxnSource.manual => 'Typed',
          TxnSource.share => 'Shared SMS',
          TxnSource.sms => 'Read automatically',
        },
      ],
  ];
  return '﻿${[for (final row in rows) row.map(_cell).join(',')].join('\r\n')}\r\n';
}

/// One cell: quoted when it holds a comma, a quote or a line break, and a
/// leading =, +, - or @ made plain text, so a spreadsheet never runs it as a
/// formula.
String _cell(String value) {
  final safe = RegExp(r'^[=+\-@]').hasMatch(value) ? "'$value" : value;
  return RegExp(r'[",\r\n]').hasMatch(safe)
      ? '"${safe.replaceAll('"', '""')}"'
      : safe;
}

/// The file's name: "penny-entries-2026-11-05.csv", or the demo's.
String exportFileName(DateTime today, {required bool demo}) =>
    'penny-${demo ? 'demo-' : ''}entries-'
    '${DateFormat('yyyy-MM-dd').format(today)}.csv';

/// Hands a file to the phone's share menu. Tests put a fake in its place.
typedef ShareFile = Future<void> Function(String name, Uint8List bytes);

final shareFileProvider = Provider<ShareFile>(
  (ref) =>
      (name, bytes) => SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'text/csv')],
          fileNameOverrides: [name],
          subject: 'Penny entries',
        ),
      ),
);

/// [csv] as the bytes of a UTF-8 file.
Uint8List csvBytes(String csv) => Uint8List.fromList(utf8.encode(csv));
