import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RemoteControlPage extends StatefulWidget {
  const RemoteControlPage({Key? key}) : super(key: key);

  @override
  State<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends State<RemoteControlPage> {
  bool isScanning = false;
  bool isConnected = false;
  String? connectedDeviceName;

  // 自定义按钮列表
  List<CustomButton> customButtons = [
    CustomButton(
      id: '1',
      name: '开关灯',
      icon: Icons.lightbulb_outline,
      data: [0x01, 0x02, 0x03],
      color: Colors.amber,
    ),
    CustomButton(
      id: '2',
      name: '鸣笛',
      icon: Icons.campaign,
      data: [0x04, 0x05, 0x06],
      color: Colors.red,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '遥控',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E3A59),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2E3A59),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddButtonDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 连接状态卡片
            _buildConnectionCard(),

            const SizedBox(height: 24),

            // 扫描按钮
            if (!isConnected) _buildScanButton(),

            if (!isConnected) const SizedBox(height: 24),

            // 自定义按钮区域
            if (isConnected) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '自定义按钮',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E3A59),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showAddButtonDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4A90E2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 按钮网格
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: customButtons.length,
                itemBuilder: (context, index) {
                  final button = customButtons[index];
                  return _buildCustomButton(button);
                },
              ),
            ],

            // 空状态提示
            if (!isConnected && !isScanning) ...[
              const SizedBox(height: 32),
              _buildEmptyState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected
              ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
              : [const Color(0xFF8E8E93), const Color(0xFF636366)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isConnected ? const Color(0xFF4CAF50) : Colors.grey)
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            isConnected ? '已连接' : '未连接',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isConnected ? connectedDeviceName ?? '未知设备' : '请扫描并连接蓝牙设备',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          if (isConnected) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _disconnectDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('断开连接'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isScanning) ...[
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 16),
            const Text(
              '正在扫描设备...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E3A59),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请确保目标设备已开启蓝牙',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _stopScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text('停止扫描'),
            ),
          ] else ...[
            const Icon(
              Icons.bluetooth_searching,
              size: 48,
              color: Color(0xFF4A90E2),
            ),
            const SizedBox(height: 16),
            const Text(
              '扫描蓝牙设备',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E3A59),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击开始扫描附近的蓝牙设备',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '开始扫描',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomButton(CustomButton button) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _sendCustomData(button),
        onLongPress: () => _editButton(button),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                button.color.withOpacity(0.1),
                button.color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: button.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  button.icon,
                  size: 32,
                  color: button.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                button.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: button.color.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '数据: ${button.data.map((e) => e.toRadixString(16).toUpperCase()).join(' ')}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.bluetooth_disabled,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '未连接设备',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E3A59),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '连接蓝牙设备后即可使用\n自定义按钮功能',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _startScan() {
    setState(() {
      isScanning = true;
    });

    // 模拟扫描过程
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isScanning = false;
          isConnected = true;
          connectedDeviceName = '智能设备 #001';
        });

        Get.snackbar(
          '连接成功',
          '已连接到 $connectedDeviceName',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    });
  }

  void _stopScan() {
    setState(() {
      isScanning = false;
    });
  }

  void _disconnectDevice() {
    setState(() {
      isConnected = false;
      connectedDeviceName = null;
    });

    Get.snackbar(
      '已断开连接',
      '设备已断开连接',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _sendCustomData(CustomButton button) {
    if (!isConnected) return;

    // TODO: 实际发送蓝牙数据
    Get.snackbar(
      '指令已发送',
      '${button.name}: ${button.data.map((e) => e.toRadixString(16).toUpperCase()).join(' ')}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: button.color,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  void _editButton(CustomButton button) {
    _showEditButtonDialog(button);
  }

  void _showAddButtonDialog() {
    _showEditButtonDialog(null);
  }

  void _showEditButtonDialog(CustomButton? button) {
    final nameController = TextEditingController(text: button?.name ?? '');
    final dataController = TextEditingController(
      text: button?.data
              .map((e) => e.toRadixString(16).toUpperCase())
              .join(' ') ??
          '',
    );
    IconData selectedIcon = button?.icon ?? Icons.touch_app;
    Color selectedColor = button?.color ?? Colors.blue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(button == null ? '添加按钮' : '编辑按钮'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '按钮名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dataController,
                  decoration: const InputDecoration(
                    labelText: '发送数据 (十六进制，空格分隔)',
                    hintText: '例如: 01 02 03',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // 图标选择
                const Text('选择图标:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Icons.lightbulb_outline,
                    Icons.power_settings_new,
                    Icons.campaign,
                    Icons.music_note,
                    Icons.flash_on,
                    Icons.favorite,
                  ]
                      .map((icon) => GestureDetector(
                            onTap: () => setState(() => selectedIcon = icon),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedIcon == icon
                                    ? Colors.blue.withOpacity(0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                // 颜色选择
                const Text('选择颜色:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Colors.blue,
                    Colors.red,
                    Colors.green,
                    Colors.orange,
                    Colors.purple,
                    Colors.teal,
                  ]
                      .map((color) => GestureDetector(
                            onTap: () => setState(() => selectedColor = color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: selectedColor == color
                                    ? Border.all(color: Colors.black, width: 2)
                                    : null,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            if (button != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    customButtons.removeWhere((b) => b.id == button.id);
                  });
                  Navigator.pop(context);
                },
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final dataStr = dataController.text.trim();

                if (name.isEmpty || dataStr.isEmpty) return;

                try {
                  final data = dataStr
                      .split(' ')
                      .map((s) => int.parse(s, radix: 16))
                      .toList();

                  final newButton = CustomButton(
                    id: button?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    icon: selectedIcon,
                    data: data,
                    color: selectedColor,
                  );

                  setState(() {
                    if (button != null) {
                      final index =
                          customButtons.indexWhere((b) => b.id == button.id);
                      if (index != -1) {
                        customButtons[index] = newButton;
                      }
                    } else {
                      customButtons.add(newButton);
                    }
                  });

                  Navigator.pop(context);
                } catch (e) {
                  Get.snackbar('错误', '数据格式不正确');
                }
              },
              child: Text(button == null ? '添加' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomButton {
  final String id;
  final String name;
  final IconData icon;
  final List<int> data;
  final Color color;

  CustomButton({
    required this.id,
    required this.name,
    required this.icon,
    required this.data,
    required this.color,
  });
}
