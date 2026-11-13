import 'package:flutter/widgets.dart';

/// 줄이 흐려지며 높이가 0 으로 접혀 사라지는 효과 (T-261113-024).
///
/// [collapsing] 이 true 가 되면 접기 시작하고, 다 접히면 [onCollapsed] 를 한 번 부른다.
/// 부모는 그때 저장해 목록에서 뺀다. 접히는 동안 다시 false 가 되면 원래 크기로 돌아간다.
class CollapseOut extends StatefulWidget {
  const CollapseOut({
    super.key,
    required this.collapsing,
    required this.onCollapsed,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
  });

  final bool collapsing;
  final VoidCallback onCollapsed;
  final Widget child;
  final Duration duration;

  @override
  State<CollapseOut> createState() => _CollapseOutState();
}

class _CollapseOutState extends State<CollapseOut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  )..addStatusListener(_onStatus);

  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.collapsing) _controller.reverse();
  }

  @override
  void didUpdateWidget(CollapseOut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsing && !oldWidget.collapsing) {
      _controller.reverse();
    } else if (!widget.collapsing && oldWidget.collapsing) {
      _controller.value = 1;
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && widget.collapsing) {
      widget.onCollapsed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}
