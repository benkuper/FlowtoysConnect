import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flowtoys Connect',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flowtoys Connect'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice bridge = null;

  bool isConnected = false;
  bool isConnecting = false;
  bool isScanning = false;
  bool isReadyToSend = false;

  final uartUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  final txUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  final rxUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  BluetoothService uartService = null;
  BluetoothCharacteristic txChar = null;
  BluetoothCharacteristic rxChar = null;

  int selectedGroup = 0;

  _MyHomePageState() {
    flutterBlue.isScanning.listen((result) {
      isScanning = result;
    });
  }

  void scanAndConnect() {
    if (isScanning) {
      print("Already scanning");
      return;
    }

    if (bridge != null && isConnected) {
      print("Already connected");
      bridge.disconnect();
    }

    print("Scanning BLE devices...");

    setState(() {
      bridge = null;
      isConnected = false;
      isReadyToSend = false;
      isConnecting = true;
    });

    flutterBlue
        .startScan(timeout: Duration(seconds: 1))
        .whenComplete(connectToBridge);

    StreamSubscription<List<ScanResult>> subscription;
    subscription = flutterBlue.scanResults.listen((scanResult) {
      // do something with scan result

      for (var result in scanResult) {
        //print('${result.device.name} found! rssi: ${result.rssi}');
        if (result.device.name == "Flowtoys Bridge") {
          bridge = result.device;
          flutterBlue.stopScan();
          return;
        }
      }
    });
  }

  void connectToBridge() async {
    if (bridge == null) {
      print("Bridge not found");
      Fluttertoast.showToast(msg: "No bridge found.");
      setState(() {
        isConnecting = false;
        isConnected = false;
      });
      return;
    }

    if (isConnected) {
      print("Already connected");
      Fluttertoast.showToast(msg: "Bridge is already connected.");
      setState(() {
        isConnecting = false;
        isConnected = false;
      });
      return;
    }

    print("Connect to bridge : " + bridge?.name);
    var stateSubscription = bridge.state.listen((state) {
      // do something with scan result
      print("State changed : " + state.toString());

      setState(() {
        isConnected = state == BluetoothDeviceState.connected;
        isConnecting = false;
      });

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
            setState(() {
              isReadyToSend = true;
            });

            return;
          }
        }
        print("Characteristic not found");
        return;
      }
    }
    ;

    print("Service not found");
  }

  void connectAndRefresh() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.

      scanAndConnect();
    });
  }

  /* helper */

  void sendString(String message) async {
    print("Sending : " + message);
    List<int> values = utf8.encode(message);
    for (int v in values) {
      print(" > " + v.toString());
    }

    try {
      await txChar.write(utf8.encode(message));
    } on PlatformException catch (error) {
      print("Error writing : " + error.toString());
    }
  }

  /* BRIDGE API FUNCTIONS */

  void wakeUp() {
    sendString("w"+selectedGroup.toString());
  }

  void powerOff() {
    sendString("z0"+selectedGroup.toString());
  }

  void syncGroups() {
    sendString("s");
  }

  void setPattern(int page, int mode) {
    sendString("p" +
        selectedGroup.toString() +
        "," +
        page.toString() +
        "," +
        mode.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff333333),
      appBar:
          AppBar(title: Text(widget.title), backgroundColor: Color(0xff222222)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (!isConnected || !isReadyToSend)
              Text(
                  isConnected
                      ? 'Getting some juce from the bridge...'
                      : (isConnecting
                          ? 'Connecting...'
                          : 'Turn on your bluetooth and hit connect'),
                  style: TextStyle(color: Color(0xffffffff))),
            if (isConnected && isReadyToSend)
              Expanded(
                child: Column(
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Text("Group : ",
                              style: (TextStyle(
                                  color: Color(0xffffffff), fontSize: 20))),
                          for (int i = 0; i < 6; i++)
                            ButtonTheme(
                              minWidth: 40.0,
                              height: 40.0,
                              child: RaisedButton(
                                  child: Text(i == 0 ? "All" : "$i"),
                                  color: Color(selectedGroup == i
                                      ? 0xff55cc00
                                      : 0x555555),
                                  textColor: Color(0xffffffff),
                                  onPressed: () {
                                       setState(() {
                                      selectedGroup = i;
                                    });
                                  }),
                            ),
                        ]),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          RaisedButton(
                            onPressed: wakeUp,
                            child: Text('Wake Up'),
                          ),
                          RaisedButton(
                            onPressed: powerOff,
                            child: Text('Power off'),
                          ),
                          RaisedButton(
                            onPressed: syncGroups,
                            child: Text('Sync groups'),
                          )
                        ]),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          for (int i in [1, 2, 3, 13])
                            Column(
                              children: [
                                Text(
                                  "Page $i",
                                  style: TextStyle(
                                      color: Color(0xffffffff), fontSize: 20),
                                ),
                                GridView.count(
                                    shrinkWrap: true,
                                    physics: new NeverScrollableScrollPhysics(),
                                    crossAxisCount: 5,
                                    childAspectRatio: 1.0,
                                    padding: const EdgeInsets.all(4.0),
                                    mainAxisSpacing: 4.0,
                                    crossAxisSpacing: 4.0,
                                    children: [
                                      for (int j = 0;
                                          j < (i == 13 ? 80 : 10);
                                          j++)
                                        RaisedButton(
                                          onPressed: () => setPattern(i, j),
                                          child: Text((j + 1).toString()),
                                        )
                                    ]),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: connectAndRefresh,
        tooltip: 'Connect Bluetooth',
        child: Icon(Icons.bluetooth),
        backgroundColor: Color(isConnected
            ? (isReadyToSend ? 0xff33ff55 : 0xffeeaa22)
            : (isConnecting ? 0xff2288ff : 0xffff5500)),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
