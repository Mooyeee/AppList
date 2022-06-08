import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';

import './app_page.dart';

class AppsListScreen extends StatefulWidget {
  const AppsListScreen({Key? key}) : super(key: key);

  @override
  _AppsListScreenState createState() => _AppsListScreenState();
}

class _AppsListScreenState extends State<AppsListScreen> {
  bool _showSystemApps = false;
  bool _onlyLaunchableApps = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Proactive Modules',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              TextSpan(
                text: '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (BuildContext context) {
              return <PopupMenuItem<String>>[
                PopupMenuItem<String>(
                  value: 'system_apps',
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          _showSystemApps
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Show system apps'),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'launchable_apps',
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          _onlyLaunchableApps
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                        ),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Launchable apps only'),
                        ),
                      ),
                    ],
                  ),
                )
              ];
            },
            onSelected: (String key) {
              if (key == 'system_apps') {
                setState(() {
                  _showSystemApps = !_showSystemApps;
                });
              }
              if (key == 'launchable_apps') {
                setState(() {
                  _onlyLaunchableApps = !_onlyLaunchableApps;
                });
              }
            },
          )
        ],
      ),
      body: _AppsListScreenContent(
        includeSystemApps: _showSystemApps,
        onlyAppsWithLaunchIntent: _onlyLaunchableApps,
        key: GlobalKey(),
      ),
    );
  }
}

class _AppsListScreenContent extends StatelessWidget {
  final bool includeSystemApps;
  final bool onlyAppsWithLaunchIntent;

  const _AppsListScreenContent({
    Key? key,
    this.includeSystemApps = false,
    this.onlyAppsWithLaunchIntent = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Application>>(
      future: DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: includeSystemApps,
        onlyAppsWithLaunchIntent: onlyAppsWithLaunchIntent,
      ),
      builder: (BuildContext context, AsyncSnapshot<List<Application>> data) {
        if (data.data == null) {
          return const Center(child: CircularProgressIndicator());
        } else {
          List<Application> apps = data.data!;
          apps.removeWhere((element) =>
              element.packageName == 'com.example.proactivemodules');

          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                  child: Text(
                    'Select the application on which you want to activate one or more proactive module(s)',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (Application app in apps) ...{
                        if (!app.packageName.startsWith("com.proactive"))
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Card(
                              child: ListTile(
                                leading: app is ApplicationWithIcon
                                    ? Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Image(
                                          image: MemoryImage(app.icon),
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : null,
                                onTap: () async {
                                  List<Application> appz = await DeviceApps
                                      .getInstalledApplications();

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => AppPage(
                                          app: app,
                                          enforcers: appz
                                              .where((element) => element
                                                  .packageName
                                                  .startsWith("com.proactive"))
                                              .toList()),
                                    ),
                                  );
                                },
                                title: Text(app.appName),
                                subtitle: Text(
                                    '${app.packageName}\nVersion: ${app.versionName}'),
                              ),
                            ),
                          ),
                      },
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
