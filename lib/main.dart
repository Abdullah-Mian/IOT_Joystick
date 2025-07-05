import 'package:custombot_control/Joysticks/action_button.dart';
import 'package:custombot_control/Joysticks/arcade_joystick.dart';
import 'package:custombot_control/Joysticks/classic_joystick.dart';
import 'package:custombot_control/Joysticks/close_buttons_joystick.dart';
import 'package:custombot_control/Joysticks/distant_buttons_joystick.dart';
import 'package:custombot_control/Joysticks/minimal_joystick.dart';
import 'package:custombot_control/Joysticks/modern_joystick.dart';
import 'package:custombot_control/Joysticks/neo_joystick.dart';
import 'package:custombot_control/Joysticks/small_buttons_joystick.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'bluetooth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Samplecodes_display_screen.dart';
import 'package:permission_handler/permission_handler.dart';

     
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Supabase.initialize(
    url: 'https://ideoikmeahylpdeegumg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlkZW9pa21lYWh5bHBkZWVndW1nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyODcxMDgsImV4cCI6MjA1Nzg2MzEwOH0.40e5m6HPlZBHuCzbsotfdCyjtk6QBIapESs7yfiBqVI',
  );
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Controller',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardTheme: CardThemeData(
          color: const Color(0xFF2D2D2D),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const ControllerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
    with SingleTickerProviderStateMixin {
  String ipAddress = 'Loading...';
  bool isServerConnected = false;
  bool isServerOn = false;
  late AnimationController _controllerIconController;
  int selectedJoystickStyle = 0;
  HttpServer? wsServer;
  List<WebSocketChannel> connectedClients = [];
  bool isBluetoothEnabled = false;
  String bluetoothStatus = 'Not Connected';

  final CustomBluetoothService bluetoothService = CustomBluetoothService();

  Map<String, String> buttonChars = {
    'forward': 'W',
    'backward': 'S',
    'left': 'A',
    'right': 'D',
    'action1': 'X',
    'action2': 'Y',
  };

  final List<Widget Function(BuildContext, Map<String, Function>)> joystickStyles = [
    (context, callbacks) => ClassicJoystick(callbacks: callbacks),
    (context, callbacks) => ModernJoystick(callbacks: callbacks),
    (context, callbacks) => MinimalJoystick(callbacks: callbacks),
    (context, callbacks) => NeoJoystick(callbacks: callbacks),
    (context, callbacks) => ArcadeJoystick(callbacks: callbacks),
    (context, callbacks) => SmallButtonsJoystick(callbacks: callbacks),
    (context, callbacks) => CloseButtonsJoystick(callbacks: callbacks),
    (context, callbacks) => DistantButtonsJoystick(callbacks: callbacks),
  ];

  final List<String> joystickNames = [
    'Classic',
    'Modern',
    'Minimal',
    'Neo',
    'Arcade',
    'SmallButtons',
    'CloseButtons',
    'DistantButtons',
  ];

  static const int port = 5000;

  @override
  void initState() {
    super.initState();
    _controllerIconController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    getIPAddress();
    loadSettings();
    _initializeBluetooth();
  }

  void _initializeBluetooth() {
    bluetoothService.bluetoothState.listen((fb.BluetoothAdapterState state) {
      if (mounted) {
        setState(() {
          isBluetoothEnabled = state == fb.BluetoothAdapterState.on;
          if (!isBluetoothEnabled) {
            bluetoothService.disconnect();
            bluetoothStatus = 'Bluetooth Off';
          }
        });
      }
    });
  }

  Future<void> getIPAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      setState(() {
        ipAddress = wifiIp != null ? '$wifiIp:$port' : 'Not found';
      });
    } catch (e) {
      setState(() {
        ipAddress = 'Error getting IP';
      });
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      buttonChars = {
        'forward': prefs.getString('forward')?.toUpperCase() ?? 'W',
        'backward': prefs.getString('backward')?.toUpperCase() ?? 'S',
        'left': prefs.getString('left')?.toUpperCase() ?? 'A',
        'right': prefs.getString('right')?.toUpperCase() ?? 'D',
        'action1': prefs.getString('action1')?.toUpperCase() ?? 'X',
        'action2': prefs.getString('action2')?.toUpperCase() ?? 'Y',
      };
      selectedJoystickStyle = prefs.getInt('joystickStyle') ?? 0;
    });
  }

  Future<void> saveJoystickStyle(int style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('joystickStyle', style);
  }

  void showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Controller Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSettingField('Forward', 'forward'),
              _buildSettingField('Backward', 'backward'),
              _buildSettingField('Left', 'left'),
              _buildSettingField('Right', 'right'),
              _buildSettingField('Action X', 'action1'),
              _buildSettingField('Action Y', 'action2'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingField(String label, String key) {
    return ListTile(
      title: Text(label),
      trailing: SizedBox(
        width: 50,
        child: TextField(
          maxLength: 1,
          controller: TextEditingController(text: buttonChars[key]),
          onChanged: (value) async {
            if (value.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(key, value.toUpperCase());
              setState(() {
                buttonChars[key] = value.toUpperCase();
              });
            }
          },
          decoration: const InputDecoration(counterText: ""),
        ),
      ),
    );
  }

  void showJoystickSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Joystick Style'),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: joystickStyles.length,
            itemBuilder: (context, index) => InkWell(
              onTap: () {
                setState(() {
                  selectedJoystickStyle = index;
                  saveJoystickStyle(index);
                });
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedJoystickStyle == index
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gamepad),
                    const SizedBox(height: 8),
                    Text(joystickNames[index]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> toggleServer(bool value) async {
    setState(() {
      isServerOn = value;
    });
    if (value) {
      try {
        var handler = webSocketHandler((WebSocketChannel socket) {
          setState(() {
            connectedClients.add(socket);
            isServerConnected = true;
            _controllerIconController.stop();
          });
          socket.stream.listen(
            (message) {},
            onDone: () {
              setState(() {
                connectedClients.remove(socket);
                if (connectedClients.isEmpty) {
                  isServerConnected = false;
                  _controllerIconController.repeat(reverse: true);
                }
              });
            },
            onError: (error) {
              print('WebSocket error: $error');
            },
          );
        });
        wsServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
        print('WebSocket server running on ws://${wsServer!.address.address}:$port');
      } catch (e) {
        print('Error starting WebSocket server: $e');
        setState(() {
          isServerOn = false;
          isServerConnected = false;
          _controllerIconController.repeat(reverse: true);
        });
      }
    } else {
      for (var client in connectedClients) {
        client.sink.close();
      }
      connectedClients.clear();
      await wsServer?.close();
      wsServer = null;
      setState(() {
        isServerConnected = false;
        _controllerIconController.repeat(reverse: true);
      });
    }
  }

  void sendCharacter(String character) {
    // Send via Bluetooth if enabled and connected
    if (isBluetoothEnabled && bluetoothService.isConnected) {
      bluetoothService.sendData(character);
    }
    // Send via WebSocket if server is on and connected
    if (isServerOn && isServerConnected && connectedClients.isNotEmpty) {
      for (var client in connectedClients) {
        client.sink.add(character);
      }
    }
  }

  void _showBluetoothDevicesDialog() {
    if (!isBluetoothEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable Bluetooth')),
      );
      return;
    }
    
    bool isScanning = true;
    bool hasFoundEsp32 = false;
    String statusMessage = 'Scanning for devices...';
    
    // First ensure we have all required permissions
    _requestBluetoothPermissions().then((permissionsGranted) {
      if (!permissionsGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth permissions are required to scan for devices')),
        );
        return;
      }
      
      // Start scanning before showing dialog with longer timeout to find ESP32 devices
      bluetoothService.stopScan();
      
      // Listen for ESP32 devices specifically
      bluetoothService.isEsp32Device.listen((isEsp32) {
        if (isEsp32) hasFoundEsp32 = true;
      });
      
      // Listen for device messages
      bluetoothService.deviceMessages.listen((message) {
        if (context.mounted) {
          setState(() {
            statusMessage = message;
          });
        }
      });
      
      bluetoothService.startScan(timeout: const Duration(seconds: 20));
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Bluetooth Device'),
                isScanning 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        setState(() {
                          isScanning = true;
                          hasFoundEsp32 = false;
                          statusMessage = 'Scanning for devices...';
                        });
                        
                        bluetoothService.stopScan();
                        bluetoothService.startScan(timeout: const Duration(seconds: 20)).then((_) {
                          if (context.mounted) {
                            setState(() => isScanning = false);
                          }
                        });
                      },
                    ),
              ],
            ),
            content: SizedBox(
              width: 300,
              height: 400,
              child: Column(
                children: [
                  // Status message display
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    width: double.infinity,
                    child: Text(
                      statusMessage,
                      style: TextStyle(color: Colors.blue[800]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  Expanded(
                    child: StreamBuilder<List<DeviceInfo>>(  // Use DeviceInfo instead of CustomBluetoothService.DeviceInfo
                      stream: bluetoothService.scanResults,
                      initialData: const [],
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data!.isEmpty) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                          );
                        }
                        
                        final devices = snapshot.data ?? [];
                        
                        if (devices.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bluetooth_searching, size: 48, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  isScanning ? 'Searching for devices...' : 'No devices found',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Sort devices with null safety
                        final espDevices = devices
                            .where((d) => d.isEsp32)  // isEsp32 is non-nullable in DeviceInfo class
                            .toList()
                          ..sort((a, b) => b.rssi.compareTo(a.rssi));  // rssi is non-nullable in DeviceInfo class
                        
                        final otherDevices = devices
                            .where((d) => !d.isEsp32)
                            .toList()
                          ..sort((a, b) => b.rssi.compareTo(a.rssi));
                        
                        final allSortedDevices = [...espDevices, ...otherDevices];
                        
                        return ListView.builder(
                          itemCount: allSortedDevices.length,
                          itemBuilder: (context, index) {
                            final deviceInfo = allSortedDevices[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: deviceInfo.isEsp32
                                  ? const Color.fromARGB(255, 235, 248, 235)  // Light green for ESP32
                                  : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: deviceInfo.isEsp32 ? Colors.green : Colors.transparent,
                                  width: deviceInfo.isEsp32 ? 1 : 0,
                                ),
                              ),
                              child: ListTile(
                                title: Text(
                                  deviceInfo.displayName,
                                  style: TextStyle(
                                    fontWeight: deviceInfo.isEsp32 ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(deviceInfo.isEsp32 
                                        ? 'ESP32 Device'
                                        : 'Bluetooth LE'),
                                    Text('Signal: ${deviceInfo.rssi} dBm', 
                                         style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: deviceInfo.isEsp32 ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    deviceInfo.isEsp32 ? Icons.memory : Icons.bluetooth,
                                    color: deviceInfo.isEsp32 ? Colors.green : Colors.blue,
                                    size: 24,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: _getRssiColor(deviceInfo.rssi).withOpacity(0.2),
                                      ),
                                      child: Text(
                                        _getRssiLabel(deviceInfo.rssi),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _getRssiColor(deviceInfo.rssi),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.arrow_forward_ios, size: 12),
                                  ],
                                ),
                                onTap: () async {
                                  // Close the dialog
                                  Navigator.of(context).pop();
                                  
                                  // Stop scanning
                                  bluetoothService.stopScan();
                                  
                                  // Show connection attempt dialog
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Connecting'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                const CircularProgressIndicator(),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text('Connecting to ${deviceInfo.displayName}...'),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Please wait while establishing connection',
                                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              deviceInfo.isEsp32 ? 'ESP32 device detected!' : 'Standard Bluetooth device',
                                              style: TextStyle(
                                                fontStyle: FontStyle.italic,
                                                fontSize: 12,
                                                color: deviceInfo.isEsp32 ? Colors.green : Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                  
                                  try {
                                    await bluetoothService.connectToDevice(deviceInfo.scanResult.device);
                                    if (context.mounted) {
                                      Navigator.of(context).pop(); // Close connection dialog
                                      setState(() {
                                        bluetoothStatus = 'Connected to ${deviceInfo.displayName}';
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Connected to ${deviceInfo.displayName}'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      Navigator.of(context).pop(); // Close connection dialog
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to connect: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  bluetoothService.stopScan();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ).then((_) {
        // Clean up when dialog is closed
        bluetoothService.stopScan();
      });
    });
  }
  
  // Helper functions for the RSSI signal display
  Color _getRssiColor(int rssi) {
    if (rssi > -60) return Colors.green;
    if (rssi > -80) return Colors.orange;
    return Colors.red;
  }
  
  String _getRssiLabel(int rssi) {
    if (rssi > -60) return 'Excellent';
    if (rssi > -70) return 'Good';
    if (rssi > -80) return 'Fair';
    if (rssi > -90) return 'Weak';
    return 'Poor';
  }

  // Handle permission requests for Bluetooth
  Future<bool> _requestBluetoothPermissions() async {
    // For Android 12 (API 31) and higher, we need specific Bluetooth permissions
    List<Permission> permissions = [Permission.location];
    
    // Check Android version to request appropriate permissions
    if (Platform.isAndroid) {
      // These permissions are only needed on Android 12+
      permissions.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ]);
    }
    
    // Request all permissions at once
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // Check if all required permissions are granted
    bool allPermissionsGranted = true;
    
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        print("Permission not granted: $permission");
        allPermissionsGranted = false;
      }
    });
    
    return allPermissionsGranted;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.download),
        onPressed: () async {
          try {
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            );

            final List<dynamic> data = await Supabase.instance.client
              .from('Code')
              .select('*');

            // Hide loading indicator
            Navigator.pop(context);

            // Navigate to the code display screen
            if (context.mounted) {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => CodeDisplayScreen(codeData: data),
                ),
              );
            }
          } catch (e) {
            // Hide loading indicator
            Navigator.pop(context);
            
            // Show error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error fetching code: ${e.toString()}')),
            );
          }
        },
      ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withAlpha((0.3 * 255).toInt()),
                colorScheme.secondaryContainer.withAlpha((0.3 * 255).toInt()),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ipAddress),
              const SizedBox(width: 8),
              FadeTransition(
                opacity: _controllerIconController,
                child: Icon(
                  Icons.network_wifi,
                  color: isServerConnected ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  if (isBluetoothEnabled) {
                    if (!bluetoothService.isConnected) {
                      _showBluetoothDevicesDialog();
                    }
                  } else {
                    setState(() {
                      isBluetoothEnabled = true;
                    });
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _showBluetoothDevicesDialog();
                    });
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      color: bluetoothStatus.startsWith('Connected')
                        ? Colors.green
                        : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(bluetoothStatus),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leak_add_sharp),
            onPressed: () {}, // implement functionality if needed
          ),
        ],
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () => showSettingsDialog(context),
                      ),
                      const SizedBox(width: 20),
                      _buildControlButton(
                        icon: Icons.gamepad,
                        label: 'Style',
                        onTap: showJoystickSelector,
                      ),
                      const SizedBox(width: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Server', style: TextStyle(fontSize: 13)),
                          Switch(
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            value: isServerOn,
                            onChanged: toggleServer,
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Bluetooth', style: TextStyle(fontSize: 13)),
                          GestureDetector(
                            onTap: () {
                              if (isBluetoothEnabled) {
                                _showBluetoothDevicesDialog();
                              } else {
                                setState(() {
                                  isBluetoothEnabled = true;
                                  _showBluetoothDevicesDialog();
                                });
                              }
                            },
                            child: Switch(
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              value: isBluetoothEnabled,
                              onChanged: (value) {
                                setState(() {
                                  isBluetoothEnabled = value;
                                  if (!value) {
                                    bluetoothService.disconnect();
                                    bluetoothStatus = 'Not Connected';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 20,
            child: joystickStyles[selectedJoystickStyle](
              context,
              {
                'onForward': () => sendCharacter(buttonChars['forward']!),
                'onBackward': () => sendCharacter(buttonChars['backward']!),
                'onLeft': () => sendCharacter(buttonChars['left']!),
                'onRight': () => sendCharacter(buttonChars['right']!),
                'onRelease': () => sendCharacter('S'),
              },
            ),
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: Row(
              children: [
                ActionButton(
                  label: 'X',
                  color: colorScheme.primaryContainer,
                  onPressed: () => sendCharacter(buttonChars['action1']!),
                ),
                const SizedBox(width: 20),
                ActionButton(
                  label: 'Y',
                  color: colorScheme.secondaryContainer,
                  onPressed: () => sendCharacter(buttonChars['action2']!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    bluetoothService.disconnect();
    bluetoothService.stopScan();
    _controllerIconController.dispose();
    for (var client in connectedClients) {
      client.sink.close();
    }
    wsServer?.close();
    super.dispose();
  }
}