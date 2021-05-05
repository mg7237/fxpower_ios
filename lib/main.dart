import 'package:currency_ios/data/model.dart';
import 'package:currency_ios/util/networkapi.dart';
import "package:currency_ios/screens/screen1.dart";
import "package:currency_ios/screens/notifications.dart";
import "package:currency_ios/screens/webview.dart";
import "package:currency_ios/screens/rateusscreen.dart";
import "package:currency_ios/util/alert_dialog.dart";
import 'data/data.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';

const String _kMonthlySubscriptionId = 'iOS_Monthly_Sub';
const List<String> _productLists = <String>[_kMonthlySubscriptionId];
//main

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.

  print("Handling a background message: ${message.messageId}");
  //Navigator.push(context, _createRoute_2());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(
      MaterialApp(title: 'distant', debugShowCheckedModeBanner: false, routes: {
    '/': (context) => Dashboard(),
    '/screen1': (context) => Screen1(),
    '/notifications': (context) => Notificationscreen()
  }));
}

//class Dashboard
class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool subsciptionActive = false;
  bool showPurchaseWidget = false;
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _loading = true;
  bool iosSubscriptionActive = false;
  String _queryProductError;
  List<String> _notFoundIds = [];

  List<IAPItem> _items = [];
  List<PurchasedItem> _purchases = [];
  StreamSubscription _purchaseUpdatedSubscription;
  StreamSubscription _purchaseErrorSubscription;
  StreamSubscription _conectionSubscription;
  String _platformVersion = 'Unknown';

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await FlutterInappPurchase.instance.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // prepare
    var result = await FlutterInappPurchase.instance.initConnection;
    print('result: $result');

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });

    // refresh items for android
    try {
      String msg = await FlutterInappPurchase.instance.consumeAllItems;
      print('consumeAllItems: $msg');
    } catch (err) {
      print('consumeAllItems error: $err');
    }

    _conectionSubscription =
        FlutterInappPurchase.connectionUpdated.listen((connected) {
      print('connected: $connected');
    });

    _purchaseUpdatedSubscription =
        FlutterInappPurchase.purchaseUpdated.listen((productItem) {
      print('purchase-updated: $productItem');
      Navigator.pushReplacement(context, _createRoute());
    });

    _purchaseErrorSubscription =
        FlutterInappPurchase.purchaseError.listen((purchaseError) {
      print('purchase-error: $purchaseError');

      AlertDialogs dialog = AlertDialogs(
          title: purchaseError.code,
          message: "Error while purchasing: ${purchaseError.message}");
      dialog.asyncAckAlert(context);
    });

    await _getProduct();

    await _getPurchases();

    await validateSubscription();
  }

  void _requestPurchase(IAPItem item, BuildContext context) async {
    try {
      await FlutterInappPurchase.instance.requestSubscription(item.productId);
      print("Success");
    } catch (e) {
      _showToast(context, "Error while purchasing: $e");
    }
  }

  Future _getProduct() async {
    _items = [];
    List<IAPItem> items =
        await FlutterInappPurchase.instance.getProducts(_productLists);
    for (var item in items) {
      print('${item.toString()}');
      if (item.productId == _kMonthlySubscriptionId) {
        this._items.add(item);
      }
    }
  }

  Future _getPurchases() async {
    List<PurchasedItem> items =
        await FlutterInappPurchase.instance.getAvailablePurchases();
    for (var item in items) {
      if (item.productId == _kMonthlySubscriptionId) {
        print('${item.toString()}');
        this._purchases.add(item);
      }
    }
  }

  void _showToast(BuildContext context, String message) {
    final scaffoldMessanger = ScaffoldMessenger.of(context);
    scaffoldMessanger.showSnackBar(
      SnackBar(
        content:
            Text(message, style: TextStyle(fontSize: 20, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 10,
      ),
    );
    print('mmm $message');
  }

  void notificationrecieve() async {
    if (Platform.isIOS) {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print('User granted permission: ${settings.authorizationStatus}');
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        return;
      }
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true, // Required to display a heads up notification
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print(
              'Message also contained a notification: ${message.notification}');
        }
      });
      iosSubscriptionActive = true;
      _saveDeviceToken();

      _fcm.subscribeToTopic("currency");
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage message) {
        if (message != null) {
          Navigator.push(context, _createRoute_2());
        }
      });

      FirebaseMessaging.onMessageOpenedApp
          .listen((RemoteMessage message) async {
        print('A new onMessageOpenedApp event was published!');
        if (await isSubscriptionActive()) {
          Navigator.push(context, _createRoute_2());
        }
      });
    }
  }

  _saveDeviceToken() async {
    fcmtoken = await _fcm.getToken();
  }

  @override
  void initState() {
    super.initState();

    notificationrecieve();
    //screen rotation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    updatetime = DateTime.now();
    currencymodel.initalizecurrencydata();
    ApiHelper.getToken("/api/token");
    initPlatformState();
  }

  @override
  void dispose() {
    if (_conectionSubscription != null) {
      _conectionSubscription.cancel();
      _conectionSubscription = null;
    }
    //_subscription.cancel();

    super.dispose();
  }

  Future<void> validateSubscription() async {
    subsciptionActive = await isSubscriptionActive();

    if (subsciptionActive) {
      Navigator.pushReplacement(context, _createRoute());
    } else {
      _loading = false;
      if (this.mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> isSubscriptionActive() async {
    if (_purchases.isNotEmpty) {
      if (await ApiHelper().verifyPurchase(
          _purchases[_purchases.length - 1].transactionReceipt)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
    var size = MediaQuery.of(context).size;
    return MaterialApp(home: Scaffold(body: Builder(
        // Create an inner BuildContext so that the onPressed methods
        // can refer to the Scaffold with Scaffold.of().
        builder: (BuildContext context) {
      return LoadingOverlay(
        opacity: 0.5,
        color: Colors.grey[400],
        progressIndicator: CircularProgressIndicator(),
        isLoading: _loading,
        child: Center(
          child: Stack(alignment: Alignment.topCenter, children: [
            Column(
              children: [
                SizedBox(
                  height: 100 * size.height / 750,
                ),
                Text(
                  "Fx Power Meter",
                  style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black87,
                      fontSize: 37 * size.width / 390,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
                //logo
                Container(
                    margin: EdgeInsets.only(top: 10, bottom: 30),
                    width: 330 * size.width / 390,
                    child: Image(image: AssetImage('assets/logo.png'))),
                //buttons
                Container(
                    child: Column(
                  children: [
                    SizedBox(
                      height: 10,
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    (!_loading)
                        ? Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                gradient: LinearGradient(
                                    colors: [
                                      Colors.grey[700],
                                      Colors.grey[900],
                                      Colors.grey[700],
                                    ],
                                    stops: [
                                      0.1,
                                      0.5,
                                      0.9
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter)),
                            height: 55 * size.width / 390,
                            child: RaisedButton(
                              color: Colors.grey.withAlpha(30),
                              padding: EdgeInsets.only(
                                  left: 100, right: 100, top: 8, bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100)),
                              onPressed: () async {
                                setState(() {
                                  _loading = true;
                                });
                                if (_items == null || _items.length == 0) {
                                  _getProduct();
                                }

                                if (await isSubscriptionActive()) {
                                  Navigator.pushReplacement(
                                      context, _createRoute());
                                } else {
                                  for (var product in _items) {
                                    if (product.productId ==
                                        _kMonthlySubscriptionId) {
                                      _requestPurchase(product, context);
                                    }
                                  }
                                  setState(() {
                                    _loading = false;
                                  });
                                  print('purchased');
                                }
                              },
                              child: Text(
                                'Start',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28 * size.width / 390,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1),
                              ),
                            ),
                          )
                        : Text(""),
                  ],
                ))
              ],
            ),
            Positioned(
                bottom: 40 * size.height / 350,
                child: Column(
                  children: [
                    Text(
                      "By signing up you agree to",
                      style: TextStyle(
                          fontSize: 16 * size.width / 390, letterSpacing: 0.1),
                      textAlign: TextAlign.center,
                    ),
                    Row(
                      children: [
                        Text("our ",
                            style: TextStyle(
                                fontSize: 16 * size.width / 390,
                                letterSpacing: 0.1)),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, _createRoute_3(5));
                          },
                          child: Text("Term of Service",
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 16 * size.width / 390,
                                  letterSpacing: 0.1)),
                        ),
                        Text(" and ",
                            style: TextStyle(
                                fontSize: 16 * size.width / 390,
                                letterSpacing: 0.1)),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, _createRoute_3(4));
                          },
                          child: Text("Privacy Policy",
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 16 * size.width / 390,
                                  letterSpacing: 0.1)),
                        ),
                      ],
                    )
                  ],
                )),
          ]),
        ),
      );
    })));
  }
}

