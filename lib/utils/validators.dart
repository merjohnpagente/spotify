// Form validators shared across auth screens.

/// Reasonably strict email check: local@domain.tld (no spaces, needs a dot
/// in the domain). Rejects `foo@` and `foo@bar` which the old
/// `contains('@')` check allowed through.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your email';
  }
  final email = value.trim();
  final pattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  if (!pattern.hasMatch(email)) {
    return 'Please enter a valid email';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your password';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  return null;
}

String? validateResetToken(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter the reset token from your email';
  }
  return null;
}
