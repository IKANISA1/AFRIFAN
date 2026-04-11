import 'package:africlub_fantasy/core/constants.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FormSparklineWidget extends StatelessWidget {
  const FormSparklineWidget({required this.values, super.key});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 120,
      child: BarChart(
        BarChartData(
          backgroundColor: Colors.transparent,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            values.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: values[index],
                  width: 18,
                  color: FantasyColors.successGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
