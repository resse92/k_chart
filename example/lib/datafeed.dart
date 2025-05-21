import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:k_chart/datafeed.dart';
import 'package:k_chart/flutter_k_chart.dart';

import 'package:http/http.dart' as http;

class CustomDataFeed extends DataFeed {
  @override
  Future<SymbolInfo> getSymbolInfo(String symbol) async {
    return SymbolInfo(
      symbol: symbol,
      name: symbol,
      exchange: 'binance',
      timezone: 'UTC',
      currency: 'USD',
    );
  }

  @override
  Future<List<KLineEntity>> getKLineData(
      SymbolInfo symbolInfo, PeriodParams periodParams) async {
    return getData(periodParams.interval);
  }

  @override
  Stream<KLineEntity> subscribeKLineData(String symbol, String interval) {
    return Stream.periodic(Duration(seconds: 1));
  }

  @override
  void unsubscribeKLineData(String symbol, String interval) {
    // TODO: implement unsubscribeKLineData
  }

  @override
  Future<List<DepthEntity>> getDepthData(SymbolInfo symbolInfo) async {
    return [];
  }

  @override
  void subscribeDepthData(
      String symbol, void Function(List<DepthEntity>) onData) {
    // TODO: implement subscribeDepthData
  }

  @override
  void unsubscribeDepthData(String symbol) {
    // TODO: implement unsubscribeDepthData
  }

  Future<List<KLineEntity>> getData(String period) async {
    /*
     * 可以翻墙使用方法1加载数据，不可以翻墙使用方法2加载数据，默认使用方法1加载最新数据
     */
    // final Future<String> future = getChatDataFromInternet(period);
    final Future<String> future = getChatDataFromJson();
    final result = await future;
    return solveChatData(result);
  }

  //获取火币数据，需要翻墙
  Future<String> getChatDataFromInternet(String? period) async {
    var url =
        'https://api.huobi.br.com/market/history/kline?period=${period ?? '1day'}&size=300&symbol=btcusdt';
    late String result;
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      result = response.body;
    } else {
      print('Failed getting IP address');
    }
    return result;
  }

  // 如果你不能翻墙，可以使用这个方法加载数据
  Future<String> getChatDataFromJson() async {
    return rootBundle.loadString('assets/chatData.json');
  }

  List<KLineEntity> solveChatData(String result) {
    final Map parseJson = json.decode(result) as Map<dynamic, dynamic>;
    final list = parseJson['data'] as List<dynamic>;
    final datas = list
        .map((item) => KLineEntity.fromJson(item as Map<String, dynamic>))
        .toList()
        .reversed
        .toList()
        .cast<KLineEntity>();
    return datas;
  }
}
