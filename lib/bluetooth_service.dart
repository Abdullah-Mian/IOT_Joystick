import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:permission_handler/permission_handler.dart';

class DeviceInfo {
  final fb.ScanResult scanResult;
  final String displayName;
  final bool isEsp32;
  final int rssi;
  final String deviceId;
  
  const DeviceInfo({
    required this.scanResult, 
    required this.displayName, 
    required this.isEsp32,
    required this.rssi,
    required this.deviceId,
  });
}

class CustomBluetoothService {
  // For ESP32 devices, common service/characteristic UUIDs
  // These are typical ESP32 BLE UART service UUIDs
  static const String ESP32_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String ESP32_RX_CHAR_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Write characteristic
  static const String ESP32_TX_CHAR_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // Read/notify characteristic
  
  // Additional ESP32 manufacturer IDs
  static const List<int> ESP32_MANUFACTURER_IDS = [0x02E5, 0x0315, 0x0504];
  
  fb.BluetoothDevice? _connectedDevice;
  fb.BluetoothCharacteristic? _characteristic;
  StreamSubscription? _deviceConnectionSubscription;
  StreamSubscription? _scanSubscription;
  
  final _scanResultsController = StreamController<List<DeviceInfo>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _isEsp32Controller = StreamController<bool>.broadcast();
  final _deviceMessageController = StreamController<String>.broadcast();
  
  Stream<List<DeviceInfo>> get scanResults => _scanResultsController.stream;
  Stream<fb.BluetoothAdapterState> get bluetoothState => fb.FlutterBluePlus.adapterState;
  Stream<bool> get connectionState => _connectionStateController.stream;
  Stream<bool> get isEsp32Device => _isEsp32Controller.stream;
  Stream<String> get deviceMessages => _deviceMessageController.stream;
  
  bool get isConnected => _connectedDevice != null && _characteristic != null;
  
  CustomBluetoothService() {
    _initListeners();
  }
  
  void _initListeners() {
    // Monitor adapter state changes
    fb.FlutterBluePlus.adapterState.listen((state) {
      print("Bluetooth adapter state changed: $state");
      if (state != fb.BluetoothAdapterState.on) {
        // If bluetooth is turned off, mark as disconnected
        _connectionStateController.add(false);
      }
    });
  }

  // Set up connection state monitoring for a specific device
  void _setupDeviceConnectionListener(fb.BluetoothDevice device) {
    // Cancel any existing subscription first
    _deviceConnectionSubscription?.cancel();
    
    _deviceConnectionSubscription = device.connectionState.listen((state) {
      bool isConnected = state == fb.BluetoothConnectionState.connected;
      print("Device ${device.platformName} connection state changed to: $state");
      _connectionStateController.add(isConnected);
      
      if (!isConnected && _connectedDevice?.id == device.id) {
        _connectedDevice = null;
        _characteristic = null;
        print("Device disconnected: ${device.platformName}");
      }
    });
  }
  
