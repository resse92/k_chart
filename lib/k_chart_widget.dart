import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:k_chart/chart_translations.dart';
import 'package:k_chart/datafeed.dart';
import 'package:k_chart/extension/map_ext.dart';
import 'package:k_chart/flutter_k_chart.dart';

enum MainState { MA, BOLL, NONE }

enum SecondaryState { MACD, KDJ, RSI, WR, CCI, NONE }

class TimeFormat {
  static const List<String> YEAR_MONTH_DAY = [yyyy, '-', mm, '-', dd];
  static const List<String> YEAR_MONTH_DAY_WITH_HOUR = [
    yyyy,
    '-',
    mm,
    '-',
    dd,
    ' ',
    HH,
    ':',
    nn
  ];
}

class KChartWidget extends StatefulWidget {
  final String symbol;
  final String interval;
  final MainState mainState;
  final bool volHidden;
  final SecondaryState secondaryState;
  final Function()? onSecondaryTap;
  final bool isLine;
  final bool isTapShowInfoDialog; //是否开启单击显示详情数据
  final bool hideGrid;
  final bool showNowPrice;
  final bool showInfoDialog;
  final bool materialInfoDialog; // Material风格的信息弹窗
  final Map<String, ChartTranslations> translations;
  final List<String> timeFormat;
  final DataFeed dataFeed;

  //当屏幕滚动到尽头会调用，真为拉到屏幕右侧尽头，假为拉到屏幕左侧尽头
  final Function(bool)? onLoadMore;

