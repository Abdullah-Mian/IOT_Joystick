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
import 'code_display_screen.dart';

     
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
        cardTheme: CardTheme(
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
    
    // Start scanning before showing dialog
    bluetoothService.stopScan(); // Stop any existing scan
    bluetoothService.startScan(); // Start scanning
    
    // Set a timer to stop the scanning indicator after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      isScanning = false;
    });
    
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
                : const Icon(Icons.bluetooth_disabled),
            ],
          ),
          content: SizedBox(
            width: 300,
            height: 400,
            child: Column(
              children: [
                // Scan button at the top for better visibility
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Update scanning state first
                      setState(() => isScanning = true);
                      
                      // Stop any existing scan
                      bluetoothService.stopScan();
                      
                      // Start a new scan
                      try {
                        bluetoothService.startScan();
                        
                        // Set a timer to update the UI after scanning for a while
                        Future.delayed(const Duration(seconds: 10), () {
                          if (context.mounted) {
                            setState(() => isScanning = false);
                          }
                        });
                      } catch (e) {
                        // Handle any errors that might occur
                        if (context.mounted) {
                          setState(() => isScanning = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to scan: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan for Devices'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<fb.ScanResult>>(
                    stream: bluetoothService.scanResults,
                    initialData: const [],
                    builder: (context, snapshot) {
                      if (snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bluetooth_searching, size: 48, color: Colors.blue),
                              const SizedBox(height: 16),
                              Text(
                                isScanning 
                                  ? 'Scanning for devices...' 
                                  : 'No devices found. Tap Scan to try again.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        );
                      }
                      
                      // Display scan results
                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final device = snapshot.data![index].device;
                          final name = device.name.isEmpty ? 'Unknown Device' : device.name;
                          return ListTile(
                            leading: const Icon(Icons.bluetooth, color: Colors.blue),
                            title: Text(name),
                            subtitle: Text(device.id.toString()),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _connectToDevice(device, name),
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
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ).then((_) => bluetoothService.stopScan());
    
    // No need for this since we're already handling it with the Future.delayed above
    // Future.delayed(const Duration(seconds: 10), () {
    //   isScanning = false;
    // });
  }

  Future<void> _connectToDevice(fb.BluetoothDevice device, String name) async {
    try {
      await bluetoothService.connectToDevice(device);
      setState(() {
        bluetoothStatus = 'Connected to $name';
      });
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        bluetoothStatus = 'Connection Failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: ${e.toString()}')),
      );
    } finally {
      bluetoothService.stopScan();
    }
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