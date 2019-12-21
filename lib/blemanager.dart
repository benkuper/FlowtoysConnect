import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

class BLEManager {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice bridge;

  bool isConnected = false;
  bool isConnecting = false;
  bool isScanning = false;
  bool isReadyToSend = false;

  StreamController<void> changeStream;

  final uartUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  final txUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  final rxUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  BluetoothService uartService;
  BluetoothCharacteristic txChar;
  BluetoothCharacteristic rxChar;

  BLEManager() {
    flutterBlue.isScanning.listen((result) {
      isScanning = result;
      changeStream?.add(null);
    });
  }

  void scanAndConnect() async {
    changeStream = StreamController<void>();

    sleep(Duration(milliseconds: 100));

    print("Start check here");
    bridge = null;

    isConnecting = true;
    isConnected = false;
    changeStream.add(null);

    await flutterBlue.connectedDevices.then((devices) {
      for (BluetoothDevice d in devices) {
        if (d.name == "Flowtoys Bridge") {
          print("Found");
          bridge = d;
          break;
        }
      }
    });

    if (bridge != null) {
      print("Already connected but not assigned");
      isConnected = true;
      isReadyToSend = true;
      if (!changeStream.isClosed) changeStream.add(null);
      return;
    }

    //Not already there, start scanning

    if (isScanning) {
      print("Already scanning");
      return;
    }

    flutterBlue.isOn.then((isOn) {
      if (!isOn) {
        Fluttertoast.showToast(msg: "Bluetooth is not activated.");
        return;
      }
      print("Scanning BLE devices...");

      bridge = null;
      isConnected = false;
      isReadyToSend = false;
      isConnecting = true;
      changeStream.add(null);

      flutterBlue
          .startScan(timeout: Duration(seconds: 5))
          .whenComplete(connectToBridge);

      StreamSubscription<List<ScanResult>> subscription;
      subscription = flutterBlue.scanResults.listen((scanResult) {
        // do something with scan result

        for (var result in scanResult) {
          print('${result.device.name} found! rssi: ${result.rssi}');
          if (result.device.name == "Flowtoys Bridge") {
            bridge = result.device;
            flutterBlue.stopScan();
            return;
          }
        }
      });
    });
  }

  void connectToBridge() async {
    if (bridge == null) {
      print("Bridge not found");
      Fluttertoast.showToast(msg: "No bridge found.");
      isConnecting = false;
      isConnected = false;
      changeStream.add(null);
      return;
    }

    if (isConnected) {
      print("Already connected");
      Fluttertoast.showToast(msg: "Bridge is already connected.");
      isConnecting = false;
      isConnected = false;
      changeStream.add(null);
      return;
    }

    print("Connect to bridge : " + bridge?.name);
    var stateSubscription = bridge.state.listen((state) {
      // do something with scan result
      print("State changed : " + state.toString());

      isConnected = state == BluetoothDeviceState.connected;
      isConnecting = false;
      if (!changeStream.isClosed) changeStream.add(null);

      Fluttertoast.showToast(
          msg: "Bridge is " +
              (isConnected ? "connected" : "disconnected") +
              ".");

      if (isConnected) {
        getRXTXCharacteristics();
      }
    });

    print("Connecting to bridge...");
    try {
      await bridge.connect();
    } on PlatformException catch (error) {
      print("Error connecting : " + error.toString());
    }
  }

  void getRXTXCharacteristics() async {
    print("Discover services");
    List<BluetoothService> services = await bridge.discoverServices();
    for (BluetoothService service in services) {
      //print("Service : "+service.uuid.toString()+" <> "+uartUUID);
      if (service.uuid.toString() == uartUUID) {
        print("Service found");
        uartService = service;

        for (BluetoothCharacteristic c in service.characteristics) {
          //print("Characteristic : "+c.uuid.toString());
          if (c.uuid.toString() == txUUID) {
            print("Characteristic found");
            txChar = c;

            isReadyToSend = true;
            if (!changeStream.isClosed) changeStream.add(null);
            if (!changeStream.isClosed) changeStream.close();
            return;
          }
        }
        print("Characteristic not found");
        if (!changeStream.isClosed) changeStream.add(null);
        if (!changeStream.isClosed) changeStream.close();
        return;
      }
    }

    print("Service not found");
    if (!changeStream.isClosed) changeStream.add(null);
    changeStream.close();
  }

