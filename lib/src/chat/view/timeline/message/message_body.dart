part of '../../chat.dart';

typedef _MessageBubbleExtraAdder =
    void Function(
      Widget child, {
      required ShapeBorder shape,
      double? spacing,
      Key? key,
    });

class _ParsedMessageBody extends StatefulWidget {
  const _ParsedMessageBody({
    required this.text,
    required this.baseStyle,
    required this.linkStyle,
    required this.details,
    required this.onLinkTap,
    this.detailOpticalOffsetFactors = const <int, double>{},
    this.onLinkLongPress,
    this.contentKey,
  });

  final String text;
  final TextStyle baseStyle;
  final TextStyle linkStyle;
  final List<InlineSpan> details;
  final Map<int, double> detailOpticalOffsetFactors;
  final ValueChanged<String> onLinkTap;
  final ValueChanged<String>? onLinkLongPress;
  final Object? contentKey;

  @override
  State<_ParsedMessageBody> createState() => _ParsedMessageBodyState();
}

class _ParsedMessageBodyState extends State<_ParsedMessageBody> {
  late ParsedMessageText _parsed;
  String? _text;
  TextStyle? _baseStyle;
  TextStyle? _linkStyle;

  @override
  void initState() {
    super.initState();
    _refreshParsedText();
  }

  @override
  void didUpdateWidget(covariant _ParsedMessageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text != widget.text ||
        _baseStyle != widget.baseStyle ||
        _linkStyle != widget.linkStyle) {
      _refreshParsedText();
    }
  }

  void _refreshParsedText() {
    _text = widget.text;
    _baseStyle = widget.baseStyle;
    _linkStyle = widget.linkStyle;
    _parsed = parseMessageText(
      text: widget.text,
      baseStyle: widget.baseStyle,
      linkStyle: widget.linkStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    void handleLinkTap(String url) => widget.onLinkTap(url);

    void handleLinkLongPress(String url) {
      final linkLongPress = widget.onLinkLongPress ?? widget.onLinkTap;
      linkLongPress(url);
    }

    final textKey = widget.contentKey == null
        ? null
        : ValueKey(widget.contentKey);
    return DynamicInlineText(
      key: textKey,
      text: _parsed.body,
      details: widget.details,
      detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
      links: _parsed.links,
      onLinkTap: handleLinkTap,
      onLinkLongPress: handleLinkLongPress,
    );
  }
}

class _MessageHtmlBody extends StatefulWidget {
  const _MessageHtmlBody({
    super.key,
    required this.html,
    required this.textStyle,
    required this.textColor,
    required this.linkColor,
    required this.shouldLoadImages,
    required this.onLinkTap,
  });

  final String html;
  final TextStyle textStyle;
  final Color textColor;
  final Color linkColor;
  final bool shouldLoadImages;
  final ValueChanged<String> onLinkTap;

  @override
  State<_MessageHtmlBody> createState() => _MessageHtmlBodyState();
}

class _MessageHtmlBodyState extends State<_MessageHtmlBody> {
  static const int _maxDocumentCacheEntries = 128;
  static const int _maxDocumentCacheBytes = 16 * 1024 * 1024;
  static final LinkedHashMap<
    String,
    ({html_dom.Document document, int retainedBytes})
  >
  _documentCacheByDigest =
      LinkedHashMap<
        String,
        ({html_dom.Document document, int retainedBytes})
      >();
  static int _documentCacheBytes = 0;

  html_dom.Document? _document;
  String? _documentHtml;
  GlobalKey _htmlAnchorKey = GlobalKey();
  List<html_widget.HtmlExtension>? _extensions;
  Map<String, html_widget.Style>? _styles;
  bool? _extensionsShouldLoadImages;
  double? _styleFallbackFontSize;
  Color? _styleTextColor;
  Color? _styleLinkColor;

  @override
  void initState() {
    super.initState();
    _refreshDocument();
  }

