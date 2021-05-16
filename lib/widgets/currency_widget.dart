import 'dart:ffi';
import 'dart:ui';
import "dart:math";
import 'package:flutter/material.dart';
import 'package:currency_ios/screens/screen2.dart';
import 'package:currency_ios/data/data.dart';
import 'package:currency_ios/widgets/customwidgets.dart';
import 'package:device_info/device_info.dart';

class currencywidget extends StatefulWidget {
  final Float degree;
  final double size;
  final int id;

  currencywidget({this.degree, Key key, this.size = 350, this.id = 0})
      : super(key: key);

  @override
  _currencywidgetState createState() => _currencywidgetState();
}

class _currencywidgetState extends State<currencywidget> {
  bool ipad = false;

  @override
  void initState() {
    super.initState();
    isIpad();
  }

  Future<void> isIpad() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    IosDeviceInfo info = await deviceInfo.iosInfo;
    if (info.model.toLowerCase().contains("ipad")) {
      ipad = true;
    }
    setState(() {});
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: EdgeInsets.all(5),
        height: ipad
            ? (130 * widget.size / 190) - 5
            : 130 * widget.size / 150, // Manish 180 -> 175
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25 * widget.size / 160),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey[200], blurRadius: 40, spreadRadius: 1)
            ]),
        child: Container(
          transform: Matrix4.translationValues(0, 30.0 * widget.size / 170, 0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                  child: Container(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: Mypaint(widget.id),
                  child: Container(),
                ),
              )),
              Positioned(
                  child: GestureDetector(
                child: Container(
                  width: (widget.size / 2.2) + 15,
                  height: ipad
                      ? widget.size / 2.5
                      : widget.size / 2.0, // Manish 2.2 to 2.5 and 2.0
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                              alignment: Alignment.center,
                              width: 30 * widget.size / 170,
                              height: 30 * widget.size / 170,
                              margin: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color:
                                      currencytypedata[sortsequency[widget.id]]
                                          .startcolor,
                                  borderRadius: BorderRadius.circular(100)),
                              child: Text(
                                (widget.id + 1).toString(),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: "Montserrat",
                                    color: Colors.white,
                                    fontSize: 20 * widget.size / 190),
                              )),
                          Text(
                            currencytypedata[sortsequency[widget.id]].type,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: currencytypedata[sortsequency[widget.id]]
                                    .startcolor,
                                fontSize: 20 * widget.size / 190),
                          ),
                        ],
                      ),
                      Text(
                        ((currencytypedata[sortsequency[widget.id]].amount)
                                    .floor())
                                .toString() +
                            "." +
                            prefix(((currencytypedata[sortsequency[widget.id]]
                                            .amount *
                                        1000)
                                    .floor() -
                                (currencytypedata[sortsequency[widget.id]]
                                            .amount)
                                        .floor() *
                                    1000)) +
                            ((currencytypedata[sortsequency[widget.id]].amount *
                                            1000)
                                        .floor() -
                                    (currencytypedata[sortsequency[widget.id]]
                                                .amount)
                                            .floor() *
                                        1000)
                                .toString(),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 16 * widget.size / 190),
                      )
                    ],
                  ),
                ),
                onTap: () {
                  cid = sortsequency[widget.id];
                  print(cid.toString());
                  Navigator.push(context, _createRoute());
                },
              )),
              Positioned(
                  child: GestureDetector(
                child: Container(
                  width: widget.size / 2.2,
                  height: widget.size / 2.2,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(30)),
                ),
                onTap: () {
                  cid = sortsequency[widget.id];
                  print(cid.toString());
                  Navigator.push(context, _createRoute());
                },
              ))
            ],
          ),
        ));
  }

  String prefix(int value) {
    return value < 10
        ? "00"
        : value < 100
            ? "0"
            : "";
  }
}

