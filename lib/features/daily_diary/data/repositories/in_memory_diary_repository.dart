import '../../domain/entities/diary_entry.dart';
import '../../domain/repositories/diary_repository.dart';

/// Volatile diary store used until a persistent database is introduced.
///
/// Entries are kept newest-first so the UI can render the latest meal without
/// sorting. The repository copies its internal list on every read, keeping the
/// state exposed to Riverpod immutable.
final class InMemoryDiaryRepository implements DiaryRepository {
  final List<DiaryEntry> _entries = <DiaryEntry>[];

  @override
  Future<List<DiaryEntry>> loadEntries() async =>
      List<DiaryEntry>.unmodifiable(_entries);

  @override
  Future<void> addEntry(DiaryEntry entry) async {
    _entries.insert(0, entry);
  }
}
