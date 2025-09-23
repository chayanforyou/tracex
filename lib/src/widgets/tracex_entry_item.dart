import 'package:flutter/material.dart';
import 'package:tracex/src/constants/tracex_colors.dart';
import 'package:tracex/src/extensions/entry_extensions.dart';
import 'package:tracex/src/extensions/string_extensions.dart';
import 'package:tracex/src/widgets/tracex_details_screen.dart';
import 'package:tracex/tracex.dart';

class TraceXEntryItem extends StatelessWidget {
  final TraceXEntry entry;

  const TraceXEntryItem(
    this.entry, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (entry is TraceXNetworkEntry) {
      return _NetworkItem(
        entry: entry as TraceXNetworkEntry,
      );
    }

    return SizedBox.shrink();
  }
}

class _NetworkItem extends StatelessWidget {
  final TraceXNetworkEntry entry;

  const _NetworkItem({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return TraceXDetailsScreen(entry);
            },
          ),
        );
      },
      title: Row(
        children: [
          _StatusIcon(entry: entry),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              entry.request.method,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (entry.response.statusCode != null)
            _StatusBadge(statusCode: entry.response.statusCode!),
        ],
      ),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.request.url,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(fontSize: 14.0),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              '${entry.timeFormatted} • ${'${entry.asReadableDuration} • ${entry.response.body.toString().asReadableSize}'}',
              style: const TextStyle(
                fontSize: 12.0,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final int statusCode;

  const _StatusBadge({
    required this.statusCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor(statusCode).withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusCode.toString(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(statusCode),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final TraceXNetworkEntry entry;

  const _StatusIcon({required this.entry});

  @override
  Widget build(BuildContext context) {
    final statusCode = entry.response.statusCode;
    
    if (statusCode == null) {
      return const Icon(
        Icons.public_off_rounded,
        color: Colors.grey,
        size: 20.0,
      );
    }

    if (statusCode >= 200 && statusCode < 300) {
      return const Icon(
        Icons.public_rounded,
        color: TraceXColors.green,
        size: 20.0,
      );
    } else if (statusCode >= 400 && statusCode < 500) {
      return const Icon(
        Icons.warning_amber_rounded,
        color: TraceXColors.orange,
        size: 20.0,
      );
    } else if (statusCode >= 500) {
      return const Icon(
        Icons.error_outline_rounded,
        color: TraceXColors.red,
        size: 20.0,
      );
    } else {
      return const Icon(
        Icons.info_outline_rounded,
        color: TraceXColors.blue,
        size: 20.0,
      );
    }
  }
}

Color _getStatusColor(int statusCode) {
  if (statusCode >= 200 && statusCode < 300) {
    return TraceXColors.green;
  } else if (statusCode >= 400 && statusCode < 500) {
    return TraceXColors.orange;
  } else if (statusCode >= 500) {
    return TraceXColors.red;
  } else {
    return TraceXColors.blue;
  }
}