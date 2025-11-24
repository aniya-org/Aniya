import 'package:flutter/material.dart';

/// Source selector widget for choosing between different data sources
class SourceSelector extends StatelessWidget {
  final String currentSource;
  final List<SourceOption> sources;
  final Function(String) onSourceChanged;

  const SourceSelector({
    super.key,
    required this.currentSource,
    required this.sources,
    required this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: sources.map((source) {
            final isSelected = currentSource == source.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(source.name),
                selected: isSelected,
                onSelected: (_) => onSourceChanged(source.id),
                avatar: source.icon != null
                    ? CircleAvatar(child: source.icon)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Represents a source option
class SourceOption {
  final String id;
  final String name;
  final Widget? icon;

  SourceOption({required this.id, required this.name, this.icon});
}
