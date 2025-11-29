import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/dom_parsing.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_widget/config/all.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown_widget/widget/span_node.dart';
import 'package:markdown_widget/widget/widget_visitor.dart';

/// Renders markdown (with inline HTML) for the novel reader.
class NovelMarkdownRenderer extends StatefulWidget {
  final String content;
  final bool isDarkMode;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final VoidCallback? onTap;

  const NovelMarkdownRenderer({
    super.key,
    required this.content,
    required this.isDarkMode,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    this.onTap,
  });

  @override
  State<NovelMarkdownRenderer> createState() => _NovelMarkdownRendererState();
}

class _NovelMarkdownRendererState extends State<NovelMarkdownRenderer> {
  static const double _tapMovementThreshold = 8;
  static const Duration _tapDurationThreshold = Duration(milliseconds: 250);

  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  bool _dragDetected = false;

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.position;
    _pointerDownTime = DateTime.now();
    _dragDetected = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_pointerDownPosition == null) return;
    final movement = (event.position - _pointerDownPosition!).distance;
    if (movement > _tapMovementThreshold) {
      _dragDetected = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_pointerDownPosition == null) {
      _resetPointerTracking();
      return;
    }

    final duration = DateTime.now().difference(
      _pointerDownTime ?? DateTime.now(),
    );

    if (!_dragDetected && duration <= _tapDurationThreshold) {
      widget.onTap?.call();
    }

    _resetPointerTracking();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _resetPointerTracking();
  }

  void _resetPointerTracking() {
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _dragDetected = false;
  }

  @override
  Widget build(BuildContext context) {
    final baseConfig = widget.isDarkMode
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;
    final codeWrapper = (Widget child, String? text, String? language) =>
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? const Color(0xFF1F1F1F)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        );

    final config = baseConfig.copy(
      configs: [
        widget.isDarkMode
            ? PreConfig.darkConfig.copy(wrapper: codeWrapper)
            : PreConfig().copy(wrapper: codeWrapper),
      ],
    );

    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      fontFamily: widget.fontFamily,
      color: widget.isDarkMode
          ? Colors.white.withOpacity(0.95)
          : Colors.black87,
    );

    final markdownData = widget.content.trim().isEmpty
        ? 'No content was returned for this chapter.'
        : widget.content;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: SelectionArea(
        child: DefaultTextStyle.merge(
          style: textStyle,
          child: MarkdownWidget(
            data: markdownData,
            config: config,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            selectable: false,
            markdownGenerator: MarkdownGenerator(
              textGenerator: (node, cfg, visitor) =>
                  _HtmlAwareTextNode(node.textContent, cfg, visitor),
              richTextBuilder: (span) => Text.rich(span),
            ),
          ),
        ),
      ),
    );
  }
}

final RegExp _htmlRegExp = RegExp(r'<[^>]+>', multiLine: true);

class _HtmlAwareTextNode extends ElementNode {
  final String text;
  final MarkdownConfig config;
  final WidgetVisitor visitor;

  _HtmlAwareTextNode(this.text, this.config, this.visitor);

  @override
  void onAccepted(SpanNode parent) {
    final paragraphStyle = config.p.textStyle.merge(parentStyle);
    children.clear();

    if (!_htmlRegExp.hasMatch(text)) {
      accept(TextNode(text: text, style: paragraphStyle));
      return;
    }

    final spans = _parseHtml(
      md.Text(text),
      visitor: WidgetVisitor(
        config: visitor.config,
        generators: visitor.generators,
        richTextBuilder: visitor.richTextBuilder,
      ),
      parentStyle: parentStyle,
    );

    for (final span in spans) {
      accept(span);
    }
  }
}

List<SpanNode> _parseHtml(
  md.Text node, {
  WidgetVisitor? visitor,
  TextStyle? parentStyle,
}) {
  final rawText = node.textContent.replaceAll(
    visitor?.splitRegExp ?? WidgetVisitor.defaultSplitRegExp,
    '',
  );
  if (!_htmlRegExp.hasMatch(rawText)) {
    return [TextNode(text: node.text)];
  }

  final fragment = html_parser.parseFragment(rawText);
  return _HtmlToSpanVisitor(
    visitor: visitor,
    parentStyle: parentStyle,
  ).toVisit(fragment.nodes.toList());
}

class _HtmlToSpanVisitor extends TreeVisitor {
  final List<SpanNode> _spans = [];
  final List<SpanNode> _stack = [];
  final WidgetVisitor visitor;
  final TextStyle parentStyle;

  _HtmlToSpanVisitor({WidgetVisitor? visitor, TextStyle? parentStyle})
    : visitor = visitor ?? WidgetVisitor(),
      parentStyle = parentStyle ?? const TextStyle();

  List<SpanNode> toVisit(List<dom.Node> nodes) {
    _spans.clear();
    for (final node in nodes) {
      final container = ConcreteElementNode(style: parentStyle);
      _spans.add(container);
      _stack.add(container);
      visit(node);
      _stack.removeLast();
    }
    final result = List<SpanNode>.from(_spans);
    _spans.clear();
    _stack.clear();
    return result;
  }

  @override
  void visitText(dom.Text node) {
    final last = _stack.last;
    if (last is ElementNode) {
      last.accept(TextNode(text: node.text));
    }
  }

  @override
  void visitElement(dom.Element node) {
    final localName = node.localName ?? '';
    final mdElement = md.Element(localName, []);
    mdElement.attributes.addAll(node.attributes.cast());

    SpanNode spanNode = visitor.getNodeByElement(mdElement, visitor.config);
    if (spanNode is! ElementNode) {
      final wrapper = ConcreteElementNode(tag: localName, style: parentStyle);
      wrapper.accept(spanNode);
      spanNode = wrapper;
    }

    final last = _stack.last;
    if (last is ElementNode) {
      last.accept(spanNode);
    }

    _stack.add(spanNode);
    for (final child in node.nodes.toList(growable: false)) {
      visit(child);
    }
    _stack.removeLast();
  }
}
