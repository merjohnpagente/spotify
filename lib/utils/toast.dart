import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Message waiting to be shown as a SnackBar. Set by non-UI layers
/// (e.g. PlayerController when a signed-out user taps Like) and consumed
/// once by the root listener in `main.dart` (AuthGate).
final toastProvider = StateProvider<String?>((ref) => null);

/// Root ScaffoldMessenger key so toasts render above whatever route is
/// currently on top (the player screen is a pushed route — a SnackBar tied
/// to MainScreen's scaffold would be hidden behind it).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
