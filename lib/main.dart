import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:meetups/firebase_options.dart';
import 'package:meetups/http/web.dart';
import 'package:meetups/models/device.dart';
import 'package:meetups/screens/events_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  NotificationSettings notificationSettings = await firebaseMessaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if(notificationSettings.authorizationStatus == AuthorizationStatus.authorized){
    print('Permissão concedida ${notificationSettings.authorizationStatus}');
    _startPushNotificationsHandler(firebaseMessaging);
  }else if(notificationSettings.authorizationStatus == AuthorizationStatus.provisional){
    print('Permissão provisória ${notificationSettings.authorizationStatus}');
    _startPushNotificationsHandler(firebaseMessaging);
  }else{
    print('Permissão de notificação não concedida');
  }

  runApp(App());
}

void _startPushNotificationsHandler(FirebaseMessaging firebaseMessaging) async {
   String? token = await firebaseMessaging.getToken();
  print('token: $token');
  setPushToken(token);

  //TRATAMENTO PARA RECEBER NOTIFICAÇÕES E/OU DADOS QUANDO O APP ESTIVER ABERTO.
  //NESTE CASO TEM QUE IMPLEMENTAR A EXIBIÇÃO DA NOTIFICAÇÃO.
   //FOREGROUND
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Notificação recebi com app aberto.');
    print('Dados da mensagem: ${message.data}');

    if(message.notification != null){
      print('A mensagem continha uma notificação: ${message.notification!.title}, '
          '${message.notification!.body}');

    }
  });

  //BACKGROUND. APP ABERTO, MAS EM SEGUNDO PLANO
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  //TERMINATED
  var notification = await FirebaseMessaging.instance.getInitialMessage();

  if(notification!.data['message'].length>0){
    showDialogMessaging(notification.data['message']);
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async{
  print('Dados da mensagem em Background: ${message.data}');
  if(message.notification != null) {
    print('Notificação recebida em Background: ${message.notification!.title}, '
        '${message.notification!.body}');
  }
}

void showDialogMessaging(String message){
  Widget okButton = OutlinedButton(onPressed: ()=>Navigator.pop(navigatorKey.currentContext!), child: Text("OK"));
  AlertDialog alertDialog = AlertDialog(
    title: Text("Promoção imperdível"),
    content: Text(message),
    actions: [
      okButton
    ],
  );

  showDialog(context: navigatorKey.currentContext!, builder: (BuildContext context){
    return alertDialog;
  });
}

void setPushToken(String? token) async{
  SharedPreferences pref = await SharedPreferences.getInstance();

  String? prefPushToken = pref.getString('pushToken');
  bool? prefSentToken = pref.getBool('sentToken');
  print('Pref Token: $prefSentToken');

  if((prefPushToken==null || prefPushToken!=token) ||
      (prefSentToken==null || !prefSentToken)){
    print('Enviando o token para o servidor');

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    String? brand;
    String? model;

    if(Platform.isAndroid){
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      print('Rodando no ${androidInfo.model}');
      model = androidInfo.model;
      brand = androidInfo.brand;
    }else{
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      print('Rodando no ${iosInfo.utsname.machine}');
      model = iosInfo.utsname.machine;
      brand = 'Apple';
    }

    Device device = Device(brand: brand, model: model, token: token);

    sendDevice(device);
  }
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dev meetups',
      home: EventsScreen(),
      navigatorKey: navigatorKey,
    );
  }
}
