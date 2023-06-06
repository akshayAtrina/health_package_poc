// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_package_poc/utils.dart';
import 'package:intl/intl.dart';

class HealthDataScreen extends StatefulWidget {
  const HealthDataScreen({super.key});

  @override
  State<HealthDataScreen> createState() => _HealthDataScreenState();
}

enum AppState {
  DATA_NOT_FETCHED,
  FETCHING_DATA,
  DATA_READY,
  NO_DATA,
  AUTHORIZED,
  AUTH_NOT_GRANTED,
  DATA_ADDED,
  DATA_DELETED,
  DATA_NOT_ADDED,
  DATA_NOT_DELETED,
  STEPS_READY,
}

class _HealthDataScreenState extends State<HealthDataScreen> {
  List<HealthDataPoint> _healthDataList = [];
  AppState _state = AppState.DATA_NOT_FETCHED;
  int _nofSteps = 0;

  // Define the types to get.
  // NOTE: These are only the ones supported on Androids new API Health Connect.
  // Both Android's Google Fit and iOS' HealthKit have more types that we support in the enum list [HealthDataType]
  // Add more - like AUDIOGRAM, HEADACHE_SEVERE etc. to try them.
  static const types = dataTypesAndroid;

  // with coresponsing permissions
  // READ only
  // final permissions = types.map((e) => HealthDataAccess.READ).toList();
  // Or READ and WRITE

  // create a HealthFactory for use in the app
  HealthFactory health = HealthFactory(useHealthConnectIfAvailable: true);

  @override
  void initState() {
    fetchData();
    fetchStepData();
    super.initState();
  }

