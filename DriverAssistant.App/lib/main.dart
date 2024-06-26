import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';

import 'package:workmanager/workmanager.dart';

class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext? context){
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
  }
}
class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
final StreamController<
    ReceivedNotification> didReceiveLocalNotificationStream =
StreamController<ReceivedNotification>.broadcast();
DateTime? lastApiCallTime;
final StreamController<
    String?> selectNotificationStream = StreamController<
    String?>.broadcast();
bool _notificationsEnabled = false;
@pragma('vm:entry-point')
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final streamSubscriptions = <StreamSubscription<dynamic>>[];

    streamSubscriptions.add(
      accelerometerEvents.listen(
            (AccelerometerEvent event) {
            _accelerometerValues = <double>[event.x, event.y, event.z];

        },
        onError: (e) {
        },
        cancelOnError: true,
      ),
    );
    streamSubscriptions.add(
      gyroscopeEvents.listen(
            (GyroscopeEvent event) {
            _gyroscopeValues = <double>[event.x, event.y, event.z];
            double difference = calculateDifference(lastGyroscopeData, _gyroscopeValues!);
            if (isDrasticChange(difference)) {
              final accelerometer =
              _accelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
              final gyroscope =
              _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
              final currentTime = DateTime.now();

              if (lastApiCallTime == null || currentTime.difference(lastApiCallTime!) >= const Duration(seconds: 2)) {
                callMLModel(double.parse(accelerometer![0]),
                  double.parse(accelerometer[1]),
                  double.parse(accelerometer[2]),
                  double.parse(gyroscope![0]),
                  double.parse(gyroscope[1]),
                  double.parse(gyroscope[2]),
                ).then((value) => _showNotificationCustomVibrationIconLed());

              } else {
                print('Skipping API call. Too soon after the last one.');
              }
            }
        },
        onError: (e) {

        },
        cancelOnError: true,
      ),
    );

    return Future.value(true);
  });
}

Future<void> _showNotificationCustomVibrationIconLed() async {
  final Int64List vibrationPattern = Int64List(4);
  vibrationPattern[0] = 1000;
  vibrationPattern[1] = 1000;
  vibrationPattern[2] = 5000;
  vibrationPattern[3] = 2000;

  final AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'other custom channel id', 'other custom channel name',
      channelDescription: 'other custom channel description',
      largeIcon: const DrawableResourceAndroidBitmap('app_icon'),
      vibrationPattern: vibrationPattern,
      enableLights: true,
      sound: const RawResourceAndroidNotificationSound('sound'),
      color: const Color.fromARGB(255, 255, 0, 0),
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500);

  final NotificationDetails notificationDetails =
  NotificationDetails(android: androidNotificationDetails);
  await flutterLocalNotificationsPlugin.show(
      1,
      'ALERT',
      'Please Drive Slow',
      notificationDetails);
}

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  const String navigationActionId = 'id_3';

  HttpOverrides.global = MyHttpOverrides();
  Workmanager().initialize(
      callbackDispatcher, // The top level function, aka callbackDispatcher
      isInDebugMode: true // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  );
  Workmanager().registerOneOffTask("task-identifier", "MYTASK");

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings(
    'app_icon',// Replace 'app_icon' with the actual resource name for your app icon
  );

  const InitializationSettings initializationSettings =
  InitializationSettings(android:  initializationSettingsAndroid);

  runApp(const MyApp());
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (
        NotificationResponse notificationResponse) {
      switch (notificationResponse.notificationResponseType) {
        case NotificationResponseType.selectedNotification:
          selectNotificationStream.add(notificationResponse.payload);
          break;
        case NotificationResponseType.selectedNotificationAction:
          if (notificationResponse.actionId == navigationActionId) {
            selectNotificationStream.add(notificationResponse.payload);
          }
          break;
      }
    },
  );

}


