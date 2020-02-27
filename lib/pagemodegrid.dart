import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class PageModeSelection extends StatefulWidget {
  PageModeSelection({Key key, this.onPageModeChanged, this.scrollController})
      : super(key: key);

  final scrollController;
  final Function(
          int page, int mode, List<bool> paramEnables, List<double> paramValues)
      onPageModeChanged;

  @override
  _PageModeSelectionState createState() => _PageModeSelectionState();
}

class _PageModeSelectionState extends State<PageModeSelection> {
  _PageModeButtonState selectedButton;
  final paramManager = GlobalKey<ModeParamManagerState>();

  void buttonSelected(_PageModeButtonState b) {
    if (b == selectedButton) return;
    if (selectedButton != null) selectedButton.setSelected(false);

    selectedButton = b;
    paramManager.currentState.setLinkedMode(selectedButton.widget);

    if (selectedButton != null) {
      selectedButton.setSelected(true);
      widget.onPageModeChanged(
          selectedButton.widget.page,
          selectedButton.widget.mode,
          selectedButton.widget.paramsEnabled,
          selectedButton.widget.paramValues);
    }
  }

  void modeParamChanged(ModeParamManagerState pm) {
    if (selectedButton == null) return;
    widget.onPageModeChanged(
        selectedButton.widget.page,
        selectedButton.widget.mode,
        selectedButton.widget.paramsEnabled,
        selectedButton.widget.paramValues);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
          Flexible(
              fit: FlexFit.loose,
              child: ListView(
                controller: widget.scrollController,
                children: [
                  for (int i in [1, 2, 3, 13])
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.all(8),
                          //decoration: deco ,
                          child: GridView.count(
                              padding: EdgeInsets.only(top: 16),
                              shrinkWrap: true,
                              physics: new NeverScrollableScrollPhysics(),
                              crossAxisCount: 10,
                              childAspectRatio: 1.0,
                              mainAxisSpacing: 2.0,
                              crossAxisSpacing: 2.0,
                              children: [
                                for (int j = 0; j < (i == 13 ? 50 : 10); j++)
                                  PageModeButton(
                                      onSelect: buttonSelected,
                                      page: (i - 1),
                                      mode: j)
                              ]),
                        ),
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(0xff444444),
                              boxShadow: [
                                BoxShadow(
                                    color: Color(0x55000000), blurRadius: 5)
                              ],
                              border: Border.all(
                                  color: Color(0x22ffffff), width: 1),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(5)),
                            ),
                            padding: EdgeInsets.fromLTRB(8, 2, 8, 2),
                            child: Text(
                              "Page $i",
                              style: TextStyle(
                                  color: Color(0xffffffff), fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              )),
          SizedBox(
              height: 200,
              child: ModeParamManager(
                  key: paramManager, onParamChanged: modeParamChanged)),
        ]);
  }
}

class PageModeButton extends StatefulWidget {
  PageModeButton({Key key, this.onSelect, this.page, this.mode})
      : super(key: key);

  final int page;
  final int mode;

  List<bool> paramsEnabled = [false, false, false, false, false];
  List<double> paramValues = [.5, 1, 1, .5, .5];

  final Function(_PageModeButtonState bt) onSelect;

  @override
  _PageModeButtonState createState() => _PageModeButtonState();
}

class _PageModeButtonState extends State<PageModeButton> {
  @override
  _PageModeButtonState() {}

  bool isSelected = false;

  void setSelected(bool value) {
    if (isSelected == value) return;

    setState(() {
      isSelected = value;
    });
  }

  Widget build(BuildContext context) {
    return RaisedButton(
        child:
            Text((widget.mode + 1).toString(), style: TextStyle(fontSize: 12)),
        padding: const EdgeInsets.all(0.0),
        color: Color(isSelected ? 0xffee8833 : 0xff555555),
        splashColor: Color(0xaaffffff),
        textColor: Color(0xffcccccc),
        onPressed: () {
          widget.onSelect(this);
        },
        shape: new RoundedRectangleBorder(
            borderRadius: new BorderRadius.circular(8.0),
            side: BorderSide(color: Color(0x33ffffff), width: 1)));
  }
}

class ModeParamManager extends StatefulWidget {
  ModeParamManager({Key key, this.onParamChanged}) : super(key: key);

  List<bool> paramsEnabled = [false, false, false, false, false];
  List<double> paramValues = [.5, 1, 1, .5, .5];

  var paramNames = ["Hue", "Saturation", "Brigthness", "Speed", "Density"];

  final Function(ModeParamManagerState manager) onParamChanged;

  @override
  ModeParamManagerState createState() => ModeParamManagerState();
}

class ModeParamManagerState extends State<ModeParamManager> {
  ModeParamManagerState() {}

  PageModeButton mode;
  void setLinkedMode(PageModeButton _mode) {
    setState(() {
      this.mode = _mode;
    });
  }

  void sliderChanged(int index, double val) {
    setState(() {
      mode.paramValues[index] = val;
      widget.onParamChanged(this);
    });
  }

  void toggleEnable(int index) {
    setState(() {
      mode.paramsEnabled[index] = !mode.paramsEnabled[index];
      widget.onParamChanged(this);
    });
  }

  Widget build(BuildContext) {
    return Column(children: [
      if(mode == null)
      Expanded(
        child:Align(
        alignment: Alignment.center,
        child:Text("Select a mode to change its parameters", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Color(0xffaaaaaa)))
      )),
      if (mode != null)
        for (int i = 0; i < widget.paramNames.length; i++)
          SizedBox(
              height: 40,
              child: Row(children: [
                SizedBox(
                    width: 100,
                    height: 20,
                    child: ButtonTheme(
                        child: RaisedButton(
                      child: Text(widget.paramNames[i]),
                      color: Color(mode.paramsEnabled[i]
                          ? 0xff008822
                          : 0xff333333), //0xffeeaa00 : 0
                      textColor: Color(mode.paramsEnabled[i]
                          ? 0xff55ff55
                          : 0xff888888), //selectedGroup == i?0xff553300:
                      shape: new RoundedRectangleBorder(
                          borderRadius: new BorderRadius.circular(8.0),
                          side: BorderSide(color: Color(0x33ffffff), width: 1)),
                      onPressed: () {
                        toggleEnable(i);
                      },
                    ))),
                Expanded(
                    child: Slider(
                  value: mode.paramValues[i],
                  onChanged: (val) {
                    sliderChanged(i, val);
                  },
                ))
              ]))
    ]);
  }
}
