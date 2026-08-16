import 'package:flutter/material.dart';

enum MoodState {
  calm('Calm'),
  hopeful('Hopeful'),
  tired('Tired'),
  heavy('Heavy'),
  crisis('Crisis');

  const MoodState(this.label);
  final String label;
}

enum EnergyLevel {
  low('Low'),
  medium('Medium'),
  high('High');

  const EnergyLevel(this.label);
  final String label;
}

enum CrisisLevel {
  safe('Safe'),
  watch('Watch'),
  urgent('Urgent');

  const CrisisLevel(this.label);
  final String label;
}

class JournalEntry {
  JournalEntry({
    required this.message,
    required this.timestamp,
    this.highlight = false,
  });

  final String message;
  final DateTime timestamp;
  final bool highlight;
}

class ReJoySession {
  ReJoySession({
    required this.userName,
    required this.age,
    required this.mood,
    required this.energy,
    required this.crisis,
    required this.dailyScore,
    required this.dailyQuestions,
    required this.missionsDone,
    required this.privateMode,
    required this.journal,
    required this.unlockedAnimals,
  });

  factory ReJoySession.seed() {
    return ReJoySession(
      userName: 'Guest',
      age: 17,
      mood: MoodState.hopeful,
      energy: EnergyLevel.medium,
      crisis: CrisisLevel.safe,
      dailyScore: 7,
      dailyQuestions: 3,
      missionsDone: 1,
      privateMode: true,
      unlockedAnimals: <String>[],
      journal: [
        JournalEntry(
          message: 'First day on ReJoy.',
          timestamp: DateTime.now(),
          highlight: true,
        ),
      ],
    );
  }

  String userName;
  int age;
  MoodState mood;
  EnergyLevel energy;
  CrisisLevel crisis;
  int dailyScore;
  int dailyQuestions;
  int missionsDone;
  bool privateMode;
  final List<JournalEntry> journal;
  final List<String> unlockedAnimals;

  void addJournal(String message, {bool highlight = false}) {
    journal.insert(
      0,
      JournalEntry(
        message: message,
        timestamp: DateTime.now(),
        highlight: highlight,
      ),
    );
    if (journal.length > 12) {
      journal.removeLast();
    }
  }

  void mergeUnlockedAnimals(Iterable<String> animalIds) {
    for (final animalId in animalIds) {
      final trimmed = animalId.trim();
      if (trimmed.isNotEmpty && !unlockedAnimals.contains(trimmed)) {
        unlockedAnimals.add(trimmed);
      }
    }
  }

  String get islandWeather {
    switch (mood) {
      case MoodState.calm:
        return 'Sunlit calm';
      case MoodState.hopeful:
        return 'Bright breeze';
      case MoodState.tired:
        return 'Soft clouds';
      case MoodState.heavy:
        return 'Rain wash';
      case MoodState.crisis:
        return 'Storm watch';
    }
  }

  List<String> get microCbts {
    switch (energy) {
      case EnergyLevel.low:
        return const [
          'Stay still for 60 seconds',
          'Name 5 things you can see',
          'Drink a full glass of water',
        ];
      case EnergyLevel.medium:
        return const [
          'Take a 5 minute walk',
          'Write one kind sentence to yourself',
          'Stretch shoulders and neck',
        ];
      case EnergyLevel.high:
        return const [
          'Pick one task and finish it',
          'Tidy one corner of the room',
          'Celebrate a small win',
        ];
    }
  }

  Color get moodColor {
    switch (mood) {
      case MoodState.calm:
        return const Color(0xFF67D7C8);
      case MoodState.hopeful:
        return const Color(0xFF6CA8FF);
      case MoodState.tired:
        return const Color(0xFFF3B35C);
      case MoodState.heavy:
        return const Color(0xFF8B90C6);
      case MoodState.crisis:
        return const Color(0xFFEF6B7A);
    }
  }
}
