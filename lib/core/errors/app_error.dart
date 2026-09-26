import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns any exception into copy that is safe to show a person.
class AppError implements Exception {
  const AppError(this.message, {this.isNetwork = false});
  final String message;
  final bool isNetwork;
  @override
  String toString() => message;

  static AppError from(Object e) {
    if (e is AppError) return e;
    if (e is SocketException || e is HttpException || e.toString().contains('ClientException') || e.toString().contains('SocketException')) {
      return const AppError('You seem to be offline. Check your connection and try again.', isNetwork: true);
    }
    if (e is AuthException) return AppError(_auth(e));
    if (e is PostgrestException) {
      if (e.code == '42501') return const AppError('You do not have access to that.');
      return const AppError('Something went wrong on our side. Please try again.');
    }
    if (e is StorageException) return const AppError('That file could not be uploaded. Please try again.');
    return const AppError('Something went wrong. Please try again.');
  }

  static String _auth(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'That email and password do not match.';
    if (m.contains('already registered') || m.contains('already exists')) return 'An account with this email already exists.';
    if (m.contains('password') && m.contains('characters')) return 'Choose a password with at least 8 characters.';
    if (m.contains('email') && m.contains('confirm')) return 'Please confirm your email first. Check your inbox.';
    if (m.contains('rate') || m.contains('too many')) return 'Too many attempts. Please wait a moment and try again.';
    if (m.contains('invalid') && m.contains('email')) return 'That email address does not look right.';
    if (m.contains('network') || m.contains('socket')) return 'You seem to be offline. Check your connection and try again.';
    return 'We could not sign you in. Please try again.';
  }
}

String friendlyError(Object e) => AppError.from(e).message;
