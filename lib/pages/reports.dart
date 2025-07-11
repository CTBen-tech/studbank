import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Financial Reports')),
      body: Center(
        child: PieChart(
          PieChartData(
            sections: [
              PieChartSectionData(value: 40, title: 'Food', color: Colors.blue),
              PieChartSectionData(value: 30, title: 'Transport', color: Colors.green),
              PieChartSectionData(value: 20, title: 'Books', color: Colors.red),
              PieChartSectionData(value: 10, title: 'Other', color: Colors.yellow),
            ],
          ),
        ),
      ),
    );
  }
}