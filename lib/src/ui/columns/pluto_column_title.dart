import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../ui.dart';

class PlutoColumnTitle extends PlutoStatefulWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  late final double height;

  PlutoColumnTitle({
    required this.stateManager,
    required this.column,
    double? height,
  })  : height = height ?? stateManager.columnHeight,
        super(key: ValueKey('column_title_${column.key}'));

  @override
  PlutoColumnTitleState createState() => PlutoColumnTitleState();
}

class PlutoColumnTitleState extends PlutoStateWithChange<PlutoColumnTitle> {
  late Offset _columnRightPosition;

  bool _isPointMoving = false;

  PlutoColumnSort _sort = PlutoColumnSort.none;

  bool get showContextIcon {
    return widget.column.showContextIcon ?? (widget.column.enableContextMenu || widget.column.enableDropToResize || !_sort.isNone);
  }

  bool get enableGesture {
    return widget.column.enableContextMenu || widget.column.enableDropToResize;
  }

  MouseCursor get contextMenuCursor {
    if (enableGesture) {
      return widget.column.enableDropToResize ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.click;
    }

    return SystemMouseCursors.basic;
  }

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  @override
  void initState() {
    super.initState();

    updateState(PlutoNotifierEventForceUpdate.instance);
  }

  @override
  void updateState(PlutoNotifierEvent event) {
    _sort = update<PlutoColumnSort>(
      _sort,
      widget.column.sort,
    );
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    final selected = await showColumnMenu(
      context: context,
      position: position,
      backgroundColor: stateManager.style.menuBackgroundColor,
      items: stateManager.columnMenuDelegate.buildMenuItems(
        stateManager: stateManager,
        column: widget.column,
      ),
    );

    if (mounted) {
      stateManager.columnMenuDelegate.onSelected(
        context: context,
        stateManager: stateManager,
        column: widget.column,
        mounted: mounted,
        selected: selected,
      );
    }
  }

  void _handleOnPointDown(PointerDownEvent event) {
    _isPointMoving = false;

    _columnRightPosition = event.position;
  }

  void _handleOnPointMove(PointerMoveEvent event) {
    // if at least one movement event has distanceSquared > 0.5 _isPointMoving will be true
    _isPointMoving |= (_columnRightPosition - event.position).distanceSquared > 0.5;

    if (!_isPointMoving) return;

    final moveOffset = event.position.dx - _columnRightPosition.dx;

    final bool isLTR = stateManager.isLTR;

    stateManager.resizeColumn(widget.column, isLTR ? moveOffset : -moveOffset);

    _columnRightPosition = event.position;
  }

  void _handleOnPointUp(PointerUpEvent event) {
    if (_isPointMoving) {
      stateManager.updateCorrectScrollOffset();
    } else if (mounted && widget.column.enableContextMenu) {
      _showContextMenu(context, event.position);
    }

    _isPointMoving = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = stateManager.configuration.style;

    final columnWidget = _SortableWidget(
      stateManager: stateManager,
      column: widget.column,
      child: _ColumnWidget(
        stateManager: stateManager,
        column: widget.column,
        height: widget.height,
      ),
    );

    final contextMenuIcon = SizedBox(
      height: widget.height,
      child: Align(
        alignment: Alignment.center,
        child: IconButton(
          icon: PlutoGridColumnIcon(
            sort: _sort,
            color: style.iconColor,
            icon: widget.column.enableContextMenu ? style.columnContextIcon : style.columnResizeIcon,
            ascendingIcon: style.columnAscendingIcon,
            descendingIcon: style.columnDescendingIcon,
          ),
          iconSize: style.iconSize,
          mouseCursor: contextMenuCursor,
          onPressed: null,
        ),
      ),
    );

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          child: widget.column.enableColumnDrag
              ? _DraggableWidget(
                  stateManager: stateManager,
                  column: widget.column,
                  child: columnWidget,
                )
              : columnWidget,
        ),
        if (showContextIcon)
          Positioned.directional(
            textDirection: stateManager.textDirection,
            end: -3,
            child: enableGesture
                ? Listener(
                    onPointerDown: _handleOnPointDown,
                    onPointerMove: _handleOnPointMove,
                    onPointerUp: _handleOnPointUp,
                    child: contextMenuIcon,
                  )
                : contextMenuIcon,
          ),
      ],
    );
  }
}

