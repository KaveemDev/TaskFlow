import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/task_model.dart';

class ProductivityChartWidget extends ConsumerStatefulWidget {
  const ProductivityChartWidget({super.key});

  @override
  ConsumerState<ProductivityChartWidget> createState() =>
      _ProductivityChartWidgetState();
}

class _ProductivityChartWidgetState
    extends ConsumerState<ProductivityChartWidget> {
  String _dateRange = 'Last 7 Days';

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Productivity Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dateRange,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    items: ['Last 7 Days', 'This Month', 'This Year'].map((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() => _dateRange = newValue);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: tasksAsync.when(
                data: (tasks) {
                  final now = DateTime.now();
                  DateTime startDate;

                  if (_dateRange == 'Last 7 Days') {
                    startDate = DateTime(
                      now.year,
                      now.month,
                      now.day,
                    ).subtract(Duration(days: 6));
                  } else if (_dateRange == 'This Month') {
                    startDate = DateTime(now.year, now.month, 1);
                  } else {
                    startDate = DateTime(now.year, 1, 1);
                  }

                  final filteredTasks = tasks.where((t) {
                    if (!t.isCompleted || t.dueDate == null) return false;
                    return t.dueDate!.isAfter(
                      startDate.subtract(Duration(days: 1)),
                    );
                  }).toList();

                  return _buildBarChart(filteredTasks, startDate);
                },
                loading: () => Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<Task> tasks, DateTime startDate) {
    final int itemsCount = _dateRange == 'This Year'
        ? 12
        : (_dateRange == 'This Month' ? 31 : 7);
    Map<int, int> counts = {};

    for (var t in tasks) {
      if (t.dueDate != null) {
        if (_dateRange == 'This Year') {
          // Group by month
          int monthIndex = t.dueDate!.month - 1; // 0-based
          counts[monthIndex] = (counts[monthIndex] ?? 0) + 1;
        } else {
          // Group by days from start date
          int diff = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day)
              .difference(
                DateTime(startDate.year, startDate.month, startDate.day),
              )
              .inDays;
          if (diff >= 0 && diff < itemsCount) {
            counts[diff] = (counts[diff] ?? 0) + 1;
          }
        }
      }
    }

    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.orange,
      Colors.pink,
    ];

    final barGroups = List.generate(itemsCount, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (counts[i] ?? 0).toDouble(),
            color: colors[i % colors.length],
            width: _dateRange == 'This Month' ? 4 : 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxY(counts) * 1.2,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      );
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(counts) * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Theme.of(context).colorScheme.onSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} tasks',
                TextStyle(
                  color: Theme.of(context).colorScheme.surface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return _getBottomTitles(value, meta, startDate);
              },
              reservedSize: 36,
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  double _getMaxY(Map<int, int> counts) {
    if (counts.isEmpty) return 5;
    double maxVal = counts.values.reduce((a, b) => a > b ? a : b).toDouble();
    return maxVal < 5 ? 5 : maxVal;
  }

  Widget _getBottomTitles(double value, TitleMeta meta, DateTime startDate) {
    final int index = value.toInt();
    String text = '';

    if (_dateRange == 'Last 7 Days') {
      final date = startDate.add(Duration(days: index));
      text = DateFormat('E').format(date);
    } else if (_dateRange == 'This Month') {
      if (index % 5 == 0 || index == 30) {
        final date = startDate.add(Duration(days: index));
        text = DateFormat('d').format(date);
      }
    } else if (_dateRange == 'This Year') {
      if (index % 2 == 0) {
        final date = DateTime(startDate.year, index + 1, 1);
        text = DateFormat('MMM').format(date);
      }
    }

    if (text.isEmpty) return SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.outline,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
