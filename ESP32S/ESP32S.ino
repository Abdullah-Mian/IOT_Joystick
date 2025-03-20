#include <WiFi.h>
#include <WebSocketsClient.h>

// Wi-Fi credentials
const char *ssid = "Redmi 9T";     // Replace with your hotspot SSID
const char *password = "68986898"; // Replace with your hotspot password

// Server details
const char *host = "192.168.18.39"; // Replace with the IP shown in the app
const int port = 5000;

// Motor control pins for L298N
const int IN1 = 26; // Motor 1 forward
const int IN2 = 25; // Motor 1 backward
const int IN3 = 33; // Motor 2 forward
const int IN4 = 32; // Motor 2 backward

WiFiClient client;
WebSocketsClient webSocket;

void setup()
{
  Serial.begin(115200);

  // Initialize motor pins as outputs
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);

  // Set all motor pins to LOW by default
  stopMotors();
  Serial.println("Motors initialized. All pins set to LOW.");

  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // Connect as a WebSocket client to the phone's IP and port
  webSocket.begin(host, port, "/");
  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(1000);      // Attempt reconnection every second
  webSocket.enableHeartbeat(15000, 3000, 2); // Enable heartbeat to maintain connection
  Serial.println("WebSocket client mode started.");
}

void webSocketEvent(WStype_t type, uint8_t *payload, size_t length)
{
  switch (type)
  {
  case WStype_DISCONNECTED:
    Serial.println("WebSocket disconnected!");
    stopMotors(); // Safety measure
    break;
  case WStype_CONNECTED:
    Serial.println("WebSocket connected!");
    break;
  case WStype_TEXT:
    if (length == 1)
    { // We expect single character commands
      char command = payload[0];
      switch (command)
      {
      case 'W':
        forward();
        break;
      case 'B':
        backward();
        break;
      case 'S':
        stopMotors();
        break;
      case 'A':
        left();
        break;
      case 'D':
        right();
        break;
      case 'X':
        forward();
        break;
      case 'Y':
        backward();
        break;
      default:
        stopMotors();
      }
    }
    break;
  default:
    break;
  }
}

// Motor control functions
void forward()
{
  digitalWrite(IN1, LOW);  // Motor 1 forward
  digitalWrite(IN2, HIGH); // Motor 1 backward
  digitalWrite(IN3, HIGH); // Motor 2 forward
  digitalWrite(IN4, LOW);  // Motor 2 backward
  Serial.println("Moving Forward");
}

void backward()
{
  digitalWrite(IN1, HIGH); // Motor 1 forward
  digitalWrite(IN2, LOW);  // Motor 1 backward
  digitalWrite(IN3, LOW);  // Motor 2 forward
  digitalWrite(IN4, HIGH); // Motor 2 backward

  Serial.println("Moving Backward");
}

void left()
{

  digitalWrite(IN1, LOW);  // Motor 1 forward
  digitalWrite(IN2, HIGH); // Motor 1 backward
  digitalWrite(IN3, LOW);  // Motor 2 forward
  digitalWrite(IN4, HIGH); // Motor 2 backward
  Serial.println("Turning Left");
}

void right()
{
  digitalWrite(IN1, HIGH); // Motor 1 forward
  digitalWrite(IN2, LOW);  // Motor 1 backward
  digitalWrite(IN3, HIGH); // Motor 2 forward
  digitalWrite(IN4, LOW);  // Motor 2 backward

  Serial.println("Turning Right");
}

void stopMotors()
{
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
  Serial.println("Motors Stopped");
}

void loop()
{
  webSocket.loop();

  // Add reconnection logic
  if (WiFi.status() != WL_CONNECTED)
  {
    stopMotors();
    Serial.println("WiFi disconnected. Reconnecting...");
    WiFi.reconnect();
    delay(100);
  }
}
