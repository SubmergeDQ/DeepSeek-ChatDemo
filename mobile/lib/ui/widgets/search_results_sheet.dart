import 'package:flutter/material.dart';

import '../../core/ext.dart';
import '../../models/models.dart';
import 'markdown_view.dart';

Future<void> showSearchResultsSheet(
  BuildContext context,
  List<Citation> citations,
) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final scheme = sheetContext.scheme;
      return Container(
        height: MediaQuery.sizeOf(sheetContext).height,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
              child: Row(
                children: [
                  const SizedBox(width: 36),
                  Expanded(
                    child: Text(
                      l10n.searchResults,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHighest,
                      foregroundColor: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 0.6, color: scheme.outlineVariant),
            Expanded(
              child: citations.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noSessions,
                        style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.45)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: citations.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 0.6,
                        indent: 20,
                        endIndent: 20,
                        color: scheme.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final citation = citations[index];
                        return _SearchResultItem(
                          citation: citation,
                          index: index + 1,
                        );
                      },
                    ),
            ),
          ],
        ),
        ),
      );
    },
  );
}

class _SearchResultItem extends StatelessWidget {
  const _SearchResultItem({required this.citation, required this.index});

  final Citation citation;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final site = citation.siteName?.trim().isNotEmpty == true
        ? citation.siteName!.trim()
        : (Uri.tryParse(citation.url)?.host ?? '');
    final title = citation.title?.trim().isNotEmpty == true ? citation.title! : citation.url;
    final snippet = citation.snippet?.trim() ?? '';
    final date = _formatDate(citation.publishedAt);
    return InkWell(
      onTap: () => openExternal(citation.url),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SiteMark(name: site, iconUrl: citation.siteIcon),
                const SizedBox(width: 6),
                if (site.isNotEmpty)
                  Flexible(
                    child: Text(
                      site,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                if (site.isNotEmpty && date.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 1,
                    height: 12,
                    color: scheme.outlineVariant,
                  ),
                  const SizedBox(width: 6),
                ],
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.42),
                    ),
                  ),
                const Spacer(),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            if (snippet.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}/$month/$day';
}

class _SiteMark extends StatelessWidget {
  const _SiteMark({required this.name, this.iconUrl});

  final String name;
  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    final fallback = Container(
      alignment: Alignment.center,
      color: context.scheme.surfaceContainerHighest,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: context.scheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
    final url = iconUrl?.trim() ?? '';
    return Container(
      width: 18,
      height: 18,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.scheme.surfaceContainerHighest,
      ),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: 18,
              height: 18,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