class PlutoGridColumnIcon extends StatelessWidget {
  final PlutoColumnSort? sort;

  final Color color;

  final IconData icon;

  final Icon? ascendingIcon;

  final Icon? descendingIcon;

  const PlutoGridColumnIcon({
    this.sort,
    this.color = Colors.black26,
    this.icon = Icons.dehaze,
    this.ascendingIcon,
    this.descendingIcon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    switch (sort) {
      case PlutoColumnSort.ascending:
        return ascendingIcon == null
            ? Transform.rotate(
                angle: 90 * pi / 90,
                child: const Icon(
                  Icons.sort,
                  color: Colors.green,
                ),
              )
            : ascendingIcon!;
      case PlutoColumnSort.descending:
        return descendingIcon == null
            ? const Icon(
                Icons.sort,
                color: Colors.red,
              )
            : descendingIcon!;
      default:
        return Icon(
          icon,
          color: color,
        );
    }
  }
}

class _DraggableWidget extends StatelessWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  final Widget child;

  const _DraggableWidget({
    required this.stateManager,
    required this.column,
    required this.child,
  });

  void _handleOnPointerMove(PointerMoveEvent event) {
    stateManager.eventManager!.addEvent(PlutoGridScrollUpdateEvent(
      offset: event.position,
      scrollDirection: PlutoGridScrollUpdateDirection.horizontal,
    ));
  }

