import 'package:flutter/material.dart';

class HorizontalTableScroller extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final Widget? toolbarLeading;

  const HorizontalTableScroller({
    super.key,
    required this.child,
    this.controller,
    this.toolbarLeading,
  });

  @override
  State<HorizontalTableScroller> createState() =>
      _HorizontalTableScrollerState();
}

class _HorizontalTableScrollerState extends State<HorizontalTableScroller> {
  late ScrollController _controller;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _setController(widget.controller);
  }

  @override
  void didUpdateWidget(HorizontalTableScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_updateButtons);
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _setController(widget.controller);
    }
  }

  void _setController(ScrollController? controller) {
    _controller = controller ?? ScrollController();
    _controller.addListener(_updateButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateButtons());
  }

  void _updateButtons() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final canScrollLeft = position.pixels > position.minScrollExtent;
    final canScrollRight = position.pixels < position.maxScrollExtent;
    if (canScrollLeft == _canScrollLeft && canScrollRight == _canScrollRight) {
      return;
    }
    setState(() {
      _canScrollLeft = canScrollLeft;
      _canScrollRight = canScrollRight;
    });
  }

  Future<void> _scroll(double direction) async {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target =
        (position.pixels + position.viewportDimension * 0.7 * direction).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_updateButtons);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateButtons());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.toolbarLeading != null) ...[
              widget.toolbarLeading!,
              const Spacer(),
            ],
            IconButton(
              tooltip: 'Défiler vers la gauche',
              onPressed: _canScrollLeft ? () => _scroll(-1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Défiler vers la droite',
              onPressed: _canScrollRight ? () => _scroll(1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Flexible(
          fit: FlexFit.loose,
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            thickness: 12,
            radius: const Radius.circular(4),
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