  // Enhanced ESP32 detection
  bool isLikelyEsp32(fb.ScanResult result) {
    final deviceName = result.device.platformName.toLowerCase();
    
    // Check device name - ESP32 devices often have "ESP32" in their name
    if (deviceName.contains("esp32") || deviceName.contains("esp-32")) {
      return true;
    }
    
    // Check advertised service UUIDs - ESP32 often advertises the UART service
    if (result.advertisementData.serviceUuids.isNotEmpty) {
      for (var uuid in result.advertisementData.serviceUuids) {
        if (uuid.toString().toUpperCase() == ESP32_SERVICE_UUID) {
          return true;
        }
      }
    }
    
    // Additional checks for ESP32 manufacturer data signatures
    if (result.advertisementData.manufacturerData.isNotEmpty) {
      // Check known ESP32 manufacturer IDs
      for (var mfgId in ESP32_MANUFACTURER_IDS) {
        if (result.advertisementData.manufacturerData.containsKey(mfgId)) {
          return true;
        }
      }
      
      // Additional heuristic: Using any() instead of forEach to check manufacturer data
      // This fixes the issue with trying to return from a forEach closure
      bool hasEsp32Pattern = false;
      result.advertisementData.manufacturerData.values.any((value) {
        if (value.isNotEmpty && value.length >= 2) {
          // Some ESP32 modules use specific patterns in their manufacturer data
          if ((value[0] == 0x02 && value[1] == 0xE5) || 
              (value[0] == 0x03 && value[1] == 0x15)) {
            hasEsp32Pattern = true;
            return true; // This only returns from the 'any' callback, not the entire method
          }
        }
        return false;
      });
      
      if (hasEsp32Pattern) {
        return true;
      }
    }
    
    // If signal strength is very strong, it might be a nearby ESP32 without proper advertising data
    // This is a last resort check that assumes a very close device might be your ESP32
    // Adjust the RSSI threshold based on your testing environment
    if (result.rssi > -50) {  // Very close device
      // Look for common patterns in local name that might indicate an ESP32
      final localName = result.advertisementData.localName.toLowerCase();
      if (localName.contains("esp") || 
          localName.contains("iot") || 
          localName.contains("ble") ||
          localName.isEmpty) {  // Many ESP32s advertise with empty local names
        return true;
      }
    }
    
    return false;
  }
  
  // Keep the private method for internal use
  bool _isLikelyEsp32(fb.ScanResult result) {
    return isLikelyEsp32(result);
  }
  
  // Create a friendly display name for devices
  String _createDisplayName(fb.ScanResult result) {
    // First try to get the advertised local name
    String advertisedName = result.advertisementData.localName;
    if (advertisedName.isNotEmpty) {
      return advertisedName;
    }
    
    // Then try the platform name from the device
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    
    // If the device might be an ESP32, give it a special name
    if (_isLikelyEsp32(result)) {
      return "ESP32 Device (${result.device.remoteId.toString().substring(0, 8)})";
    }
    
    // For unknown devices, create a name based on device type and ID
    String deviceType = "Unknown Device";
    if (result.advertisementData.connectable) {
      deviceType = "BLE Device";
    }
    
    // Use a shortened version of the ID for display
    String shortId = result.device.remoteId.toString();
    if (shortId.length > 8) {
      shortId = shortId.substring(0, 8) + "...";
    }
    
    return "$deviceType ($shortId)";
  }
  
