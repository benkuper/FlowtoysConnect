import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';


class GroupSelection  extends StatefulWidget {
  const GroupSelection({
    Key key,
    this.onGroupChanged
  }) : super(key: key);

  final Function(int group) onGroupChanged;

  @override
  _GroupSelectionState createState() => _GroupSelectionState();
}

class _GroupSelectionState extends State<GroupSelection> {

  int selectedGroup = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (int i = 0; i < 6; i++)
            ButtonTheme(
              minWidth: 50.0,
              height: 40.0,
              child: RaisedButton(
                  child: Text(i == 0 ? "All" : "$i"),
                  color: Color(
                      selectedGroup == i ? 0xffeeaa00 : 0x555555),
                  textColor: Color(selectedGroup == i?0xff553300:0x88ffffff),
                  shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(8.0), side: BorderSide(color:Color(0x33ffffff),width:1)),

                  onPressed: () {
                    setState(() {
                      selectedGroup = i;
                    });
                    widget.onGroupChanged(selectedGroup);
                  }),
            ),
        ]);
  }
}
