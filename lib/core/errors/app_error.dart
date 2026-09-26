import 'dart:io';

import '../services/api_client.dart';

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
    if (e is ApiException) return AppError(_api(e));
    return const AppError('Something went wrong. Please try again.');
  }

  static String _api(ApiException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'That email and password do not match.';
      case 'email_already_registered':
        return 'An account with this email already exists.';
      case 'invalid_or_expired_token':
        return 'This link is invalid or has expired.';
      case 'not_authenticated':
        return 'Please sign in again.';
      case 'moment_not_found':
      case 'media_not_found':
        return 'That could not be found.';
      case 'file_too_large':
        return 'That file is too large.';
      case 'invalid_request':
        return 'Please check the information you entered.';
    }
    if (e.status >= 500) return 'Something went wrong on our side. Please try again.';
    return 'Something went wrong. Please try again.';
  }
}

String friendlyError(Object e) => AppError.from(e).message;
