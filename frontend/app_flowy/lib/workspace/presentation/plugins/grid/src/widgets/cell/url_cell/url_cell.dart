import 'dart:async';
import 'package:app_flowy/generated/locale_keys.g.dart';
import 'package:app_flowy/workspace/application/grid/cell/url_cell_bloc.dart';
import 'package:app_flowy/workspace/presentation/home/toast.dart';
import 'package:app_flowy/workspace/presentation/plugins/grid/src/widgets/cell/cell_accessory.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/image.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app_flowy/workspace/application/grid/prelude.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cell_builder.dart';
import 'cell_editor.dart';

class GridURLCellStyle extends GridCellStyle {
  String? placeholder;

  List<GridURLCellAccessoryType> accessoryTypes;

  GridURLCellStyle({
    this.placeholder,
    this.accessoryTypes = const [],
  });
}

enum GridURLCellAccessoryType {
  edit,
  copyURL,
}

class GridURLCell extends StatefulWidget with GridCellWidget {
  final GridCellContextBuilder cellContextBuilder;
  late final GridURLCellStyle? cellStyle;
  GridURLCell({
    required this.cellContextBuilder,
    GridCellStyle? style,
    Key? key,
  }) : super(key: key) {
    if (style != null) {
      cellStyle = (style as GridURLCellStyle);
    } else {
      cellStyle = null;
    }
  }

  @override
  State<GridURLCell> createState() => _GridURLCellState();

  GridCellAccessory accessoryFromType(GridURLCellAccessoryType ty, GridCellAccessoryBuildContext buildContext) {
    switch (ty) {
      case GridURLCellAccessoryType.edit:
        final cellContext = cellContextBuilder.build() as GridURLCellContext;
        return _EditURLAccessory(cellContext: cellContext, anchorContext: buildContext.anchorContext);

      case GridURLCellAccessoryType.copyURL:
        final cellContext = cellContextBuilder.build() as GridURLCellContext;
        return _CopyURLAccessory(cellContext: cellContext);
    }
  }

  @override
  List<GridCellAccessory> Function(GridCellAccessoryBuildContext buildContext) get accessoryBuilder => (buildContext) {
        final List<GridCellAccessory> accessories = [];
        if (cellStyle != null) {
          accessories.addAll(cellStyle!.accessoryTypes.map((ty) {
            return accessoryFromType(ty, buildContext);
          }));
        }

        // If the accessories is empty then the default accessory will be GridURLCellAccessoryType.edit
        if (accessories.isEmpty) {
          accessories.add(accessoryFromType(GridURLCellAccessoryType.edit, buildContext));
        }

        return accessories;
      };
}

class _GridURLCellState extends State<GridURLCell> {
  late URLCellBloc _cellBloc;

  @override
  void initState() {
    final cellContext = widget.cellContextBuilder.build() as GridURLCellContext;
    _cellBloc = URLCellBloc(cellContext: cellContext);
    _cellBloc.add(const URLCellEvent.initial());
    _handleRequestFocus();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return BlocProvider.value(
      value: _cellBloc,
      child: BlocBuilder<URLCellBloc, URLCellState>(
        builder: (context, state) {
          final richText = RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
              text: state.content,
              style: TextStyle(
                color: theme.main2,
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          );

          return SizedBox.expand(
              child: GestureDetector(
            child: Align(alignment: Alignment.centerLeft, child: richText),
            onTap: () async {
              widget.isFocus.value = true;
              final url = context.read<URLCellBloc>().state.url;
              await _openUrlOrEdit(url);
            },
          ));
        },
      ),
    );
  }

  @override
  Future<void> dispose() async {
    widget.requestBeginFocus.removeAllListener();
    _cellBloc.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GridURLCell oldWidget) {
    _handleRequestFocus();
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _openUrlOrEdit(String url) async {
    final uri = Uri.parse(url);
    if (url.isNotEmpty && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final cellContext = widget.cellContextBuilder.build() as GridURLCellContext;
      URLCellEditor.show(context, cellContext);
    }
  }

  void _handleRequestFocus() {
    widget.requestBeginFocus.setListener(() {
      _openUrlOrEdit(_cellBloc.state.url);
    });
  }
}

class _EditURLAccessory extends StatelessWidget with GridCellAccessory {
  final GridURLCellContext cellContext;
  final BuildContext anchorContext;
  const _EditURLAccessory({
    required this.cellContext,
    required this.anchorContext,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return svgWidget("editor/edit", color: theme.iconColor);
  }

  @override
  void onTap() {
    URLCellEditor.show(anchorContext, cellContext);
  }
}

class _CopyURLAccessory extends StatelessWidget with GridCellAccessory {
  final GridURLCellContext cellContext;
  const _CopyURLAccessory({required this.cellContext, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return svgWidget("editor/copy", color: theme.iconColor);
  }

  @override
  void onTap() {
    final content = cellContext.getCellData(loadIfNoCache: false)?.content ?? "";
    Clipboard.setData(ClipboardData(text: content));
    showMessageToast(LocaleKeys.grid_row_copyProperty.tr());
  }
}
