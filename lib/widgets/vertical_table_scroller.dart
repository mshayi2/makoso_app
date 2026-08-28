import 'package:flutter/material.dart';

class VerticalTableScroller extends StatefulWidget {
  final Widget child;

  const VerticalTableScroller({super.key, required this.child});

  @override
  State<VerticalTableScroller> createState() =>
      _VerticalTableScrollerState();
}

class _VerticalTableScrollerState extends State<VerticalTableScroller> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 12,
      radius: const Radius.circular(4),
      scrollbarOrientation: ScrollbarOrientation.right,
      child: SingleChildScrollView(
        controller: _controller,
        padding: const EdgeInsets.only(right: 16),
        child: widget.child,
      ),
    );
  }
}