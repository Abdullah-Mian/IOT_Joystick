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
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Samplecodes_display_screen.dart';

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
  
  // WiFi serial terminal variables
  String currentReceivedData = 'No data received yet...';
  List<String> wifiDataLog = [];
  StreamSubscription? _dataSubscription;

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
  }

  Future<void> getIPAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      setState(() {
        ipAddress = wifiIp != null ? '$wifiIp:$port' : 'Not found';
      });
      print('WiFi IP Address: $ipAddress');
    } catch (e) {
      print('Error getting IP address: $e');
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
        print('Starting WebSocket server...');
        
        var handler = webSocketHandler((WebSocketChannel socket) {
          print('WebSocket client connected');
          setState(() {
            connectedClients.add(socket);
            isServerConnected = true;
            _controllerIconController.stop();
          });
          
          // Listen for incoming data from ESP32
          socket.stream.listen(
            (message) {
              print('Received message: $message');
              // Handle received data from ESP32
              setState(() {
                currentReceivedData = message.toString();
                wifiDataLog.add('${DateTime.now().toString().substring(11, 19)}: $message');
                // Keep only last 1000 entries to prevent memory issues
                if (wifiDataLog.length > 1000) {
                  wifiDataLog.removeAt(0);
                }
              });
            },
            onDone: () {
              print('WebSocket client disconnected');
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
              setState(() {
                connectedClients.remove(socket);
                if (connectedClients.isEmpty) {
                  isServerConnected = false;
                  _controllerIconController.repeat(reverse: true);
                }
              });
            },
          );
        });
        
        wsServer = await shelf_io.serve(
          handler, 
          InternetAddress.anyIPv4, 
          port,
        );
        
        print('WebSocket server running on ws://${wsServer!.address.address}:$port');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server started on ${wsServer!.address.address}:$port'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
      } catch (e) {
        print('Error starting WebSocket server: $e');
        setState(() {
          isServerOn = false;
          isServerConnected = false;
          _controllerIconController.repeat(reverse: true);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start server: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print('Stopping WebSocket server...');
      try {
        for (var client in connectedClients) {
          await client.sink.close();
        }
        connectedClients.clear();
        await wsServer?.close();
        wsServer = null;
        setState(() {
          isServerConnected = false;
          _controllerIconController.repeat(reverse: true);
        });
        print('WebSocket server stopped');
      } catch (e) {
        print('Error stopping server: $e');
      }
    }
  }

  void sendCharacter(String character) {
    print('Sending character: $character');
    
    // Send via WebSocket if server is on and connected
    if (isServerOn && isServerConnected && connectedClients.isNotEmpty) {
      for (var client in connectedClients) {
        try {
          client.sink.add(character);
          print('Sent "$character" to WebSocket client');
        } catch (e) {
          print('Error sending to WebSocket client: $e');
        }
      }
    } else {
      print('No WebSocket clients connected');
    }
  }

  // Send data to ESP32 via WiFi
  void sendWifiData(String data) {
    print('Sending WiFi data: $data');
    
    if (isServerOn && isServerConnected && connectedClients.isNotEmpty) {
      for (var client in connectedClients) {
        try {
          client.sink.add(data);
        } catch (e) {
          print('Error sending WiFi data: $e');
        }
      }
      // Add to log for reference
      setState(() {
        wifiDataLog.add('${DateTime.now().toString().substring(11, 19)}: SENT: $data');
        if (wifiDataLog.length > 1000) {
          wifiDataLog.removeAt(0);
        }
      });
    } else {
      print('No WebSocket clients to send data to');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ESP32 connected. Make sure server is ON and ESP32 is connected.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showWifiSerialTerminal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WifiSerialTerminalScreen(
          dataLog: wifiDataLog,
          onSendData: sendWifiData,
          isConnected: isServerConnected,
        ),
      ),
    );
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isServerOn 
                      ? (isServerConnected ? Colors.green : Colors.orange)
                      : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isServerOn 
                      ? (isServerConnected ? 'CONNECTED' : 'WAITING')
                      : 'OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal),
            onPressed: _showWifiSerialTerminal,
            tooltip: 'WiFi Serial Terminal',
          ),
        ],
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // WiFi data display bar
                Center(
                  child: IntrinsicWidth(
                    child: GestureDetector(
                      onTap: _showWifiSerialTerminal,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi,
                              size: 16,
                              color: isServerConnected ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'WiFi Data: ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                currentReceivedData,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (wifiDataLog.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${wifiDataLog.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Icon(
                              Icons.terminal,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Control buttons card
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildControlButton(
                          icon: Icons.settings,
                          label: 'Settings',
                          onTap: () => showControllerSettings(context),
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
                        const SizedBox(width: 20),
                        if (isServerOn) ...[
                          Icon(
                            isServerConnected ? Icons.link : Icons.link_off,
                            color: isServerConnected ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${connectedClients.length} ESP32',
                            style: TextStyle(
                              fontSize: 12,
                              color: isServerConnected ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
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

  void showControllerSettings(BuildContext context) {
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

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _controllerIconController.dispose();
    
    // Clean up WebSocket connections
    for (var client in connectedClients) {
      client.sink.close();
    }
    wsServer?.close();
    
    super.dispose();
  }
}

// New WiFi Serial Terminal Screen
class WifiSerialTerminalScreen extends StatefulWidget {
  final List<String> dataLog;
  final Function(String) onSendData;
  final bool isConnected;

  const WifiSerialTerminalScreen({
    super.key,
    required this.dataLog,
    required this.onSendData,
    required this.isConnected,
  });

  @override
  State<WifiSerialTerminalScreen> createState() => _WifiSerialTerminalScreenState();
}

class _WifiSerialTerminalScreenState extends State<WifiSerialTerminalScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll to bottom when opening and when new data arrives
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendData() {
    if (_inputController.text.isNotEmpty) {
      widget.onSendData(_inputController.text);
      _inputController.clear();
      // Auto-scroll after sending data
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Auto-scroll when new data arrives
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.dataLog.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('WiFi Serial Terminal'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.isConnected ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.isConnected ? 'CONNECTED' : 'DISCONNECTED',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                widget.dataLog.clear();
              });
            },
            tooltip: 'Clear Log',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // Export log functionality
              final logContent = widget.dataLog.join('\n');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Log has ${widget.dataLog.length} entries'),
                  action: SnackBarAction(
                    label: 'View',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Full Log'),
                          content: SizedBox(
                            width: double.maxFinite,
                            height: 400,
                            child: SingleChildScrollView(
                              child: Text(
                                logContent,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
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
                    },
                  ),
                ),
              );
            },
            tooltip: 'Export Log',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: widget.isConnected 
                ? Colors.green.withOpacity(0.1) 
                : Colors.red.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  widget.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: widget.isConnected ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isConnected 
                        ? 'ESP32 connected via WiFi WebSocket - Real-time communication active' 
                        : 'Waiting for ESP32 connection... Make sure ESP32 is connected to the same WiFi network',
                    style: TextStyle(
                      color: widget.isConnected ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.isConnected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Terminal output area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
              ),
              child: widget.dataLog.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isConnected ? Icons.terminal : Icons.wifi_off,
                            size: 48,
                            color: Colors.green.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.isConnected
                                ? 'Terminal ready! Waiting for data from ESP32...'
                                : 'No data received yet...\nData from ESP32 will appear here.',
                            style: const TextStyle(
                              color: Colors.green,
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (!widget.isConnected) ...[
                            const Text(
                              'Setup checklist:',
                              style: TextStyle(
                                color: Colors.yellow,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Server switch is ON\n• ESP32 is powered on\n• ESP32 is connected to WiFi\n• ESP32 WebSocket code is running\n• ESP32 connects to this server',
                              style: TextStyle(
                                color: Colors.green,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: widget.dataLog.length,
                      itemBuilder: (context, index) {
                        final logEntry = widget.dataLog[index];
                        final isSentData = logEntry.contains('SENT:');
                        final isJson = logEntry.contains('{') && logEntry.contains('}');
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            logEntry,
                            style: TextStyle(
                              color: isSentData 
                                  ? Colors.blue 
                                  : isJson 
                                      ? Colors.orange 
                                      : Colors.green,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          // Input area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: widget.isConnected,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: widget.isConnected 
                          ? 'Type command or message to send to ESP32...' 
                          : 'Connect ESP32 to send data',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      suffixIcon: widget.isConnected 
                          ? IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _sendData,
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _sendData(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: widget.isConnected ? _sendData : null,
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}