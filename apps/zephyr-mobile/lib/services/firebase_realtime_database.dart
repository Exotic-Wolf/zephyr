import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

const String zephyrRealtimeDatabaseUrl =
    'https://zephyr-495115-default-rtdb.asia-southeast1.firebasedatabase.app';

FirebaseDatabase createZephyrRealtimeDatabase() {
  return FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: zephyrRealtimeDatabaseUrl,
  );
}
