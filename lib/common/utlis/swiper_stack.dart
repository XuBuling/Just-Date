// ignore_for_file: unnecessary_null_comparison, sort_child_properties_last

import 'dart:math';

import 'package:flutter/widgets.dart';

enum SwiperPosition { none, left, right }

enum StackFrom { none, top, left, right, bottom }

class SwiperItem {
  Widget Function(SwiperPosition, double progress) builder;

  SwiperItem({required this.builder});
}

class SwipeStack extends StatefulWidget {
  final List<SwiperItem> children;
  final int maxAngle;
  final int threshold;
  final StackFrom stackFrom;
  final int visibleCount;
  final int translationInterval;
  final double scaleInterval;
  final Duration animationDuration;
  final int historyCount;
  final void Function(int, SwiperPosition)? onSwipe;
  final void Function(int, SwiperPosition)? onRewind;
  final void Function()? onEnd;
  final EdgeInsetsGeometry padding;

  const SwipeStack(
      {required Key key,
      required this.children,
      this.maxAngle = 35,
      this.threshold = 30,
      this.stackFrom = StackFrom.none,
      this.visibleCount = 2,
      this.translationInterval = 0,
      this.scaleInterval = 0,
      this.animationDuration = const Duration(milliseconds: 200),
      this.historyCount = 1,
      this.onEnd,
      this.onSwipe,
      this.onRewind,
      this.padding = const EdgeInsets.symmetric(vertical: 20, horizontal: 25)})
      : assert(maxAngle >= 0 && maxAngle <= 360),
        assert(threshold >= 1 && threshold <= 100),
        assert(visibleCount >= 2),
        assert(translationInterval >= 0),
        assert(scaleInterval >= 0),
        assert(historyCount >= 0),
        super(key: key);

  @override
  SwipeStackState createState() => SwipeStackState();
}

