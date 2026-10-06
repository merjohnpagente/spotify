import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/services/api_client.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/validators.dart';
import 'package:spotify_fy/widgets/app_input_field.dart';
import 'package:spotify_fy/widgets/sign_in_button.dart';

/// Real forgot-password flow: sends the email to the backend reset
/// endpoint, then shows a confirmation state. The backend replies with a
/// generic message so accounts can't be enumerated.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _sentMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SpotifyColors.textPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _sentMessage != null ? _buildSent() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Reset Password',
            style: TextStyle(
              color: SpotifyColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your account email and we will send you a reset link.',
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 48),
          AppInputField(
            controller: _emailController,
            label: 'Email',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: validateEmail,
          ),
          const SizedBox(height: 32),
          SignInButton(
            text: 'Send Reset Link',
            onPressed: _handleSubmit,
            loading: _isSubmitting,
          ),
        ],
      ),
    );
  }

  Widget _buildSent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 32),
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: SpotifyColors.secondaryBackground,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: SpotifyColors.primaryAccent,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Check your email',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _sentMessage!,
          style: const TextStyle(
            color: SpotifyColors.textSecondary,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SignInButton(
          text: 'Back to Sign In',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final message = await ref.read(authServiceProvider).forgotPassword(
            email: _emailController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _sentMessage = message;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: SpotifyColors.errorBackground,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not reach the server. Please try again.'),
          backgroundColor: SpotifyColors.errorBackground,
        ),
      );
    }
  }
}