class Menulist extends StatefulWidget {
  var changeid;
  Menulist(this.changeid);
  @override
  _MenulistState createState() => _MenulistState(changeid);
}

class _MenulistState extends State<Menulist> {
  int stateflag = 0;
  var changeid;
  _MenulistState(this.changeid);
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    TextStyle substyle = TextStyle(
        fontSize: 18, fontFamily: "Montserrat", fontWeight: FontWeight.w500);
    return Drawer(
        child: ListView(children: [
      if (stateflag == 0)
        Container(
          height: 60,
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.only(top: 20, left: 20),
          decoration: BoxDecoration(color: Colors.grey[350]),
          child: Text(
            'Fx Power Meter',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
        ),
      if (stateflag == 1)
        Container(
          height: 60,
          padding: EdgeInsets.only(top: 20, left: 10),
          decoration: BoxDecoration(color: Colors.grey[350]),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                padding: EdgeInsets.only(left: 5),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Colors.black),
                child: GestureDetector(
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                  onTap: () {
                    setState(() {
                      stateflag = 0;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 50,
              ),
              Text(
                'Alert Setting',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      if (stateflag == 0)
        Column(
          children: [
            GestureDetector(
              child: Container(
                  width: size.width,
                  padding: EdgeInsets.only(top: 30, left: 20),
                  child: Row(
                    children: [
                      Image(
                        image: AssetImage("assets/strong_icon.png"),
                        height: 25,
                      ),
                      Text(
                        ' Strongest & Weakest',
                        style: substyle,
                      ),
                    ],
                  )),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, _createRoute_2());
              },
            ),
            GestureDetector(
              child: Container(
                  width: size.width,
                  padding: EdgeInsets.only(top: 30, left: 20),
                  child: Row(
                    children: [
                      Icon(Icons.notifications),
                      Text(
                        ' Alert Setting',
                        style: substyle,
                      ),
                    ],
                  )),
              onTap: () {
                setState(() {
                  stateflag = 1;
                });
              },
            ),
            /*         GestureDetector(
              child: Container(
                  width: size.width,
                  padding: EdgeInsets.only(top: 30, left: 20),
                  child: Row(
                    children: [
                      Icon(Icons.grade_rounded),
                      Text(
                        ' Rate us',
                        style: substyle,
                      ),
                    ],
                  )),
              onTap: () {
                Navigator.push(context, _createRoute_3(0));
              },
            ),
   */
            GestureDetector(
              child: Container(
                  width: size.width,
                  padding: EdgeInsets.only(top: 30, left: 20),
                  child: Row(
                    children: [
                      Icon(Icons.near_me),
                      Text(
                        ' Support',
                        style: substyle,
                      ),
                    ],
                  )),
              onTap: () {
                Navigator.push(context, _createRoute_3(1));
              },
            ),
            GestureDetector(
              child: Container(
                  width: size.width,
                  padding: EdgeInsets.only(top: 30, left: 20),
                  child: Row(
                    children: [
                      Icon(Icons.business),
                      Text(
                        ' About us',
                        style: substyle,
                      ),
                    ],
                  )),
              onTap: () {
                Navigator.push(context, _createRoute_3(2));
              },
            ),
          ],
        ),
      if (stateflag == 1)
        Column(
          children: [
            //title
            Container(
              width: size.width,
              padding:
                  EdgeInsets.only(top: 20, bottom: 10, left: 20, right: 20),
              child: Text(
                'Strongest-Weakest by timeframe',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              decoration: BoxDecoration(color: Colors.grey[200]),
            ),
            GestureDetector(
              onTap: () {
                if (notification_time[0] == true)
                  for (int i = 1; i < 11; i++) {
                    setState(() {
                      notification_time[0] = false;
                      notification_time[i] = false;
                      Map<String, String> register_data = {
                        "register_token": fcmtoken,
                        "time": i.toString(),
                        'enable': "0"
                      };
                      ApiHelper.postRegister(register_data);
                      Datafilemanage.save_notification_time();
                    });
                  }
              },
              //show notification
              child: Container(
                margin: EdgeInsets.only(bottom: 10),
                width: size.width,
                height: 40,
                decoration: BoxDecoration(color: Colors.grey[200]),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 40,
                      child: Text(
                        "Show Alert",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Positioned(
                        right: 20,
                        child: Switch(
                          value: notification_time[0],
                          onChanged: (value) {
                            if (value == false)
                              for (int i = 1; i < 11; i++) {
                                setState(() {
                                  notification_time[0] = false;
                                  notification_time[i] = false;
                                  Map<String, String> register_data = {
                                    "register_token": fcmtoken,
                                    "time": i.toString(),
                                    'enable': "0"
                                  };
                                  ApiHelper.postRegister(register_data);
                                  Datafilemanage.save_notification_time();
                                });
                              }
                          },
                        ))
                  ],
                ),
              ),
            ),
            //timeset
            SizedBox(
              height: 10,
            ),
            for (int i = 1; i < 11; i++)
              GestureDetector(
                onTap: () {
                  notification_time[i] = !notification_time[i];
                  if (notification_time[i] == true)
                    setState(() {
                      notification_time[0] = true;
                      Map<String, String> register_data = {
                        "register_token": fcmtoken,
                        "time": i.toString(),
                        'enable': "1"
                      };
                      ApiHelper.postRegister(register_data);
                      Datafilemanage.save_notification_time();
                    });
                  else {
                    int fflag = 0;
                    for (int j = 1; j < 11; j++) {
                      if (notification_time[j] == true) fflag = 1;
                    }
                    if (fflag == 0) notification_time[0] = false;
                    setState(() {
                      Map<String, String> register_data = {
                        "register_token": fcmtoken,
                        "time": i.toString(),
                        'enable': "0"
                      };
                      ApiHelper.postRegister(register_data);
                      Datafilemanage.save_notification_time();
                    });
                  }
                },
                child: Container(
                  width: size.width,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 40,
                        child: Text(
                          notificationtimename_1[i],
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Positioned(
                          right: 20,
                          child: Switch(
                            value: notification_time[i],
                            onChanged: (value) {
                              if (value == true)
                                setState(() {
                                  notification_time[0] = true;
                                  notification_time[i] = true;
                                  Map<String, String> register_data = {
                                    "register_token": fcmtoken,
                                    "time": i.toString(),
                                    'enable': "1"
                                  };
                                  ApiHelper.postRegister(register_data);
                                  Datafilemanage.save_notification_time();
                                });
                              else {
                                setState(() {
                                  notification_time[i] = false;
                                  int fflag = 0;
                                  for (int j = 1; j < 11; j++) {
                                    if (notification_time[j] == true) fflag = 1;
                                  }
                                  if (fflag == 0) notification_time[0] = false;
                                  Map<String, String> register_data = {
                                    "register_token": fcmtoken,
                                    "time": i.toString(),
                                    'enable': "0"
                                  };
                                  ApiHelper.postRegister(register_data);
                                  Datafilemanage.save_notification_time();
                                });
                              }
                            },
                          ))
                    ],
                  ),
                ),
              ),
            SizedBox(
              height: 10,
            ),
          ],
        ),
    ]));
  }
}

Route _createRoute() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => Screen1(),
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

Route _createRoute_2() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) =>
        Notificationscreen(),
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

Route _createRoute_3(int id) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => Webviewscreen(
      id: id,
    ),
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

Route _createRoute_4() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => Rateusscreen(),
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
