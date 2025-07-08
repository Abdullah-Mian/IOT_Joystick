#include <WiFi.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>

// IMPORTANT: Update these with your actual WiFi credentials and phone IP
const char* ssid = "Pixel 7";
const char* password = "68986898";
const char* websocket_server = "192.168.18.166";
const int websocket_port = 5000;

// Enhanced timing and connection management
unsigned long lastRandomMessage = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastConnectionAttempt = 0;
unsigned long lastWiFiCheck = 0;
const unsigned long randomMessageInterval = 2000;
const unsigned long heartbeatInterval = 8000;
const unsigned long connectionRetryInterval = 3000;
const unsigned long wifiCheckInterval = 5000;

// Enhanced connection status
bool isConnected = false;
bool wasConnected = false;
bool ledState = false;
int connectionAttempts = 0;
int messageCounter = 0;
const int maxConnectionAttempts = 10;

// Built-in LED pin
const int LED_PIN = 2;

// WebSocket client
WebSocketsClient webSocket;

// Array of random test messages
const char* testMessages[] = {
  "Hello from ESP32!",
  "Testing WiFi Terminal...",
  "ESP32 status: OK",
  "Connection test successful",
  "System running smoothly",
  "WiFi signal strong",
  "Data transmission active",
  "Sensors online",
  "Motors ready",
  "Battery level good"
};

const int numTestMessages = sizeof(testMessages) / sizeof(testMessages[0]);

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== ESP32 WebSocket Client ===");
  Serial.println("Starting WiFi connection...");
  
  // Initialize LED pin
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  // Connect to WiFi
  connectToWiFi();
  
  // Initialize WebSocket connection
  initializeWebSocket();
  
  Serial.println("ESP32 WebSocket Client initialized!");
  Serial.println("Ready to send test messages...");
  
  // Seed random number generator
  randomSeed(analogRead(0));
}

void loop() {
  unsigned long currentTime = millis();
  
  // Check WiFi connection periodically
  if (currentTime - lastWiFiCheck >= wifiCheckInterval) {
    checkWiFiConnection();
    lastWiFiCheck = currentTime;
  }
  
  // Handle WebSocket events
  webSocket.loop();
  
  // Retry WebSocket connection if needed
  if (!isConnected && WiFi.status() == WL_CONNECTED && 
      (currentTime - lastConnectionAttempt >= connectionRetryInterval)) {
    
    if (connectionAttempts < maxConnectionAttempts) {
      Serial.println("Attempting WebSocket reconnection...");
      initializeWebSocket();
      connectionAttempts++;
      lastConnectionAttempt = currentTime;
    } else {
      // Reset attempts after a longer delay
      if (currentTime - lastConnectionAttempt >= 30000) { // 30 seconds
        connectionAttempts = 0;
        Serial.println("Resetting connection attempts...");
      }
    }
  }
  
  // Send messages only when connected
  if (isConnected) {
    // Send random test messages periodically
    if (currentTime - lastRandomMessage >= randomMessageInterval) {
      sendRandomTestMessage();
      lastRandomMessage = currentTime;
    }
    
    // Send heartbeat periodically
    if (currentTime - lastHeartbeat >= heartbeatInterval) {
      sendHeartbeat();
      lastHeartbeat = currentTime;
    }
  }
  
  // Enhanced LED status indication
  updateLEDStatus(currentTime);
  
  delay(10);
}

void checkWiFiConnection() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi connection lost! Attempting to reconnect...");
    isConnected = false;
    connectToWiFi();
  }
}

void updateLEDStatus(unsigned long currentTime) {
  if (isConnected) {
    // Fast blink when connected and active
    digitalWrite(LED_PIN, (currentTime / 100) % 2 == 0);
  } else if (WiFi.status() == WL_CONNECTED) {
    // Medium blink when WiFi connected but WebSocket disconnected
    digitalWrite(LED_PIN, (currentTime / 500) % 2 == 0);
  } else {
    // Slow blink when no WiFi
    digitalWrite(LED_PIN, (currentTime / 1500) % 2 == 0);
  }
}

void connectToWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }
  
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
  
  Serial.println("Connecting to WiFi: " + String(ssid));
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi connected successfully!");
    Serial.println("📶 Network: " + String(ssid));
    Serial.println("📍 IP address: " + WiFi.localIP().toString());
    Serial.println("📡 Signal strength: " + String(WiFi.RSSI()) + " dBm");
    Serial.println("🎯 Target server: " + String(websocket_server) + ":" + String(websocket_port));
    
    connectionAttempts = 0;
  } else {
    Serial.println("\n❌ Failed to connect to WiFi!");
    Serial.println("Please check WiFi credentials and network availability");
  }
}

