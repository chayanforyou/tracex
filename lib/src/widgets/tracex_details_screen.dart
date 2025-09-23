import 'package:flutter/material.dart';
import 'package:tracex/src/extensions/entry_extensions.dart';
import 'package:tracex/src/extensions/object_extensions.dart';
import 'package:tracex/src/extensions/string_extensions.dart';
import 'package:tracex/src/widgets/tracex_theme_wrapper.dart';
import 'package:tracex/tracex.dart';

enum MenuItem { copy, copyCurl, share }

class TraceXDetailsScreen extends StatefulWidget {
  final TraceXNetworkEntry entry;

  const TraceXDetailsScreen(
    this.entry, {
    super.key,
  });

  @override
  State<TraceXDetailsScreen> createState() => _TraceXDetailsScreenState();
}

class _TraceXDetailsScreenState extends State<TraceXDetailsScreen> {
  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();

  @override
  void dispose() {
    _scrollController1.dispose();
    _scrollController2.dispose();
    super.dispose();
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
        // final text = widget.entry.toString();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TraceXThemeWrapper(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: Navigator.of(context).pop,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            '${widget.entry.asReadableDuration}, ${widget.entry.response.body.toString().asReadableSize}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            PopupMenuButton<MenuItem>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              onSelected: (item) {
                handleClick(context, item);
              },
              itemBuilder: (_) {
                return <PopupMenuEntry<MenuItem>>[
                  const PopupMenuItem<MenuItem>(
                    value: MenuItem.copy,
                    child: Text('Copy'),
                  ),
                  const PopupMenuItem<MenuItem>(
                    value: MenuItem.copyCurl,
                    child: Text('Copy cURL'),
                  ),
                  /*const PopupMenuItem<MenuItem>(
                    value: MenuItem.share,
                    child: Text('Share'),
                  ),*/
                ];
              },
            ),
            const SizedBox(width: 12.0),
          ],
        ),
        body: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Request'),
                  Tab(text: 'Response'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    Scrollbar(
                      controller: _scrollController1,
                      child: ListView(
                        controller: _scrollController1,
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
                          ),
                          if (widget.entry.request.method != 'GET') ...[
                            const Divider(height: 0.0),
                            SelectableCopiableTile(
                              title: 'BODY',
                              subtitle: widget.entry.request.body.prettyJson,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Scrollbar(
                      controller: _scrollController2,
                      child: ListView(
                        controller: _scrollController2,
                        children: [
                          SelectableCopiableTile(
                            title: 'STATUS CODE',
                            subtitle: widget.entry.response.statusCode.toString(),
                          ),
                          const Divider(height: 0.0),
                          SelectableCopiableTile(
                            title: 'HEADERS',
                            subtitle: widget.entry.response.headers.prettyJson,
                          ),
                          const Divider(height: 0.0),
                          SelectableCopiableTile(
                            title: 'BODY',
                            subtitle: widget.entry.response.body.prettyJson,
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
      ),
    );
  }
}

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
      title: SelectableText(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        onTap: () => _copyToClipboard(context),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: SelectableText(
          subtitle,
          onTap: () => _copyToClipboard(context),
        ),
      ),
      // trailing: const Icon(Icons.copy),
    );
  }

  Future<void> _copyToClipboard(BuildContext context) {
    return subtitle.copyToClipboard(context);
  }
}
