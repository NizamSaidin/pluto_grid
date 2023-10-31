import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'ui.dart';

class PlutoBaseCell extends StatelessWidget implements PlutoVisibilityLayoutChild {
  final PlutoCell cell;

  final PlutoColumn column;

  final int rowIdx;

  final PlutoRow row;

  final PlutoGridStateManager stateManager;

  final bool isLastColumn;

  const PlutoBaseCell({
    Key? key,
    required this.cell,
    required this.column,
    required this.rowIdx,
    required this.row,
    required this.stateManager,
    this.isLastColumn = false,
  }) : super(key: key);

  @override
  double get width => column.width;

  @override
  double get startPosition => column.startPosition;

  @override
  bool get keepAlive => stateManager.currentCell == cell;

  void _addGestureEvent(PlutoGridGestureType gestureType, Offset offset) {
    stateManager.eventManager!.addEvent(
      PlutoGridCellGestureEvent(
        gestureType: gestureType,
        offset: offset,
        cell: cell,
        column: column,
        rowIdx: rowIdx,
      ),
    );
  }

  void _handleOnTapUp(TapUpDetails details) {
    _addGestureEvent(PlutoGridGestureType.onTapUp, details.globalPosition);
  }

  void _handleOnLongPressStart(LongPressStartDetails details) {
    if (stateManager.selectingMode.isNone) {
      return;
    }

    _addGestureEvent(
      PlutoGridGestureType.onLongPressStart,
      details.globalPosition,
    );
  }

  void _handleOnLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (stateManager.selectingMode.isNone) {
      return;
    }

    _addGestureEvent(
      PlutoGridGestureType.onLongPressMoveUpdate,
      details.globalPosition,
    );
  }

  void _handleOnLongPressEnd(LongPressEndDetails details) {
    if (stateManager.selectingMode.isNone) {
      return;
    }

    _addGestureEvent(
      PlutoGridGestureType.onLongPressEnd,
      details.globalPosition,
    );
  }

  void _handleOnDoubleTap() {
    _addGestureEvent(PlutoGridGestureType.onDoubleTap, Offset.zero);
  }

  void _handleOnSecondaryTap(TapDownDetails details) {
    _addGestureEvent(
      PlutoGridGestureType.onSecondaryTap,
      details.globalPosition,
    );
  }

  void Function()? _onDoubleTapOrNull() {
    return stateManager.onRowDoubleTap == null ? null : _handleOnDoubleTap;
  }

  void Function(TapDownDetails details)? _onSecondaryTapOrNull() {
    return stateManager.onRowSecondaryTap == null ? null : _handleOnSecondaryTap;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Essential gestures.
      onTapUp: _handleOnTapUp,
      onLongPressStart: _handleOnLongPressStart,
      onLongPressMoveUpdate: _handleOnLongPressMoveUpdate,
      onLongPressEnd: _handleOnLongPressEnd,
      // Optional gestures.
      onDoubleTap: _onDoubleTapOrNull(),
      onSecondaryTapDown: _onSecondaryTapOrNull(),
      child: _CellContainer(
        cell: cell,
        rowIdx: rowIdx,
        row: row,
        column: column,
        isLastColumn: isLastColumn,
        cellPadding: column.cellPadding ?? stateManager.configuration.style.defaultCellPadding,
        stateManager: stateManager,
        child: _Cell(
          stateManager: stateManager,
          rowIdx: rowIdx,
          column: column,
          row: row,
          cell: cell,
        ),
      ),
    );
  }
}

class _CellContainer extends PlutoStatefulWidget {
  final PlutoCell cell;

  final PlutoRow row;

  final int rowIdx;

  final PlutoColumn column;

  final EdgeInsets cellPadding;

  final PlutoGridStateManager stateManager;

  final Widget child;

  final bool isLastColumn;

  const _CellContainer({
    required this.cell,
    required this.row,
    required this.rowIdx,
    required this.column,
    required this.cellPadding,
    required this.stateManager,
    required this.child,
    this.isLastColumn = false,
  });

