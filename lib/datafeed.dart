import 'package:k_chart/entity/index.dart';

class SymbolInfo {
  String symbol;
  String name;
  String exchange;
  String timezone;
  String currency;

  SymbolInfo({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.timezone,
    required this.currency,
  });
}

class PeriodParams {
  String interval;
  int from;
  int to;

  PeriodParams({
    required this.interval,
    required this.from,
    required this.to,
  });
}

abstract class DataFeed {
  Future<SymbolInfo> getSymbolInfo(String symbol);

  // for kline chart
  Future<List<KLineEntity>> getKLineData(
      SymbolInfo symbolInfo, PeriodParams periodParams);

  Stream<KLineEntity> subscribeKLineData(String symbol, String interval);

  void unsubscribeKLineData(String symbol, String interval);

  // for depth chart
  Future<List<DepthEntity>> getDepthData(SymbolInfo symbolInfo);

  void subscribeDepthData(
      String symbol, void Function(List<DepthEntity>) onData);

  void unsubscribeDepthData(String symbol);

  // for marks
  // getMarks
  // getTimescaleMarks
}
