import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:async/async.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class fallDetection extends StatefulWidget {
  @override
  _fallDetectionState createState() => _fallDetectionState();
}

class _fallDetectionState extends State<fallDetection> {
  late Stream<List<dynamic>> _sensorStream;
  double _accelerometerValue = 0;
  double _previousAccelerometerValue = 100;
  double _magnetometerValue = 0;
  double _previousMagnetometerValue = 100;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _sensorStream =
        StreamZip([accelerometerEventStream(), magnetometerEventStream()]);
    _enableBackgroundExecution();
  }

  void _enableBackgroundExecution() async {
    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "Deteksi Jatuh",
      notificationText: "Sedang berjalan...",
      notificationImportance: AndroidNotificationImportance.Default,
      // notificationIcon:'background_icon', // Nama file gambar dalam folder aset Anda
    );

    await FlutterBackground.initialize(androidConfig: androidConfig);
    bool success = await FlutterBackground.enableBackgroundExecution();
    if (success) {
      print("Background execution enabled");
    } else {
      print("Background execution could NOT be enabled");
    }
  }

  void _disableBackgroundExecution() async {
    bool success = await FlutterBackground.disableBackgroundExecution();
    if (success) {
      print("Background execution disabled");
    } else {
      print("Background execution could NOT be disabled");
    }
  }

  void sendEmail(String latitude, String longitude) async {
    String username = 'kurniawanindrajaya20001@outlook.com';
    String password = 'Indra123123!#';

    final smtpServer = SmtpServer('smtp-mail.outlook.com',
        port: 587,
        username: username,
        password: password,
        ssl: false,
        ignoreBadCertificate: true);

    final message = Message()
      ..from = Address(username, 'Fall Detection')
      ..recipients.add('kurniawanindrajaya20002@gmail.com')
      ..recipients.add('kustiasih65@gmail.com')
      ..recipients.add('agungbudiarso93@gmail.com')
      ..subject = 'Pesan Otomatis - Terdeteksi jatuh untuk Kurniawan Indra Jaya'
      ..text =
          'Pesan Penting: Terdeteksi jatuh pada Kurniawan Indra Jaya dengan lokasi dengan koordinat berikut:\nLatitude: $latitude dan Longitude: $longitude. Mohon segera periksa kondisi terkini.\nPesan ini dikirm dari Secara Otomatis (Fall Detection)';

    try {
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } on MailerException catch (e) {
      print('Message not sent. \n' + e.toString());
    }
  }

  void getGPSDataAndSendEmail() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Layanan lokasi dinonaktifkan.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Izin lokasi ditolak');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Izin lokasi ditolak selamanya, kami tidak dapat meminta izin.');
    }

    Position position = await Geolocator.getCurrentPosition();
    sendEmail(position.latitude.toString(), position.longitude.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          StreamBuilder<List<dynamic>>(
            stream: _sensorStream,
            builder:
                (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
              if (_isStreaming) {
                if (snapshot.hasData) {
                  AccelerometerEvent accEvent = snapshot.data![0];
                  MagnetometerEvent magEvent = snapshot.data![1];

                  _previousAccelerometerValue = _accelerometerValue;
                  _accelerometerValue = accEvent.x + accEvent.y + accEvent.z;

                  _previousMagnetometerValue = _magnetometerValue;
                  _magnetometerValue = magEvent.x + magEvent.y + magEvent.z;

                  Future.delayed(Duration(seconds: 1), () {
                    if ((_accelerometerValue - _previousAccelerometerValue)
                                .abs() >
                            6 &&
                        (_magnetometerValue - _previousMagnetometerValue)
                                .abs() >
                            3) {
                      // deteksi jatuh
                      getGPSDataAndSendEmail();
                      return Text('Deteksi Jatuh!');
                    }
                  });
                }
                return Text(
                    'Akselerometer:$_accelerometerValue,Magnetometer:$_magnetometerValue');
              } else {
                return Text('Aplikasi tidak aktif');
              }
            },
          ),
          ElevatedButton(
            onPressed: () async {
              if (_isStreaming) {
                _disableBackgroundExecution();
                setState(() {
                  _sensorStream = Stream.empty();
                });
              } else {
                _enableBackgroundExecution();
                setState(() {
                  _sensorStream = StreamZip(
                      [accelerometerEventStream(), magnetometerEventStream()]);
                });
              }
              _isStreaming = !_isStreaming;
            },
            child: Text('Cek Deteksi Jatuh'),
          ),
        ],
      ),
    );
  }
}
