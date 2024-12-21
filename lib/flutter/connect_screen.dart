import 'dart:ui';

import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'package:wordgame/state.dart';

class ConnectScreen extends StatefulWidget {
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final TextEditingController roomController = TextEditingController();
  final usernameController = TextEditingController();
  final scrollTipVideoController = ScrollController();
  final scrollTipCaptionController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaffoldColor = HSLColor.fromColor(theme.primaryColor).withSaturation(.5).withLightness(.9).toColor();

    var appState = context.watch<WordGameState>();
    final roomID = Uri.base.queryParameters['room'];
    if (roomID != null) {
      roomController.value = TextEditingValue(text: roomID.toUpperCase());
    }
    SharedPreferences.getInstance().then((prefs) => usernameController.value = TextEditingValue(text: prefs.getString('username') ?? ''));
    final tipControllers = TipVideoAndCaption.TIPS.map((e) {
      final controller = VideoPlayerController.asset(e.path);
      controller.setVolume(0);
      controller.setLooping(true);
      controller.initialize();
      return controller;
    }).toList();
    tipControllers.first.play();
    final tipPlayers = tipControllers.map((e) => SizedBox(width: 600, height: 400, child: VideoPlayer(e))).toList();

    join() async {
      if (roomController.text.isNotEmpty && roomController.text.length <= 16 && usernameController.text.isNotEmpty && usernameController.text.length <= 16) {
        SharedPreferences.getInstance().then((prefs) => prefs.setString('username', usernameController.text));
        await appState.connect(roomController.text, usernameController.text);
      }
    }
    ValueNotifier<int> tipIndex = ValueNotifier(0);
    final dotsIndicator = ValueListenableBuilder(
      valueListenable: tipIndex,
      builder: (BuildContext context, int val, Widget? child) {
        return DotsIndicator(dotsCount: tipControllers.length, position: val, decorator: DotsDecorator(color: Colors.white),);
    });
    scrollTip(int indexDelta) {
      tipControllers[tipIndex.value].pause();
      tipIndex.value = (tipIndex.value + indexDelta) % tipControllers.length;
      tipControllers[tipIndex.value].seekTo(Duration.zero);
      tipControllers[tipIndex.value].play();
      scrollTipVideoController.animateTo(tipIndex.value * 600, duration: Durations.medium1, curve: Curves.easeInOut);
      scrollTipCaptionController.animateTo(tipIndex.value * 600, duration: Durations.medium1, curve: Curves.easeInOut);
    }

    buildCounter(context, {required currentLength, required isFocused, required maxLength}) {
      if (currentLength < maxLength) return SizedBox(height: 1);
      return SizedBox(height: 1, child: OverflowBox(maxHeight: 200, alignment: Alignment.bottomRight, child: Stack(clipBehavior: Clip.none, children: [Positioned(top: 195, right: 0, child: Text('$currentLength/$maxLength', style: theme.textTheme.labelSmall))])));
    }

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: Center(
        child: SizedBox(
          width: 800,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 400,
                child: Stack(
                  children: [
                    Image.asset('images/logo_shadow.png', alignment: Alignment.bottomCenter, opacity: AlwaysStoppedAnimation(0.5)),
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 5.0,
                        sigmaY: 5.0,
                      ),
                      child: Image.asset(
                        'images/logo.png',
                      ),
                    )
                  ],
                )),
              SizedBox(height: 48),
              SizedBox(
                width: 600,
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(150, 16, 150, 16),
                    child: Column(
                      children: [
                        Text('Room ID:', style: theme.textTheme.titleMedium),
                        TextField(controller: roomController, maxLength: 16, buildCounter: buildCounter, textAlign: TextAlign.center, inputFormatters: [UpperCaseTextFormatter()], autofocus: roomID == null),
                        SizedBox(height: 16),
                        Text('Username:', style: theme.textTheme.titleMedium),
                        TextField(controller: usernameController, maxLength: 16, buildCounter: buildCounter, textAlign: TextAlign.center, onSubmitted: (String _) async {await join();}, autofocus: roomID != null),
                        SizedBox(height: 16),
                        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor), onPressed: join, child: Text('Join', style: theme.textTheme.labelLarge!.copyWith(color: Colors.white, fontFamily: 'Katahdin Round'))),
                      ]
              )))),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    child: Center(child: IconButton.filled(padding: EdgeInsets.all(0), iconSize: 32, onPressed: () => scrollTip(-1), icon: const Icon(Icons.arrow_left_rounded)))
                  ),
                  Card(
                    color: scaffoldColor,
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 600,
                      height: 450,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: NeverScrollableScrollPhysics(),
                        controller: scrollTipVideoController,
                        children: tipPlayers
                  ))),
                  SizedBox(
                    width: 80,
                    child: Center(child: IconButton.filled(padding: EdgeInsets.all(0), iconSize: 32, onPressed: () => scrollTip(1), icon: const Icon(Icons.arrow_right_rounded)))
                  ),
                ]
              ),
              dotsIndicator,
              SizedBox(
                width: 600,
                height: 100,
                child: ShaderMask(shaderCallback: (Rect rect) =>
                  LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                    stops: [0, .2, .8, 1]
                  ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: NeverScrollableScrollPhysics(),
                  controller: scrollTipCaptionController,
                  children: TipVideoAndCaption.TIPS.map((e) => SizedBox(
                    width: 600,
                    height: 100,
                    child: Center(child: SizedBox(
                      width: 400,
                      height: 100,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Center(child: Text(e.caption, textAlign: TextAlign.center)))))))).toList()
                ))),
            ],
          ))));
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class TipVideoAndCaption {
  final String path, caption;

  TipVideoAndCaption(String name, this.caption) : path = 'tips/$name.mp4';

  static final List<TipVideoAndCaption> TIPS = [
    TipVideoAndCaption('tip1', 'Type to place tiles.\nPress Enter to play them.'),
    TipVideoAndCaption('tip2', 'Arrow keys move your cursor, Tab switches direction. Play next to your teammates!'),
    TipVideoAndCaption('tip3', 'The more colorful a word is,\nthe more it\'s worth!'),
    TipVideoAndCaption('tip4', 'Form loops to surround\ntiles and earn points!'),
    TipVideoAndCaption('tip5', 'Form rectangular chunks\nto earn even more points!'),
  ];
}