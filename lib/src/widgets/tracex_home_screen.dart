import 'package:flutter/material.dart';
import 'package:tracex/src/constants/tracex_colors.dart';
import 'package:tracex/src/core/tracex_fab_state.dart';
import 'package:tracex/src/widgets/tracex_entry_item.dart';
import 'package:tracex/src/widgets/tracex_theme_wrapper.dart';
import 'package:tracex/tracex.dart';

class TraceXHomeScreen extends StatefulWidget {
  final TraceX instance;

  const TraceXHomeScreen(
    this.instance, {
    super.key,
  });

  @override
  State<TraceXHomeScreen> createState() => _TraceXHomeScreenState();
}

class _TraceXHomeScreenState extends State<TraceXHomeScreen> {
  late final TextEditingController _controller;
  late final TraceXFabState _fabState;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _fabState = TraceXFabState();
    _fabState.open();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fabState.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TraceXThemeWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: ValueListenableBuilder<List<TraceXEntry>>(
            valueListenable: widget.instance.logs,
            builder: (_, value, child) {
              return Text('Network (${value.length})');
            },
          ),
          actions: [
            IconButton(
              onPressed: () {
                widget.instance.clear();
              },
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear Logs',
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: ValueListenableBuilder<List<TraceXEntry>>(
          valueListenable: widget.instance.logs,
          builder: (_, value, child) {
            return _List(
              logs: value,
              controller: _controller,
            );
          },
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.logs,
    required this.controller,
  });

  final List<TraceXEntry> logs;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, searchWidget) {
        final String search = controller.text.toLowerCase();
        final filtered = logs.where((log) {
          return log.contents.any(
            (content) => content.toLowerCase().contains(search),
          );
        }).toList();

        return Column(
          children: [
            searchWidget!,
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(
                      hasSearchQuery: search.isNotEmpty,
                      totalLogs: logs.length,
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      padding: const EdgeInsets.only(bottom: 30),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemBuilder: (_, index) {
                        final log = filtered[index];
                        return TraceXEntryItem(log);
                      },
                      separatorBuilder: (_, index) => const Divider(height: 1),
                    ),
            ),
          ],
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search',
            border: OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: controller.clear,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasSearchQuery,
    required this.totalLogs,
  });

  final bool hasSearchQuery;
  final int totalLogs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearchQuery
                ? Icons.search_off_rounded
                : Icons.network_check_rounded,
            size: 64,
            color: TraceXColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearchQuery
                ? 'No results found'
                : totalLogs == 0
                    ? 'No network requests yet'
                    : 'No logs to display',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: TraceXColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearchQuery
                ? 'Try adjusting your search terms'
                : totalLogs == 0
                    ? 'Make some network requests to see them here'
                    : 'All logs have been cleared',
            style: TextStyle(
              fontSize: 14,
              color: TraceXColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
