import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // Import package_info_plus
// You might also need SharedPreferences if you plan to add "don't show again" logic
// import 'package:shared_preferences/shared_preferences.dart';

class ShowUpdate {
  // The URL for your app on the Google Play Store
  final String _appStoreUrl =
      'https://play.google.com/store/apps/details?id=com.kotarokase.moneyTracker&pcampaignid=web_share';

  Future<void> checkUpdate(
      BuildContext context, // Pass BuildContext for showing dialog
      Function(String, String) onUpdateAvailableShowDialog) async {
    try {
      // 1. Get current app version dynamically
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentAppVersion = packageInfo.version;

      print("Current App Version (from package_info): $currentAppVersion");

      // 2. Get the newest version code from Firebase Firestore
      DocumentSnapshot newestVersionSnapshot = await FirebaseFirestore.instance
          .collection("update")
          .doc("version")
          .get();

      if (newestVersionSnapshot.exists && newestVersionSnapshot.data() != null) {
        String newestVersionCodeFromServer =
            (newestVersionSnapshot.data() as Map<String, dynamic>)['version']
                    ?.toString() ??
                "0.0.0";

        print(
            "Newest Version Code (from Firestore): $newestVersionCodeFromServer");

        // 3. Compare versions
        if (newestVersionCodeFromServer != currentAppVersion) {
          if (isVersionNewer(
              newestVersionCodeFromServer, currentAppVersion)) {
            print(
                "A new version $newestVersionCodeFromServer is available. Current version is $currentAppVersion. Please update.");
            // Call the callback function to notify the UI or trigger an update dialog
            onUpdateAvailableShowDialog(
                currentAppVersion, newestVersionCodeFromServer);
          } else {
            print(
                "Current app version $currentAppVersion is same or newer than server version $newestVersionCodeFromServer.");
          }
        } else {
          print("App is up to date. Current version: $currentAppVersion");
        }
      } else {
        print(
            "Error: 'version' document does not exist or has no data in Firestore.");
      }
    } catch (e) {
      print("Error checking for updates: $e");
    }
  }

  /// Compares two version strings.
  /// Returns true if serverVersion is newer than currentVersion.
  bool isVersionNewer(String serverVersion, String currentVersion) {
    List<int> serverParts = serverVersion
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    List<int> currentParts = currentVersion
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();

    int maxLength = serverParts.length > currentParts.length
        ? serverParts.length
        : currentParts.length;

    for (int i = 0; i < maxLength; i++) {
      int serverPart = i < serverParts.length ? serverParts[i] : 0;
      int currentPart = i < currentParts.length ? currentParts[i] : 0;

      if (serverPart > currentPart) {
        return true;
      }
      if (serverPart < currentPart) {
        return false;
      }
    }
    return false; // Versions are identical
  }

  // Method to launch the app store URL
  Future<void> launchAppStore() async {
    final Uri url = Uri.parse(_appStoreUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Log or show an error to the user if the URL can't be launched
      print('Could not launch $_appStoreUrl');
      // Optionally, show a SnackBar or another dialog to inform the user
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Could not open the app store link.')),
      // );
    }
  }
}

// Example of how you might call this from your UI (e.g., in initState of your main widget)