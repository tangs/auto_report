// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// import 'package:flutter/material.dart';
import 'package:auto_report/banks/kbiz/utils/string_helper.dart';
import 'package:flutter_test/flutter_test.dart';

// import 'package:auto_report/main.dart';

void main() {
  testWidgets('kbiz test', (WidgetTester tester) async {
    expect(StringHelper.transferorConvert('xxx-x-x5305-x'), '5305x');
    expect(StringHelper.transferorConvert('xxx-x-x5305-xx'), '5305xx');
    expect(StringHelper.transferorConvert('xxx-x-x5305x-x'), '5305xx');
    expect(StringHelper.transferorConvert('xxx-x-x5305xx-x'), '5305xxx');
    expect(StringHelper.transferorConvert('xxx-x-x5305xx-xx'), '5305xxxx');
    expect(StringHelper.transferorConvert('xxx-x-x5305x'), '5305x');
    expect(StringHelper.transferorConvert('xx---xxx-xxx-xxxx5305-x'), '5305x');
  });
}