  @override
  void didUpdateWidget(covariant _MessageHtmlBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_documentHtml != widget.html) {
      _refreshDocument();
    }
  }

  void _refreshDocument() {
    _documentHtml = widget.html;
    _document = _documentForHtml(widget.html);
    _htmlAnchorKey = GlobalKey();
  }

  static html_dom.Document _documentForHtml(String html) {
    final key = _documentCacheKey(html);
    final cached = _cachedDocumentForKey(key);
    if (cached != null) {
      try {
        return cached.clone(true);
      } on Exception {
        _removeCachedDocument(key);
      }
    }
    try {
      final document = html_parser.parse(html);
      _putCachedDocument(key, document, _documentRetainedBytes(key, html));
      return document.clone(true);
    } on Exception {
      return html_parser.parse(html);
    }
  }

  static html_dom.Document? _cachedDocumentForKey(String key) {
    final cached = _documentCacheByDigest.remove(key);
    if (cached == null) {
      return null;
    }
    _documentCacheByDigest[key] = cached;
    return cached.document;
  }

  static void _putCachedDocument(
    String key,
    html_dom.Document document,
    int retainedBytes,
  ) {
    final replaced = _documentCacheByDigest.remove(key);
    if (replaced != null) {
      _documentCacheBytes -= replaced.retainedBytes;
    }
    _documentCacheByDigest[key] = (
      document: document,
      retainedBytes: retainedBytes,
    );
    _documentCacheBytes += retainedBytes;
    while (_documentCacheByDigest.length > _maxDocumentCacheEntries ||
        _documentCacheBytes > _maxDocumentCacheBytes) {
      final removed = _documentCacheByDigest.remove(
        _documentCacheByDigest.keys.first,
      );
      if (removed == null) {
        break;
      }
      _documentCacheBytes -= removed.retainedBytes;
    }
  }

  static void _removeCachedDocument(String key) {
    final removed = _documentCacheByDigest.remove(key);
    if (removed != null) {
      _documentCacheBytes -= removed.retainedBytes;
    }
  }

  static String _documentCacheKey(String html) {
    final digest = sha256.convert(utf8.encode(html));
    return '${html.length}:$digest';
  }

  static int _documentRetainedBytes(String key, String html) =>
      key.length + utf8.encode(html).length;

  @visibleForTesting
  static void resetDocumentCacheForTesting() {
    _documentCacheByDigest.clear();
    _documentCacheBytes = 0;
  }

  @visibleForTesting
  static int get documentCacheEntryCountForTesting =>
      _documentCacheByDigest.length;

  @visibleForTesting
  static bool documentCacheClonesAreIndependentForTesting(String html) {
    resetDocumentCacheForTesting();
    final first = _documentForHtml(html);
    final second = _documentForHtml(html);
    first.body?.append(html_dom.Element.tag('span')..text = 'mutated');
    return !identical(first, second) &&
        second.body?.text.contains('mutated') != true;
  }

  void _refreshRenderInputs(double fallbackFontSize) {
    var parserInputsChanged = false;
    var extensionsChanged = false;
    void refreshExtensions() {
      _extensionsShouldLoadImages = widget.shouldLoadImages;
      _extensions = createEmailHtmlExtensions(
        shouldLoadImages: widget.shouldLoadImages,
      );
      extensionsChanged = true;
    }

    if (_extensionsShouldLoadImages != widget.shouldLoadImages) {
      refreshExtensions();
      parserInputsChanged = true;
    }
    if (_styleFallbackFontSize != fallbackFontSize ||
        _styleTextColor != widget.textColor ||
        _styleLinkColor != widget.linkColor) {
      _styleFallbackFontSize = fallbackFontSize;
      _styleTextColor = widget.textColor;
      _styleLinkColor = widget.linkColor;
      _styles = createEmailHtmlStyles(
        fallbackFontSize: fallbackFontSize,
        textColor: widget.textColor,
        linkColor: widget.linkColor,
      );
      parserInputsChanged = true;
    }
    if (parserInputsChanged) {
      if (!extensionsChanged) {
        refreshExtensions();
      }
      _htmlAnchorKey = GlobalKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final fallbackFontSize =
        widget.textStyle.fontSize ??
        textTheme.p.fontSize ??
        textTheme.small.fontSize ??
        context.sizing.menuItemIconSize;
    _refreshRenderInputs(fallbackFontSize);
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: double.infinity,
        child: html_widget.Html.fromDom(
          anchorKey: _htmlAnchorKey,
          document: _document,
          shrinkWrap: false,
          extensions: _extensions!,
          style: _styles!,
          onLinkTap: (url, _, _) {
            if (url == null) {
              return;
            }
            widget.onLinkTap(url);
          },
        ),
      ),
    );
  }
}

@visibleForTesting
void resetMessageHtmlDocumentCacheForTesting() {
  _MessageHtmlBodyState.resetDocumentCacheForTesting();
}

@visibleForTesting
int messageHtmlDocumentCacheEntryCountForTesting() {
  return _MessageHtmlBodyState.documentCacheEntryCountForTesting;
}

@visibleForTesting
bool messageHtmlDocumentCacheClonesAreIndependentForTesting(String html) {
  return _MessageHtmlBodyState.documentCacheClonesAreIndependentForTesting(
    html,
  );
}

class _MessageHtmlWebViewBody extends StatelessWidget {
  const _MessageHtmlWebViewBody({
    super.key,
    required this.html,
    required this.loadingHtml,
    required this.rawHtml,
    required this.diagnosticContentKey,
    required this.textStyle,
    required this.backgroundColor,
    required this.textColor,
    required this.linkColor,
    required this.baseFontSize,
    required this.shouldLoadImages,
    required this.contentMode,
    required this.initialContentHeight,
    required this.onLinkTap,
    required this.onContentHeightChanged,
    this.paintContent = true,
  });

  final String html;
  final String loadingHtml;
  final String? rawHtml;
  final Object diagnosticContentKey;
  final TextStyle textStyle;
  final Color backgroundColor;
  final Color textColor;
  final Color linkColor;
  final double baseFontSize;
  final bool shouldLoadImages;
  final EmailHtmlContentMode contentMode;
  final double? initialContentHeight;
  final ValueChanged<String> onLinkTap;
  final ValueChanged<double> onContentHeightChanged;
  final bool paintContent;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    return SizedBox(
      width: double.infinity,
      child: EmailHtmlWebView.embedded(
        html: html,
        allowRemoteImages: shouldLoadImages,
        diagnosticContentKey: diagnosticContentKey,
        diagnosticRawHtml: rawHtml,
        diagnosticFlutterHtml: loadingHtml,
        paintContent: paintContent,
        minHeight: sizing.attachmentPreviewExtent,
        backgroundColor: backgroundColor,
        textColor: textColor,
        linkColor: linkColor,
        baseFontSize: baseFontSize,
        contentMode: contentMode,
        initialContentHeight: initialContentHeight,
        onContentHeightChanged: onContentHeightChanged,
        loadingFallback: _MessageHtmlBody(
          html: loadingHtml,
          textStyle: textStyle,
          textColor: textColor,
          linkColor: linkColor,
          shouldLoadImages: false,
          onLinkTap: onLinkTap,
        ),
        simplifyLayout: true,
        onLinkTap: onLinkTap,
      ),
    );
  }
}
