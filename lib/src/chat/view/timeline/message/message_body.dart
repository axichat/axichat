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
    final inlineText = DynamicInlineText(
      key: textKey,
      text: _parsed.body,
      details: widget.details,
      detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
      links: _parsed.links,
      onLinkTap: handleLinkTap,
      onLinkLongPress: handleLinkLongPress,
    );
    return inlineText;
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
  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final fallbackFontSize =
        widget.textStyle.fontSize ??
        textTheme.p.fontSize ??
        textTheme.small.fontSize ??
        context.sizing.menuItemIconSize;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: double.infinity,
        child: html_widget.Html(
          data: widget.html,
          shrinkWrap: true,
          extensions: createEmailHtmlExtensions(
            shouldLoadImages: widget.shouldLoadImages,
          ),
          style: createEmailHtmlStyles(
            fallbackFontSize: fallbackFontSize,
            textColor: widget.textColor,
            linkColor: widget.linkColor,
          ),
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

class _MessageHtmlWebViewBody extends StatelessWidget {
  const _MessageHtmlWebViewBody({
    super.key,
    required this.html,
    required this.backgroundColor,
    required this.textColor,
    required this.linkColor,
    required this.shouldLoadImages,
    required this.onLinkTap,
  });

  final String html;
  final Color backgroundColor;
  final Color textColor;
  final Color linkColor;
  final bool shouldLoadImages;
  final ValueChanged<String> onLinkTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    return SizedBox(
      width: double.infinity,
      child: EmailHtmlWebView.embedded(
        html: html,
        allowRemoteImages: shouldLoadImages,
        minHeight: sizing.attachmentPreviewExtent,
        backgroundColor: backgroundColor,
        textColor: textColor,
        linkColor: linkColor,
        simplifyLayout: true,
        onLinkTap: onLinkTap,
      ),
    );
  }
}

class _MessageViewFullAction extends StatelessWidget {
  const _MessageViewFullAction({
    required this.self,
    required this.label,
    required this.onPressed,
  });

  final bool self;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.xs),
      child: Align(
        alignment: self ? Alignment.centerRight : Alignment.centerLeft,
        widthFactor: 1.0,
        child: AxiButton.secondary(
          size: AxiButtonSize.sm,
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}
