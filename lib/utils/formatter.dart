import 'package:intl/intl.dart';

class Fmt {
  static final _won = NumberFormat('#,###', 'ko_KR');
  static final _decimal = NumberFormat('#,##0.##', 'ko_KR');

  static String won(double v) => '${_won.format(v.round())}원';
  static String num(double v) => _decimal.format(v);
  static String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
  static String pctRaw(double v) => '${v.toStringAsFixed(1)}%';
  static String date(DateTime dt) => DateFormat('yyyy.MM.dd').format(dt);
  static String datetime(DateTime dt) => DateFormat('yyyy.MM.dd HH:mm').format(dt);
}
