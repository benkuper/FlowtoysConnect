import 'dart:async';

import 'package:flowtoysconnect/groupselection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pagemodegrid.dart';
import 'blemanager.dart';
import 'oscmanager.dart';

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
        unselectedWidgetColor:Colors.grey
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

enum ConnectionMode { BLE, OSC }

class _MyHomePageState extends State<MyHomePage> {
  int selectedGroup = 0;
  ConnectionMode mode;
  BLEManager bleManager;
  OSCManager oscManager;

  //ui
  ScrollController scrollController;
  bool dialVisible = true;

  SharedPreferences prefs;

  _MyHomePageState() {
    bleManager = new BLEManager();
    oscManager = new OSCManager();

    /*scrollController = ScrollController()
      ..addListener(() {
        setDialVisible(scrollController.position.userScrollDirection ==
            ScrollDirection.forward);
      });*/

    loadPreferences();
  }

  void loadPreferences() async
  {
    if (prefs == null) prefs = await SharedPreferences.getInstance();
    int m = prefs.getInt("mode");
    print("mode loaded "+m.toString());
    setMode(m != null?ConnectionMode.values[m]:ConnectionMode.BLE);
  }

  void setMode(ConnectionMode _mode) {
    setState(() {
      if(mode == _mode) return;

      mode = _mode;
      if (mode == ConnectionMode.OSC) {
        bleManager.bridge?.disconnect();
      } else {
        //leManager.scanAndConnect();
      }
    });

    print("Mode is now " + mode.toString());
    prefs.setInt("mode", ConnectionMode.values.indexOf(mode));
  }

  /* helper */

  /* BRIDGE API FUNCTIONS */

  void wakeUp() {
    if(mode == ConnectionMode.BLE)
    {
      bleManager.sendString("w" + selectedGroup.toString());
    }else{
      oscManager.sendGroupMessage("/wakeUp",selectedGroup);
    }
  }

  void powerOff() {
   
   if(mode == ConnectionMode.BLE)
    {
      bleManager.sendString("z" + selectedGroup.toString());
    }else{
      oscManager.sendGroupMessage("/powerOff",selectedGroup);
    }
  }


  void syncGroups()
  {
    if(mode == ConnectionMode.BLE)
    {
      bleManager.sendString("s0"); //infinite
    }else{
      oscManager.sendSync(0);
    }
  }

  void stopSync()
  {
    if(mode == ConnectionMode.BLE)
    {
      bleManager.sendString("S");
    }else{
      oscManager.sendSimpleMessage("/stopSync");
    }
  }

  void setPattern(int page, int _mode) {
    if(mode == ConnectionMode.BLE)
    {
      bleManager.sendString("p" +
        selectedGroup.toString() +
        "," +
        page.toString() +
        "," +
        _mode.toString());
    }else{
      oscManager.sendPattern(selectedGroup, page, _mode);
    }
  }

  //UI
  void setDialVisible(bool value) {
    if(dialVisible == value) return;
    setState(() {
      dialVisible = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xff333333),
        appBar: AppBar(
            title: Text(widget.title), backgroundColor: Color(0xff222222)),
        body: Center(
            child: Column(
              children: [
                GroupSelection(
                  onGroupChanged: (group) { selectedGroup=group; },
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                       CommandButton(text:"Wake Up",onPressed: wakeUp, color:Colors.green),
                       CommandButton(text:"Power off",onPressed: powerOff, color:Colors.red),
                       CommandButton(text:"Start sync",onPressed: syncGroups, color:Colors.blue),
                       CommandButton(text:"Stop sync",onPressed: stopSync, color:Colors.purple),
                    ]),
                Expanded(
                    child: PageModeSelection(
                  scrollController: scrollController,
                  onPageModeChanged: setPattern,
                )),
              ],
            ),
        ),
        floatingActionButton: Stack(
          children: <Widget>[
            if (dialVisible)
              Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                      padding: EdgeInsets.only(right: 70),
                      child: mode == ConnectionMode.BLE?BLEConnectIcon(manager:bleManager):OSCSettingsIcon(manager:oscManager),
                  )
              ),


            SpeedDial(
              child: Icon(
                  mode == ConnectionMode.BLE ? Icons.bluetooth : Icons.wifi),
              visible: dialVisible,
              closeManually: false,
              tooltip: 'Choose your connection',
              heroTag: 'speed-dial-hero-tag',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 32.0,
              curve: Curves.bounceInOut,
              overlayColor: Colors.black,
              overlayOpacity: 0.5,
              shape: CircleBorder(),
              children: [
                SpeedDialChild(
                    child: Icon(Icons.bluetooth),
                    label: 'Bluetooth',
                    labelStyle: TextStyle(fontSize: 18.0),
                    onTap: () {
                      setMode(ConnectionMode.BLE);
                    }),
                SpeedDialChild(
                  child: Icon(Icons.wifi),
                  label: 'OSC',
                  labelStyle: TextStyle(fontSize: 18.0),
                  onTap: () {
                    setMode(ConnectionMode.OSC);
                  },
                )
              ],
            )
          ],
        )
      ); 
  }
}

class CommandButton extends StatelessWidget 
{
  const CommandButton({this.text, this.onPressed, this.color });

  final String text;
  final Function onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ButtonTheme(
                        minWidth: 80.0,
                        child:RaisedButton(
                        onPressed: onPressed,
                        padding: const EdgeInsets.all(0),
                        child: Text(text,style:TextStyle(fontSize: 14),),
                        color:color,
                        textColor:Colors.white70,
                        splashColor: Colors.white70,
                       ),
                      );
  }

}