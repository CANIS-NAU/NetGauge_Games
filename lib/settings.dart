// This page will hold information and FAQs pertaining to the project
// importing libraries, pages, and packages

import 'package:flutter/material.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';
import 'surveys.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'activity_logs.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'daily_reminder_service.dart';
import 'account_identity.dart';
import 'theme_controller.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _dailyReminderEnabled = DailyReminderService.isEnabled;

  Future<void> _toggleDailyReminder(bool value) async {
    setState(() => _dailyReminderEnabled = value);
    final enabled = await DailyReminderService.setEnabled(value);
    if (!mounted) return;
    setState(() => _dailyReminderEnabled = enabled);
    if (value && !enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications are blocked. Enable them for NetGauge in your device settings.')),
      );
    }
  }

  // Guests have no account to sign back in to, so leaving guest mode means losing access to their data.
  Future<void> _confirmAndLogout() async {
    if (!isGuest(FirebaseAuth.instance.currentUser)) {
      await logout();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave guest mode?'),
        content: const Text(
          "You're using the app as a guest. If you leave, you won't be able to get back to your guest data "
          '(your stats, favorites and measurements). Measurements you already shared stay on the public map.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true) await logout();
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      
      // Use pushAndRemoveUntil to clear the entire navigation stack
      // This prevents the user from using the back button to return to the app
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false, // Remove all previous routes
        );
      }
    } on FirebaseAuthException catch (e) {
      // Handle potential errors during sign out
      debugPrint('Error signing out: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    // final userData = Provider.of<UserDataProvider>(context); // Not currently used in build
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
              'Settings',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 25)
          ),
          backgroundColor: const Color(0xFF440154),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Column(
          children:[
            const SizedBox(height: 8),
           /* TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SurveyState(
                    surveyDocId: 'METUX',
                    responseCollection: 'survey_responses',
                  )),
                );
              },
              style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(
                      color: Colors.black, // Specify the border color
                      width: 3,           // Specify the border width
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  fixedSize: const Size(500, 25),
                  //backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                  )
              ),
              child: const Text("Take METUX Survey"),
              //TODO: Nice-to-have-->add a trailing expand icon here
            ),*/
            const SizedBox(height: 20),
            const CircleAvatar(
              backgroundColor: Colors.purple,
              radius: 60,
              child: Icon(
                Icons.person,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            // light or dark mode, remembered on this device
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                        ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                        ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                      ],
                      selected: {context.watch<ThemeController>().mode},
                      onSelectionChanged: (selection) => context.read<ThemeController>().setMode(selection.first),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              activeThumbColor: Colors.purple,
              title: const Text('Daily reminder'),
              subtitle: const Text('Get a notification once a day to check into the app'),
              value: _dailyReminderEnabled,
              onChanged: _toggleDailyReminder,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(20),
              ),
              onPressed: _confirmAndLogout,
              child: Text(isGuest(FirebaseAuth.instance.currentUser) ? 'Leave Guest Mode' : 'Logout',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20)),
            ),
          ],
        ),
        )
    );
  }
}

