import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:device_apps/device_apps.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';

import './android_xml_decompress.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    Key? key,
    required this.app,
    required this.enforcers,
  }) : super(key: key);

  final Application app;
  final List<Application> enforcers;

  Future<String> readFile() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
    String path = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOCUMENTS);

    String file = "{}";
    bool exists = await File('$path/packages.json').exists();

    if (exists) {
      try {
        file = await File('$path/packages.json').readAsString();
      } catch (e) {
        print(e);
      }
    }

    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: app.appName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder(
          future: readFile(),
          builder: (context, snapshot) {
            return snapshot.connectionState == ConnectionState.done
                ? EnforcerList(
                    app: app,
                    enforcers: enforcers,
                    mapString: snapshot.data as String,
                  )
                : const Center(child: CircularProgressIndicator());
          }),
    );
  }
}

class EnforcerList extends StatefulWidget {
  const EnforcerList({
    Key? key,
    required this.app,
    required this.enforcers,
    required this.mapString,
  }) : super(key: key);

  final Application app;
  final List<Application> enforcers;
  final String mapString;

  @override
  _EnforcerListState createState() => _EnforcerListState();
}

class _EnforcerListState extends State<EnforcerList> {
  final RoundedLoadingButtonController _btnController =
      RoundedLoadingButtonController();
  Map<String, List<String>> enforcer2apps = {};

  @override
  void initState() {
    super.initState();
    Map<String, List<dynamic>> decoded =
        Map<String, List<dynamic>>.from(json.decode(widget.mapString));

    enforcer2apps =
        decoded.map((key, value) => MapEntry(key, List<String>.from(value)));
  }

  @override
  Widget build(BuildContext context) {
    print(enforcer2apps);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Text(
                  'Select which proactive module(s) you want to activate on this application',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyText1,
                ),
                ListTile(
                  leading: widget.app is ApplicationWithIcon
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image(
                            image: MemoryImage(
                                (widget.app as ApplicationWithIcon).icon),
                            fit: BoxFit.contain,
                          ),
                        )
                      : null,
                  title: Text(widget.app.packageName),
                  subtitle: Text('Version: ${widget.app.versionName}'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'PROACTIVE MODULES',
                        style: TextStyle(
                          letterSpacing: 5,
                          color: Colors.black26,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                for (Application enforcer in widget.enforcers) ...{
                  EnforcerCard(
                    enforcer: enforcer,
                    onTap: onTap,
                    checkMap: checkMap,
                    readXml: readXml,
                  ),
                },
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RoundedLoadingButton(
              elevation: 0,
              loaderSize: 20,
              child: const Text(
                'APPLY',
                style: TextStyle(
                  letterSpacing: 10,
                  color: Colors.white,
                ),
              ),
              color: Theme.of(context).buttonTheme.colorScheme?.background,
              height: 35,
              controller: _btnController,
              successColor:
                  Theme.of(context).buttonTheme.colorScheme?.background,
              onPressed: () async {
                _btnController.start();

                try {
                  String path =
                      await ExternalPath.getExternalStoragePublicDirectory(
                          ExternalPath.DIRECTORY_DOCUMENTS);

                  await File('$path/packages.json').writeAsString(
                    json.encode(enforcer2apps),
                  );
                } catch (e) {
                  _btnController.error();
                }

                _btnController.success();
                await Future.delayed(const Duration(seconds: 2), () {});
                _btnController.reset();
              },
            ),
          ),
        ],
      ),
    );
  }

  bool checkMap(enforcer) {
    if (enforcer2apps.containsKey(enforcer.packageName)) {
      return enforcer2apps[enforcer.packageName]!
          .contains(widget.app.packageName);
    } else {
      return false;
    }
  }

  void onTap(enforcer) {
    setState(() {
      if (enforcer2apps.containsKey(enforcer.packageName)) {
        if (enforcer2apps[enforcer.packageName]!
            .contains(widget.app.packageName)) {
          enforcer2apps[enforcer.packageName]!.remove(widget.app.packageName);
          if (enforcer2apps[enforcer.packageName]!.isEmpty) {
            enforcer2apps.remove(enforcer.packageName);
          }
        } else {
          enforcer2apps[enforcer.packageName]!.add(widget.app.packageName);
        }
      } else {
        enforcer2apps.putIfAbsent(
            enforcer.packageName, () => [widget.app.packageName]);
      }
    });
  }

  String readXml(Application enforcer) {
    var zipBytes = File(enforcer.apkFilePath).readAsBytesSync();
    Archive archive = ZipDecoder().decodeBytes(zipBytes);

    for (final file in archive) {
      if (file.isFile && file.name == 'AndroidManifest.xml') {
        final data = file.content;

        String decoded = AndroidXMLDecompress.decompressXML(data);

        String xposedDescription = decoded.substring(
            decoded.indexOf("<meta-data name=\"xposeddescription\" value=\"") +
                43);

        return xposedDescription.substring(0, xposedDescription.indexOf("\""));
      }
    }

    return "";
  }
}

class EnforcerCard extends StatefulWidget {
  const EnforcerCard({
    Key? key,
    required this.enforcer,
    required this.checkMap,
    required this.onTap,
    required this.readXml,
  }) : super(key: key);

  final Application enforcer;
  final Function checkMap;
  final Function onTap;
  final Function readXml;

  @override
  _EnforcerCardState createState() => _EnforcerCardState();
}

class _EnforcerCardState extends State<EnforcerCard> {
  String description = "";

  @override
  void initState() {
    super.initState();
    description = widget.readXml(widget.enforcer);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        child: ListTile(
          onTap: () => widget.onTap(widget.enforcer),
          leading: Icon(
            widget.checkMap(widget.enforcer)
                ? Icons.check_box
                : Icons.check_box_outline_blank,
          ),
          title: Text(widget.enforcer.appName),
          subtitle: Text(
              '${widget.enforcer.packageName}\nVersion: ${widget.enforcer.versionName}\nDescription: ' +
                  description),
        ),
      ),
    );
  }
}