class SwipeStackState extends State<SwipeStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animationX;
  late Animation<double> _animationY;
  late Animation<double> _animationAngle;

  double _left = 0;
  double _top = 0;
  double _angle = 0;
  double _maxAngle = 0;
  double _progress = 0;
  double _centerSlow = 1;
  SwiperPosition _currentItemPosition = SwiperPosition.none;
  final List<Map<String, dynamic>> _history = [];

  final Map<StackFrom, Alignment> _alignment = {
    StackFrom.left: Alignment.centerLeft,
    StackFrom.top: Alignment.topCenter,
    StackFrom.right: Alignment.centerRight,
    StackFrom.bottom: Alignment.bottomCenter,
    StackFrom.none: Alignment.center
  };

  bool _isTop = false;
  bool _isLeft = false;

  int _animationType = 0;
  // 0 None, 1 move, 2 manuel, 3 rewind

  late BoxConstraints _baseContainerConstraints;

  int get currentIndex => widget.children.length - 1;

  @override
  void initState() {
    if (widget.maxAngle > 0) _maxAngle = widget.maxAngle * (pi / 180);

    _animationController =
        AnimationController(duration: widget.animationDuration, vsync: this);

    _animationController.addListener(() {
      if (_animationController.status == AnimationStatus.forward) {
        if (_animationX != null) _left = _animationX.value;

        if (_animationY != null) _top = _animationY.value;

        if (_animationType != 1 && _animationAngle != null) {
          _angle = _animationAngle.value;
        }

        _progress = (100 / _baseContainerConstraints.maxWidth) * _left.abs();
        _currentItemPosition = (_left.toInt() == 0)
            ? SwiperPosition.none
            : (_left < 0)
                ? SwiperPosition.left
                : SwiperPosition.right;

        setState(() {});
      }
    });

    _animationController.addStatusListener((AnimationStatus animationStatus) {
      if (animationStatus == AnimationStatus.completed) {
        // history
        if (_animationType != 3 && _animationType != 0) {
          if (widget.historyCount > 0) {
            _history.add({
              "item": widget.children[widget.children.length - 1],
              "position": _currentItemPosition,
              "left": _left,
              "top": _top,
              "angle": _angle
            });

            if (_history.length > widget.historyCount) _history.removeAt(0);
          }
        } else if (_animationType == 3) {
          if (widget.onRewind != null) {
            widget.onRewind!(widget.children.length - 1,
                _history[_history.length - 1]["position"]);
          }
          _history.removeAt(_history.length - 1);
        }

        if (_animationType != 0 && _animationType != 3) {
          widget.children.removeAt(widget.children.length - 1);

          if (widget.onSwipe != null) {
            widget.onSwipe!(widget.children.length, _currentItemPosition);
          }

          if (widget.children.isEmpty && widget.onEnd != null) {
            widget.onEnd!();
          }
        }

        _left = 0;
        _top = 0;
        _angle = 0;
        _progress = 0;
        _currentItemPosition = SwiperPosition.none;
        _animationType = 0;
        setState(() {});
        _animationController.reset();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      _baseContainerConstraints = constraints;

      if (widget.children.isEmpty) return Container();

      return Container(
        padding: widget.padding,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: widget.children
                  .asMap()
                  .map((int index, _) {
                    return MapEntry(index, _item(constraints, index));
                  })
                  .values
                  .toList(),
            );
          },
        ),
      );
    });
  }

  Widget _item(BoxConstraints constraints, int index) {
    if (index != widget.children.length - 1) {
      double scaleReduced =
          (widget.scaleInterval * (widget.children.length - index));
      scaleReduced -= ((widget.scaleInterval * 2) / 100) * _progress;
      final double scale = 1 - scaleReduced;

      double positionReduced =
          ((widget.translationInterval * (widget.children.length - index - 1)))
              .toDouble();
      positionReduced -= (widget.translationInterval / 100) * _progress;
      final double position = positionReduced * -1;

      return Visibility(
        visible: (widget.children.length - index) <= widget.visibleCount,
        child: Positioned(
            top: widget.stackFrom == StackFrom.top ? position : null,
            left: widget.stackFrom == StackFrom.left ? position : null,
            right: widget.stackFrom == StackFrom.right ? position : null,
            bottom: widget.stackFrom == StackFrom.bottom ? position : null,
            child: Transform.scale(
                scale: scale,
                alignment: _alignment[widget.stackFrom],
                child: Container(
                    constraints: constraints,
                    child: widget.children[index]
                        .builder(SwiperPosition.none, 0)))),
      );
    }

    if (widget.maxAngle > 0 &&
        _animationController.status != AnimationStatus.forward) {
      _angle = ((_maxAngle / 100) * _progress) * _centerSlow;
      _angle = _angle *
          ((_isTop && _isLeft)
              ? 1
              : (!_isTop && !_isLeft)
                  ? 1
                  : -1);
    }

    return Positioned(
      left: _left,
      top: _top,
      child: GestureDetector(
          child: Transform.rotate(
            angle: _angle,
            child: Container(
                constraints: constraints,
                child: widget.children[index]
                    .builder(_currentItemPosition, _progress)),
          ),
          onPanStart: (DragStartDetails dragStartDetails) {
            RenderBox getBox = context.findRenderObject() as RenderBox;
            var local = getBox.globalToLocal(dragStartDetails.globalPosition);

            _isLeft = local.dx < getBox.size.width / 2;
            _isTop = local.dy < getBox.size.height / 2;

            double halfHeight = getBox.size.height / 2;
            _centerSlow = ((halfHeight - local.dy) * (1 / halfHeight)).abs();
          },
          onPanUpdate: (DragUpdateDetails dragUpdateDetails) {
            _left += dragUpdateDetails.delta.dx;
            _top += dragUpdateDetails.delta.dy;

            _progress =
                (100 / _baseContainerConstraints.maxWidth) * _left.abs();
            _currentItemPosition = (_left.toInt() == 0)
                ? SwiperPosition.none
                : (_left < 0)
                    ? SwiperPosition.left
                    : SwiperPosition.right;
            setState(() {});
          },
          onPanEnd: _onPandEnd),
    );
  }

  void _onPandEnd(_) {
    setState(() {});
    if (_progress < widget.threshold) {
      _goFirstPosition();
    } else {
      _animationType = 1;
      _animationX = Tween<double>(
              begin: _left,
              end: _baseContainerConstraints.maxWidth * (_left < 0 ? -1 : 1))
          .animate(_animationController);
      _animationY = Tween<double>(begin: _top, end: _top + _top)
          .animate(_animationController);
      _animationController.forward();
    }
  }

  void _goFirstPosition() {
    _animationX =
        Tween<double>(begin: _left, end: 0.0).animate(_animationController);
    _animationY =
        Tween<double>(begin: _top, end: 0.0).animate(_animationController);
    if (widget.maxAngle > 0) {
      _animationAngle =
          Tween<double>(begin: _angle, end: 0.0).animate(_animationController);
    }
    _animationController.forward();
  }

  void swipeLeft() {
    if (widget.children.isNotEmpty &&
        _animationController.status != AnimationStatus.forward) {
      _animationType = 2;
      _animationX =
          Tween<double>(begin: 0, end: _baseContainerConstraints.maxWidth * -1)
              .animate(_animationController);
      _animationY = Tween<double>(
              begin: 0, end: (_baseContainerConstraints.maxHeight / 2) * -1)
          .animate(_animationController);
      if (widget.maxAngle > 0) {
        _animationAngle = Tween<double>(begin: 0, end: _maxAngle * 0.7)
            .animate(_animationController);
      }
      _animationController.forward();
    }
  }

  void swipeRight() {
    if (widget.children.isNotEmpty &&
        _animationController.status != AnimationStatus.forward) {
      _animationType = 2;
      _animationX =
          Tween<double>(begin: 0, end: _baseContainerConstraints.maxWidth)
              .animate(_animationController);
      _animationY = Tween<double>(
              begin: 0, end: (_baseContainerConstraints.maxHeight / 2) * -1)
          .animate(_animationController);
      if (widget.maxAngle > 0) {
        _animationAngle = Tween<double>(begin: 0, end: (_maxAngle * 0.7) * -1)
            .animate(_animationController);
      }
      _animationController.forward();
    }
  }

  void rewind() {
    if (_history.isNotEmpty &&
        _animationController.status != AnimationStatus.forward) {
      _animationType = 3;

      final lastHistory = _history[_history.length - 1];

      widget.children.add(lastHistory["item"]);
      _animationX = Tween<double>(begin: lastHistory["left"], end: 0)
          .animate(_animationController);
      _animationY = Tween<double>(begin: lastHistory["top"], end: 0)
          .animate(_animationController);
      if (widget.maxAngle > 0) {
        _animationAngle = Tween<double>(begin: lastHistory["angle"], end: 0)
            .animate(_animationController);
      }

      _animationController.forward();
    }
  }

  void clearHistory() => _history.clear();

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