  void sendString(String message) async {
    if (bridge == null) {
      Fluttertoast.showToast(msg: "Bridge is disconnected, not sending");
      return;
    }

    if (txChar == null) {
      Fluttertoast.showToast(
          msg: "Bridge is broken (tx characteristic not found), not sending");
      return;
    }

    print("Sending : " + message);
    List<int> values = utf8.encode(message);
    for (int v in values) {
      print(" > " + v.toString());
    }

    try {
      await txChar.write(utf8.encode(message));
    } on PlatformException catch (error) {
      print("Error writing : " + error.toString());
      Fluttertoast.showToast(
          msg: "Error sending Bluetooth command :\n${error.toString()}",
          textColor: Colors.deepOrange);
    } on Exception catch (error) {
      print("Error writing (exception) : " + error.toString());
      Fluttertoast.showToast(
          msg: "Error sending Bluetooth command :\n${error.toString()}",
          textColor: Colors.deepOrange);
    }
  }

  void sendCredentials(String ssid, String pass) {
    sendString("n"+ssid+","+pass);
    Fluttertoast.showToast(
          msg: "Wifi credentials set : "+ssid+" : "+pass);
  }
}

class BLEConnectIcon extends StatefulWidget {
  BLEConnectIcon({Key key, this.manager}) : super(key: key) {}

  final BLEManager manager;

  @override
  _BLEConnectIconState createState() => _BLEConnectIconState(manager);
}

class _BLEConnectIconState extends State<BLEConnectIcon> {
  _BLEConnectIconState(BLEManager _manager) : manager = _manager {
    connect();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  StreamSubscription<void> subscription;
  BLEManager manager;

  void connect() {
    manager.scanAndConnect();
    subscription = manager.changeStream.stream.listen((data) {
      setState(() {
        print("GOT INFO HERE ! " + manager.isReadyToSend.toString());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onLongPress: () => showDialog(
            context: context,
            builder: (BuildContext context) =>
                BLEWifiSettingsDialog(manager: manager)),

        child: FloatingActionButton(
          onPressed: connect,
          child: Icon(Icons.link),
          backgroundColor: Color(widget.manager.isConnected
              ? (widget.manager.isReadyToSend ? 0xff11aa33 : 0xffeeaa22)
              : (widget.manager.isConnecting ? 0xff2288ff : 0xffff5500)),
        )
    );
  }
  
}

class BLEWifiSettingsDialog extends StatelessWidget {
  BLEWifiSettingsDialog({Key key, this.manager});

  final BLEManager manager;

  final TextEditingController ssidController = new TextEditingController();
  final TextEditingController passController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    print("rebuild dialog");
    return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0.0,
        backgroundColor: Color(0xff333333),
        child: Padding(
            padding: EdgeInsets.all(8),
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                Container(
                    margin: EdgeInsets.only(bottom: 20),
                    alignment: Alignment.center,
                    child: Text(
                      "Setup WiFi credentials via BLE",
                      style: TextStyle(color: Color(0xffcccccc)),
                    )),
                TextFormField(
                  controller: ssidController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      labelText: "Remote Host",
                      labelStyle: TextStyle(color: Colors.white54),
                      fillColor: Colors.white,
                      border: new OutlineInputBorder(
                          borderRadius: new BorderRadius.circular(2.0),
                          borderSide: new BorderSide(color: Colors.red))),
                ),
                TextFormField(
                  controller: passController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      labelText: "Remote Host",
                      labelStyle: TextStyle(color: Colors.white54),
                      fillColor: Colors.white,
                      border: new OutlineInputBorder(
                          borderRadius: new BorderRadius.circular(2.0),
                          borderSide: new BorderSide(color: Colors.red))),
                ),
                Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: RaisedButton(
                      child: Text("Save"),
                      onPressed: () {
                        manager.sendCredentials(
                            ssidController.text, passController.text);
                        Navigator.of(context).pop();
                      },
                    ))
              ],
            )));
  }
}