  /// Fetch data points from the health plugin and show them in the app.
  Future fetchData() async {
    setState(() => _state = AppState.FETCHING_DATA);

    // get data within the last 24 hours
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));

    // Clear old data points
    _healthDataList.clear();

    try {
      // fetch health data
      List<HealthDataPoint> healthData =
          await health.getHealthDataFromTypes(yesterday, now, types);
      // save all the new data points (only the first 100)
      _healthDataList.addAll(
          (healthData.length < 100) ? healthData : healthData.sublist(0, 100));
    } catch (error) {
      print("Exception in getHealthDataFromTypes: $error");
    }

    // filter out duplicates
    _healthDataList = HealthFactory.removeDuplicates(_healthDataList);

    // print the results
    _healthDataList.forEach((x) => print(x));

    // update the UI to display the results
    setState(() {
      _state = _healthDataList.isEmpty ? AppState.NO_DATA : AppState.DATA_READY;
    });
  }

  /// Add some random health data.
  Future addData() async {
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(minutes: 20));
    // Add data for supported types
    // NOTE: These are only the ones supported on Androids new API Health Connect.
    // Both Android's Google Fit and iOS' HealthKit have more types that we support in the enum list [HealthDataType]
    // Add more - like AUDIOGRAM, HEADACHE_SEVERE etc. to try them.
    bool success = true;
    success &= await health.writeHealthData(
        10, HealthDataType.BODY_FAT_PERCENTAGE, earlier, now);
    success &= await health.writeHealthData(
        1.925, HealthDataType.HEIGHT, earlier, now);
    success &=
        await health.writeHealthData(90, HealthDataType.WEIGHT, earlier, now);
    success &= await health.writeHealthData(
        90, HealthDataType.HEART_RATE, earlier, now);
    success &=
        await health.writeHealthData(90, HealthDataType.STEPS, earlier, now);
    success &= await health.writeHealthData(
        200, HealthDataType.ACTIVE_ENERGY_BURNED, earlier, now);
    success &= await health.writeHealthData(
        70, HealthDataType.HEART_RATE, earlier, now);
    success &= await health.writeHealthData(
        37, HealthDataType.BODY_TEMPERATURE, earlier, now);
    success &= await health.writeBloodOxygen(98, earlier, now, flowRate: 1.0);
    success &= await health.writeHealthData(
        105, HealthDataType.BLOOD_GLUCOSE, earlier, now);
    success &=
        await health.writeHealthData(1.8, HealthDataType.WATER, earlier, now);
    success &= await health.writeWorkoutData(
        HealthWorkoutActivityType.AMERICAN_FOOTBALL,
        now.subtract(const Duration(minutes: 15)),
        now,
        totalDistance: 2430,
        totalEnergyBurned: 400);
    success &= await health.writeBloodPressure(90, 80, earlier, now);

    // Store an Audiogram
    // Uncomment these on iOS - only available on iOS
    // const frequencies = [125.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0];
    // const leftEarSensitivities = [49.0, 54.0, 89.0, 52.0, 77.0, 35.0];
    // const rightEarSensitivities = [76.0, 66.0, 90.0, 22.0, 85.0, 44.5];

    // success &= await health.writeAudiogram(
    //   frequencies,
    //   leftEarSensitivities,
    //   rightEarSensitivities,
    //   now,
    //   now,
    //   metadata: {
    //     "HKExternalUUID": "uniqueID",
    //     "HKDeviceName": "bluetooth headphone",
    //   },
    // );

    setState(() {
      _state = success ? AppState.DATA_ADDED : AppState.DATA_NOT_ADDED;
    });
  }

  /// Delete some random health data.
  Future deleteData() async {
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(hours: 24));

    bool success = true;
    for (HealthDataType type in types) {
      success &= await health.delete(type, earlier, now);
    }

    setState(() {
      _state = success ? AppState.DATA_DELETED : AppState.DATA_NOT_DELETED;
    });
  }

  /// Fetch steps from the health plugin and show them in the app.
  Future fetchStepData() async {
    int? steps;

    // get steps for today (i.e., since midnight)
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    bool requested = await health.requestAuthorization([HealthDataType.STEPS]);

    if (requested) {
      try {
        steps = await health.getTotalStepsInInterval(midnight, now);
      } catch (error) {
        print("Caught exception in getTotalStepsInInterval: $error");
      }

      print('Total number of steps: $steps');

      setState(() {
        _nofSteps = (steps == null) ? 0 : steps;
        _state = (steps == null) ? AppState.NO_DATA : AppState.STEPS_READY;
      });
    } else {
      print("Authorization not granted - error in authorization");
      setState(() => _state = AppState.DATA_NOT_FETCHED);
    }
  }

  Future revokeAccess() async {
    try {
      await health.revokePermissions().then((value) {
        Navigator.pop(context);
      });
    } catch (error) {
      print("Caught exception in revokeAccess: $error");
    }
  }

  Widget _contentFetchingData() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
            padding: const EdgeInsets.all(20),
            child: const CircularProgressIndicator(
              strokeWidth: 5,
            )),
        const Text('Fetching data...')
      ],
    );
  }

  Widget _contentDataReady() {
    return Column(
      children: [
        const Text(
          "24 hours health Data",
          style: TextStyle(fontSize: 20.0),
        ),
        Expanded(
          child: GridView.builder(
              itemCount: _healthDataList.length,
              padding: const EdgeInsets.all(40.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisSpacing: 30,
              ),
              itemBuilder: (_, index) {
                HealthDataPoint p = _healthDataList[index];

                if (p.value is AudiogramHealthValue) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p.type.name,
                            style: const TextStyle(
                                fontSize: 16.0, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '${p.value.toString()} ${p.unitString}',
                            style: const TextStyle(
                                fontSize: 15.0, fontWeight: FontWeight.w400),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (p.value is WorkoutHealthValue) {
                  String fromDate =
                      DateFormat('dd MMMM yyyy hh:mm aaa').format(p.dateFrom);
                  String toDate =
                      DateFormat('dd MMMM yyyy hh:mm aaa').format(p.dateTo);
                  return Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              p.type.name,
                              style: const TextStyle(
                                  fontSize: 22.0, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                'Total Distance: ',
                                style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.start,
                              ),
                              Text(
                                '${(p.value as WorkoutHealthValue).totalDistance} M',
                                style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text(
                                'Total Energy Burn: ',
                                style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.start,
                              ),
                              Text(
                                '${(p.value as WorkoutHealthValue).totalEnergyBurned} Kcal',
                                style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text(
                                'Workout Activity Type: ',
                                style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.start,
                              ),
                              Flexible(
                                child: Text(
                                  '${(p.value as WorkoutHealthValue).workoutActivityType.name}',
                                  style: const TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const Text(
                                'From: ',
                                style: TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                fromDate,
                                style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const Text(
                                'TO: ',
                                style: TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                toDate,
                                style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  double value =
                      double.parse(p.value.toString()).truncateToDouble();
                  String fromDate =
                      DateFormat('dd MMMM yyyy hh:mm aaa').format(p.dateFrom);
                  String toDate =
                      DateFormat('dd MMMM yyyy hh:mm aaa').format(p.dateTo);
                  return Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            p.type.name,
                            style: const TextStyle(
                                fontSize: 22.0, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '${value.toString()} ${p.unitString}',
                            style: const TextStyle(
                                fontSize: 18.0, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'From: ',
                                style: TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                fromDate,
                                style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'TO: ',
                                style: TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                toDate,
                                style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }),
        ),
      ],
    );
  }

  Widget _contentNoData() {
    return const Text('No Data to show');
  }

  Widget _contentNotFetched() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Press the download button to fetch data.'),
        Text('Press the plus button to insert some random data.'),
        Text('Press the walking button to get total step count.'),
      ],
    );
  }

  Widget _authorized() {
    return const Text('Authorization granted!');
  }

  Widget _authorizationNotGranted() {
    return const Text('Authorization not given. '
        'For Android please check your OAUTH2 client ID is correct in Google Developer Console. '
        'For iOS check your permissions in Apple Health.');
  }

  Widget _dataAdded() {
    return const Text('Data points inserted successfully!');
  }

  Widget _dataDeleted() {
    return const Text('Data points deleted successfully!');
  }

  Widget _stepsFetched() {
    return Text('Total number of steps: $_nofSteps');
  }

  Widget _dataNotAdded() {
    return const Text('Failed to add data');
  }

  Widget _dataNotDeleted() {
    return const Text('Failed to delete data');
  }

  Widget _content() {
    if (_state == AppState.DATA_READY) {
      return _contentDataReady();
    } else if (_state == AppState.NO_DATA) {
      return _contentNoData();
    } else if (_state == AppState.FETCHING_DATA) {
      return _contentFetchingData();
    } else if (_state == AppState.AUTHORIZED) {
      return _authorized();
    } else if (_state == AppState.AUTH_NOT_GRANTED) {
      return _authorizationNotGranted();
    } else if (_state == AppState.DATA_ADDED) {
      return _dataAdded();
    } else if (_state == AppState.DATA_DELETED) {
      return _dataDeleted();
    } else if (_state == AppState.STEPS_READY) {
      return _stepsFetched();
    } else if (_state == AppState.DATA_NOT_ADDED) {
      return _dataNotAdded();
    } else if (_state == AppState.DATA_NOT_DELETED) {
      return _dataNotDeleted();
    } else {
      return _contentNotFetched();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Health Data'),
          actions: [
            IconButton(
                onPressed: revokeAccess,
                icon: const Icon(Icons.logout_rounded)),
            const SizedBox(
              width: 10.0,
            )
          ],
        ),
        body: Column(
          children: [
            const SizedBox(
              height: 20.0,
            ),
            const Text(
              "Steps Data From Midnight to Now",
              style: TextStyle(fontSize: 20.0),
            ),
            const SizedBox(
              height: 5.0,
            ),

            SizedBox(
              height: 150,
              width: 150,
              child: Card(
                elevation: 4,
                color: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(80),
                  //set border radius more than 50% of height and width to make circle
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "No of Steps",
                      style: TextStyle(fontSize: 20.0),
                    ),
                    Text(
                      _nofSteps.toString(),
                      style: const TextStyle(
                          fontSize: 20.0, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            // Wrap(
            //   spacing: 10,
            //   children: [
            //     // TextButton(
            //     //     onPressed: authorize,
            //     //     style: const ButtonStyle(
            //     //         backgroundColor:
            //     //             MaterialStatePropertyAll(Colors.blue)),
            //     //     child:
            //     //         const Text("Auth", style: TextStyle(color: Colors.white))),
            //     // TextButton(
            //     //     onPressed: fetchData,
            //     //     style: const ButtonStyle(
            //     //         backgroundColor:
            //     //             MaterialStatePropertyAll(Colors.blue)),
            //     //     child: const Text("Fetch Data",
            //     //         style: TextStyle(color: Colors.white))),
            //     // TextButton(
            //     //     onPressed: addData,
            //     //     style: const ButtonStyle(
            //     //         backgroundColor:
            //     //             MaterialStatePropertyAll(Colors.blue)),
            //     //     child: const Text("Add Data",
            //     //         style: TextStyle(color: Colors.white))),
            //     // TextButton(
            //     //     onPressed: deleteData,
            //     //     style: const ButtonStyle(
            //     //         backgroundColor:
            //     //             MaterialStatePropertyAll(Colors.blue)),
            //     //     child: const Text("Delete Data",
            //     //         style: TextStyle(color: Colors.white))),
            //     // TextButton(
            //     //     onPressed: fetchStepData,
            //     //     style: const ButtonStyle(
            //     //         backgroundColor:
            //     //             MaterialStatePropertyAll(Colors.blue)),
            //     //     child: const Text("Fetch Step Data",
            //     //         style: TextStyle(color: Colors.white))),
            //
            //
            // // TextButton(
            //     //     onPressed: revokeAccess,
            //     //     style: const ButtonStyle(
            //     //         backgroundColor:
            //     //             MaterialStatePropertyAll(Colors.blue)),
            //     //     child: const Text("Revoke Access",
            //     //         style: TextStyle(color: Colors.white))),
            //   ],
            // ),
            const SizedBox(
              height: 15.0,
            ),

            Expanded(child: _content())
          ],
        ),
      ),
    );
  }
}