  void _handleOnPointerUp(PointerUpEvent event) {
    PlutoGridScrollUpdateEvent.stopScroll(
      stateManager,
      PlutoGridScrollUpdateDirection.horizontal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: _handleOnPointerMove,
      onPointerUp: _handleOnPointerUp,
      child: Draggable<PlutoColumn>(
        data: column,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: PlutoShadowContainer(
            alignment: column.titleTextAlign.alignmentValue,
            width: PlutoGridSettings.minColumnWidth,
            height: stateManager.columnHeight,
            backgroundColor: stateManager.configuration.style.gridBackgroundColor,
            borderColor: stateManager.configuration.style.gridBorderColor,
            child: Text(
              column.title,
              style: stateManager.configuration.style.columnTextStyle.copyWith(
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SortableWidget extends StatelessWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  final Widget child;

  const _SortableWidget({
    required this.stateManager,
    required this.column,
    required this.child,
  });

  void _onTap() {
    stateManager.toggleSortColumn(column);
  }

  @override
  Widget build(BuildContext context) {
    return column.enableSorting
        ? MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: const ValueKey('ColumnTitleSortableGesture'),
              onTap: _onTap,
              child: child,
            ),
          )
        : child;
  }
}

class _ColumnWidget extends StatelessWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  final double height;

  const _ColumnWidget({
    required this.stateManager,
    required this.column,
    required this.height,
  });

  EdgeInsets get padding => column.titlePadding ?? stateManager.configuration.style.defaultColumnTitlePadding;

  bool get showSizedBoxForIcon => column.isShowRightIcon && (column.titleTextAlign.isRight || stateManager.isRTL);

  Alignment get childAlignment {
    switch (column.checkboxTitleMainAxisAlign) {
      case MainAxisAlignment.start:
        return Alignment.centerLeft;
      case MainAxisAlignment.center:
        return Alignment.center;
      case MainAxisAlignment.end:
        return Alignment.centerRight;
      case MainAxisAlignment.spaceBetween:
        return Alignment.center;
      case MainAxisAlignment.spaceAround:
        return Alignment.center;
      case MainAxisAlignment.spaceEvenly:
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  CheckboxPosition get checkboxPosition {
    if (column.checkboxPosition != null) {
      return column.checkboxPosition!;
    }

    if (column.checkboxMode == PlutoColumnCheckboxMode.column) {
      return CheckboxPosition.bottom;
    } else if (column.checkboxMode == PlutoColumnCheckboxMode.row) {
      return CheckboxPosition.left;
    } else {
      return CheckboxPosition.left;
    }
  }

  Widget get child {
    final style = stateManager.style;

    if (column.checkboxMode == PlutoColumnCheckboxMode.column) {
      return Column(
        mainAxisAlignment: column.checkboxTitleMainAxisAlign,
        crossAxisAlignment: column.checkboxTitleCrossAxisAlign,
        children: [
          if (column.enableRowChecked && (checkboxPosition == CheckboxPosition.left || checkboxPosition == CheckboxPosition.top))
            CheckboxAllSelectionWidget(stateManager: stateManager, column: column),
          Flexible(
            child: _ColumnTextWidget(
              column: column,
              stateManager: stateManager,
              height: height,
            ),
          ),
          if (column.enableRowChecked && (checkboxPosition == CheckboxPosition.right || checkboxPosition == CheckboxPosition.bottom))
            CheckboxAllSelectionWidget(stateManager: stateManager, column: column),
          if (showSizedBoxForIcon) SizedBox(width: style.iconSize),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: column.checkboxTitleMainAxisAlign,
        crossAxisAlignment: column.checkboxTitleCrossAxisAlign,
        children: [
          if (column.enableRowChecked && (checkboxPosition == CheckboxPosition.left || checkboxPosition == CheckboxPosition.top))
            CheckboxAllSelectionWidget(stateManager: stateManager, column: column),
          Expanded(
            child: _ColumnTextWidget(
              column: column,
              stateManager: stateManager,
              height: height,
            ),
          ),
          if (column.enableRowChecked && (checkboxPosition == CheckboxPosition.right || checkboxPosition == CheckboxPosition.bottom))
            CheckboxAllSelectionWidget(stateManager: stateManager, column: column),
          if (showSizedBoxForIcon) SizedBox(width: style.iconSize),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlutoColumn>(
      onWillAcceptWithDetails: (DragTargetDetails<PlutoColumn> details) {
        return details.data.key != column.key &&
            !stateManager.limitMoveColumn(
              column: details.data,
              targetColumn: column,
            );
      },
      onAcceptWithDetails: (DragTargetDetails<PlutoColumn> details) {
        if (details.data.key != column.key) {
          stateManager.moveColumn(column: details.data, targetColumn: column);
        }
      },
      builder: (dragContext, candidate, rejected) {
        final bool noDragTarget = candidate.isEmpty;

        final style = stateManager.style;

        return SizedBox(
          width: column.width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: noDragTarget ? column.backgroundColor : style.dragTargetColumnColor,
              border: BorderDirectional(
                end: style.enableColumnBorderVertical ? BorderSide(color: style.borderColor, width: 1.0) : BorderSide.none,
              ),
            ),
            child: Padding(
              padding: padding,
              child: Align(
                alignment: childAlignment,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class CheckboxAllSelectionWidget extends PlutoStatefulWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  const CheckboxAllSelectionWidget({required this.stateManager, Key? key, required this.column}) : super(key: key);

  @override
  CheckboxAllSelectionWidgetState createState() => CheckboxAllSelectionWidgetState();
}

class CheckboxAllSelectionWidgetState extends PlutoStateWithChange<CheckboxAllSelectionWidget> {
  bool? _checked;

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  @override
  void initState() {
    super.initState();

    updateState(PlutoNotifierEventForceUpdate.instance);
  }

  @override
  void updateState(PlutoNotifierEvent event) {
    _checked = update<bool?>(
      _checked,
      tristateCheckedRow,
    );
  }

  List<PlutoRow> get enabledRows => stateManager.refRows
      .where((element) =>
          element.cells[widget.column.field]?.enableCheckbox != null ? (element.cells[widget.column.field]?.enableCheckbox == true) : (element.cells[widget.column.field]?.enabled == true))
      .toList();

  bool? get tristateCheckedRow {
    final length = enabledRows.length;

    if (length == 0) return false;

    int countTrue = 0;

    int countFalse = 0;

    for (var i = 0; i < length; i += 1) {
      enabledRows[i].checked == true ? ++countTrue : ++countFalse;
      if (countTrue > 0 && countFalse > 0) return null;
    }
    return countTrue == length;
  }

  void _handleOnChanged(bool? changed) {
    if (changed == _checked) {
      return;
    }

    changed ??= false;

    if (_checked == null) changed = true;

    stateManager.toggleAllRowChecked(changed, column: widget.column);

    if (stateManager.onRowChecked != null) {
      stateManager.onRowChecked!(
        PlutoGridOnRowCheckedAllEvent(isChecked: changed),
      );
    }

    setState(() {
      _checked = changed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlutoScaledCheckbox(
      value: _checked,
      handleOnChanged: _handleOnChanged,
      tristate: true,
      scale: widget.column.checkboxScale ?? 0.86,
      disabledBackgroundColor: widget.column.checkboxDisabledBackgroundColor ?? stateManager.configuration.style.disabledIconColor,
      disabledColor: widget.column.checkboxDisabledColor ?? stateManager.configuration.style.disabledIconColor,
      unselectedColor: widget.column.checkboxUnselectedColor ?? stateManager.configuration.style.iconColor,
      activeColor: widget.column.checkboxActiveColor ?? stateManager.configuration.style.activatedBorderColor,
      checkColor: widget.column.checkboxCheckColor ?? stateManager.configuration.style.activatedColor,
      hoverColor: widget.column.checkboxHoverColor,
      margin: widget.column.checkboxMargin,
      enabled: enabledRows.isNotEmpty,
      shape: widget.column.checkboxShape,
      fillColor: widget.column.checkboxFillColor,
      focusColor: widget.column.checkboxFocusColor,
      materialTapTargetSize: widget.column.checkboxMaterialTapTargetSize,
      mouseCursor: widget.column.checkboxMouseCursor,
      side: widget.column.checkboxSide,
      disabledSide: widget.column.disabledCheckboxSide,
      splashRadius: widget.column.checkboxSplashRadius,
      tooltipBoxDecoration: widget.column.checkboxBoxDecoration,
      tooltipTextStyle: widget.column.checkboxTextStyle,
      overlayColor: widget.column.checkboxOverlayColor,
      themeData: widget.column.checkboxThemeData,
    );
  }
}

class _ColumnTextWidget extends PlutoStatefulWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  final double height;

  const _ColumnTextWidget({
    required this.stateManager,
    required this.column,
    required this.height,
  });

  @override
  _ColumnTextWidgetState createState() => _ColumnTextWidgetState();
}

class _ColumnTextWidgetState extends PlutoStateWithChange<_ColumnTextWidget> {
  bool _isFilteredList = false;

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  @override
  void initState() {
    super.initState();

    updateState(PlutoNotifierEventForceUpdate.instance);
  }

  @override
  void updateState(PlutoNotifierEvent event) {
    _isFilteredList = update<bool>(
      _isFilteredList,
      stateManager.isFilteredColumn(widget.column),
    );
  }

  void _handleOnPressedFilter() {
    stateManager.showFilterPopup(
      context,
      calledColumn: widget.column,
    );
  }

  String? get _title => widget.column.titleSpan == null ? widget.column.title : null;

  List<InlineSpan> get _children => [
        if (widget.column.titleSpan != null) widget.column.titleSpan!,
        if (_isFilteredList)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: IconButton(
              icon: Icon(
                Icons.filter_alt_outlined,
                color: stateManager.configuration.style.iconColor,
                size: stateManager.configuration.style.iconSize,
              ),
              onPressed: _handleOnPressedFilter,
              constraints: BoxConstraints(
                maxHeight: widget.height + (PlutoGridSettings.rowBorderWidth * 2),
              ),
            ),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: _title,
        children: _children,
      ),
      style: stateManager.configuration.style.columnTextStyle,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      maxLines: 1,
      textAlign: widget.column.titleTextAlign.value,
    );
  }
}