  @override
  State<_CellContainer> createState() => _CellContainerState();
}

class _CellContainerState extends PlutoStateWithChange<_CellContainer> {
  BoxDecoration _decoration = const BoxDecoration();

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  @override
  void initState() {
    super.initState();

    updateState(PlutoNotifierEventForceUpdate.instance);
  }

  @override
  void updateState(PlutoNotifierEvent event) {
    final style = stateManager.style;

    final isCurrentCell = stateManager.isCurrentCell(widget.cell);

    _decoration = update(
      _decoration,
      _boxDecoration(
        hasFocus: stateManager.hasFocus,
        readOnly: widget.column.checkReadOnly(widget.row, widget.cell),
        isEditing: stateManager.isEditing,
        isCurrentCell: isCurrentCell,
        isSelectedCell: stateManager.isSelectedCell(
          widget.cell,
          widget.column,
          widget.rowIdx,
        ),
        isGroupedRowCell: stateManager.enabledRowGroups && stateManager.rowGroupDelegate!.isExpandableCell(widget.cell),
        enableCellHorizontalBorder: style.enableCellBorderHorizontal,
        enableCellVerticalBorder: style.enableCellBorderVertical,
        enableActiveColorOnDisabledCell: style.enableActiveColorOnDisabledCell,
        enableActiveColorOnReadOnlyCell: style.enableActiveColorOnReadOnlyCell,
        borderColor: style.borderColor,
        activatedBorderColor: style.activatedBorderColor,
        activatedColor: style.activatedColor,
        inactivatedBorderColor: style.inactivatedBorderColor,
        gridBackgroundColor: style.gridBackgroundColor,
        cellColorInEditState: style.cellColorInEditState,
        cellColorInReadOnlyState: style.cellColorInReadOnlyState,
        cellColorGroupedRow: style.cellColorGroupedRow,
        selectingMode: stateManager.selectingMode,
      ),
    );
  }

  Color? _currentCellColor({
    required bool readOnly,
    required bool hasFocus,
    required bool isEditing,
    required Color activatedColor,
    required Color gridBackgroundColor,
    required Color cellColorInEditState,
    required Color cellColorInReadOnlyState,
    required PlutoGridSelectingMode selectingMode,
  }) {
    if (!hasFocus) {
      return gridBackgroundColor;
    }

    if (!isEditing) {
      return selectingMode.isRow ? activatedColor : null;
    }

    return readOnly == true ? cellColorInReadOnlyState : cellColorInEditState;
  }

