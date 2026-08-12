import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeModel(),
      child: const MyApp(),
    ),
  );
}

/// Stores and manages the app theme state.
class ThemeModel with ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

/// Builds the main app and applies the theme.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<ThemeModel>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'State Management Example',

      theme: themeModel.isDark
          ? ThemeData.dark()
          : ThemeData.light(),

      home: const CounterScreen(),
    );
  }
}

/// Displays the counter screen.
class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

/// Handles the counter value changes.
class _CounterScreenState extends State<CounterScreen> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  /// Builds the counter screen layout.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Counter Screen"),

        actions: [
          IconButton(
            icon: const Icon(
        Icons.brightness_4_rounded,
        size: 28,
      ),

            tooltip: "Theme Settings",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ThemeScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "You have pushed the button this many times:",
            ),

            // Displays the current counter value.
            Text(
              "$_counter",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: "Increment Counter",
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  /// Builds the theme settings screen.
  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<ThemeModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Theme Settings"),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
            Icons.brightness_4_rounded,
            size: 50,
          ),

            SizedBox(height: 20),

            const Text(
              "Toggle Light/Dark Theme",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 20),

            // Switch changes the shared theme state.
            Switch(
              value: themeModel.isDark,
              onChanged: (_) {
                themeModel.toggleTheme();
              },
            ),

            SizedBox(height: 20),

            // Displays the currently selected theme.
            Text(
              themeModel.isDark
                  ? "Dark Mode Enabled"
                  : "Light Mode Enabled",
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}