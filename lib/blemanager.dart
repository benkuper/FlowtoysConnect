import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum BridgeMode { WiFi, BLE, Both }

class BLEManager {
  FlutterBlue flutterBlue;
  BluetoothDevice bridge;

  bool isConnected = false;
  bool isConnecting = false;
  bool isScanning = false;
  bool isReadyToSend = false;
  bool isSending = false;

  StreamController<void> changeStream;

  BridgeMode bridgeMode;
  String deviceName = "";
  String ssid = "";
  String pass = "";

  final uartUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  final txUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  final rxUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  BluetoothService uartService;
  BluetoothCharacteristic txChar;
  BluetoothCharacteristic rxChar;

  BLEManager() {
    changeStream = StreamController<void>.broadcast();
    bridgeMode = BridgeMode.Both;
    initBLE();
  }


  void initBLE() async {
    FlutterBlue.isAvailable.then((value) {
      if (!value) {
        print("Bluetooth device not available on this device");
        return;
      }

      flutterBlue = FlutterBlue.instance;

      flutterBlue.isScanning.listen((result) {
        isScanning = result;
        changeStream?.add(null);
      });
    });
  }

  void scanAndConnect() async {
    if (flutterBlue == null) return;


    sleep(Duration(milliseconds: 100));

    print("Start check here");
    bridge = null;

    isConnecting = true;
    isConnected = false;
    changeStream.add(null);

    await flutterBlue.connectedDevices.then((devices) {
      for (BluetoothDevice d in devices) {
        if (d.name.contains("FlowConnect")) {
          //print("Found");
          bridge = d;
          break;
        }
      }
    });

    if (bridge != null) {
      print("Already connected but not assigned");
      isConnected = false;
      isReadyToSend = txChar != null;
       connectToBridge();
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
          //print('${result.device.name} found! rssi: ${result.rssi}');
          if (result.device.name.contains("FlowConnect")) {
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
      //print("Bridge not found");
      Fluttertoast.showToast(msg: "No FlowConnect bridge found.");
      isConnecting = false;
      isConnected = false;
      changeStream.add(null);
      return;
    }

    print("Connect to bridge : " + bridge?.name);

    var stateSubscription = bridge.state.listen((state) {
      // do something with scan result
      //print("State changed : " + state.toString());
      
      bool newConnected = state == BluetoothDeviceState.connected;
      isConnected = newConnected;
      isConnecting = false;
      changeStream.add(null);

      if(isConnected || newConnected)
      {
        Fluttertoast.showToast(
          msg: 
              (isConnected ? "Connected to " : "Disconnected from ") +
              bridge.name+".");
      }

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
    //print("Discover services");
    List<BluetoothService> services = await bridge.discoverServices();
    for (BluetoothService service in services) {
      //print("Service : "+service.uuid.toString()+" <> "+uartUUID);
      if (service.uuid.toString() == uartUUID) {
        //print("Service found");
        uartService = service;

        for (BluetoothCharacteristic c in service.characteristics) {
          //print("Characteristic : "+c.uuid.toString());
          if (c.uuid.toString() == txUUID) {
            //print("Characteristic found");
            txChar = c;

            isReadyToSend = true;
            deviceName = bridge.name.substring(12);
            
            changeStream.add(null);
            return;
          }
        }
        //print("Characteristic not found");
        changeStream.add(null);
        return;
      }
    }

    //print("Service not found");
    changeStream.add(null);
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
   
    //for(int i=0;i<10 && isSending;i++) sleep(Duration(milliseconds: 100));

    try {
      isSending = true;
       await txChar.write(
          utf8.encode(
            message,
          ),
          withoutResponse: true);
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

    isSending = false;
  }


   void sendConfig(String _deviceName, BridgeMode mode,String _ssid, String _pass) async 
   {
      sendString("n" + ssid + "," + pass);
      ssid = _ssid;
      pass = _pass;
      
      sleep(Duration(milliseconds: 40)); //safe between 2 calls
      if(_deviceName.isEmpty) deviceName = "*";
      sendString("g" + _deviceName + "," + BridgeMode.values.indexOf(mode).toString());
      
      if(deviceName != _deviceName)
      {
        deviceName = _deviceName;
        if(bridge != null) bridge.disconnect();
        Future.delayed(Duration(seconds:6),scanAndConnect);
      }
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
    subscription = manager.changeStream.stream.listen((data) {
      print("connection changed here");
      setState(() {});
    });
  }

  @override
  void dispose() {
    print("DISPOSE");
    subscription.cancel();
    super.dispose();
  }

  StreamSubscription<void> subscription;
  BLEManager manager;

  void connect() {
    if (manager.flutterBlue == null) return;
    manager.scanAndConnect();
    
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
        ));
  }
}

class BLEWifiSettingsDialog extends StatefulWidget {
  BLEWifiSettingsDialog({Key key, this.manager}) : super(key: key) {}

  final BLEManager manager;

  @override
  BLEWifiSettingsDialogState createState() => BLEWifiSettingsDialogState();
}

class BLEWifiSettingsDialogState extends State<BLEWifiSettingsDialog> {
  BLEWifiSettingsDialogState({Key key});

  final TextEditingController ssidController = new TextEditingController();
  final TextEditingController passController = new TextEditingController();
  final TextEditingController nameController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
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
                        "Setup Device",
                        style: TextStyle(color: Color(0xffcccccc)),
                      )),
                  InputTF(controller: nameController, labelText: "Name",initialValue:widget.manager.deviceName),
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                       children: <Widget>[
                      for (BridgeMode m in BridgeMode.values)
                          Row(
                          children:<Widget>[
                            Radio<BridgeMode>(
                          value: m,
                          groupValue: widget.manager.bridgeMode,
                          activeColor: Colors.white,
                          onChanged: (BridgeMode value) {
                            setState(() {
                              widget.manager.bridgeMode = value;
                            });
                          },
                        ),
                        Text(
                           m.toString().split(".").last,
                              style: TextStyle(
                                color: Colors.white, fontSize: 12
                                )),
                          ])
                      
                    ]),
                  ),
                 
                 if (widget.manager.bridgeMode == BridgeMode.WiFi ||
                    widget.manager.bridgeMode == BridgeMode.Both)
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: InputTF(
                          controller: ssidController, labelText: "SSID", initialValue: widget.manager.ssid,),
                    ),
                if (widget.manager.bridgeMode == BridgeMode.WiFi ||
                    widget.manager.bridgeMode == BridgeMode.Both)
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: InputTF(
                          controller: passController, labelText: "Password", initialValue: widget.manager.pass),
                    ),
                    Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: RaisedButton(
                          child: Text("Save"),
                          onPressed: () {
                            widget.manager.sendConfig(nameController.text, widget.manager.bridgeMode,
                                ssidController.text, passController.text);
                            Navigator.of(context).pop();
                          },
                        ))
              ],
            ),
        )
    );
  }
}

class InputTF extends StatelessWidget {
  InputTF({this.labelText, this.controller, this.initialValue})
  {
    controller.text = initialValue;
  }

  final labelText;
  final TextEditingController controller;
  final initialValue;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
            contentPadding:EdgeInsets.fromLTRB(8, 0, 8, 0),
            labelText: labelText,
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: new OutlineInputBorder(
                borderRadius: new BorderRadius.circular(2.0),
                borderSide: new BorderSide(color: Colors.grey))));
  }
}
