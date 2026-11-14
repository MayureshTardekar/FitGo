import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// Segmented control that follows the current platform's conventions.
class FitGoSegmentedControl<T extends Object> extends StatelessWidget {
  const FitGoSegmentedControl({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isApple =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    if (labels.length != values.length) {
      throw ArgumentError('values and labels must have the same length');
    }

    if (isApple) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<T>(
          groupValue: selected,
          onValueChanged: (value) {
            if (value != null) onChanged(value);
          },
          children: {
            for (var i = 0; i < values.length; i++)
              values[i]: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(labels[i]),
              ),
          },
        ),
      );
    }

    return SegmentedButton<T>(
      segments: [
        for (var i = 0; i < values.length; i++)
          ButtonSegment<T>(value: values[i], label: Text(labels[i])),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onChanged(selection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.tokens.inputRadius),
          ),
        ),
      ),
    );
  }
}
