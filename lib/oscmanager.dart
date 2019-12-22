import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:osc/osc.dart';
import 'package:osc/src/convert.dart';
import 'package:osc/src/message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:validators/validators.dart';
import 'package:multicast_dns/multicast_dns.dart';

class OSCManager {
  InternetAddress remoteHost;
  int remotePort = 8888;

  String autoDetectedBridge;

  RawDatagramSocket socket;
  SharedPreferences prefs;

  StreamController<int> zeroconfStream ;

  OSCManager() {
    RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((_socket) {
      loadPreferences();
      socket = _socket;
    });

    autoDetectedBridge = "";
  }

  void discoverServices() async {
   
    zeroconfStream = new StreamController<int>();
   
    const String name = '_osc._udp.local';

    final MDnsClient client = MDnsClient();

    print("Starting discovery, looking for " + name + " ...");
    // Start the client with default options.
    await client.start();
    print("Discovery started");

    zeroconfStream.add(0);

    bool found = false;

    // Get the PTR recod for the service.
    await for (PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(name),
        timeout: const Duration(minutes: 1))) {
      // Use the domainName from the PTR record to get the SRV record,
      // which will have the port and local hostname.
      // Note that duplicate messages may come through, especially if any
      // other mDNS queries are running elsewhere on the machine.

      await for (SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName))) {
        // Domain name will be something like "io.flutter.example@some-iphone.local._dartobservatory._tcp.local"
        final String bundleId =
            ptr.domainName; //.substring(0, ptr.domainName.indexOf('@'));

        print('OSC instance found at ' + srv.toString());
        if(srv.name.contains("flowtoysconnect"))
        {
          await for (IPAddressResourceRecord ipr
            in client.lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target))) {
          // Domain name will be something like "io.flutter.example@some-iphone.local._dartobservatory._tcp.local"

          print("IPV4 Found : " + ipr.address.address);
          autoDetectedBridge = ipr.address.address;
          Fluttertoast.showToast(
              msg: "Bridge detected on " + autoDetectedBridge);
          found = true;
          if(!zeroconfStream.isClosed) zeroconfStream.add(1);
          client.stop();
        }
        }
       
      }
    }

    if (!found) {
      autoDetectedBridge = "";
      if(!zeroconfStream.isClosed) zeroconfStream.add(2);
    }

    client.stop();
    zeroconfStream.close();

    print('Discovery Done.');
  }

  void loadPreferences() async {
    if (prefs == null) prefs = await SharedPreferences.getInstance();
    try {
      remoteHost =
          InternetAddress(prefs.getString("oscRemoteHost") ?? "192.168.4.1");
    } on ArgumentError catch (error) {
      print("Error getting IP from preferences : " + error.message);
    }

    Fluttertoast.showToast(
        msg: "Now sending OSC to " +
            remoteHost?.address +
            ":" +
            remotePort.toString());
  }

  void setRemoteHost(String value) {
    prefs.setString("oscRemoteHost", value);
    try {
      remoteHost =
          InternetAddress(prefs.getString("oscRemoteHost") ?? "192.168.4.1");
    } on ArgumentError catch (error) {
      print("Error getting IP from preferences : " + error.message);
    }

    Fluttertoast.showToast(
        msg: "Now sending OSC to " +
            remoteHost?.address +
            ":" +
            remotePort.toString());
  }


  //OSC Messages

  void sendMessage(OSCMessage m) {
    print("Send message : " + m.address + " to "+remoteHost?.address);
    socket.send(m.toBytes(), remoteHost, remotePort);
  }

  void sendSimpleMessage(String message) {
    sendMessage(new OSCMessage(message, arguments:List<Object>()));
  }

  void sendGroupMessage(String message, int group) {
    List<Object> args = new List<Object>();
    args.add(group);
    args.add(0);//groupIsPublic = false, force private group
    OSCMessage m = new OSCMessage(message, arguments: args);
    sendMessage(m);
  }

  void sendPattern(int group, int page, int mode) {
    List<Object> args = new List<Object>();
    args.add(group);
    args.add(0);//groupIsPublic = false, force private group
    args.add(page);
    args.add(mode);
    OSCMessage m = new OSCMessage("/pattern", arguments: args);
    sendMessage(m);
  }

  void sendSync(double time)
  {
    List<Object> args = new List<Object>();
    args.add(time);
     OSCMessage m = new OSCMessage("/sync", arguments: args);
    sendMessage(m);
  }
}

class OSCSettingsDialog extends StatefulWidget {
  OSCSettingsDialog({Key key, this.manager}) : super(key: key) {}

  final OSCManager manager;

  @override
  OSCSettingsDialogState createState() => OSCSettingsDialogState(manager);
}

class OSCSettingsDialogState extends State<OSCSettingsDialog> {
  OSCSettingsDialogState(OSCManager _manager) : manager = _manager{

    ipController.text = manager.remoteHost?.address;

    manager.discoverServices();
    subscription = manager.zeroconfStream.stream.listen((data){
      setState(()
      {
        isSearchingZeroconf = data == 0;
        foundZeroconf = data == 1;
      });
    }); 
  }

  @override
  void dispose()
  {
    subscription.cancel();
    super.dispose();
  }

  StreamSubscription<int> subscription;
  bool isSearchingZeroconf = false;
  bool foundZeroconf = false;

  OSCManager manager;
  final TextEditingController ipController = new TextEditingController();

  final formKey = GlobalKey<FormState>();

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
                      "OSC Settings",
                      style: TextStyle(color: Color(0xffcccccc)),
                    )),
                Form(
                  key: formKey,
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: TextFormField(
                          controller: ipController,
                          style: TextStyle(color: Colors.white),
                          validator: (value) {
                            return isIP(value, "4")
                                ? null
                                : "IP format is invalid (must be x.x.x.x)";
                          },
                          decoration: InputDecoration(
                              labelText: "Remote Host",
                              labelStyle: TextStyle(color: Colors.white54),
                              fillColor: Colors.white,
                              border: new OutlineInputBorder(
                                  borderRadius: new BorderRadius.circular(2.0),
                                  borderSide:
                                      new BorderSide(color: Colors.red))),
                        ),
                      ),
                      Padding(
                          padding: EdgeInsets.only(left: 15),
                          child: RaisedButton(
                              child: Text(isSearchingZeroconf?"Searching...":(foundZeroconf?"Auto-set":"Not found"),
                                  style: TextStyle(color: Color(0xffcccccc))),
                              color: Colors.green,
                              disabledColor: isSearchingZeroconf?Colors.blue:Colors.red,
                              onPressed: foundZeroconf
                                  ? () {
                                      ipController.text = manager.autoDetectedBridge;
                                    }
                                  : null)),
                    ],
                  ),
                ),
                Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: RaisedButton(
                      child: Text("Save"),
                      onPressed: () {
                        if (formKey.currentState.validate()) {
                          manager.setRemoteHost(ipController.text);
                          Navigator.of(context).pop();
                        }
                      },
                    ))
              ],
            )));
  }
}

class OSCSettingsIcon extends StatelessWidget {
  OSCSettingsIcon({Key key, this.manager}) : super(key: key) {}

  final OSCManager manager;

  Widget build(BuildContext context) {
    return FloatingActionButton(
        child: Icon(Icons.settings),
        onPressed: () => showDialog(
            context: context,
            builder: (BuildContext context) =>
                OSCSettingsDialog(manager: manager)));
  }
}
