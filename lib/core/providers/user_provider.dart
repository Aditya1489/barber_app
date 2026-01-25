import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/models/models.dart';

final userProvider = StateProvider<User>((ref) {
  return User(
    id: "user1",
    name: "Alex Johnson",
    email: "alex.johnson@email.com",
    phone: "+1 234 567 890",
    role: AppRole.customer,
    profilePhoto: "https://picsum.photos/200/200?random=100",
    permissions: {
      "location": true,
      "notifications": true,
      "camera": true,
      "storage": false,
    },
  );
});
