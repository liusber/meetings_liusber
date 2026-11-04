import 'package:flutter/material.dart';

/// Fila de columnas con divisores que se arrastran para cambiar el ancho.
/// [weights] son proporciones; [onChanged] recibe las nuevas al soltar.
class ResizableRow extends StatefulWidget {
  final List<Widget> children;
  final List<double> weights;
  final ValueChanged<List<double>> onChanged;
  final double minWidth;

  const ResizableRow({
    super.key,
    required this.children,
    required this.weights,
    required this.onChanged,
    this.minWidth = 220,
  });

  @override
  State<ResizableRow> createState() => _ResizableRowState();
}

class _ResizableRowState extends State<ResizableRow> {
  static const _handle = 9.0;
  late List<double> _w = _normalized(widget.weights);

  List<double> _normalized(List<double> w) {
    final total = w.fold<double>(0, (a, b) => a + b);
    return w.map((x) => x / total).toList();
  }

  void _drag(int i, double dx, double width) {
    final min = (widget.minWidth / width).clamp(0.05, 0.3);
    final pair = _w[i] + _w[i + 1];
    final left = (_w[i] + dx / width).clamp(min, pair - min);
    setState(() {
      _w[i] = left;
      _w[i + 1] = pair - left;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      final n = widget.children.length;
      final usable = c.maxWidth - _handle * (n - 1);
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < n; i++) ...[
          SizedBox(width: usable * _w[i], child: widget.children[i]),
          if (i < n - 1)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) => _drag(i, d.delta.dx, usable),
                onHorizontalDragEnd: (_) => widget.onChanged(List.of(_w)),
                onDoubleTap: () {
                  setState(() => _w = _normalized(List.filled(n, 1)));
                  widget.onChanged(List.of(_w));
                },
                child: SizedBox(
                  width: _handle,
                  child: Center(
                    child: Container(
                      width: 1,
                      color: cs.outlineVariant,
                      alignment: Alignment.center,
                      child: OverflowBox(
                        maxWidth: 5,
                        child: Container(
                          width: 5,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cs.outline,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ]);
    });
  }
}
