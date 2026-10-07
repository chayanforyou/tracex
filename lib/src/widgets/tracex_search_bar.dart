import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tracex/src/constants/tracex_colors.dart';

class TraceXSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;
  final int currentMatch;
  final int totalMatches;

  const TraceXSearchBar({
    required this.onSearch,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    required this.currentMatch,
    required this.totalMatches,
    super.key,
  });

  @override
  State<TraceXSearchBar> createState() => _TraceXSearchBarState();
}

class _TraceXSearchBarState extends State<TraceXSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  /// Searching a large body scans every node, so wait for typing to pause.
  static const _debounceDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    // Auto-focus when search bar appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8).add(EdgeInsets.only(left: 8)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search...',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                suffixIconConstraints: BoxConstraints(),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.clear),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          _debounce?.cancel();
                          _controller.clear();
                          widget.onSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: (query) {
                // Rebuild now so the clear button and counter follow the text
                setState(() {});
                _debounce?.cancel();
                _debounce = Timer(
                  _debounceDuration,
                  () => widget.onSearch(query),
                );
              },
              // onSubmitted: (_) => widget.onNext(),
            ),
          ),
          const SizedBox(width: 8),
          // Match counter
          if (_controller.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: TraceXColors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.totalMatches > 0
                    ? '${widget.currentMatch}/${widget.totalMatches}'
                    : '0/0',
                style: TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(width: 4),
          // Previous button
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            iconSize: 18,
            tooltip: 'Previous',
            onPressed: widget.totalMatches > 0 ? widget.onPrevious : null,
          ),
          // Next button
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            iconSize: 18,
            tooltip: 'Next',
            onPressed: widget.totalMatches > 0 ? widget.onNext : null,
          ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: 18,
            tooltip: 'Close',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}
