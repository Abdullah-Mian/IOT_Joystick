import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;

class CustomBluetoothService {
  // Singleton pattern to ensure a single instance
  static final CustomBluetoothService _instance = CustomBluetoothService._internal();
  factory CustomBluetoothService() => _instance;

  CustomBluetoothService._internal();

  fb.BluetoothDevice? connectedDevice;
  fb.BluetoothCharacteristic? targetCharacteristic;

  /// Starts scanning for Bluetooth devices if no device is currently connected.
  void startScan() {
    if (!isConnected) {
      fb.FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    }
  }

  /// Stops the current Bluetooth scan.
  void stopScan() {
    fb.FlutterBluePlus.stopScan();
  }

  /// Stream of scan results from nearby Bluetooth devices.
  Stream<List<fb.ScanResult>> get scanResults => fb.FlutterBluePlus.scanResults;

  /// Stream of the Bluetooth adapter's state (e.g., on, off).
  Stream<fb.BluetoothAdapterState> get bluetoothState => fb.FlutterBluePlus.adapterState;

  /// Checks if a device is connected and a writable characteristic is available.
  bool get isConnected => connectedDevice != null && targetCharacteristic != null;

  /// Connects to a specified Bluetooth device.
  Future<void> connectToDevice(fb.BluetoothDevice device) async {
    try {
      // Connect with a timeout to avoid hanging
      await device.connect(autoConnect: false).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Connection timed out');
        },
      );
      connectedDevice = device;
      await _discoverServices();
    } catch (e) {
      print('Error connecting to device: $e');
      await disconnect(); // Clean up on failure
      rethrow; // Propagate the error to the caller
    }
  }

  /// Disconnects from the currently connected device.
  Future<void> disconnect() async {
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
      } catch (e) {
        print('Error disconnecting: $e');
      }
      connectedDevice = null;
      targetCharacteristic = null;
    }
  }

  /// Discovers services and finds a writable characteristic on the connected device.
  Future<void> _discoverServices() async {
    if (connectedDevice == null) return;
    try {
      List<fb.BluetoothService> services = await connectedDevice!.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            targetCharacteristic = characteristic;
            return; // Use the first writable characteristic found
          }
        }
      }
      throw Exception('No writable characteristic found');
    } catch (e) {
      print('Error discovering services: $e');
      await disconnect();
      rethrow;
    }
  }

  /// Sends data to the connected Bluetooth device.
  Future<void> sendData(String data) async {
    if (!isConnected || targetCharacteristic == null) return;
    try {
      await targetCharacteristic!.write(
        data.codeUnits, // Convert string to byte list
        withoutResponse: targetCharacteristic!.properties.writeWithoutResponse,
      );
    } catch (e) {
      print('Error sending data: $e');
      await disconnect();
    }
  }
}