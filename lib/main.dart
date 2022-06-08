import 'package:flutter/material.dart';

import './apps_list.dart';

void main() => runApp(
      MaterialApp(
        home: const AppList(),
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          /* light theme settings */
        ),
        darkTheme: _darkTheme.copyWith(
          colorScheme: _darkTheme.colorScheme.copyWith(secondary: Colors.white),
        ),
      ),
    );

class AppList extends StatelessWidget {
  const AppList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AppsListScreen();
  }
}

final _darkTheme = ThemeData(
  brightness: Brightness.dark,
  primarySwatch: Colors.grey,
  primaryColor: Colors.black,
  backgroundColor: Colors.black38,
  dividerColor: Colors.black26,
);
