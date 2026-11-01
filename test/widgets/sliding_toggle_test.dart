import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/widgets/sliding_toggle.dart';

void main() {
  late String value;

  Widget toggle() {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => SlidingToggle<String>(
              options: const [
                ToggleOption(value: 'spent', label: 'Spent', color: AppColors.pink),
                ToggleOption(value: 'got', label: 'Got', color: AppColors.mint),
              ],
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() => value = 'spent');

  testWidgets('tapping an option selects it', (tester) async {
    await tester.pumpWidget(toggle());

    await tester.tap(find.text('Got'));
    await tester.pumpAndSettle();

    expect(value, 'got');
  });

  testWidgets('dragging the highlight across selects the other option',
      (tester) async {
    await tester.pumpWidget(toggle());

    await tester.drag(find.text('Spent'), const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(value, 'got');

    await tester.drag(find.text('Got'), const Offset(-90, 0));
    await tester.pumpAndSettle();
    expect(value, 'spent');
  });

  testWidgets('a short drag snaps back', (tester) async {
    await tester.pumpWidget(toggle());

    await tester.drag(find.text('Spent'), const Offset(15, 0));
    await tester.pumpAndSettle();

    expect(value, 'spent');
  });
}
