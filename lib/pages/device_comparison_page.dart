import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import '../controllers/monitor_controller.dart';
import '../models/device_data.dart';

class DeviceComparisonPage extends StatefulWidget {
  const DeviceComparisonPage({Key? key}) : super(key: key);

  @override
  State<DeviceComparisonPage> createState() => _DeviceComparisonPageState();
}

class _DeviceComparisonPageState extends State<DeviceComparisonPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final monitorController = Get.find<MonitorController>();

  List<String> _selectedDeviceIds = [];
  final Map<String, Color> _deviceColors = {};
  final List<Color> _availableColors = [
    const Color(0xFF4A90E2),
    const Color(0xFF50C878),
    const Color(0xFFFF6B6B),
    const Color(0xFF9C27B0),
    const Color(0xFFFF9800),
    const Color(0xFF00BCD4),
    const Color(0xFF8BC34A),
    const Color(0xFFE91E63),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeDeviceColors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeDeviceColors() {
    final allDevices = [
      ...monitorController.selectedDevices,
      ...monitorController.savedDevices,
    ];

    for (int i = 0; i < allDevices.length && i < _availableColors.length; i++) {
      _deviceColors[allDevices[i].deviceId] = _availableColors[i];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '设备数据对比',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E3A59),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2E3A59),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showDeviceSelectionDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF4A90E2),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFF4A90E2),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: '电流对比'),
                Tab(text: '电压对比'),
                Tab(text: '功率对比'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 设备选择状态栏
          _buildDeviceSelectionBar(),

          // 图表对比内容
          Expanded(
            child: _selectedDeviceIds.isEmpty
                ? _buildEmptyState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildComparisonChart('current'),
                      _buildComparisonChart('voltage'),
                      _buildComparisonChart('power'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelectionBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '对比设备',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E3A59),
                ),
              ),
              TextButton.icon(
                onPressed: _showDeviceSelectionDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('选择设备'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4A90E2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedDeviceIds.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '请选择要对比的设备',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedDeviceIds.map((deviceId) {
                final device = _getDeviceById(deviceId);
                final color = _deviceColors[deviceId] ?? Colors.grey;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        device?.deviceName ?? '未知设备',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _removeDevice(deviceId),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.compare_arrows,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '选择设备开始对比',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E3A59),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '请选择2个或更多设备\n来对比它们的数据',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showDeviceSelectionDialog,
            icon: const Icon(Icons.add),
            label: const Text('选择设备'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonChart(String dataType) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getChartTitle(dataType),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E3A59),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildLineChart(dataType),
          ),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLineChart(String dataType) {
    List<LineChartBarData> lineBarsData = [];

    for (String deviceId in _selectedDeviceIds) {
      final device = _getDeviceById(deviceId);
      if (device == null) continue;

      final color = _deviceColors[deviceId] ?? Colors.grey;
      final data = _getChartData(device.dataHistory, dataType);

      if (data.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: data,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
        );
      }
    }

    if (lineBarsData.isEmpty) {
      return const Center(
        child: Text(
          '暂无数据',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    // 计算Y轴范围
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var lineData in lineBarsData) {
      for (var spot in lineData.spots) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }

    // 如果没有数据，设置默认范围
    if (minY.isInfinite || maxY.isInfinite) {
      minY = 0;
      maxY = 10;
    } else {
      // 添加一些边距
      final range = maxY - minY;
      minY = minY - range * 0.1;
      maxY = maxY + range * 0.1;
      if (minY < 0) minY = 0; // 确保最小值不小于0
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: (maxY - minY) / 5,
          verticalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              interval: (maxY - minY) / 5,
              getTitlesWidget: (value, meta) {
                if (value == minY && value == 0) return const SizedBox.shrink();
                String unit = _getUnitForDataType(dataType);
                return Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: const TextStyle(fontSize: 9),
                );
              },
            ),
            axisNameWidget: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _getAxisNameForDataType(dataType),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 10,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: lineBarsData,
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: _selectedDeviceIds.map((deviceId) {
        final device = _getDeviceById(deviceId);
        final color = _deviceColors[deviceId] ?? Colors.grey;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              device?.deviceName ?? '未知设备',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showDeviceSelectionDialog() {
    final allDevices = [
      ...monitorController.selectedDevices,
      ...monitorController.savedDevices,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择对比设备'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: allDevices.map((device) {
              final color = _deviceColors[device.deviceId] ?? Colors.grey;

              return StatefulBuilder(
                builder: (context, setStateLocal) {
                  final isSelectedLocal =
                      _selectedDeviceIds.contains(device.deviceId);
                  return CheckboxListTile(
                    value: isSelectedLocal,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          if (!_selectedDeviceIds.contains(device.deviceId)) {
                            _selectedDeviceIds.add(device.deviceId);
                          }
                        } else {
                          _selectedDeviceIds.remove(device.deviceId);
                        }
                      });
                      setStateLocal(() {}); // 立即更新本地状态
                    },
                    title: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(device.deviceName)),
                      ],
                    ),
                    subtitle: Text('数据点: ${device.dataHistory.length}'),
                  );
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedDeviceIds.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('清空'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  SelectedDevice? _getDeviceById(String deviceId) {
    return monitorController.selectedDevices
            .firstWhereOrNull((d) => d.deviceId == deviceId) ??
        monitorController.savedDevices
            .firstWhereOrNull((d) => d.deviceId == deviceId);
  }

  void _removeDevice(String deviceId) {
    setState(() {
      _selectedDeviceIds.remove(deviceId);
    });
  }

  List<FlSpot> _getChartData(List<DeviceData> data, String dataType) {
    if (data.isEmpty) return [];

    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final deviceData = entry.value;

      double value;
      switch (dataType) {
        case 'current':
          value = deviceData.current;
          break;
        case 'voltage':
          value = deviceData.voltage;
          break;
        case 'power':
          value = deviceData.power;
          break;
        default:
          value = 0;
      }

      return FlSpot(index.toDouble(), value);
    }).toList();
  }

  String _getChartTitle(String dataType) {
    switch (dataType) {
      case 'current':
        return '电流对比';
      case 'voltage':
        return '电压对比';
      case 'power':
        return '功率对比';
      default:
        return '数据对比';
    }
  }

  /// 获取数据类型对应的单位
  String _getUnitForDataType(String dataType) {
    switch (dataType) {
      case 'current':
        return 'mA';
      case 'voltage':
        return 'mV';
      case 'power':
        return 'mW';
      default:
        return '';
    }
  }

  /// 获取数据类型对应的坐标轴名称
  String _getAxisNameForDataType(String dataType) {
    switch (dataType) {
      case 'current':
        return '电流(mA)';
      case 'voltage':
        return '电压(mV)';
      case 'power':
        return '功率(mW)';
      default:
        return '数值';
    }
  }
}
