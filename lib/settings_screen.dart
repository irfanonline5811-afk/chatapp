import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _isNotificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettingsData();
  }

  // Settings ka save hua data load karne ke liye
  _loadSettingsData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _isNotificationEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  // Dark mode toggling handler
  _toggleDarkMode(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = value;
    });
    await prefs.setBool('dark_mode', value);
  }

  // Notification toggling handler
  _toggleNotifications(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationEnabled = value;
    });
    await prefs.setBool('notifications_enabled', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 1. Account Settings Group
          const SettingHeader(title: 'Account & Security'),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.teal),
                  title: const Text('Privacy & Blocked'),
                  subtitle: const Text('Manage your visibility and blocked users'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    // Privacy page ka route yahan aayega
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                ListTile(
                  leading: const Icon(Icons.security_outlined, color: Colors.teal),
                  title: const Text('Account Security'),
                  subtitle: const Text('Two-step verification & recovery settings'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    // Security page ka route yahan aayega
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // 2. App Preferences Group
          const SettingHeader(title: 'Preferences'),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                // Dark Mode Switch
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined, color: Colors.teal),
                  title: const Text('Dark Theme'),
                  subtitle: const Text('Enable dark appearance across app'),
                  value: _isDarkMode,
                  activeColor: Colors.teal,
                  onChanged: _toggleDarkMode,
                ),
                const Divider(height: 1, thickness: 0.5),
                // Notification Switch
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined, color: Colors.teal),
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Get alerts for new messages & updates'),
                  value: _isNotificationEnabled,
                  activeColor: Colors.teal,
                  onChanged: _toggleNotifications,
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // 3. About Section
          const SettingHeader(title: 'About'),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: const ListTile(
              leading: Icon(Icons.info_outline, color: Colors.teal),
              title: Text('App Version'),
              trailing: Text('1.0.0', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// Subheadings ke liye Custom Helper Widget
class SettingHeader extends StatelessWidget {
  final String title;
  const SettingHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.teal,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}