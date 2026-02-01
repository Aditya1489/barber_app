import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/models/models.dart';

final userProvider = StateProvider<User>((ref) {
  return User(
    id: "8277e487-4624-489f-8f26-48a992e82cf4", // Real Sattu ID from DB
    name: "Sattu",
    email: "sattu@gmail.com",
    phone: "+91 9876543210",
    role: AppRole.barber,
    profilePhoto: "https://picsum.photos/200/200?random=100",
    permissions: {
      "location": true,
      "notifications": true,
      "camera": true,
      "storage": false,
    },
  );
});
