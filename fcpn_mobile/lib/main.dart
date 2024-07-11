import 'dart:async';
import 'dart:convert';

import 'package:centrifuge/centrifuge.dart' as centrifuge;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
NotificationAppLaunchDetails? notificationAppLaunchDetails;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  notificationAppLaunchDetails = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  
  final InitializationSettings initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onSelectNotification,
  );

  runApp(MyApp());
}

void onSelectNotification(NotificationResponse response) async {
  // Handle notification response
  final String? payload = response.payload;
  if (payload != null && payload.isNotEmpty) {
    debugPrint("payload : $payload");
    // Do something with the payload
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Centrifuge Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        
      ),
      home: MyHomePage(title: 'Centrifuge Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late centrifuge.Client _centrifuge;
  centrifuge.Subscription? _subscription;
  late ScrollController _controller;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  final _items = <_ChatItem>[];

  @override
  void initState() {
    super.initState();
    final url = 'ws://192.168.43.70:8000/connection/websocket?format=protobuf';
    _centrifuge = centrifuge.createClient(url);

    _controller = ScrollController();
    
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var android = AndroidInitializationSettings('@mipmap/ic_launcher');
    var iOS = DarwinInitializationSettings();
    var initSettings = InitializationSettings(android: android, iOS: iOS);
    flutterLocalNotificationsPlugin.initialize(initSettings, onDidReceiveNotificationResponse: onSelectNotification);
  }

  Future<void> _showNotification(String msg) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        '696969', 'FCPN',
        importance: Importance.max, priority: Priority.high, ticker: 'ticker');
    var iOSPlatformChannelSpecifics = DarwinNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0, 'plain title', msg, platformChannelSpecifics,
        payload: 'item x');
  }

  @override
  void dispose() {
    _centrifuge.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          PopupMenuButton<Function>(
            onSelected: (f) => f(),
            itemBuilder: (context) => <PopupMenuItem<Function>>[
              PopupMenuItem(
                value: () => _connect(),
                child: Text('Connect'),
              ),
              PopupMenuItem(
                value: () => _subscribe(),
                child: Text('Subscribe'),
              ),
            ],
          )
        ],
      ),
      body: ListView.builder(
          itemCount: _items.length,
          controller: _controller,
          itemBuilder: (context, index) {
            final item = _items[index];
            return ListTile(
              title: Text(item.title),
              subtitle: Text(item.subtitle),
            );
          }),
    );
  }

  void _connect() async {
    try {
      await _centrifuge.connect();
    } catch (exception) {
      _show(exception);
    }
  }

  // void _subscribe() async {
  //   final channel = 'global';
  //   _subscription = _centrifuge.getSubscription(channel);

  //   _subscription?.subscribeErrorStream.listen(_show);
  //   _subscription?.subscribeSuccessStream.listen(_show);
  //   _subscription?.unsubscribeStream.listen(_show);

  //   final onNewItem = (_ChatItem item) {
  //     setState(() {
  //       _items.insert(0, item);
  //     });
  //   };

  //   _subscription?.joinStream.listen((event) {
  //     final user = event.user;
  //     final client = event.client;

  //     final item = _ChatItem(
  //         title: 'User $user joined channel $channel',
  //         subtitle: '(client ID $client)');
  //     onNewItem(item);
  //   });

  //   _subscription?.leaveStream.listen((event) {
  //     final user = event.user;
  //     final client = event.client;
  //     final item = _ChatItem(
  //         title: 'User $user left channel $channel',
  //         subtitle: '(client ID $client)');
  //     onNewItem(item);
  //   });

  //   _subscription?.publishStream.listen((event) {
  //     final String message = json.decode(utf8.decode(event.data))['input'];

  //     _showNotification(message);
  //     final item = _ChatItem(title: message, subtitle: 'User: user');
  //     onNewItem(item);
  //   });

  //   _subscription?.subscribe();
  // }

  void _subscribe() async {
  final channel = 'global';
  _subscription = _centrifuge.getSubscription(channel);

  _subscription?.error.listen((event) {
    _show('Subscription error: $event');
  });

  _subscription?.subscribed.listen((event) {
    _show('Subscribed to channel: $channel');
  });

  _subscription?.unsubscribe();

  final onNewItem = (_ChatItem item) {
    setState(() {
      _items.insert(0, item);
    });
  };

  _subscription?.join.listen((event) {
    final user = event.user;
    final client = event.client;

    final item = _ChatItem(
        title: 'User $user joined channel $channel',
        subtitle: '(client ID $client)');
    onNewItem(item);
  });

  _subscription?.leave.listen((event) {
    final user = event.user;
    final client = event.client;
    final item = _ChatItem(
        title: 'User $user left channel $channel',
        subtitle: '(client ID $client)');
    onNewItem(item);
  });

  // _subscription?.publish.listen((data) {
  //   final String message = json.decode(utf8.decode(data))['input'];

  //   _showNotification(message);
  //   final item = _ChatItem(title: message, subtitle: 'User: user');
  //   onNewItem(item);
  // });

  try {
    await _subscription?.subscribe();
  } catch (e) {
    _show('Subscription failed: $e');
  }
}


  void _show(dynamic error) {
    showDialog<AlertDialog>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(
          error.toString(),
        ),
      ),
    );
  }
}

class _ChatItem {
  _ChatItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}