void initializeWebSocket() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ Cannot initialize WebSocket - WiFi not connected");
    return;
  }
  
  webSocket.disconnect();
  delay(100);
  
  Serial.println("🔌 Initializing WebSocket connection...");
  Serial.println("🎯 Connecting to: ws://" + String(websocket_server) + ":" + String(websocket_port));
  
  webSocket.begin(websocket_server, websocket_port, "/");
  webSocket.onEvent(webSocketEvent);
  webSocket.enableHeartbeat(10000, 3000, 2);
  webSocket.setReconnectInterval(3000);
  
  Serial.println("📡 WebSocket client initialized - waiting for connection...");
}

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.println("❌ [WebSocket] Disconnected from Flutter app!");
      isConnected = false;
      break;
      
    case WStype_CONNECTED:
      Serial.println("✅ [WebSocket] Connected to Flutter app!");
      Serial.printf("🔗 Server URL: %s\n", payload);
      isConnected = true;
      connectionAttempts = 0;
      sendConnectionMessage();
      break;
      
    case WStype_TEXT:
      Serial.printf("📨 [WebSocket] Command received: %s\n", payload);
      handleReceivedMessage((char*)payload);
      break;
      
    case WStype_ERROR:
      Serial.printf("⚠️ [WebSocket] Error: %s\n", payload);
      isConnected = false;
      break;
      
    default:
      break;
  }
}

void sendConnectionMessage() {
  if (!isConnected) return;
  
  DynamicJsonDocument doc(1024);
  doc["type"] = "ESP32_CONNECTED";
  doc["message"] = "🤖 ESP32 WebSocket Client Ready!";
  doc["ip"] = WiFi.localIP().toString();
  doc["rssi"] = WiFi.RSSI();
  doc["timestamp"] = millis();
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  webSocket.sendTXT(jsonString);
  webSocket.sendTXT("🚀 ESP32 connected and ready for commands!");
  
  Serial.println("📤 Connection message sent to Flutter app");
}

void handleReceivedMessage(String message) {
  Serial.println("Processing command: " + message);
  
  String response = "";
  
  if (message == "W") {
    response = "✅ Moving forward...";
    Serial.println("Command: Move Forward");
  }
  else if (message == "S") {
    response = "⏹️ Stopping/Moving backward...";
    Serial.println("Command: Move Backward / Stop");
  }
  else if (message == "A") {
    response = "⬅️ Turning left...";
    Serial.println("Command: Turn Left");
  }
  else if (message == "D") {
    response = "➡️ Turning right...";
    Serial.println("Command: Turn Right");
  }
  else if (message == "X") {
    response = "🔴 Executing action X...";
    Serial.println("Command: Action X");
    ledState = !ledState;
    digitalWrite(LED_PIN, ledState ? HIGH : LOW);
  }
  else if (message == "Y") {
    response = "🟡 Executing action Y...";
    Serial.println("Command: Action Y");
  }
  else {
    response = "📝 Custom command: " + message;
    Serial.println("Command: Custom - " + message);
  }
  
  if (isConnected) {
    webSocket.sendTXT(response);
    Serial.println("Response sent: " + response);
  }
}

void sendRandomTestMessage() {
  if (!isConnected) return;
  
  String message;
  int messageType = random(0, 5);
  
  switch(messageType) {
    case 0:
      message = String(testMessages[random(0, numTestMessages)]) + " #" + String(messageCounter);
      break;
      
    case 1:
      message = "📊 Sensor data: " + String(random(10, 99)) + "°C, " + String(random(30, 80)) + "%";
      break;
      
    case 2:
      message = "⚡ System: " + String(millis()/1000) + "s uptime, " + String(ESP.getFreeHeap()) + " bytes free";
      break;
      
    case 3: {
      String status[] = {"🟢 All systems normal", "🔵 Sensors active", "🟡 Standby mode", "🟠 Processing data"};
      message = status[random(0, 4)];
      break;
    }
    
    case 4:
      message = "🎯 Test message #" + String(messageCounter) + " - Connection stable";
      break;
  }
  
  webSocket.sendTXT(message);
  Serial.println("📤 Sent: " + message);
  messageCounter++;
}

void sendHeartbeat() {
  if (!isConnected) return;
  
  DynamicJsonDocument doc(512);
  doc["type"] = "HEARTBEAT";
  doc["uptime_ms"] = millis();
  doc["uptime_readable"] = String(millis()/1000) + "s";
  doc["free_heap"] = ESP.getFreeHeap();
  doc["wifi_rssi"] = WiFi.RSSI();
  doc["status"] = "alive";
  doc["message_count"] = messageCounter;
  doc["ip"] = WiFi.localIP().toString();
  doc["connection_quality"] = WiFi.RSSI() > -70 ? "excellent" : WiFi.RSSI() > -80 ? "good" : "fair";
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  webSocket.sendTXT(jsonString);
  Serial.println("💓 Heartbeat #" + String(messageCounter) + " | Signal: " + String(WiFi.RSSI()) + "dBm");
}