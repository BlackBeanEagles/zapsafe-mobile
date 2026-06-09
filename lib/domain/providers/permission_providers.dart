import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/permission_service.dart';

/// Day 20 — single source of truth for the [PermissionService] instance.
///
/// Carved out as its own provider so widget tests can `overrideWith(...)` a
/// fake that returns canned outcomes without touching the platform channel
/// permission_handler relies on.
final permissionServiceProvider =
    Provider<PermissionService>((_) => PermissionService());
