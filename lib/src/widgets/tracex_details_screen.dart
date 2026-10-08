import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tracex/src/extensions/entry_extensions.dart';
import 'package:tracex/src/extensions/object_extensions.dart';
import 'package:tracex/src/extensions/string_extensions.dart';
import 'package:tracex/src/widgets/json_skeleton.dart';
import 'package:tracex/src/widgets/json_tree_viewer.dart';
import 'package:tracex/src/widgets/tracex_search_bar.dart';
import 'package:tracex/src/widgets/tracex_theme_wrapper.dart';
import 'package:tracex/tracex.dart';

enum MenuItem { copy, copyCurl, share, shareCurl }

class TraceXDetailsScreen extends StatefulWidget {
  final TraceXNetworkEntry entry;
  final TraceX instance;

  const TraceXDetailsScreen(
    this.entry, {
    required this.instance,
    super.key,
  });

  @override
  State<TraceXDetailsScreen> createState() => _TraceXDetailsScreenState();
}

class _TraceXDetailsScreenState extends State<TraceXDetailsScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _requestController = ScrollController();
  final ScrollController _responseController = ScrollController();
  late final TabController _tabController;

  bool _showSearch = false;
  String _searchQuery = '';
  int _currentMatchIndex = 0;
  int _totalMatches = 0;

  /// Search match count reported by the body viewer of each tab.
  final List<int> _matchCounts = [0, 0];

  // Encoding a large body is expensive, so do it once rather than per build,
  // and do it for the bodies off the UI thread.
  late final String _title =
      '${widget.entry.asReadableDuration}, ${widget.entry.responseSize}';
  late final String _requestHeaders = widget.entry.request.headers.prettyJson;
  late final Future<String> _requestBody =
      _prettyJsonInBackground(widget.entry.request.body);
  late final String _responseHeaders = widget.entry.response.headers.prettyJson;
  late final Future<String> _responseBody =
      _prettyJsonInBackground(widget.entry.response.body);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      // Show the active tab's match count when switching tabs
      setState(() {
        _totalMatches = _matchCounts[_tabController.index];
        _currentMatchIndex = 0;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _requestController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchQuery = '';
        _currentMatchIndex = 0;
        _totalMatches = 0;
      }
    });
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentMatchIndex = 0;
    });
  }

  void _onMatchCountChanged(int tab, int count) {
    if (_matchCounts[tab] == count) return;
    _matchCounts[tab] = count;
    if (_tabController.index == tab) {
      setState(() => _totalMatches = count);
    }
  }

  /// Formats [body] in a background isolate when it can be sent to one.
  /// Other bodies (e.g. [FormData], which holds file streams) are formatted
  /// here.
  static Future<String> _prettyJsonInBackground(Object? body) async {
    if (body is Map || body is List || body is String) {
      try {
        return await compute(_prettyJsonOf, body);
      } catch (_) {
        // Not sendable, e.g. a Map holding a custom object.
      }
    }
    return body.prettyJson;
  }

  Widget _bodyTile(int tab, Future<String> body) {
    return FutureBuilder<String>(
      future: body,
      builder: (context, snapshot) {
        final json = snapshot.data;
        if (json == null) {
          // Same padding and title row height as JsonTreeTile, so nothing
          // jumps when the tree replaces this.
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 40.0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'BODY',
                        style: Theme.of(context).listTileTheme.titleTextStyle,
                      ),
                    ),
                  ),
                  const JsonSkeleton(label: 'Formatting body…'),
                ],
              ),
            ),
          );
        }
        return JsonTreeTile(
          title: 'BODY',
          jsonString: json,
          showExpandActions: true,
          searchQuery: _searchQuery,
          currentMatchIndex: _matchIndexFor(tab),
          onMatchCountChanged: (count) => _onMatchCountChanged(tab, count),
        );
      },
    );
  }

  /// Only the active tab highlights a current match and scrolls to it.
  int _matchIndexFor(int tab) =>
      _tabController.index == tab ? _currentMatchIndex : -1;

  void _goToNextMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
    });
  }

  void _goToPreviousMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
    });
  }

  void handleClick(BuildContext context, MenuItem item) {
    switch (item) {
      case MenuItem.copy:
        final text = widget.entry.toString();
        text.copyToClipboard(context);
        break;
      case MenuItem.copyCurl:
        final cmd = widget.entry.toCurlCommand();
        cmd.copyToClipboard(context);
        break;
      case MenuItem.share:
        final text = widget.entry.toString();
        widget.instance.onShare?.call(text);
        break;
      case MenuItem.shareCurl:
        final cmd = widget.entry.toCurlCommand();
        widget.instance.onShare?.call(cmd);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TraceXThemeWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // Search button
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search (Ctrl+F)',
              onPressed: _toggleSearch,
            ),
            MenuAnchor(
              builder: (context, controller, child) {
                return IconButton(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                );
              },
              menuChildren: [
                MenuItemButton(
                  onPressed: () => handleClick(context, MenuItem.copy),
                  child: const Text('Copy'),
                ),
                MenuItemButton(
                  onPressed: () => handleClick(context, MenuItem.copyCurl),
                  child: const Text('Copy cURL'),
                ),
                SubmenuButton(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: () => handleClick(context, MenuItem.share),
                      child: const Text('Share'),
                    ),
                    MenuItemButton(
                      onPressed: () => handleClick(context, MenuItem.shareCurl),
                      child: const Text('Share cURL'),
                    ),
                  ],
                  child: const Text('Share'),
                ),
              ],
            ),
            const SizedBox(width: 12.0),
          ],
        ),
        body: Column(
          children: [
            if (_showSearch)
              TraceXSearchBar(
                onSearch: _onSearch,
                onNext: _goToNextMatch,
                onPrevious: _goToPreviousMatch,
                onClose: _toggleSearch,
                currentMatch: _currentMatchIndex + 1,
                totalMatches: _totalMatches,
              ),
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Request'),
                      Tab(text: 'Response'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        Scrollbar(
                          controller: _requestController,
                          child: CustomScrollView(
                            controller: _requestController,
                            slivers: [
                              SliverToBoxAdapter(
                                child: SelectableCopiableTile(
                                  title: 'METHOD',
                                  subtitle: widget.entry.request.method,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                  child: Divider(height: 0.0)),
                              SliverToBoxAdapter(
                                child: SelectableCopiableTile(
                                  title: 'URL',
                                  subtitle: widget.entry.request.url,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                  child: Divider(height: 0.0)),
                              JsonTreeTile(
                                title: 'HEADERS',
                                jsonString: _requestHeaders,
                              ),
                              if (widget.entry.request.method != 'GET') ...[
                                const SliverToBoxAdapter(
                                    child: Divider(height: 0.0)),
                                _bodyTile(0, _requestBody),
                              ],
                            ],
                          ),
                        ),
                        Scrollbar(
                          controller: _responseController,
                          child: CustomScrollView(
                            controller: _responseController,
                            slivers: [
                              SliverToBoxAdapter(
                                child: SelectableCopiableTile(
                                  title: 'STATUS CODE',
                                  subtitle: widget.entry.response.statusCode
                                      .toString(),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                  child: Divider(height: 0.0)),
                              JsonTreeTile(
                                title: 'HEADERS',
                                jsonString: _responseHeaders,
                              ),
                              const SliverToBoxAdapter(
                                  child: Divider(height: 0.0)),
                              _bodyTile(1, _responseBody),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-level so it can run in a background isolate via [compute].
String _prettyJsonOf(Object? body) => body.prettyJson;

class SelectableCopiableTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const SelectableCopiableTile({
    required this.title,
    required this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _copyToClipboard(context),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(subtitle),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context) {
    return subtitle.copyToClipboard(context);
  }
}

/// A sliver that displays a title and a collapsible JSON tree viewer.
class JsonTreeTile extends StatefulWidget {
  final String title;
  final String jsonString;
  final String searchQuery;
  final int currentMatchIndex;
  final ValueChanged<int>? onMatchCountChanged;

  /// Shows "Expand all" and "Collapse all" buttons next to the title.
  final bool showExpandActions;

  const JsonTreeTile({
    required this.title,
    required this.jsonString,
    this.searchQuery = '',
    this.currentMatchIndex = -1,
    this.onMatchCountChanged,
    this.showExpandActions = false,
    super.key,
  });

  @override
  State<JsonTreeTile> createState() => _JsonTreeTileState();
}

class _JsonTreeTileState extends State<JsonTreeTile> {
  final JsonTreeController _treeController = JsonTreeController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.listTileTheme.titleTextStyle,
                  ),
                ),
                if (widget.showExpandActions) ...[
                  IconButton(
                    icon: const Icon(Icons.unfold_more, size: 18.0),
                    tooltip: 'Expand all',
                    visualDensity: VisualDensity.compact,
                    onPressed: _treeController.expandAll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.unfold_less, size: 18.0),
                    tooltip: 'Collapse all',
                    visualDensity: VisualDensity.compact,
                    onPressed: _treeController.collapseAll,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.copy, size: 18.0),
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => widget.jsonString.copyToClipboard(context),
                ),
              ],
            ),
          ),
          SliverJsonTreeViewer(
            jsonString: widget.jsonString,
            searchQuery: widget.searchQuery,
            currentMatchIndex: widget.currentMatchIndex,
            onMatchCountChanged: widget.onMatchCountChanged,
            controller: _treeController,
          ),
        ],
      ),
    );
  }
}