  Future<bool> requestPermissions() async {
    // Request permissions needed for BLE scanning
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
    
    // Check if all permissions are granted
    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
        print("Permission not granted: $permission");
      }
    });
    
    return allGranted;
  }
  
  Future<void> startScan({Duration? timeout}) async {
    try {
      // First request necessary permissions
      bool permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        throw Exception("Required permissions not granted");
      }
      
      // Check if Bluetooth is available and on
      bool isAvailable = await fb.FlutterBluePlus.isAvailable;
      if (!isAvailable) {
        throw Exception('Bluetooth is not available on this device');
      }
      
      bool isOn = await fb.FlutterBluePlus.isOn;
      if (!isOn) {
        throw Exception('Bluetooth is not enabled');
      }
      
      // Clear old results before scanning
      _scanResultsController.add([]);
      
      // Stop any previous scan
      if (await fb.FlutterBluePlus.isScanning.first) {
        await fb.FlutterBluePlus.stopScan();
      }
      
      _isEsp32Controller.add(false); // Reset ESP32 device detection flag
      
      print("Starting BLE scan with timeout: ${timeout?.inSeconds ?? 15} seconds");
      
      // Handle scan results directly instead of using the global stream
      _scanSubscription?.cancel();
      _scanSubscription = fb.FlutterBluePlus.onScanResults.listen((results) {
        if (results.isNotEmpty) {
          List<DeviceInfo> deviceInfoList = [];
          bool foundEsp32 = false;
          
          // Process each result as it comes in
          for (var result in results) {
            final device = result.device;
            
            // Create a better display name
            String displayName = _createDisplayName(result);
            
            // Check if this is likely an ESP32 device
            bool isEsp32 = _isLikelyEsp32(result);
            if (isEsp32) {
              print("  ==> POTENTIAL ESP32 DEVICE FOUND: $displayName <==");
              foundEsp32 = true;
            }
            
            // Log device details for debugging
            print("Found device: $displayName (${device.remoteId}), RSSI: ${result.rssi}");
            if (result.advertisementData.serviceUuids.isNotEmpty) {
              print("  Service UUIDs: ${result.advertisementData.serviceUuids}");
            }
            if (result.advertisementData.manufacturerData.isNotEmpty) {
              print("  Manufacturer Data: ${result.advertisementData.manufacturerData}");
            }
            
            // Add to our custom device info list
            deviceInfoList.add(DeviceInfo(
              scanResult: result,
              displayName: displayName,
              isEsp32: isEsp32,
              rssi: result.rssi,
              deviceId: device.remoteId.toString(),
            ));
          }
          
          // Update the ESP32 detection flag
          _isEsp32Controller.add(foundEsp32);
          
          // Sort devices by RSSI (signal strength) so closest devices appear first
          deviceInfoList.sort((a, b) => b.rssi.compareTo(a.rssi));
          
          // Update the scan results stream with our enhanced device info
          _scanResultsController.add(deviceInfoList);
        }
      }, onError: (error) {
        print("Scan results error: $error");
      });
      
      // Configure scan settings optimized for ESP32 detection
      await fb.FlutterBluePlus.startScan(
        timeout: timeout ?? const Duration(seconds: 20),
        androidScanMode: fb.AndroidScanMode.lowLatency,
        // Don't filter for services to ensure we catch all ESP32 devices
      );
      
      print("BLE scan started successfully");
    } catch (e) {
      print('Error starting Bluetooth scan: $e');
      rethrow;
    }
  }
  
  Future<void> stopScan() async {
    try {
      _scanSubscription?.cancel();
      _scanSubscription = null;
      
      if (await fb.FlutterBluePlus.isScanning.first) {
        await fb.FlutterBluePlus.stopScan();
        print("BLE scan stopped");
      }
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }
  
  Future<void> connectToDevice(fb.BluetoothDevice device) async {
    try {
      // Disconnect from any previous device
      await disconnect();
      
      print("Attempting to connect to: ${device.platformName} (${device.remoteId})");
      _deviceMessageController.add("Connecting to ${device.platformName}...");
      
      // Connect with improved options for ESP32
      await device.connect(
        autoConnect: false, // Don't auto-connect as this can be unreliable with ESP32
        timeout: const Duration(seconds: 30), // ESP32 might need longer to connect
      );
      
      _connectedDevice = device;
      
      // Set up connection state listener for this specific device
      _setupDeviceConnectionListener(device);
      
      print("Connected to device: ${device.platformName} (${device.remoteId})");
      _connectionStateController.add(true);
      _deviceMessageController.add("Connected to ${device.platformName}");
      
      // Discover services
      print("Discovering services...");
      _deviceMessageController.add("Discovering services...");
      List<fb.BluetoothService> services = await device.discoverServices();
      print("Discovered ${services.length} services");
      
      // Look specifically for ESP32 UART service first
      fb.BluetoothCharacteristic? espCharacteristic = await _findEsp32Characteristic(services);
      
      // If ESP32 UART characteristic not found, fall back to any writable characteristic
      if (espCharacteristic == null) {
        print("ESP32 UART characteristics not found, looking for any writable characteristic...");
        espCharacteristic = await _findAnyWritableCharacteristic(services);
      }
      
      if (espCharacteristic != null) {
        _characteristic = espCharacteristic;
        print("Using characteristic: ${_characteristic!.uuid}");
        _deviceMessageController.add("Ready to communicate");
        
        // Set up notifications for receiving data if this is a notify characteristic
        if (_characteristic!.properties.notify) {
          await _setupNotifications();
        }
        
        return;
      }
      
      // If no suitable characteristic found, throw error
      throw Exception('No writable characteristic found on this device');
    } catch (e) {
      print('Connection error: $e');
      _deviceMessageController.add("Connection failed: ${e.toString()}");
      
      if (_connectedDevice != null) {
        try {
          await _connectedDevice!.disconnect();
        } catch (disconnectError) {
          print('Error during disconnect after failed connection: $disconnectError');
        }
      }
      _connectedDevice = null;
      _characteristic = null;
      _connectionStateController.add(false);
      rethrow;
    }
  }
  
  // Set up notifications to receive data from ESP32
  Future<void> _setupNotifications() async {
    try {
      if (_characteristic == null || !_characteristic!.properties.notify) {
        return;
      }
      
      // Subscribe to characteristic notifications
      await _characteristic!.setNotifyValue(true);
      
      // Listen for incoming data
      _characteristic!.onValueReceived.listen((value) {
        if (value.isNotEmpty) {
          String receivedData = String.fromCharCodes(value);
          print("Received data: $receivedData");
          _deviceMessageController.add("Received: $receivedData");
        }
      });
      
      print("Notifications set up successfully");
    } catch (e) {
      print('Error setting up notifications: $e');
    }
  }
  
  // Helper method to find ESP32 UART characteristic
  Future<fb.BluetoothCharacteristic?> _findEsp32Characteristic(List<fb.BluetoothService> services) async {
    for (fb.BluetoothService service in services) {
      print("Checking service: ${service.uuid}");
      
      // Check if this service is the ESP32 UART service
      if (service.uuid.toString().toUpperCase() == ESP32_SERVICE_UUID) {
        print("Found ESP32 UART service!");
        _deviceMessageController.add("Found ESP32 UART service");
        
        // Look for the ESP32 RX characteristic (the one we write to)
        for (fb.BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toUpperCase() == ESP32_RX_CHAR_UUID) {
            print("Found ESP32 RX characteristic!");
            
            // Verify it's writable
            if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
              return characteristic;
            }
          }
        }
      }
    }
    return null;
  }
  
  // Helper method to find any writable characteristic as fallback
  Future<fb.BluetoothCharacteristic?> _findAnyWritableCharacteristic(List<fb.BluetoothService> services) async {
    for (fb.BluetoothService service in services) {
      for (fb.BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
          print("Found writable characteristic: ${characteristic.uuid} in service: ${service.uuid}");
          return characteristic;
        }
      }
    }
    return null;
  }
  
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      try {
        // Cancel the device connection subscription
        _deviceConnectionSubscription?.cancel();
        _deviceConnectionSubscription = null;
        
        await _connectedDevice!.disconnect();
        print("Disconnected from device");
        _deviceMessageController.add("Disconnected");
      } catch (e) {
        print('Disconnect error: $e');
      } finally {
        _connectedDevice = null;
        _characteristic = null;
        _connectionStateController.add(false);
      }
    }
  }
  
  Future<void> sendData(String data) async {
    if (!isConnected) {
      throw Exception('Not connected to any device');
    }
    
    try {
      List<int> bytes = data.codeUnits;
      print("Sending data: $data (${bytes.length} bytes)");
      _deviceMessageController.add("Sending: $data");
      
      // Try to determine the best way to write for ESP32
      if (_characteristic!.properties.writeWithoutResponse) {
        // ESP32 typically works better with write without response
        await _characteristic!.write(bytes, withoutResponse: true);
      } else {
        await _characteristic!.write(bytes);
      }
      print("Data sent successfully");
    } catch (e) {
      print('Write error: $e');
      _deviceMessageController.add("Send error: ${e.toString()}");
      rethrow;
    }
  }
  
  void dispose() {
    disconnect();
    stopScan();
    _deviceConnectionSubscription?.cancel();
    _scanSubscription?.cancel();
    _scanResultsController.close();
    _connectionStateController.close();
    _isEsp32Controller.close();
    _deviceMessageController.close();
  }
}