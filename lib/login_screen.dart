// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_package_poc/health_data_screen.dart';
import 'package:health_package_poc/utils.dart';
import 'package:permission_handler/permission_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const types = dataTypesAndroid;

  final permissions = types.map((e) => HealthDataAccess.READ_WRITE).toList();
  HealthFactory health = HealthFactory(useHealthConnectIfAvailable: true);

  Future authorize() async {
    // If we are trying to read Step Count, Workout, Sleep or other data that requires
    // the ACTIVITY_RECOGNITION permission, we need to request the permission first.
    // This requires a special request authorization call.
    //
    // The location permission is requested for Workouts using the Distance information.
    await Permission.activityRecognition.request();
    await Permission.location.request();

    // Check if we have permission
    bool? hasPermissions =
        await health.hasPermissions(types, permissions: permissions);

    // hasPermissions = false because the hasPermission cannot disclose if WRITE access exists.
    // Hence, we have to request with WRITE as well.
    hasPermissions = false;

    bool authorized = false;
    if (!hasPermissions) {
      // requesting access to the data types before reading them
      try {
        authorized =
            await health.requestAuthorization(types, permissions: permissions);
        if (authorized) {
          if (context.mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return const HealthDataScreen();
              },
            ));
          }
        }
        
      } catch (error) {
        print("Exception in authorize: $error");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 200,
          child: ElevatedButton(
              onPressed: authorize,
              child: const Text(
                "Login",
                style: TextStyle(
                  fontSize: 16.0,
                ),
              )),
        ),
      ),
    );
  }
}
