// import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_webview/printer.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Flutterchannel {
  static void addJavaScriptChannel(
      WebViewController controller, BuildContext context) {
    controller.addJavaScriptChannel(
      'Toaster',
      onMessageReceived: (JavaScriptMessage message) async {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   // SnackBar(
        //   //   content: Text(message.message),
        //   // ),
        // );
        debugPrint(message.message, wrapWidth: 1024);  
        print('=----massage');
        try {
          final receiptData = json.decode(message.message);
          if (receiptData != null) {
            ReceiptPrinter().printReceipt(receiptData);
          } else {
            throw Exception("Invalid data received");
          }
        } catch (e) {
          print('Error: $e');
        }
      },
    );
  }
}