  final int fixedLength;
  final List<int> maDayList;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool)? isOnDrag;
  final ChartColors chartColors;
  final ChartStyle chartStyle;
  final VerticalTextAlignment verticalTextAlignment;
  final double xFrontPadding;

  KChartWidget(
    this.dataFeed,
    this.symbol,
    this.interval,
    this.chartStyle,
    this.chartColors, {
    this.xFrontPadding = 100,
    this.mainState = MainState.MA,
    this.secondaryState = SecondaryState.MACD,
    this.onSecondaryTap,
    this.volHidden = false,
    this.isLine = false,
    this.isTapShowInfoDialog = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.showInfoDialog = true,
    this.materialInfoDialog = true,
    this.translations = kChartTranslations,
    this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
    this.onLoadMore,
    this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
    this.verticalTextAlignment = VerticalTextAlignment.left,
  });

  @override
  _KChartWidgetState createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget>
    with TickerProviderStateMixin {
  double mScaleX = 1.0, mScrollX = 0.0, mSelectX = 0.0;
  StreamController<InfoWindowEntity?>? mInfoWindowStream;
  double mHeight = 0, mWidth = 0;
  AnimationController? _controller;
  Animation<double>? aniX;
  List<KLineEntity> kLineData = [];
  StreamSubscription<KLineEntity>? kLineSubscription;

  bool _loading = false;

  double getMinScrollX() {
    return mScaleX;
  }

  double _lastScale = 1.0;
  bool isScale = false, isDrag = false, isLongPress = false, isOnTap = false;

  @override
  void initState() {
    super.initState();
    mInfoWindowStream = StreamController<InfoWindowEntity?>();
    _loading = true;
    _loadKLineData(widget.symbol, widget.interval);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant KChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.interval != widget.interval) {
      kLineSubscription?.cancel();
      _loadKLineData(widget.symbol, widget.interval);
    }
  }

  @override
  void dispose() {
    mInfoWindowStream?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kLineData.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }
    final _painter = ChartPainter(
      widget.chartStyle,
      widget.chartColors,
      xFrontPadding: widget.xFrontPadding,
      datas: kLineData,
      scaleX: mScaleX,
      scrollX: mScrollX,
      selectX: mSelectX,
      isLongPass: isLongPress,
      isOnTap: isOnTap,
      isTapShowInfoDialog: widget.isTapShowInfoDialog,
      mainState: widget.mainState,
      volHidden: widget.volHidden,
      secondaryState: widget.secondaryState,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      showNowPrice: widget.showNowPrice,
      sink: mInfoWindowStream?.sink,
      fixedLength: widget.fixedLength,
      maDayList: widget.maDayList,
      verticalTextAlignment: widget.verticalTextAlignment,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        mHeight = constraints.maxHeight;
        mWidth = constraints.maxWidth;

        return _loading
            ? Container(
                width: double.infinity,
                height: 450,
                alignment: Alignment.center,
                child: const CircularProgressIndicator())
            : RawGestureDetector(
                gestures: {
                  TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                      TapGestureRecognizer>(
                    () => TapGestureRecognizer()
                      ..onTapUp = (details) {
                        if (widget.onSecondaryTap != null &&
                            _painter.isInSecondaryRect(details.localPosition)) {
                          widget.onSecondaryTap!();
                        }

                        if (_painter.isInMainRect(details.localPosition)) {
                          isOnTap = true;
                          if (mSelectX != details.localPosition.dx &&
                              widget.isTapShowInfoDialog) {
                            mSelectX = details.localPosition.dx;
                            notifyChanged();
                          }
                        }
                      },
                    (instance) {},
                  ),
                  HorizontalDragGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          HorizontalDragGestureRecognizer>(
                    () => HorizontalDragGestureRecognizer()
                      ..onDown = (details) {
                        isOnTap = false;
                        _stopAnimation();
                        _onDragChanged(true);
                      }
                      ..onUpdate = (details) {
                        if (isScale || isLongPress) return;
                        mScrollX =
                            ((details.primaryDelta ?? 0) / mScaleX + mScrollX)
                                .clamp(0.0, ChartPainter.maxScrollX)
                                .toDouble();
                        notifyChanged();
                      }
                      ..onEnd = (details) {
                        var velocity = details.velocity.pixelsPerSecond.dx;
                        _onFling(velocity);
                      }
                      ..onCancel = () => _onDragChanged(false),
                    (instance) {},
                  ),
                  ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                      ScaleGestureRecognizer>(
                    () => ScaleGestureRecognizer()
                      ..onStart = (_) {
                        isScale = true;
                      }
                      ..onUpdate = (details) {
                        if (isDrag || isLongPress) return;
                        mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
                        notifyChanged();
                      }
                      ..onEnd = (_) {
                        isScale = false;
                        _lastScale = mScaleX;
                      },
                    (instance) {},
                  ),
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer()
                      ..onLongPressStart = (details) {
                        isOnTap = false;
                        isLongPress = true;
                        if (mSelectX != details.localPosition.dx) {
                          mSelectX = details.localPosition.dx;
                          notifyChanged();
                        }
                      }
                      ..onLongPressMoveUpdate = (details) {
                        if (mSelectX != details.localPosition.dx) {
                          mSelectX = details.localPosition.dx;
                          notifyChanged();
                        }
                      }
                      ..onLongPressEnd = (details) {
                        isLongPress = false;
                        mInfoWindowStream?.sink.add(null);
                        notifyChanged();
                      },
                    (instance) {},
                  ),
                },
                child: Stack(
                  children: <Widget>[
                    CustomPaint(
                      size: Size(double.infinity, double.infinity),
                      painter: _painter,
                    ),
                    if (widget.showInfoDialog) _buildInfoDialog(),
                  ],
                ),
              );
      },
    );
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller!.isAnimating) {
      _controller!.stop();
      _onDragChanged(false);
      if (needNotify) {
        notifyChanged();
      }
    }
  }

  void _onDragChanged(bool isOnDrag) {
    isDrag = isOnDrag;
    if (widget.isOnDrag != null) {
      widget.isOnDrag!(isDrag);
    }
  }

  void _onFling(double x) {
    _controller = AnimationController(
        duration: Duration(milliseconds: widget.flingTime), vsync: this);
    aniX = null;
    aniX = Tween<double>(begin: mScrollX, end: x * widget.flingRatio + mScrollX)
        .animate(CurvedAnimation(
            parent: _controller!.view, curve: widget.flingCurve));
    aniX!.addListener(() {
      mScrollX = aniX!.value;
      if (mScrollX <= 0) {
        mScrollX = 0;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(true);
        }
        _stopAnimation();
      } else if (mScrollX >= ChartPainter.maxScrollX) {
        mScrollX = ChartPainter.maxScrollX;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(false);
        }
        _stopAnimation();
      }
      notifyChanged();
    });
    aniX!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDragChanged(false);
        notifyChanged();
      }
    });
    _controller!.forward();
  }

  void notifyChanged() => setState(() {});

  late List<String> infos;

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity?>(
        stream: mInfoWindowStream?.stream,
        builder: (context, snapshot) {
          if ((!isLongPress && !isOnTap) ||
              widget.isLine == true ||
              !snapshot.hasData ||
              snapshot.data?.kLineEntity == null) return Container();
          KLineEntity entity = snapshot.data!.kLineEntity;
          double upDown = entity.change ?? entity.close - entity.open;
          double upDownPercent = entity.ratio ?? (upDown / entity.open) * 100;
          final double? entityAmount = entity.amount;
          infos = [
            getDate(entity.time),
            entity.open.toStringAsFixed(widget.fixedLength),
            entity.high.toStringAsFixed(widget.fixedLength),
            entity.low.toStringAsFixed(widget.fixedLength),
            entity.close.toStringAsFixed(widget.fixedLength),
            "${upDown > 0 ? "+" : ""}${upDown.toStringAsFixed(widget.fixedLength)}",
            "${upDownPercent > 0 ? "+" : ''}${upDownPercent.toStringAsFixed(2)}%",
            if (entityAmount != null) entityAmount.toInt().toString()
          ];
          final dialogPadding = 4.0;
          final dialogWidth = mWidth / 3;
          return Container(
            margin: EdgeInsets.only(
                left: snapshot.data!.isLeft
                    ? dialogPadding
                    : mWidth - dialogWidth - dialogPadding,
                top: 25),
            width: dialogWidth,
            decoration: BoxDecoration(
                color: widget.chartColors.selectFillColor,
                border: Border.all(
                    color: widget.chartColors.selectBorderColor, width: 0.5)),
            child: ListView.builder(
              padding: EdgeInsets.all(dialogPadding),
              itemCount: infos.length,
              itemExtent: 14.0,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final translations = widget.translations.of(context);

                return _buildItem(
                  infos[index],
                  translations.byIndex(index),
                );
              },
            ),
          );
        });
  }

  Widget _buildItem(String info, String infoName) {
    Color color = widget.chartColors.infoWindowNormalColor;
    if (info.startsWith("+"))
      color = widget.chartColors.infoWindowUpColor;
    else if (info.startsWith("-")) color = widget.chartColors.infoWindowDnColor;
    final infoWidget = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
            child: Text("$infoName",
                style: TextStyle(
                    color: widget.chartColors.infoWindowTitleColor,
                    fontSize: 10.0))),
        Text(info, style: TextStyle(color: color, fontSize: 10.0)),
      ],
    );
    return widget.materialInfoDialog
        ? Material(color: Colors.transparent, child: infoWidget)
        : infoWidget;
  }

  String getDate(int? date) => dateFormat(
      DateTime.fromMillisecondsSinceEpoch(
          date ?? DateTime.now().millisecondsSinceEpoch),
      widget.timeFormat);

  void _loadKLineData(String symbol, String interval) async {
    final symbolInfo = await widget.dataFeed.getSymbolInfo(symbol);
    final periodParams = PeriodParams(
      interval: interval,
      from: DateTime.now().millisecondsSinceEpoch,
      to: DateTime.now().add(Duration(minutes: 1)).millisecondsSinceEpoch ~/
          1000,
    );
    final kLineData =
        await widget.dataFeed.getKLineData(symbolInfo, periodParams);
    setState(() {
      this.kLineData = kLineData;
      _loading = false;
    });

    // kLineSubscription =
    //     widget.dataFeed.subscribeKLineData(symbol, interval).listen((data) {
    //   if (mounted) {
    //     if (kLineData.isEmpty) {
    //       setState(() {
    //         this.kLineData.add(data);
    //       });
    //       return;
    //     }
    //     if (data.time < kLineData.last.time) {
    //       return;
    //     } else if (data.time == kLineData.last.time) {
    //       this.kLineData.last = data;
    //     } else {
    //       this.kLineData.add(data);
    //     }
    //   }
    // });
  }
}