class Mypaint extends CustomPainter {
  final id;
  Mypaint(this.id);
  @override
  void paint(Canvas canvas, Size size) {
    var rect = Rect.fromLTWH(0, 0, size.width, size.height);
    var arcpaint = Paint()
      ..shader = LinearGradient(colors: [
        currencytypedata[sortsequency[id]].startcolor,
        currencytypedata[sortsequency[id]].endcolor,
      ], stops: [
        0.3,
        0.6
      ], begin: Alignment.topLeft, end: Alignment.bottomRight)
          .createShader(rect)
      ..strokeWidth = 55 * size.width / 390
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    var arcpaint1 = Paint()
      ..color = Colors.grey[100]
      ..strokeWidth = 55 * size.width / 390
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width - 40 * size.width / 200,
            height: size.width - 40 * size.width / 200),
        pi,
        pi,
        false,
        arcpaint1);
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width - 40 * size.width / 200,
            height: size.width - 40 * size.width / 200),
        pi,
        currencytypedata[sortsequency[id]].amount / 10 * pi,
        false,
        arcpaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class currencywidget2 extends StatelessWidget {
  final Float degree;
  final double size;
  final int id;
  var reset;
  int pinnum = cid;
  void choosepinnum() {
    for (int i = 0; i < 8; i++) if (sortsequency_2[id][i] == cid) pinnum = i;
  }

  currencywidget2(
      {this.degree, Key key, this.size = 350, this.id = 0, this.reset})
      : super(key: key) {
    print("updated++++++++++++++++++++++++");
    print(id.toString());
    choosepinnum();
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < 8; i++)
            Positioned(
              child: Container(
                  transform: Matrix4.translationValues(
                      0, -size * (600 / 960 - 0.5), 0),
                  child: Transform(
                      alignment: FractionalOffset(0.5, 1 * 600 / 936),
                      transform: Matrix4.rotationZ(-(pi + 1.08) / 8 * i),
                      child: Container(
                        width: size * 1.1,
                        height: size * 1.1 * 936 / 1200,
                        child: Image(
                          image: AssetImage("assets/" +
                              currencytypedata[sortsequency_2[id][i]].type +
                              ".png"),
                        ),
                      ))),
            ),
          Positioned(
            child: Container(
                transform:
                    Matrix4.translationValues(0, -size * (600 / 960 - 0.5), 0),
                child: Transform(
                    alignment: FractionalOffset(0.5, 1 * 600 / 936),
                    transform: Matrix4.rotationZ(-(pi + 1.08) / 8 * (pinnum)),
                    child: Container(
                      width: size * 1.1,
                      height: size * 1.1 * 936 / 1200,
                      child: Image(
                        image: AssetImage("assets/pin.png"),
                      ),
                    ))),
          ),
          //backimage
          Positioned(
            child: GestureDetector(
              onTap: () {
                showDialog(
                    context: context,
                    builder: (context) => Dialogboxwidget(
                          reset,
                          id: id + 1,
                        ));
                String test = "d";
              },
              child: Container(
                  transform: Matrix4.translationValues(
                      0, -size * 1.1 * 936 / 1200 * (600 / 936 - 0.5), 0),
                  child: Image(
                    width: size * 1.1,
                    image: AssetImage("assets/background.png"),
                  )),
            ),
          ),
          Positioned(
            child: GestureDetector(
              onTap: () {
                showDialog(
                    context: context,
                    builder: (context) => Dialogboxwidget(
                          reset,
                          id: id + 1,
                        ));
              },
              child: Container(
                width: size / 2 - 20 * size / 180,
                height: size / 2 - 20 * size / 180,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      notificationtimename[cupdate[id + 1]],
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: (cupdate[id + 1] < 3)
                              ? 15 * size / 270
                              : 20 * size / 270),
                    ),
                  ],
                ),
              ),
            ),
          ), //
        ],
      ),
    );
  }
}

Route _createRoute() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => Screen2(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var begin = Offset(1.0, 0);
      var end = Offset.zero;
      var curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}
