import 'ui.dart';
import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';


class TrinaBodyRows extends TrinaStatefulWidget {
  final TrinaGridStateManager stateManager;

  const TrinaBodyRows(
    this.stateManager, {
    super.key,
  });

  @override
  TrinaBodyRowsState createState() => TrinaBodyRowsState();
}

class TrinaBodyRowsState extends TrinaStateWithChange<TrinaBodyRows> {
  List<TrinaColumn> _columns = [];

  List<TrinaRow> _rows = [];
  List<TrinaRow> _frozenTopRows = [];
  List<TrinaRow> _frozenBottomRows = [];
  List<TrinaRow> _scrollableRows = [];

  late final ScrollController _verticalScroll;

  late final ScrollController _horizontalScroll;

  @override
  TrinaGridStateManager get stateManager => widget.stateManager;

  @override
  void initState() {
    super.initState();

    _horizontalScroll = stateManager.scroll.horizontal!.addAndGet();

    stateManager.scroll.setBodyRowsHorizontal(_horizontalScroll);

    _verticalScroll = stateManager.scroll.vertical!.addAndGet();

    stateManager.scroll.setBodyRowsVertical(_verticalScroll);

    updateState(TrinaNotifierEventForceUpdate.instance);
  }

  @override
  void dispose() {
    _verticalScroll.dispose();

    _horizontalScroll.dispose();

    super.dispose();
  }

  @override
  void updateState(TrinaNotifierEvent event) {
    forceUpdate();

    _columns = _getColumns();

    // Get frozen rows from the original list to keep them across pagination
    _frozenTopRows = stateManager.refRows.originalList
        .where((row) => row.frozen == TrinaRowFrozen.start)
        .toList();
    _frozenBottomRows = stateManager.refRows.originalList
        .where((row) => row.frozen == TrinaRowFrozen.end)
        .toList();

    // Get non-frozen rows from the current page
    _rows = stateManager.refRows;
    _scrollableRows =
        _rows.where((row) => row.frozen == TrinaRowFrozen.none).toList();
  }

  List<TrinaColumn> _getColumns() {
    return stateManager.showFrozenColumn == true
        ? stateManager.bodyColumns
        : stateManager.columns;
  }

  Widget _buildRow(BuildContext context, TrinaRow row, int index) {
    Widget rowWidget = TrinaBaseRow(
      key: ValueKey('body_row_${row.key}'),
      rowIdx: index,
      row: row,
      columns: _columns,
      stateManager: stateManager,
      visibilityLayout: true,
    );

    return stateManager.rowWrapper?.call(context, rowWidget, stateManager) ??
        rowWidget;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: stateManager.style.rowColor,
        borderRadius: stateManager.configuration.style.gridBorderRadius,
      ),
      child: SingleChildScrollView(
        controller: _horizontalScroll,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: CustomSingleChildLayout(
          delegate: ListResizeDelegate(stateManager, _columns),
          child: Column(
            children: [
              // Frozen top rows
              if (_frozenTopRows.isNotEmpty)
                Column(
                  children: _frozenTopRows
                      .asMap()
                      .entries
                      .map((e) => _buildRow(context, e.value, e.key))
                      .toList(),
                ),
              // Scrollable rows
              Expanded(
                child: ListView.builder(
                  controller: _verticalScroll,
                  scrollDirection: Axis.vertical,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _scrollableRows.length,
                  itemExtent: stateManager.rowWrapper != null
                      ? null
                      : stateManager.rowTotalHeight,
                  addRepaintBoundaries: false,
                  itemBuilder: (ctx, i) => _buildRow(
                      context, _scrollableRows[i], i + _frozenTopRows.length),
                ),
              ),
              // Frozen bottom rows
              if (_frozenBottomRows.isNotEmpty)
                Column(
                  children: _frozenBottomRows
                      .asMap()
                      .entries
                      .map((e) => _buildRow(
                          context,
                          e.value,
                          e.key +
                              _frozenTopRows.length +
                              _scrollableRows.length))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ListResizeDelegate extends SingleChildLayoutDelegate {
  TrinaGridStateManager stateManager;

  List<TrinaColumn> columns;

  ListResizeDelegate(this.stateManager, this.columns)
      : super(relayout: stateManager.resizingChangeNotifier);

  @override
  bool shouldRelayout(covariant SingleChildLayoutDelegate oldDelegate) {
    return true;
  }

  double _getWidth() {
    return columns.fold(
      0,
      (previousValue, element) => previousValue + element.width,
    );
  }

  @override
  Size getSize(BoxConstraints constraints) {
    return constraints.tighten(width: _getWidth()).biggest;
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return const Offset(0, 0);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.tighten(width: _getWidth());
  }
}
