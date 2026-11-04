import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:penny/data/providers.dart';

/// Today pinned to [day], for screens that change with the date.
Override todayIs(DateTime day) => todayProvider.overrideWith(() => _Fixed(day));

class _Fixed extends Today {
  _Fixed(this.day);

  final DateTime day;

  @override
  DateTime build() => day;

  @override
  void check() {}
}
