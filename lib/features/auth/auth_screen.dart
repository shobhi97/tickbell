import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/repository_providers.dart';

enum _AuthMode { signIn, signUp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthMode _mode = _AuthMode.signIn;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorMsg = null;
      _loading = true;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      if (_mode == _AuthMode.signUp) {
        if (_passwordCtrl.text.length < 8) {
          throw Exception('Password must be at least 8 characters.');
        }
        final hasSession = await auth.signUp(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          displayName: _nameCtrl.text,
        );
        if (!hasSession) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Account created — check your email to confirm, then sign in.'),
          ));
          setState(() {
            _mode = _AuthMode.signIn;
            _loading = false;
          });
          return;
        }
      } else {
        await auth.signInWithPassword(email: _emailCtrl.text, password: _passwordCtrl.text);
      }
      if (!mounted) return;
      context.go('/home');
    } catch (err) {
      final friendly = AuthRepository.friendlyMessage(err);
      setState(() => _errorMsg = friendly);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendly)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // Browser/app is redirecting; the auth-state listener + router
      // redirect handles navigation once the session lands.
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AuthRepository.friendlyMessage(err))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _AuthMode.signUp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: TickBellColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.notifications, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text('TickBell', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isSignUp ? 'Create account' : 'Welcome back',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSignUp ? 'Start ringing in seconds.' : 'Sign in to keep the bell close.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _handleGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: Theme.of(context).textTheme.labelSmall),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isSignUp) ...[
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name', hintText: 'Your name'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', hintText: '••••••••'),
                    onSubmitted: (_) => _loading ? null : _submit(),
                  ),
                  if (isSignUp)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'At least 8 characters. Avoid common passwords like "password123".',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (_errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_errorMsg!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isSignUp ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _mode = isSignUp ? _AuthMode.signIn : _AuthMode.signUp),
                      child: Text(isSignUp ? 'Already have an account? Sign in' : "New here? Create an account"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
