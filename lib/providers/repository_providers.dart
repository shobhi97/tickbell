import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/bell_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/message_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/push_repository.dart';
import '../data/supabase/supabase_client_provider.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(supabaseClientProvider)));
final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(supabaseClientProvider)));
final groupRepositoryProvider = Provider((ref) => GroupRepository(ref.watch(supabaseClientProvider)));
final messageRepositoryProvider = Provider((ref) => MessageRepository(ref.watch(supabaseClientProvider)));
final bellRepositoryProvider = Provider((ref) => BellRepository(ref.watch(supabaseClientProvider)));
final pushRepositoryProvider = Provider((ref) => PushRepository(ref.watch(supabaseClientProvider)));
