import '../entities/diary_entry.dart';

/// Persistence boundary for the daily diary.
///
/// Production uses a local SQLite implementation, while unit tests use an
/// in-memory implementation. Consumers depend only on this interface.
abstract interface class DiaryRepository {
  Future<List<DiaryEntry>> loadEntries();

  Future<void> addEntry(DiaryEntry entry);
}
