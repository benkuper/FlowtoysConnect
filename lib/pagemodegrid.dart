import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class PageModeSelection extends StatefulWidget {
  const PageModeSelection(
      {Key key, this.onPageModeChanged, this.scrollController})
      : super(key: key);

  final scrollController;
  final Function(int page, int mode) onPageModeChanged;

  @override
  _PageModeSelectionState createState() => _PageModeSelectionState();
}

class _PageModeSelectionState extends State<PageModeSelection> {
  _PageModeButtonState selectedButton;

  void buttonSelected(_PageModeButtonState b) {
    if (b == selectedButton) return;
    if (selectedButton != null) selectedButton.setSelected(false);
    selectedButton = b;
    if (selectedButton != null) {
      selectedButton.setSelected(true);
      widget.onPageModeChanged(
          selectedButton.widget.page, selectedButton.widget.mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Build GRID here");
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.only(bottom:70),
      children: [
        for (int i in [1, 2, 3, 13])
          Container(
              padding: const EdgeInsets.all(4),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
              color: Color(0xff444444),
              boxShadow: [BoxShadow(color:Color(0x55000000),blurRadius: 5)],
              border: Border.all(color: Color(0x22ffffff), width: 1),
              borderRadius: BorderRadius.all(Radius.circular(5)),
              
            ),

            child: Column(
                children: [
                    Text(
                    "Page $i",
                    style: TextStyle(color: Color(0xffffffff), fontSize: 16),
                  ),
                  
                  GridView.count(
                      padding:EdgeInsets.only(top:10),
                      shrinkWrap: true,
                      physics: new NeverScrollableScrollPhysics(),
                      crossAxisCount: 10,
                      childAspectRatio: 1.0,
                      mainAxisSpacing: 2.0,
                      crossAxisSpacing: 2.0,
                      children: [
                        for (int j = 0; j < (i == 13 ? 80 : 10); j++)
                          PageModeButton(
                              onSelect: buttonSelected, page: i, mode: j)
                      ]),

                  
                ],
            ),
          ),

      ],
    );
  }
}

class PageModeButton extends StatefulWidget {
  PageModeButton({Key key, this.onSelect, this.page, this.mode})
      : super(key: key);

  final int page;
  final int mode;

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
