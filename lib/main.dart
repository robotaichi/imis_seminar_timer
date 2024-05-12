import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TimerPage(),
    );
  }
}

class TimerPage extends StatefulWidget {
  @override
  _TimerPageState createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  Duration duration = Duration();
  Timer? timer;
  List<int> initialAlarmTimes = [9 * 60, 12 * 60, 21 * 60]; // 初期設定値
  List<int> alarmTimes = [];
  List<TextEditingController> controllers = [];
  List<bool> isAlarmEnabled = [true, true, true]; // 初期値: すべて有効
  int alarmIndex = 0;
  AudioPlayer audioPlayer = AudioPlayer();
  Color backgroundColor = Colors.black; // 初期の背景色
  bool isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    Wakelock.enable();
    alarmTimes = List.from(initialAlarmTimes); // 初期値でリストを初期化
    for (int time in alarmTimes) {
      controllers.add(TextEditingController(text: (time ~/ 60).toString()));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    audioPlayer.dispose();
    Wakelock.disable();
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void startTimer() {
    Vibration.vibrate();
    if (!isTimerRunning) {
      timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          duration = Duration(seconds: duration.inSeconds + 1);
          checkAlarms();
        });
      });
      isTimerRunning = true;
    }
  }

  void stopTimer() {
    Vibration.vibrate();
    if (timer != null) {
      timer!.cancel();
      isTimerRunning = false;
    }
  }

  void resetTimer() {
    Vibration.vibrate();
    stopTimer();
    setState(() {
      duration = Duration(seconds: 0);
      alarmIndex = 0;
      alarmTimes = List.from(initialAlarmTimes); // 初期値でリセット
      for (int i = 0; i < controllers.length; i++) {
        controllers[i].text = (alarmTimes[i] ~/ 60).toString();
      }
    });
  }

  void checkAlarms() {
    while (alarmIndex < alarmTimes.length &&
        duration.inSeconds >= alarmTimes[alarmIndex]) {
      if (isAlarmEnabled[alarmIndex]) {
        playAlarm(alarmIndex + 1);
        flashScreen();
      }
      alarmIndex++;
    }
  }

  Future<void> playAlarm(int times) async {
    if (times == 1) {
      await audioPlayer.play(AssetSource("table-top-bell1.mp3"));
    } else if (times == 2) {
      await audioPlayer.play(AssetSource("table-top-bell2.mp3"));
    } else if (times == 3) {
      await audioPlayer.play(AssetSource("table-top-bell3.mp3"));
    }
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate();
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void flashScreen() {
    int flashCount = 0;
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        backgroundColor =
            backgroundColor == Colors.yellow ? Colors.black : Colors.yellow;
      });
      if (++flashCount >= 6) {
        timer.cancel();
      }
    });
  }

  String formatDuration(Duration d) {
    return d.toString().split('.').first.padLeft(8, "0");
  }

  String nextAlarmIn() {
    if (alarmIndex < alarmTimes.length) {
      int nextAlarmSeconds = alarmTimes[alarmIndex] - duration.inSeconds;
      return formatDuration(Duration(seconds: nextAlarmSeconds));
    }
    return "No more alarms";
  }

  void updateAlarms(int index, String value) {
    int? newTime = int.tryParse(value);
    if (newTime != null) {
      setState(() {
        alarmTimes[index] = newTime * 60;
        alarmTimes.sort();
        alarmIndex = alarmTimes.indexWhere((time) => time > duration.inSeconds);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double fontSizeBig = isLandscape ? screenHeight * 0.2 : screenWidth * 0.2;
    double fontSizeSmall =
        isLandscape ? screenHeight * 0.05 : screenWidth * 0.1;

    return Scaffold(
      appBar: AppBar(
        title:
            Text('IMIS Seminar Timer', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      body: AnimatedContainer(
        duration: Duration(milliseconds: 500),
        color: backgroundColor,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(formatDuration(duration),
                    style:
                        TextStyle(fontSize: fontSizeBig, color: Colors.white)),
                SizedBox(height: 30),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Next Alarm in: ${nextAlarmIn()}',
                      style: TextStyle(
                          fontSize: fontSizeSmall, color: Colors.white)),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: controllers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: <Widget>[
                          Checkbox(
                            value: isAlarmEnabled[index],
                            onChanged: (bool? value) {
                              setState(() {
                                isAlarmEnabled[index] = value ?? true;
                              });
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: controllers[index],
                              decoration: InputDecoration(
                                labelText: 'Alarm ${index + 1} time (minutes)',
                                labelStyle: TextStyle(color: Colors.white),
                              ),
                              style: TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => updateAlarms(index, value),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => playAlarm(index + 1),
                            child: Text('🔊'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: startTimer,
                      child:
                          Text('Start', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        fixedSize: Size(screenWidth / 3.5, 60),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: stopTimer,
                      child:
                          Text('Stop', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        fixedSize: Size(screenWidth / 3.5, 60),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: resetTimer,
                      child:
                          Text('Reset', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        fixedSize: Size(screenWidth / 3.5, 60),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
