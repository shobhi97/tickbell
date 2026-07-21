import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/supabase/supabase_client_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/services/notification_service_provider.dart';
import '../../shared/services/push_availability.dart';
import '../../shared/widgets/avatar_widget.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();
  bool _saving = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _statusCtrl.dispose();
    _phoneCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(String userId) async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(
            userId: userId,
            displayName: _nameCtrl.text,
            statusMessage: _statusCtrl.text,
            phone: _phoneCtrl.text,
            avatarUrl: _avatarCtrl.text,
          );
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      if (firebasePushAvailable) {
        await ref.read(notificationServiceProvider).unregisterOnSignOut();
      }
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // Best-effort; continue to clear local state and return to auth.
    } finally {
      if (mounted) {
        ref.invalidate(myProfileProvider);
        ref.invalidate(myGroupsProvider);
        context.go('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load profile: $e')),
        data: (profile) {
          if (!_hydrated && profile != null) {
            _hydrated = true;
            _nameCtrl.text = profile.displayName;
            _statusCtrl.text = profile.statusMessage ?? '';
            _phoneCtrl.text = profile.phone ?? '';
            _avatarCtrl.text = profile.avatarUrl ?? '';
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: AvatarWidget(
                  url: _avatarCtrl.text.isNotEmpty ? _avatarCtrl.text : profile?.avatarUrl,
                  initialsSource: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : (profile?.displayName ?? '?'),
                  size: 88,
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text(profile?.email ?? '', style: Theme.of(context).textTheme.bodySmall)),
              const SizedBox(height: 24),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Display name')),
              const SizedBox(height: 12),
              TextField(
                controller: _statusCtrl,
                decoration: const InputDecoration(labelText: 'Status message', hintText: 'e.g. In a meeting until 3pm'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  helperText: 'Lets contacts find you by phone number',
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _avatarCtrl, decoration: const InputDecoration(labelText: 'Avatar image URL')),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_saving || userId == null) ? null : () => _save(userId),
                child: _saving ? const Text('Saving…') : const Text('Save changes'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _signOut, child: const Text('Sign out')),
            ],
          );
        },
      ),
    );
  }
}
