import 'package:flutter_test/flutter_test.dart';
import 'package:tickbell/data/models/bell.dart';
import 'package:tickbell/data/models/group.dart';

void main() {
  group('model parsing', () {
    test('Group.fromJson tolerates missing created_at and created_by', () {
      final group = Group.fromJson({
        'id': 'g1',
        'name': 'Ops',
        'description': 'Team',
      });

      expect(group.id, 'g1');
      expect(group.name, 'Ops');
      expect(group.createdBy, isEmpty);
      expect(group.createdAt, isA<DateTime>());
    });

    test('Bell.fromJson handles missing embedded relations', () {
      final bell = Bell.fromJson({
        'id': 'b1',
        'sender_id': 'u1',
        'recipient_id': null,
        'group_id': 'g1',
        'created_at': '2026-07-21T12:00:00.000Z',
      });

      expect(bell.id, 'b1');
      expect(bell.senderDisplayName, isNull);
      expect(bell.groupName, isNull);
    });
  });
}
