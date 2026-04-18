import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart'; 
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

/**
 * AI SRT EDITOR - CINEMATIC PRO EDITION
 * FIXED: MULTI-LANGUAGE TRANSLATION LOGIC
 * IMPROVED: DYNAMIC PROMPT BASED ON USER SELECTION
 */

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.blueAccent,
        cardTheme: CardThemeData(color: Colors.grey[900], elevation: 5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true, fillColor: Colors.black26),
      ),
      home: const SplashScreen(),
    );
  }
}

class SubtitleItem {
  String index, timestamp, original, translation;
  SubtitleItem({required this.index, required this.timestamp, required this.original, required this.translation});
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const HomeScreen()));
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const RainbowLiveText(text: "AI SRT EDITOR", fontSize: 40),
            const SizedBox(height: 15),
            const Text("CINEMATIC PRO EDITION", style: TextStyle(color: Colors.blueAccent, letterSpacing: 6, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _fileName = "NO FILE SELECTED", _savePath = "N/A", _displayUsername = "Syncing...", _expiryDateStr = "N/A";
  List<SubtitleItem> _subtitles = [];
  List<dynamic> _historyList = [];
  bool _isFileSelected = false, _isAuthorized = false;
  
  static const String _githubToken = String.fromEnvironment('GH_TOKEN');
  final String _apiBaseUrl = "https://api.github.com/repos/mratommr619-ui/titan-db/contents/users";
  final String _rawBaseUrl = "https://raw.githubusercontent.com/mratommr619-ui/titan-db/main/users";

  final TextEditingController _apiKeyController = TextEditingController();
  String _selectedAI = "Gemini";
  String _targetLanguage = "Burmese";

  final List<String> _aiProviders = ["Gemini", "OpenAI (GPT-4)", "DeepSeek", "Claude AI", "Groq", "Grok"];
  final List<String> _languages = ["Burmese", "English", "Thai", "Korean", "Japanese", "Chinese", "Hindi", "French", "Spanish", "German", "Russian", "Arabic", "Bengali", "Portuguese", "Urdu", "Indonesian", "Italian", "Turkish", "Vietnamese", "Tamil", "Telugu", "Marathi", "Punjabi", "Gujarati", "Malayalam", "Kannada", "Odia", "Malay", "Filipino", "Persian", "Pashto", "Kurdish", "Hebrew", "Greek", "Dutch", "Swedish", "Norwegian", "Danish", "Finnish", "Polish", "Hungarian", "Czech", "Slovak", "Romanian", "Bulgarian", "Ukrainian", "Lao", "Khmer", "Sinhala", "Mongolian"];

  @override
  void initState() { 
    super.initState(); 
    _init(); 
    _handleIncomingFile();
  }

  Future<void> _handleIncomingFile() async {
    const MethodChannel('com.mratom.aisrt/openfile').setMethodCallHandler((call) async {
      if (call.method == 'openFile') {
        String path = call.arguments;
        final content = await File(path).readAsString();
        _parseSRT(content, path.split('/').last);
      }
    });
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (Platform.isAndroid) {
      await [Permission.storage, Permission.manageExternalStorage].request();
    }
    String? savedPath = prefs.getString('custom_save_path');
    if (savedPath == null) {
      Directory? dir = Platform.isAndroid ? Directory("/storage/emulated/0/Download/EasySRT_Editor") : await getDownloadsDirectory();
      if (!await dir!.exists()) await dir.create(recursive: true);
      savedPath = dir.path;
    }
    String? cachedExp = prefs.getString('cached_expiry');
    String? cachedName = prefs.getString('cached_username');
    if (cachedExp != null) {
      DateTime expDate = DateTime.parse(cachedExp);
      setState(() {
        _isAuthorized = expDate.isAfter(DateTime.now());
        _displayUsername = cachedName ?? "User";
        _expiryDateStr = DateFormat('yyyy-MM-dd').format(expDate);
      });
    }
    setState(() {
      _savePath = savedPath!;
      _apiKeyController.text = prefs.getString('api_key') ?? "";
      _selectedAI = prefs.getString('selected_ai') ?? "Gemini";
      _targetLanguage = prefs.getString('target_lang') ?? "Burmese";
      _historyList = json.decode(prefs.getString('master_db_final') ?? "[]");
    });
    _syncAuth();
  }

  Future<void> _pickSavePath() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_save_path', result);
      setState(() => _savePath = result);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Save Path Updated!")));
    }
  }

  Future<void> _syncAuth() async {
    try {
      String id = "Unknown";
      if (Platform.isAndroid) id = await const AndroidId().getId() ?? "AndroidID";
      else if (Platform.isWindows) id = (await DeviceInfoPlugin().windowsInfo).deviceId;

      String shard = id.substring(0, 2).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '0');
      String shardRawUrl = "$_rawBaseUrl/$shard.json";
      String shardApiUrl = "$_apiBaseUrl/$shard.json";

      final rawRes = await http.get(Uri.parse(shardRawUrl)).timeout(const Duration(seconds: 10));
      if (rawRes.statusCode == 200) {
        var db = json.decode(rawRes.body);
        if (db['users'].containsKey(id)) {
          String expiry = db['users'][id]['expiry'];
          bool status = db['users'][id]['status'];
          DateTime expDate = DateTime.parse(expiry);

          if (expDate.isBefore(DateTime.now()) && status == true) {
             _updateServerStatusToFalse(id, shard, shardApiUrl);
          }
          
          _updateLocalAndUI(db['users'][id]['username'], expiry, db['users'][id]['status']);
          return;
        }
      }

      final apiRes = await http.get(Uri.parse(shardApiUrl), headers: {'Authorization': 'token $_githubToken'});
      Map<String, dynamic> shardDb = {"users": {}, "last_no": 0};
      String? sha;
      if (apiRes.statusCode == 200) {
        final data = json.decode(apiRes.body);
        sha = data['sha'];
        shardDb = json.decode(utf8.decode(base64.decode(data['content'].replaceAll('\n', ''))));
      }

      int nextNo = (shardDb['last_no'] ?? 0) + 1;
      String newUsername = "UA-${shard.toUpperCase()}${nextNo.toString().padLeft(4, '0')}";
      String expiry = DateTime.now().add(const Duration(days: 3)).toIso8601String();

      shardDb['users'][id] = {"username": newUsername, "status": true, "expiry": expiry};
      shardDb['last_no'] = nextNo;

      await http.put(Uri.parse(shardApiUrl), headers: {'Authorization': 'token $_githubToken'},
        body: jsonEncode({"message": "Reg $newUsername", "content": base64.encode(utf8.encode(jsonEncode(shardDb))), if (sha != null) "sha": sha}));
      
      _updateLocalAndUI(newUsername, expiry, true);
    } catch (e) { }
  }

  Future<void> _updateServerStatusToFalse(String id, String shard, String apiUrl) async {
    try {
      final res = await http.get(Uri.parse(apiUrl), headers: {'Authorization': 'token $_githubToken'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        Map<String, dynamic> db = json.decode(utf8.decode(base64.decode(data['content'].replaceAll('\n', ''))));
        db['users'][id]['status'] = false;
        await http.put(Uri.parse(apiUrl), headers: {'Authorization': 'token $_githubToken'},
          body: jsonEncode({"message": "Expired Auto-Disable", "content": base64.encode(utf8.encode(jsonEncode(db))), "sha": data['sha']}));
      }
    } catch (e) {}
  }

  void _updateLocalAndUI(String username, String expiry, bool status) async {
    final prefs = await SharedPreferences.getInstance();
    DateTime expDate = DateTime.parse(expiry);
    setState(() { 
      _displayUsername = username; 
      _expiryDateStr = DateFormat('yyyy-MM-dd').format(expDate); 
      _isAuthorized = expDate.isAfter(DateTime.now()) && status == true; 
    });
    await prefs.setString('cached_username', username); 
    await prefs.setString('cached_expiry', expiry);
  }

  // FIXED TRANSLATION PROMPT - DYNAMIC LANGUAGE SELECTION
  Future<String> _translateAI(String text) async {
    if (_apiKeyController.text.isEmpty) return "API Key Missing";
    String url = ""; Map<String, String> headers = {'Content-Type': 'application/json'}; Map<String, dynamic> body = {};
    
    // THE DYNAMIC MULTI-LANGUAGE TRANSLATOR PROMPT
    String prompt = "";
    if (_targetLanguage == "Burmese") {
      prompt = """
        Act as a professional Movie Subtitle Translator. 
        Translate the following English dialogue into natural, spoken Burmese (Colloquial style).

        STRICT RULES:
        1. USE SPOKEN BURMESE: Use ending particles like "တယ်", "နေတာ", "တာပေါ့", "လေ", "လား", "နော်".
        2. NO FORMAL BURMESE: Absolutely avoid "သည်", "သနည်း", "ပါ၏", "ပါသည်".
        3. CONTEXTUAL TONE: Maintain the original emotion (Angry, Sad, Sarcastic, or Friendly).
        4. OUTPUT ONLY TRANSLATED TEXT: Do not include English subtitles, notes, or explanations. 

        Dialogue: "$text" """;
    } else {
      prompt = """
        Act as a professional Movie Subtitle Translator. 
        Translate the following dialogue into natural, accurate $_targetLanguage.

        STRICT RULES:
        1. MAINTAIN CONTEXT: Ensure the tone matches the original movie dialogue.
        2. FLUENCY: The translation must sound natural to native speakers of $_targetLanguage.
        3. OUTPUT ONLY TRANSLATED TEXT: Do not include original text, notes, or explanations.

        Dialogue: "$text" """;
    }

    try {
      switch (_selectedAI) {
        case "Gemini":
          url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${_apiKeyController.text}";
          body = {"contents": [{"parts": [{"text": prompt}]}]};
          break;
        case "OpenAI (GPT-4)":
          url = "https://api.openai.com/v1/chat/completions";
          headers['Authorization'] = 'Bearer ${_apiKeyController.text}';
          body = {"model": "gpt-4o", "messages": [{"role": "user", "content": prompt}]};
          break;
        case "DeepSeek":
          url = "https://api.deepseek.com/chat/completions";
          headers['Authorization'] = 'Bearer ${_apiKeyController.text}';
          body = {"model": "deepseek-chat", "messages": [{"role": "user", "content": prompt}]};
          break;
        case "Claude AI":
          url = "https://api.anthropic.com/v1/messages";
          headers['x-api-key'] = _apiKeyController.text;
          headers['anthropic-version'] = '2023-06-01';
          body = {"model": "claude-3-5-sonnet-20240620", "max_tokens": 1024, "messages": [{"role": "user", "content": prompt}]};
          break;
        case "Groq":
          url = "https://api.groq.com/openai/v1/chat/completions";
          headers['Authorization'] = 'Bearer ${_apiKeyController.text}';
          body = {"model": "llama-3.3-70b-versatile", "messages": [{"role": "user", "content": prompt}]};
          break;
        case "Grok":
          url = "https://api.x.ai/v1/chat/completions";
          headers['Authorization'] = 'Bearer ${_apiKeyController.text}';
          body = {"model": "grok-2-latest", "messages": [{"role": "user", "content": prompt}]};
          break;
      }
      final res = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 25));
      final d = jsonDecode(res.body);
      if (res.statusCode == 200) {
        if (_selectedAI == "Gemini") return d['candidates'][0]['content']['parts'][0]['text'].trim();
        if (_selectedAI == "Claude AI") return d['content'][0]['text'].trim();
        return d['choices'][0]['message']['content'].trim();
      }
      return "Error: ${res.statusCode}";
    } catch (e) { return "AI Failed"; }
  }

  void _parseSRT(String content, String name) {
    _subtitles.clear();
    bool isVtt = name.toLowerCase().endsWith('.vtt') || content.startsWith('WEBVTT');
    String normalized = content.replaceAll('\r\n', '\n').trim();
    if (isVtt) normalized = normalized.replaceFirst('WEBVTT', '').trim();
    
    final segments = normalized.split(RegExp(r'\n\s*\n'));
    List<SubtitleItem> temp = [];
    
    for (var s in segments) {
      if (s.contains('-->')) {
        var lines = s.trim().split('\n');
        String index = "0", timestamp = "", text = "";
        if (lines[0].contains('-->')) { 
          timestamp = lines[0]; text = lines.sublist(1).join('\n'); 
        } else { 
          index = lines[0]; timestamp = lines[1]; text = lines.sublist(2).join('\n'); 
        }
        temp.add(SubtitleItem(index: index, timestamp: timestamp, original: text, translation: text));
      }
    }

    if (temp.isEmpty && name.toLowerCase().endsWith('.txt')) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("INVALID TXT FORMAT (SRT ONLY)"), backgroundColor: Colors.red));
       return;
    }

    setState(() {
      _subtitles = temp;
      _fileName = name; _isFileSelected = true;
    });
  }

  void _saveToHistory(String name, String content) async {
    final prefs = await SharedPreferences.getInstance();
    int idx = _historyList.indexWhere((item) => item['name'] == name);
    setState(() {
      if (idx != -1) _historyList[idx]['content'] = content;
      else _historyList.insert(0, {'name': name, 'content': content});
    });
    await prefs.setString('master_db_final', json.encode(_historyList));
  }

  void _openEditor(int index) {
    final transCtrl = TextEditingController(text: _subtitles[index].translation);
    final timeCtrl = TextEditingController(text: _subtitles[index].timestamp);
    
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) => AlertDialog(
      title: Text("Edit Line #${_subtitles[index].index}"),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: "Timestamp", labelStyle: TextStyle(color: Color(0xFF39FF14)))),
        const SizedBox(height: 10),
        Text(_subtitles[index].original, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const Divider(),
        TextField(controller: transCtrl, maxLines: 5, decoration: const InputDecoration(filled: true)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () async {
          setDS(() => transCtrl.text = "AI Thinking...");
          String result = await _translateAI(_subtitles[index].original);
          setDS(() => transCtrl.text = result);
        }, icon: const Icon(Icons.auto_awesome), label: Text("USE $_selectedAI")))
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
        ElevatedButton(onPressed: () {
          setState(() {
            _subtitles[index].translation = transCtrl.text;
            _subtitles[index].timestamp = timeCtrl.text;
            _saveToHistory(_fileName, _subtitles.map((s) => "${s.index}\n${s.timestamp}\n${s.translation}\n\n").join().trim());
          });
          Navigator.pop(ctx);
        }, child: const Text("SAVE"))
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    bool isExpired = !_isAuthorized;
    return Scaffold(
      appBar: AppBar(title: const RainbowLiveText(text: "AI SRT EDITOR"), actions: [
        IconButton(icon: const Icon(Icons.history), onPressed: () => showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (c) => StatefulBuilder(builder: (c, setSheetState) => Column(children: [
          const Padding(padding: EdgeInsets.all(15), child: Text("RECENT PROJECTS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))),
          const Divider(),
          Expanded(child: ListView.builder(itemCount: _historyList.length, itemBuilder: (c, i) => ListTile(
            leading: const Icon(Icons.history, color: Colors.blueAccent),
            title: Text(_historyList[i]['name'], maxLines: 1),
            onTap: () { _parseSRT(_historyList[i]['content'], _historyList[i]['name']); Navigator.pop(context); },
            trailing: IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () async {
                setState(() => _historyList.removeAt(i));
                setSheetState(() {});
                (await SharedPreferences.getInstance()).setString('master_db_final', json.encode(_historyList));
            }),
          )))
        ]))))
      ]),
      drawer: Drawer(backgroundColor: Colors.black, child: ListView(children: [
        DrawerHeader(child: Column(children: [
          const RainbowLiveText(text: "MR. ATOM", fontSize: 35),
          Text("ID: $_displayUsername", style: const TextStyle(color: Colors.blueAccent)),
          Text("EXP: $_expiryDateStr", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isExpired ? Colors.red : Colors.green)),
        ])),
        Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          DropdownButtonFormField<String>(
            value: _selectedAI,
            decoration: const InputDecoration(labelText: "AI PROVIDER"),
            items: _aiProviders.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) async {
          setState(() {
            _selectedAI = v!;
          });
    
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selected_ai', v!);
            },
          ),
          const SizedBox(height: 15),
          TextField(controller: _apiKeyController, decoration: const InputDecoration(labelText: "API KEY"), onChanged: (v) async => (await SharedPreferences.getInstance()).setString('api_key', v)),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(value: _targetLanguage, decoration: const InputDecoration(labelText: "LANGUAGE"), items: _languages.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) async {
            setState(() => _targetLanguage = v!);
            (await SharedPreferences.getInstance()).setString('target_lang', v!);
          }),
          const Divider(height: 40),
          ListTile(onTap: _pickSavePath, leading: const Icon(Icons.folder_shared, color: Colors.blueAccent), title: const Text("Output Folder"), subtitle: Text(_savePath, style: const TextStyle(fontSize: 9))),
          ListTile(leading: const Icon(Icons.telegram, color: Colors.blue), title: const Text("Get Support"), onTap: () => launchUrl(Uri.parse("https://t.me/mratom_619"))),
        ]))
      ])),
      body: Column(children: [
        InkWell(onTap: () async {
          FilePickerResult? r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'vtt', 'txt']);
          if (r != null) {
            final content = await File(r.files.single.path!).readAsString();
            _parseSRT(content, r.files.single.name);
            _saveToHistory(r.files.single.name, content);
          }
        }, child: Container(margin: const EdgeInsets.all(15), height: 70, decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent, width: 2), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(_fileName, style: const TextStyle(fontWeight: FontWeight.bold))))),
        Expanded(child: ListView.builder(itemCount: _subtitles.length, itemBuilder: (c, i) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
          child: ListTile(
            onTap: () => _openEditor(i), 
            title: Text(_subtitles[i].timestamp, style: const TextStyle(color: Color(0xFF39FF14), fontSize: 12, fontWeight: FontWeight.bold)), 
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Text(_subtitles[i].original, style: const TextStyle(fontSize: 11, color: Colors.grey)),
               Text(_subtitles[i].translation, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ]),
          )
        ))),
      ]),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: Colors.blueAccent, icon: const Icon(Icons.save_alt), label: const Text("EXPORT FILE"), onPressed: () async {
        if (!_isAuthorized) {
          showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
            title: const Text("ACCESS EXPIRED", style: TextStyle(color: Colors.red)),
            content: const Text("Please contact support to renew your access."),
            actions: [
              TextButton(onPressed: () => launchUrl(Uri.parse("https://t.me/mratom_619")), child: const Text("CONTACT")),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
            ],
          ));
          return;
        }
        if (!_isFileSelected) return;
        String exportFormat = "SRT";
        showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) => AlertDialog(
          title: const Text("SAVE PROJECT"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Select export format:"),
            DropdownButton<String>(
              isExpanded: true, value: exportFormat,
              items: ["SRT", "VTT", "TXT"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setDS(() => exportFormat = v!),
            )
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
            ElevatedButton(onPressed: () async {
              Navigator.pop(ctx);
              await _executeExport(exportFormat);
            }, child: const Text("EXPORT"))
          ],
        )));
      }),
    );
  }

  Future<void> _executeExport(String format) async {
    try {
      String content = "", ext = format.toLowerCase();
      if (format == "VTT") {
        content = "WEBVTT\n\n" + _subtitles.map((s) => "${s.timestamp}\n${s.translation}\n\n").join().trim();
      } else {
        content = _subtitles.map((s) => "${s.index}\n${s.timestamp}\n${s.translation}\n\n").join().trim();
      }
      final f = File("$_savePath/${_fileName.split('.').first}_PRO.$ext");
      await f.writeAsString(content);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("SAVED AS $format SUCCESSFULLY!"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("EXPORT ERROR!"), backgroundColor: Colors.red));
    }
  }
}

class RainbowLiveText extends StatefulWidget {
  final String text; final double fontSize;
  const RainbowLiveText({super.key, required this.text, this.fontSize = 24});
  @override State<RainbowLiveText> createState() => _RainbowLiveTextState();
}
class _RainbowLiveTextState extends State<RainbowLiveText> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (context, child) => ShaderMask(shaderCallback: (b) => LinearGradient(colors: const [Colors.blue, Colors.purple, Colors.orange, Colors.red, Colors.blue], transform: GradientRotation(_c.value * 6.28)).createShader(b), child: Text(widget.text, style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.bold, color: Colors.white))));
  }
}