  BoxDecoration _boxDecoration({
    required bool hasFocus,
    required bool readOnly,
    required bool isEditing,
    required bool isCurrentCell,
    required bool isSelectedCell,
    required bool isGroupedRowCell,
    required bool enableCellVerticalBorder,
    required bool enableCellHorizontalBorder,
    required bool enableActiveColorOnDisabledCell,
    required bool enableActiveColorOnReadOnlyCell,
    required Color borderColor,
    required Color activatedBorderColor,
    required Color activatedColor,
    required Color inactivatedBorderColor,
    required Color gridBackgroundColor,
    required Color cellColorInEditState,
    required Color cellColorInReadOnlyState,
    required Color? cellColorGroupedRow,
    required PlutoGridSelectingMode selectingMode,
  }) {
    if (isCurrentCell) {
      // BorderSide borderSide = BorderSide(color: hasFocus ? activatedBorderColor : inactivatedBorderColor, width: 1);
      // double leftWidth = 1;
      // double rightWidth = 1;
      // if (!enableCellVerticalBorder && enableCellHorizontalBorder) {
      //   leftWidth = 2;
      // }
      // if (enableCellVerticalBorder || enableCellHorizontalBorder) {
      //   rightWidth = 2;
      // }
      Color borderColor = (hasFocus) ? activatedBorderColor : inactivatedBorderColor;

      if (!enableActiveColorOnDisabledCell) {
        if (widget.cell.enabled == false) {
          borderColor = inactivatedBorderColor;
        }
      }

      if (!enableActiveColorOnReadOnlyCell) {
        if (widget.column.readOnly == true) {
          borderColor = inactivatedBorderColor;
        }
      }

      return BoxDecoration(
        color: widget.cell.enabled
            ? _currentCellColor(
                hasFocus: hasFocus,
                isEditing: isEditing,
                readOnly: readOnly,
                gridBackgroundColor: gridBackgroundColor,
                activatedColor: activatedColor,
                cellColorInReadOnlyState: cellColorInReadOnlyState,
                cellColorInEditState: cellColorInEditState,
                selectingMode: selectingMode,
              )
            : cellColorInReadOnlyState,
        // border: BorderDirectional(top: borderSide, bottom: borderSide, start: borderSide.copyWith(width: leftWidth), end: borderSide.copyWith(width: rightWidth)),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      );
    } else if (isSelectedCell) {
      return BoxDecoration(
        color: widget.cell.enabled ? activatedColor : cellColorInReadOnlyState,
        border: Border.all(
          color: hasFocus ? activatedBorderColor : inactivatedBorderColor,
          width: 1,
        ),
      );
    } else {
      return BoxDecoration(
        color: isGroupedRowCell
            ? cellColorGroupedRow
            : widget.cell.enabled
                ? null
                : cellColorInReadOnlyState,
        border: (enableCellVerticalBorder && !widget.isLastColumn) ? BorderDirectional(end: BorderSide(color: borderColor, width: 1)) : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _decoration,
      child: Padding(
        padding: widget.cellPadding,
        child: widget.child,
      ),
    );
  }
}

class _Cell extends PlutoStatefulWidget {
  final PlutoGridStateManager stateManager;

  final int rowIdx;

  final PlutoRow row;

  final PlutoColumn column;

  final PlutoCell cell;

  const _Cell({
    required this.stateManager,
    required this.rowIdx,
    required this.row,
    required this.column,
    required this.cell,
    Key? key,
  }) : super(key: key);

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends PlutoStateWithChange<_Cell> {
  bool _showTypedCell = false;

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  /// override default column configuration if the row has its own column configuration
  PlutoColumn get column => widget.row.columns?[widget.column.field] != null ? widget.row.columns![widget.column.field]! : widget.column;

  @override
  void initState() {
    super.initState();

    updateState(PlutoNotifierEventForceUpdate.instance);
  }

  @override
  void updateState(PlutoNotifierEvent event) {
    _showTypedCell = update<bool>(
      _showTypedCell,
      stateManager.isEditing && stateManager.isCurrentCell(widget.cell),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showTypedCell && column.enableEditingMode == true && widget.cell.enabled) {
      if (column.type.isSelect) {
        return PlutoSelectCell(
          stateManager: stateManager,
          cell: widget.cell,
          column: column,
          row: widget.row,
        );
      } else if (column.type.isNumber) {
        return PlutoNumberCell(
          stateManager: stateManager,
          cell: widget.cell,
          column: column,
          row: widget.row,
        );
      } else if (column.type.isDate) {
        return PlutoDateCell(
          stateManager: stateManager,
          cell: widget.cell,
          column: column,
          row: widget.row,
        );
      } else if (column.type.isTime) {
        return PlutoTimeCell(
          stateManager: stateManager,
          cell: widget.cell,
          column: column,
          row: widget.row,
        );
      } else if (column.type.isText) {
        return PlutoTextCell(
          stateManager: stateManager,
          cell: widget.cell,
          column: column,
          row: widget.row,
        );
      } else if (column.type.isCurrency) {
        return PlutoCurrencyCell(
          stateManager: stateManager,
          cell: widget.cell,
          column: column,
          row: widget.row,
        );
      }
    }

    return PlutoDefaultCell(
      cell: widget.cell,
      column: column,
      rowIdx: widget.rowIdx,
      row: widget.row,
      stateManager: stateManager,
    );
  }
}