List<double> lastGyroscopeData = [
  0,
  0,
  0
]; // Assuming gyroscope data is a List of 3 values (x, y, z)
double threshold = 3; // Set your threshold value
String apiEndpoint = ""; // Set your API endpoint URL
List<double>? _accelerometerValues;
List<double>? _gyroscopeValues;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  Future<String> _nameSaver(String api) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('api', api);
    return 'saved';
  }

  _nameRetriever() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    apiEndpoint = prefs.getString('api') ?? '';
  }

  void _showAlertDialog(String msg) {
    _showNotificationCustomVibrationIconLed();
    lastGyroscopeData = _gyroscopeValues!;
    lastApiCallTime = DateTime.now();
    _status = "UNSAFE";
    _isDanger=true;
    _isMute=false;
    _isSafe=false;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Text('ALERT'),
              Icon(Icons.warning_rounded,color: Colors.red,size: 30,)
            ],
          ),
          content: const Text("PLEASE DRIVE SLOW \nOTHERWISE YOU WILL BE IN TROUBLE",style: TextStyle(fontWeight: FontWeight.bold),),
          actions: [
            TextButton(
              onPressed: () {
                _status = "MUTED";
                _isMute =true;
                _isSafe = false;
                _isDanger=false;
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('MUTE'),
            ),
          ],
        );
      },
    );
  }

  void _showEditAPI() {
    final myController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Text('MODIFY API')
            ],
          ),
          content: TextField(
            controller: myController,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                apiEndpoint=myController.value.text;
                _nameSaver(myController.value.text); // Close the dialog
                Navigator.of(context).pop();
              },
              child: const Text('APPLY'),
            ),
          ],
        );
      },
    );
  }

  //Future<String> status="" as Future<String>;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  var _status = "SAFE";
  bool _isSafe = true;
  bool _isMute = false;
  bool _isDanger = false;

  @override
  Widget build(BuildContext context) {
    final prefs = SharedPreferences.getInstance();
    return Scaffold(
      backgroundColor: const Color(0xFFF1EFEF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191717),
        title: GestureDetector(
          onLongPress: (){
            _showEditAPI();
          },
          child: const Text('DRIVER ASSISTANT',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold
          ),),
        ),
        elevation: 4,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Card(
                    color: const Color(0xFF7D7C7C),
          // Customize card properties as needed:
                    elevation: 100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    margin: const EdgeInsets.all(40),
                    child: Padding(
                      padding: const EdgeInsets.all(70.0),
                      child: Column(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const Text('Status',style:
                              TextStyle(fontSize:30,fontWeight: FontWeight.bold,color: Colors.white),),
                                Visibility(
                                    visible: _isSafe,
                                    child: SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: Image.asset('assets/status.png',color: Colors.green,width: 50,))
                                ),
                                Visibility(
                                    visible: _isMute,
                                    child: const SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: Icon(Icons.volume_off_outlined,color: Colors.yellow,size: 100))
                                ),
                                Visibility(
                                    visible: _isDanger,
                                    child: const Icon(Icons.warning_amber,color: Colors.red,size: 100,)
                                ),

                                Container(height: 20,),
                                Card(
                                    elevation: 10,
                                    color: const Color(0xFFCCC8AA),
                                    child: Container(
                                        margin: const EdgeInsets.all(5.0),
                                        child: Text(_status,style: const TextStyle(fontSize:30,fontWeight: FontWeight.bold,color:  Color(0xFF191717),),))),
                            ],
                          )
                        ],
                      ),
                    )),

              ],
            ),
          ),


        ],
      ),
    );
  }

  @override
  void dispose() {
    didReceiveLocalNotificationStream.close();
    selectNotificationStream.close();
    super.dispose();

    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    _isAndroidPermissionGranted();
    _requestPermissions();
    _nameRetriever();

    _streamSubscriptions.add(
      accelerometerEvents.listen(
            (AccelerometerEvent event) {
          setState(() {
            _accelerometerValues = <double>[event.x, event.y, event.z];
          });
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support Gyroscope Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );
    _streamSubscriptions.add(
      gyroscopeEvents.listen(
            (GyroscopeEvent event) {
          setState(() {
            _gyroscopeValues = <double>[event.x, event.y, event.z];
            double difference = calculateDifference(lastGyroscopeData, _gyroscopeValues!);
            if (isDrasticChange(difference)) {
              final accelerometer =
              _accelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
              final gyroscope =
              _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
              final currentTime = DateTime.now();

              if (lastApiCallTime == null || currentTime.difference(lastApiCallTime!) >= const Duration(seconds: 2)) {
                callMLModel(double.parse(accelerometer![0]),
                  double.parse(accelerometer[1]),
                  double.parse(accelerometer[2]),
                  double.parse(gyroscope![0]),
                  double.parse(gyroscope[1]),
                  double.parse(gyroscope[2]),
                ).then((value) => _showAlertDialog(value));

              } else {
                print('Skipping API call. Too soon after the last one.');
              }
            }
          });
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support User Accelerometer Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );
  }

  Future<void> _isAndroidPermissionGranted() async {
    if (Platform.isAndroid) {
      final bool granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled() ??
          false;

      setState(() {
        _notificationsEnabled = granted;
      });
    }
  }
  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final bool? grantedNotificationPermission =
      await androidImplementation?.requestNotificationsPermission();
      setState(() {
        _notificationsEnabled = grantedNotificationPermission ?? false;
      });
    }
  }

  Future<void> _showNotificationCustomVibrationIconLed() async {
    final Int64List vibrationPattern = Int64List(4);
    vibrationPattern[0] = 1000;
    vibrationPattern[1] = 1000;
    vibrationPattern[2] = 5000;
    vibrationPattern[3] = 2000;

    final AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        'other custom channel id', 'other custom channel name',
        channelDescription: 'other custom channel description',
        largeIcon: const DrawableResourceAndroidBitmap('app_icon'),
        vibrationPattern: vibrationPattern,
        enableLights: true,
        sound: const RawResourceAndroidNotificationSound('sound'),
        color: const Color.fromARGB(255, 255, 0, 0),
        ledColor: const Color.fromARGB(255, 255, 0, 0),
        ledOnMs: 1000,
        ledOffMs: 500);

    final NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        1,
        'ALERT',
        'Please Drive Slow',
        notificationDetails);
  }
}

