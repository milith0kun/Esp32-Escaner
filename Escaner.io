#include <WiFi.h>
#include <WebServer.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>

// Configuración WiFi
const char* ssid = "jrdev";
const char* password = "123456ed";

WebServer server(80);

// Variables
int numRedesWiFi = 0;
int numDispositivosBLE = 0;
String resultadoWiFi = "";
String resultadoBLE = "";
BLEScan* pBLEScan;

class MyAdvertisedDeviceCallbacks: public BLEAdvertisedDeviceCallbacks {
  void onResult(BLEAdvertisedDevice advertisedDevice) {}
};

void escanearWiFi() {
  numRedesWiFi = WiFi.scanNetworks();
  resultadoWiFi = "";
  
  for (int i = 0; i < numRedesWiFi && i < 15; i++) {
    String nombre = WiFi.SSID(i);
    if (nombre.length() == 0) nombre = "(Oculta)";
    
    resultadoWiFi += "<tr><td>" + String(i+1) + "</td><td>" + nombre + "</td>";
    resultadoWiFi += "<td>" + WiFi.BSSIDstr(i) + "</td>";
    resultadoWiFi += "<td>" + String(WiFi.RSSI(i)) + "</td>";
    resultadoWiFi += "<td>" + String(WiFi.channel(i)) + "</td></tr>";
  }
  WiFi.scanDelete();
}

void escanearBluetooth() {
  resultadoBLE = "";
  BLEScanResults* foundDevices = pBLEScan->start(5, false);
  numDispositivosBLE = foundDevices->getCount();
  
  for (int i = 0; i < numDispositivosBLE && i < 15; i++) {
    BLEAdvertisedDevice device = foundDevices->getDevice(i);
    
    String nombre = device.getName().c_str();
    if (nombre.length() == 0) nombre = "(Desconocido)";
    
    String tipo = "Generico";
    if (nombre.indexOf("Phone") >= 0 || nombre.indexOf("Galaxy") >= 0 || 
        nombre.indexOf("Xiaomi") >= 0 || nombre.indexOf("Redmi") >= 0) {
      tipo = "Celular";
    } else if (nombre.indexOf("Watch") >= 0 || nombre.indexOf("Band") >= 0) {
      tipo = "Reloj";
    } else if (nombre.indexOf("Buds") >= 0 || nombre.indexOf("AirPods") >= 0) {
      tipo = "Audio";
    }
    
    resultadoBLE += "<tr><td>" + String(i+1) + "</td><td>" + nombre + "<br><small>" + tipo + "</small></td>";
    resultadoBLE += "<td>" + String(device.getAddress().toString().c_str()) + "</td>";
    resultadoBLE += "<td>" + String(device.getRSSI()) + "</td></tr>";
  }
  pBLEScan->clearResults();
}

void handleRoot() {
  String html = "<!DOCTYPE html><html><head><meta charset='UTF-8'>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<title>ESP32 Scanner</title>";
  html += "<style>body{font-family:Arial;margin:20px;background:#667eea}";
  html += ".c{background:#fff;padding:20px;border-radius:10px;margin:10px 0}";
  html += "h1{color:#fff;text-align:center}h2{color:#333}";
  html += "table{width:100%;border-collapse:collapse}";
  html += "th{background:#667eea;color:#fff;padding:10px}";
  html += "td{padding:8px;border-bottom:1px solid #ddd}";
  html += ".b{background:#667eea;color:#fff;padding:12px 30px;border:none;border-radius:25px;cursor:pointer;text-decoration:none;display:inline-block;margin:10px}";
  html += "</style><meta http-equiv='refresh' content='25'></head><body>";
  html += "<h1>Detector ESP32</h1>";
  html += "<div class='c'><p><b>Total:</b> " + String(numRedesWiFi + numDispositivosBLE);
  html += " | WiFi: " + String(numRedesWiFi) + " | BLE: " + String(numDispositivosBLE) + "</p>";
  html += "<p><b>IP:</b> " + WiFi.localIP().toString() + "</p>";
  html += "<center><a href='/scan' class='b'>Escanear</a></center></div>";
  
  html += "<div class='c'><h2>Redes WiFi (" + String(numRedesWiFi) + ")</h2>";
  if (numRedesWiFi > 0) {
    html += "<table><tr><th>#</th><th>Nombre</th><th>MAC</th><th>RSSI</th><th>Canal</th></tr>";
    html += resultadoWiFi + "</table>";
  } else {
    html += "<p>Sin redes</p>";
  }
  html += "</div>";
  
  html += "<div class='c'><h2>Dispositivos BLE (" + String(numDispositivosBLE) + ")</h2>";
  if (numDispositivosBLE > 0) {
    html += "<table><tr><th>#</th><th>Nombre/Tipo</th><th>MAC</th><th>RSSI</th></tr>";
    html += resultadoBLE + "</table>";
  } else {
    html += "<p>Sin dispositivos</p>";
  }
  html += "</div></body></html>";
  
  server.send(200, "text/html", html);
}

void handleScan() {
  escanearWiFi();
  escanearBluetooth();
  server.sendHeader("Location", "/");
  server.send(303);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\nESP32 Scanner iniciando...");
  
  BLEDevice::init("");
  pBLEScan = BLEDevice::getScan();
  pBLEScan->setAdvertisedDeviceCallbacks(new MyAdvertisedDeviceCallbacks());
  pBLEScan->setActiveScan(true);
  pBLEScan->setInterval(100);
  pBLEScan->setWindow(99);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  int i = 0;
  while (WiFi.status() != WL_CONNECTED && i < 20) {
    delay(500);
    Serial.print(".");
    i++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConectado!");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
  }
  
  server.on("/", handleRoot);
  server.on("/scan", handleScan);
  server.begin();
  
  Serial.println("Servidor iniciado");
  escanearWiFi();
  escanearBluetooth();
}

void loop() {
  server.handleClient();
  
  static unsigned long ultimo = 0;
  if (millis() - ultimo > 25000) {
    escanearWiFi();
    escanearBluetooth();
    ultimo = millis();
  }
}
