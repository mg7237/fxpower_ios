import 'package:currency_ios/data/model.dart';
import 'package:currency_ios/util/networkapi.dart';
import "package:currency_ios/screens/screen1.dart";
import "package:currency_ios/screens/notifications.dart";
import "package:currency_ios/screens/webview.dart";
import "package:currency_ios/screens/rateusscreen.dart";
import 'data/data.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const String _kMonthlySubscriptionId = 'subscription_monthly';
const List<String> _kProductIds = <String>[_kMonthlySubscriptionId];
//main
void main() {
  // WidgetsFlutterBinding.ensureInitialized();

  InAppPurchaseConnection.enablePendingPurchases();
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
  int freenum = 7;
  bool freePeriodUtilized = false;
  bool subsciptionActive = false;
  bool showPurchaseWidget = false;
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _loading = true;
  bool iosSubscriptionActive = false;
  bool _subscriptionCheckComplete = false;
  String _queryProductError;
  List<String> _notFoundIds = [];
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];

  final InAppPurchaseConnection _connection = InAppPurchaseConnection.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging();

  StreamSubscription iosSubscription;
  StreamSubscription<List<PurchaseDetails>> _subscription;

  void notificationrecieve() {
    if (Platform.isIOS) {
      iosSubscription = _fcm.onIosSettingsRegistered.listen((data) {
        print(data);
        _saveDeviceToken();
      });
      iosSubscriptionActive = true;
      _fcm.requestNotificationPermissions(IosNotificationSettings());
    } else {
      _saveDeviceToken();
    }

    _fcm.subscribeToTopic("currency");
    _fcm.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        Navigator.push(context, _createRoute_2());
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
        Navigator.push(context, _createRoute_2());
      },
    );

    _fcm.requestNotificationPermissions(const IosNotificationSettings(
        sound: true, badge: true, alert: true, provisional: true));
  }

  _saveDeviceToken() async {
    // Get the current user
    String uid = 'kni';
    //  FirebaseUser user = await _auth.currentUser();
    // Get the token for this device
    fcmtoken = await _fcm.getToken();
    // Save it to Firestore
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() {
          _purchasePending = true;
        });
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        setState(() {
          _purchasePending = false;
        });
      } else if (purchaseDetails.status == PurchaseStatus.purchased) {
        bool valid = await _verifyPurchase(purchaseDetails);

        if (valid) {
          deliverProduct(purchaseDetails);
        } else {
          _handleInvalidPurchase(purchaseDetails);
          return;
        }
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await InAppPurchaseConnection.instance
            .completePurchase(purchaseDetails);
      }
    });
  }

  startTime() async {
    var _duration = new Duration(milliseconds: 500);
    return new Timer(_duration, validateSubscription);
  }

  Future<void> initStoreInfo() async {
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        InAppPurchaseConnection.instance.purchaseUpdatedStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      print('Error: $error');
      // Scaffold.of(context).showSnackBar(SnackBar(
      //     content: Text(
      //         'Error processing your purchase request. Please try later.')));
    });

    final bool isAvailable = await _connection.isAvailable();

    if (!isAvailable) {
      setState(() {
        _isAvailable = isAvailable;
        _products = [];
        _purchases = [];
        _notFoundIds = [];
        _purchasePending = false;
        _loading = false;
        // Scaffold.of(context).showSnackBar(SnackBar(
        //   content: Text('Payment Server Unavailable! Please try again later.'),
        // ));
      });
      return;
    }

    ProductDetailsResponse productDetailResponse =
        await _connection.queryProductDetails(_kProductIds.toSet());
    if (productDetailResponse.error != null) {
      setState(() {
        _queryProductError = productDetailResponse.error.message;
        _isAvailable = isAvailable;
        _products = productDetailResponse.productDetails;
        _purchases = [];
        _notFoundIds = productDetailResponse.notFoundIDs;
        _purchasePending = false;
        _loading = false;
        print('Error: $_queryProductError');
        // Scaffold.of(context).showSnackBar(SnackBar(
        //     content: Text(
        //         'Error retreiving product details! Please try again later.')));
      });
      return;
    }

    if (productDetailResponse.productDetails.isEmpty) {
      setState(() {
        _queryProductError = null;
        _isAvailable = isAvailable;
        _products = productDetailResponse.productDetails;
        _purchases = [];
        _notFoundIds = productDetailResponse.notFoundIDs;
        _purchasePending = false;
        _loading = false;
      });
      return;
    }
    QueryPurchaseDetailsResponse purchaseResponse;
    try {
      purchaseResponse = await _connection.queryPastPurchases();
    } catch (e) {
      purchaseResponse = null;
    }

    if (purchaseResponse.error != null) {
      print('Error: $_queryProductError');
      // Scaffold.of(context).showSnackBar(SnackBar(
      //     content: Text(
      //         'Error retreiving past purchase details! Please try again later.')));
    }

    final List<PurchaseDetails> verifiedPurchases = [];

    for (PurchaseDetails purchase in purchaseResponse.pastPurchases) {
      if (await _verifyPurchase(purchase)) {
        verifiedPurchases.add(purchase);
      }
    }

    setState(() {
      _isAvailable = isAvailable;
      _products = productDetailResponse.productDetails;
      _purchases = verifiedPurchases;
      _notFoundIds = productDetailResponse.notFoundIDs;
      _purchasePending = false;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    notificationrecieve();
    //screen rotation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    updatetime = DateTime.now();
    currencymodel.initalizecurrencydata();
    ApiHelper.getToken("http://zapp.fxsonic.com/api/token");
    startTime();
    initStoreInfo();
    validateFreePeriod();
    setState(() {});
  }

  @override
  void dispose() {
    if (iosSubscriptionActive) iosSubscription.cancel();
    //_subscription.cancel();

    super.dispose();
  }

  Future<void> validateFreePeriod() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    freePeriodUtilized = (prefs.getBool("free_period_utilized") ?? false);
  }

  Future<void> validateSubscription() async {
    subsciptionActive = await isSubscriptionActive();

    if (subsciptionActive) {
      Navigator.pushReplacement(context, _createRoute());
    } else {
      _subscriptionCheckComplete = true;
      if (this.mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> isSubscriptionActive() async {
    QueryPurchaseDetailsResponse purchaseResponse;
    try {
      purchaseResponse = await _connection.queryPastPurchases();
    } catch (e) {
      purchaseResponse = null;
    }

    if (purchaseResponse.error != null) {
      print('Error: ${purchaseResponse.error}');
    }
    final List<PurchaseDetails> verifiedPurchases = [];
    for (PurchaseDetails purchase in purchaseResponse.pastPurchases) {
      if (await _verifyPurchase(purchase)) {
        verifiedPurchases.add(purchase);
        if (purchase.productID == _kMonthlySubscriptionId)
          return Future<bool>.value(true);
      }
    }

    return Future<bool>.value(false);
  }

  Future<void> deliverProduct(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.pendingCompletePurchase) {
      await InAppPurchaseConnection.instance.completePurchase(purchaseDetails);
    }
    setState(() {
      _purchases.add(purchaseDetails);
      _purchasePending = false;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool("free_period_utilized", true);
    Navigator.pushReplacement(context, _createRoute());
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    return Future<bool>.value(true);
    // String purchaseValidationJson =
    //     purchaseDetails.verificationData.localVerificationData;
    // Map<String, dynamic> map = jsonDecode(purchaseValidationJson);
    // await InAppPurchaseConnection.instance.completePurchase(purchaseDetails);
    // if (map['productId'] == _kMonthlySubscriptionId &&
    //     map['purchaseToken'] != '' &&
    //     map['purchaseTime'] != '') {
    //   return Future<bool>.value(true);
    // } else
    //   return Future<bool>.value(false);
  }

  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {
    print('Error: Invalid Purchase');
    // Scaffold.of(context).showSnackBar(SnackBar(
    //     content:
    //         Text('Error processing your purchase request. Please try later.')));
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
    var size = MediaQuery.of(context).size;
    return MaterialApp(home: Scaffold(body: Builder(
        // Create an inner BuildContext so that the onPressed methods
        // can refer to the Scaffold with Scaffold.of().
        builder: (BuildContext context) {
      return Center(
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
                  Text(
                    _subscriptionCheckComplete
                        ? ((freePeriodUtilized ?? false)
                            ? "Subscription Expired!"
                            : freenum.toString() + "-Day Free Trial")
                        : "Verifying Subscription ...",
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 24 * size.width / 390,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  _subscriptionCheckComplete
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
                              // Manish
                              //Navigator.push(context, _createRoute());
                              // setState(() {
                              //   showPurchaseWidget = true;
                              //   print('stRT');
                              // });
                              ProductDetails _subscriptionProductDetails;
                              for (ProductDetails _product in _products) {
                                if (_product.id == _kMonthlySubscriptionId)
                                  _subscriptionProductDetails = _product;
                              }

                              if (await isSubscriptionActive()) {
                              } else {
                                PurchaseParam purchaseParam = PurchaseParam(
                                    productDetails: _subscriptionProductDetails,
                                    applicationUserName: null);

                                _connection.buyNonConsumable(
                                    purchaseParam: purchaseParam);
                                print('purchased');
                              }
                            },
                            child: Text(
                              ((freePeriodUtilized ?? false)
                                  ? 'Renew now'
                                  : 'Start'),
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
              bottom: 40 * size.height / 750,
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
        fontSize: 20, fontFamily: "Montserrat", fontWeight: FontWeight.w600);
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
