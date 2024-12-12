import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle, NetworkAssetBundle;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class ReceiptPrinter {
  Future<void> printReceipt(Map<String, dynamic> receiptData) async {
    final receiptJson = receiptData['receipt'];
    if (receiptJson == null) {
      print('Error: receipt is null');
      return;
    }

    List<dynamic> receiptList = [];
    try {
      // Check if the receiptJson is already a list, otherwise decode it from JSON
      if (receiptJson is String) {
        receiptList = jsonDecode(receiptJson);
      } else if (receiptJson is List) {
        receiptList = receiptJson;
      } else {
        throw Exception('Invalid type for receiptJson');
      }
    } catch (e) {
      print('Error decoding receipt JSON: $e');
      return;
    }

    if (receiptList.isEmpty) {
      print('Error: receipt list is empty');
      return;
    }

    final receipt = receiptList[0];
    final dataPrint = receipt['data_print'];
    if (dataPrint == null) {
      print('Error: data_print is null');
      return;
    }

    final biller = dataPrint['biller'];
    final printDetails = dataPrint['print'];

    if (biller == null || printDetails == null) {
      print('Error: biller or print details are null');
      return;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> ticket = [];

    final logo = biller['logo'];
    if (logo is String && logo.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(logo));
        if (response.statusCode == 200) {
          final decodedImage = img.decodeImage(response.bodyBytes);

          if (decodedImage != null) {
            const int targetHeight = 70;
            final resizedImage = img.copyResize(
              decodedImage,
              height: targetHeight,
            );

            ticket += generator.image(
              resizedImage,
              isDoubleDensity: true,
              align: PosAlign.center,
            );
          }
        }
      } catch (e) {
        print("Error fetching logo from URL: $e");
      }
    }
    ticket += generator.text(
      ' ',
      styles: const PosStyles(align: PosAlign.center),
    );
    // Header Section
    ticket += generator.text(
      biller['company_name'] ?? 'Company Name',
      styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1),
    );
    ticket += generator.text(
      biller['address'] ?? '',
      styles: const PosStyles(align: PosAlign.center),
    );
    ticket += generator.text(
      'Tel: ${biller['phone'] ?? ''}',
      styles: const PosStyles(align: PosAlign.center),
    );

    if (printDetails['cf_value1'] != null &&
        printDetails['cf_value1']!.trim().isNotEmpty) {
      ticket += generator.text(
        printDetails['cf_value1']!,
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );
    } else {
      print('is empty:::::1');
    }
    if (printDetails['cf_value2'] != null &&
        printDetails['cf_value2']!.trim().isNotEmpty) {
      ticket += generator.text(
        printDetails['cf_value2']!,
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );
    } else {
      print('is empty:::::2');
    }
    if (printDetails['cf_value3'] != null &&
        printDetails['cf_value3']!.trim() != ':') {
      ticket += generator.text(
        printDetails['cf_value3']!,
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );
    } else {
      print('is empty:::::3');
    }

    if (printDetails['cf_value4'] != null &&
        printDetails['cf_value4']!.trim().isNotEmpty) {
      ticket += generator.text(
        printDetails['cf_value4']!,
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );
    } else {
      print('is empty:::::4');
    }

    ticket += generator.hr();

    ticket += generator.text(
      '${printDetails['ref'] ?? ''}',
      styles: const PosStyles(align: PosAlign.left),
    );
    ticket += generator.text(
      '${printDetails['date'] ?? ''}',
      styles: const PosStyles(align: PosAlign.left),
    );
    ticket += generator.text(
      ' ',
      styles: const PosStyles(align: PosAlign.center),
    );
    // Items Section
    ticket += generator.row([
      PosColumn(
          text: 'Item'.padLeft(-32),
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(
          text: 'Price',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(
          text: 'Total',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);

    ticket += generator.hr();

    for (var item in printDetails['items']) {
      ticket += generator.row([
        PosColumn(
            text: item['product_name'],
            width: 6,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: '${item['unit_quantity']}',
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: item['unit_price'],
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: item['subtotal'],
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    // Totals Section
    ticket += generator.hr();
    ticket += generator.row([
      PosColumn(
          text: 'Subtotal:',
          width: 8,
          styles: const PosStyles(align: PosAlign.left)),
      PosColumn(
          text: printDetails['total'],
          width: 4,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (printDetails['tax'] != '\$0.000') {
      ticket += generator.row([
        PosColumn(
            text: 'Tax:',
            width: 8,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: printDetails['tax'],
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    if (printDetails['order_discount'] != '\$0.000') {
      ticket += generator.row([
        PosColumn(
            text: 'Discount:',
            width: 8,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: printDetails['order_discount'],
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    ticket += generator.row([
      PosColumn(
          text: 'Grand Total:',
          width: 8,
          styles: const PosStyles(align: PosAlign.left)),
      PosColumn(
          text: printDetails['grand_total'],
          width: 4,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    ticket += generator.hr();
    ticket += generator.row([
      PosColumn(
          text: 'Paid Amount',
          width: 8,
          styles: const PosStyles(align: PosAlign.left)),
      PosColumn(
          text: printDetails['paid'],
          width: 4,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    double grandTotal = double.tryParse(
            printDetails['grand_total']?.replaceAll('\$', '') ?? '0') ??
        0;
    double paid =
        double.tryParse(printDetails['paid']?.replaceAll('\$', '') ?? '0') ?? 0;
    double balance = grandTotal - paid;

    ticket += generator.row([
      PosColumn(
          text: 'Balance',
          width: 8,
          styles: const PosStyles(align: PosAlign.left)),
      PosColumn(
          text: '\$${balance.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    ticket += generator.hr();
    // Footer Section
    ticket += generator.text(
      '${printDetails['sales_person'] ?? ''}',
      styles: const PosStyles(align: PosAlign.left),
    );

    ticket += generator.text(
      ' ',
      styles: const PosStyles(align: PosAlign.center),
    );

    if (printDetails['sale_queue'] != null &&
        printDetails['sale_queue']!.isNotEmpty &&
        printDetails['sale_queue'] != '0') {
      ticket += generator.text(
        '---------Queue Number---------',
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );
      ticket += generator.text(
        '${printDetails['sale_queue'] ?? ''}',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    }
    ticket += generator.text(
      ' ',
      styles: const PosStyles(align: PosAlign.center),
    );
    if (printDetails['qrcode'] != null && printDetails['qrcode'].isNotEmpty) {
      String qrContent = printDetails['qrcode'].split(':').last.trim();
      ticket += generator.qrcode(qrContent, size: QRSize.size6);
    }

    ticket += generator.text(
      ' ',
      styles: const PosStyles(align: PosAlign.center),
    );
    ticket += generator.text('@Easytouch | Powered by Yooltech',
        styles: const PosStyles(align: PosAlign.center));
    ticket += generator.cut();

    final printer = PrinterNetworkManager('192.168.100.16', port: 9100);

    final PosPrintResult printResult = await printer.printTicket(ticket);
    if (printResult == PosPrintResult.success) {
      print('-------------------------------Print successful!');
    } else {
      print('--------------------------------Print failed: $printResult');
    }

    printer.disconnect();
  }
}
