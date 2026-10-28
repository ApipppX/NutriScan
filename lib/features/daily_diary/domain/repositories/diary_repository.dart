import '../entities/diary_entry.dart';

/// Persistence boundary for the daily diary.
///
/// The current implementation is in-memory. Swapping in sqflite or a local
/// JSON store later only requires a new implementation of this interface.
abstract interface class DiaryRepository {
  Future<List<DiaryEntry>> loadEntries();

  Future<void> addEntry(DiaryEntry entry);
}
