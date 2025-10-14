import 'package:flutter/material.dart';
import 'package:tracex/src/extensions/entry_extensions.dart';
import 'package:tracex/src/extensions/object_extensions.dart';
import 'package:tracex/src/extensions/string_extensions.dart';
import 'package:tracex/src/highlight/json_highlight_search.dart';
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

class _TraceXDetailsScreenState extends State<TraceXDetailsScreen> with SingleTickerProviderStateMixin{
  final GlobalKey _requestBodyMatchKey = GlobalKey();
  final GlobalKey _responseBodyMatchKey = GlobalKey();
  final ScrollController _requestController = ScrollController();
  final ScrollController _responseController = ScrollController();
  late final TabController _tabController;

  bool _showSearch = false;
  String _searchQuery = '';
  int _currentMatchIndex = 0;
  int _totalMatches = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Reset search count when switching tabs
      if (_searchQuery.isNotEmpty) {
        setState(() {
          _totalMatches = _countMatches(_searchQuery);
          _currentMatchIndex = 0;
        });
      }
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
      _totalMatches = _countMatches(query);
    });
  }

  int _countMatches(String query) {
    if (query.isEmpty) return 0;

    final textToSearch = _tabController.index == 0
        ? widget.entry.request.body.prettyJson
        : widget.entry.response.body.prettyJson;

    final lowerText = textToSearch.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int count = 0, index = 0;
    while ((index = lowerText.indexOf(lowerQuery, index)) != -1) {
      count++;
      index += query.length;
    }

    return count;
  }

  void _goToNextMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
    });
    _scrollToCurrentMatch();
  }

  void _goToPreviousMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
    });
    _scrollToCurrentMatch();
  }

  void _scrollToCurrentMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _tabController.index == 0
          ? _requestBodyMatchKey.currentContext
          : _responseBodyMatchKey.currentContext;

      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.2,
        );
      }
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
            '${widget.entry.asReadableDuration}, ${widget.entry.response.body.toString().asReadableSize}',
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
                          child: ListView(
                            controller: _requestController,
                            children: [
                              SelectableCopiableTile(
                                title: 'METHOD',
                                subtitle: widget.entry.request.method,
                              ),
                              const Divider(height: 0.0),
                              SelectableCopiableTile(
                                title: 'URL',
                                subtitle: widget.entry.request.url,
                              ),
                              const Divider(height: 0.0),
                              SelectableCopiableTile(
                                title: 'HEADERS',
                                subtitle: widget.entry.request.headers.prettyJson,
                                highlight: true,
                              ),
                              if (widget.entry.request.method != 'GET') ...[
                                const Divider(height: 0.0),
                                SelectableCopiableTile(
                                  title: 'BODY',
                                  subtitle: widget.entry.request.body.prettyJson,
                                  highlight: true,
                                  searchQuery: _searchQuery,
                                  currentMatchIndex: _currentMatchIndex,
                                  currentMatchKey: _requestBodyMatchKey,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Scrollbar(
                          controller: _responseController,
                          child: ListView(
                            controller: _responseController,
                            children: [
                              SelectableCopiableTile(
                                title: 'STATUS CODE',
                                subtitle: widget.entry.response.statusCode.toString(),
                              ),
                              const Divider(height: 0.0),
                              SelectableCopiableTile(
                                title: 'HEADERS',
                                subtitle: widget.entry.response.headers.prettyJson,
                                highlight: true,
                              ),
                              const Divider(height: 0.0),
                              SelectableCopiableTile(
                                title: 'BODY',
                                subtitle: widget.entry.response.body.prettyJson,
                                highlight: true,
                                searchQuery: _searchQuery,
                                currentMatchIndex: _currentMatchIndex,
                                currentMatchKey: _responseBodyMatchKey,
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
          ],
        ),
      ),
    );
  }
}

class SelectableCopiableTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool highlight;
  final String searchQuery;
  final int currentMatchIndex;
  final GlobalKey? currentMatchKey;

  const SelectableCopiableTile({
    required this.title,
    required this.subtitle,
    this.highlight = false,
    this.searchQuery = '',
    this.currentMatchIndex = 0,
    this.currentMatchKey,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _copyToClipboard(context),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: highlight ? JsonHighlightSearch(
          subtitle,
          searchQuery: searchQuery,
          currentMatchIndex: currentMatchIndex,
          currentMatchKey: currentMatchKey,
        ) : Text(subtitle),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context) {
    return subtitle.copyToClipboard(context);
  }
}
