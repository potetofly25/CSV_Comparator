import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() => runApp(CsvComparatorApp());

class CsvComparatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSV比較ツール',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CsvCompareScreen(),
    );
  }
}

class CsvCompareScreen extends StatefulWidget {
  @override
  _CsvCompareScreenState createState() => _CsvCompareScreenState();
}

class _CsvCompareScreenState extends State<CsvCompareScreen> {
  bool showOnlyDiff = false;
  List<List<String>>? csv1;
  List<List<String>>? csv2;
  int precision = 0;
  String fileName1 = '';
  String fileName2 = '';

  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();

  Future<void> pickCsv(int index) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      List<List<String>> rows;
      try {
        rows = CsvToListConverter(eol: '\n')
            .convert(content)
            .map((e) => e.map((v) => v.toString()).toList())
            .toList();
      } catch (e) {
        // 改行だけの一列CSVにも対応
        rows = LineSplitter.split(content)
            .where((line) => line.trim().isNotEmpty)
            .map((line) => [line.trim()])
            .toList();
      }

      setState(() {
        if (index == 1) {
          csv1 = rows;
          fileName1 = result.files.single.name;
        } else {
          csv2 = rows;
          fileName2 = result.files.single.name;
        }
      });
    }
  }

  bool compare(String a, String b) {
    final numA = num.tryParse(a);
    final numB = num.tryParse(b);
    if (numA != null && numB != null) {
      final factor = pow(10, precision);
      return (numA * factor).truncate() == (numB * factor).truncate();
    }
    return a == b;
  }

  Widget buildCsvTable(
      List<List<String>> csvData,
      List<List<String>>? compareTo,
      ScrollController scrollController,
      bool isLeft) {
    final rowCount = csvData.length;
    final colCounts = csvData.map((e) => e.length).toList();
    final maxCols = colCounts.isNotEmpty ? colCounts.reduce(max) : 0;

    return Scrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columnSpacing: 20,
            columns: [
              DataColumn(label: Text("#")),
              ...List.generate(
                maxCols,
                (i) => DataColumn(label: Text("Col ${i + 1}")),
              )
            ],
            rows: List.generate(rowCount, (rowIdx) {
              final row = csvData[rowIdx];
              final bool isDiffRow = List.generate(row.length, (colIdx) {
                if (compareTo != null &&
                    rowIdx < compareTo.length &&
                    colIdx < compareTo[rowIdx].length) {
                  return !compare(row[colIdx], compareTo[rowIdx][colIdx]);
                }
                return false;
              }).any((diff) => diff);

              if (showOnlyDiff && !isDiffRow) return null;

              return DataRow(cells: [
                DataCell(Text((rowIdx + 1).toString())),
                ...List.generate(row.length, (colIdx) {
                  final cell = row[colIdx];
                  String refCell = '';
                  if (compareTo != null &&
                      rowIdx < compareTo.length &&
                      colIdx < compareTo[rowIdx].length) {
                    refCell = compareTo[rowIdx][colIdx];
                  }
                  final isSame = compare(cell, refCell);
                  return DataCell(Container(
                    color: isSame ? null : Colors.red[200],
                    padding: EdgeInsets.all(4),
                    child: Text(cell),
                  ));
                })
              ]);
            }).whereType<DataRow>().toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController1.addListener(() {
        if (_scrollController2.hasClients &&
            _scrollController1.offset != _scrollController2.offset) {
          _scrollController2.jumpTo(_scrollController1.offset);
        }
      });
      _scrollController2.addListener(() {
        if (_scrollController1.hasClients &&
            _scrollController2.offset != _scrollController1.offset) {
          _scrollController1.jumpTo(_scrollController2.offset);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text("CSV比較ツール")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton(
                    onPressed: () => pickCsv(1), child: Text("CSV1を選択")),
                SizedBox(width: 5),
                Text(fileName1.isNotEmpty ? fileName1 : "未選択"),
                SizedBox(width: 15),
                ElevatedButton(
                    onPressed: () => pickCsv(2), child: Text("CSV2を選択")),
                SizedBox(width: 5),
                Text(fileName2.isNotEmpty ? fileName2 : "未選択"),
                SizedBox(width: 20),
                Text("小数桁数："),
                DropdownButton<int>(
                  value: precision,
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text("$i"),
                    ),
                  ),
                  onChanged: (val) => setState(() => precision = val!),
                ),
                SizedBox(width: 10),
                Row(
                  children: [
                    Checkbox(
                      value: showOnlyDiff,
                      onChanged: (val) => setState(() => showOnlyDiff = val!),
                    ),
                    Text("差分行のみ表示"),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: (csv1 != null && csv2 != null)
                ? Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text("CSV1",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                                child: buildCsvTable(
                                    csv1!, csv2, _scrollController1, true)),
                          ],
                        ),
                      ),
                      VerticalDivider(width: 1),
                      Expanded(
                        child: Column(
                          children: [
                            Text("CSV2",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                                child: buildCsvTable(
                                    csv2!, csv1, _scrollController2, false)),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(child: Text("2つのCSVを選択してください")),
          ),
        ],
      ),
    );
  }
}
