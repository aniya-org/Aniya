import 'package:flutter/material.dart';

/// A search bar widget for browse screens
class BrowseSearchBar extends StatefulWidget {
  final String hintText;
  final String? initialQuery;
  final ValueChanged<String> onSearch;
  final VoidCallback? onClear;

  const BrowseSearchBar({
    super.key,
    this.hintText = 'Search...',
    this.initialQuery,
    required this.onSearch,
    this.onClear,
  });

  @override
  State<BrowseSearchBar> createState() => _BrowseSearchBarState();
}

class _BrowseSearchBarState extends State<BrowseSearchBar> {
  late TextEditingController _controller;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _isExpanded = widget.initialQuery?.isNotEmpty ?? false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit(String value) {
    if (value.trim().isNotEmpty) {
      widget.onSearch(value.trim());
    }
  }

  void _handleClear() {
    _controller.clear();
    widget.onClear?.call();
    setState(() {
      _isExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isExpanded) {
      return IconButton(
        icon: const Icon(Icons.search),
        onPressed: () {
          setState(() {
            _isExpanded = true;
          });
        },
      );
    }

    return Container(
      width: 200,
      height: 40,
      margin: const EdgeInsets.only(right: 8),
      child: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hintText,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _handleClear,
          ),
        ),
        onSubmitted: _handleSubmit,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