Future<String> callMLModel(double ax,double ay,double az,double gx,double gy,double gz) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  apiEndpoint = prefs.getString('api') ?? '';
  final response = await
    http.post(
      Uri.parse("$apiEndpoint/predict"),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, double>{

        "AccX": ax ?? 0,
        "AccY": ay ?? 0,
        "AccZ": az ?? 0,
        "GyroX": gx ?? 0,
        "GyroY": gy ?? 0,
        "GyroZ": gz ?? 0
      }),
    );
    print(jsonEncode(<String, double>{

      "AccX": ax ?? 0,
      "AccY": ay ?? 0,
      "AccZ": az ?? 0,
      "GyroX": gx ?? 0,
      "GyroY": gy ?? 0,
      "GyroZ": gz ?? 0
    }));


    if (response.statusCode==200) {

      // If the server did return a 201 CREATED response,
      // then parse the JSON.
      return response.body;
    } else {
      // If the server did not return a 201 CREATED response,
      // then throw an exception.
      throw Exception(response.body);
    }
  }


double calculateDifference(List<double> oldData, List<double> newData) {
  // Implement logic to calculate the difference based on your gyroscope data
  // For example, you can calculate the Euclidean distance between oldData and newData.
  // Similar logic can be applied to other sensor types.
  double sum = 0;
  for (int i = 0; i < oldData.length; i++) {
    sum += (oldData[i] - newData[i]) * (oldData[i] - newData[i]);
  }
  return sqrt(sum);
}

// Function to check if the difference exceeds the threshold
bool isDrasticChange(double difference) {
  return difference > threshold;
}
