import 'package:flutter/material.dart';

import '../../core/rejoy_session.dart';
import '../../services/doctor_pdf_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/compassionate_gamification_service.dart';
import '../../services/local_sync_service.dart';
import '../../services/rejoy_api_client.dart';
import '../../widgets/rejoy_loading.dart';

String _gentleEnergyLabel(String energyLevel) {
  switch (energyLevel) {
    case 'rest':
    case 'low':
      return 'พลังงานน้อย ค่อย ๆ ทำได้';
    case 'medium':
      return 'พลังงานปานกลาง';
    case 'high':
      return 'พลังงานพร้อมขึ้น';
    default:
      return 'เลือกเท่าที่ไหว';
  }
}

int _questEaseScore(QuestItem quest) {
  final text = '${quest.name} ${quest.description}'.toLowerCase();
  final energyScore = switch (quest.energyLevel) {
    'rest' => 0,
    'low' => 1,
    'medium' => 4,
    'high' => 8,
    _ => 5,
  };
  final microStepScore =
      text.contains('breathe') ||
          text.contains('water') ||
          text.contains('bed') ||
          text.contains('kind') ||
          text.contains('write') ||
          text.contains('หายใจ') ||
          text.contains('จิบ') ||
          text.contains('น้ำ') ||
          text.contains('ขยับ') ||
          text.contains('หนึ่ง') ||
          text.contains('สั้น')
      ? -1
      : 0;
  return energyScore + microStepScore;
}

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({
    super.key,
    required this.session,
    required this.onEnergySelected,
    this.onGoToIsland,
  });

  final ReJoySession session;
  final ValueChanged<EnergyLevel> onEnergySelected;
  final VoidCallback? onGoToIsland;

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  late final ReJoyApiClient _client;
  late final DoctorPdfService _doctorPdfService;
  final CompassionateGamificationService _compassionateSystem =
      const CompassionateGamificationService();
  final AuditLogService _auditLog = const AuditLogService();
  final LocalSyncService _localSyncService = const LocalSyncService();
  BackendUser? _currentUser;
  List<QuestItem> _availableQuests = [];
  final List<QuestItem> _selectedQuests = [];
  final Set<String> _completedQuestIds = {};
  final Set<String> _skippedQuestIds = {};
  String? _memoryNote;
  String? _energyLevelFilter;
  String? _statusMessage;
  String? _errorMessage;
  bool _loading = true;
  bool _exportingPdf = false;
  bool _isRestDay = false;

  @override
  void initState() {
    super.initState();
    _client = ReJoyApiClient();
    _doctorPdfService = const DoctorPdfService();
    _loadBoard();
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<void> _loadBoard({
    bool keepSelection = true,
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _client.fetchActiveClinicalProfile(
        forceRefresh: forceRefresh,
      );
      final quests = await _client.fetchQuests(
        energyLevel: _energyLevelFilter,
        forceRefresh: forceRefresh,
      );
      final syncedCount = await _localSyncService.flush(_client);
      final draft = await _localSyncService.loadDiaryDraft(
        userId: profile.user.id,
      );

      final user = profile.user;
      final available = quests.where((quest) {
        return !_selectedQuests.any((selected) => selected.id == quest.id) &&
            !_skippedQuestIds.contains(quest.id);
      }).toList();
      available.sort(
        (a, b) => _questEaseScore(a).compareTo(_questEaseScore(b)),
      );
      final dailyQuests = available.take(10).toList();

      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _memoryNote = draft ?? _memoryNote;
        _availableQuests = dailyQuests;
        if (!keepSelection) {
          _selectedQuests.clear();
          _completedQuestIds.clear();
          _skippedQuestIds.clear();
        }
        _loading = false;
        if (syncedCount > 0) {
          _statusMessage = 'Synced $syncedCount saved item(s) to cloud.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _setFilter(String? energyLevel) {
    setState(() {
      _energyLevelFilter = energyLevel;
    });
    _loadBoard();
  }

  void _setRestDay(bool value) {
    setState(() {
      _isRestDay = value;
      if (value) {
        _selectedQuests.clear();
        _completedQuestIds.clear();
        _skippedQuestIds.clear();
        widget.session.addJournal(
          'เลือกพักอย่างปลอดภัยวันนี้',
          highlight: true,
        );
        _statusMessage = 'วันนี้พักได้ ระบบจะบันทึกเป็น Rest Day ให้หมอเห็น';
      } else {
        _statusMessage = 'กลับมาเลือกเควสเบา ๆ ได้ตามแรงใจของวันนี้';
      }
    });
    if (!value) {
      _loadBoard();
    }
  }

  bool _isSameLocalDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<ReportEntry?> _saveMemoryNote(String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _statusMessage = 'กรุณาเขียนความในใจก่อนบันทึก';
      });
      return null;
    }

    final user = _currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'ยังไม่พบผู้ใช้สำหรับบันทึกความในใจ';
      });
      return null;
    }

    final today = DateTime.now();
    final cbtCompletionRate = _isRestDay
        ? 'Resting'
        : '${_completedQuestIds.length}/${_selectedQuests.length}';
    final unlockedAnimalToday = user.unlockedAnimals.isEmpty
        ? ''
        : user.unlockedAnimals.last;
    final reportPayload = <String, dynamic>{
      'dailyMood': widget.session.mood.label,
      'diaryNote': trimmed,
      'cbtCompletionRate': cbtCompletionRate,
      'unlockedAnimalToday': unlockedAnimalToday,
      'isRestDay': _isRestDay,
      'isSosTriggered': widget.session.crisis != CrisisLevel.safe,
      'date': today.toIso8601String(),
    };

    setState(() {
      _memoryNote = trimmed;
      widget.session.addJournal('เขียนความในใจวันนี้', highlight: true);
      _statusMessage = 'บันทึกความในใจเรียบร้อย';
    });

    await _localSyncService.saveDiaryDraft(
      userId: user.id,
      note: trimmed,
      date: today,
    );

    try {
      await _client.savePositiveMemoryForUser(
        userId: user.id,
        answer: trimmed,
        prompt: _compassionateSystem.nightPrompt(widget.session.mood),
        animalId: unlockedAnimalToday,
        moodState: widget.session.mood.label,
        date: today,
      );
    } catch (_) {
      // The report is the clinical source of truth; this memory can sync later.
    }

    String? updateReportId;
    try {
      final reports = await _client.fetchReports(userId: user.id);
      final todayReport = reports.cast<ReportEntry?>().firstWhere(
        (report) => _isSameLocalDay(report?.date, today),
        orElse: () => null,
      );

      if (todayReport != null && todayReport.id.isNotEmpty) {
        updateReportId = todayReport.id;
        final updatedReport = await _client.updateReport(
          reportId: todayReport.id,
          diaryNote: trimmed,
          dailyMood: widget.session.mood.label,
          cbtCompletionRate: cbtCompletionRate,
          unlockedAnimalToday: unlockedAnimalToday,
          isRestDay: _isRestDay,
          isSosTriggered: widget.session.crisis != CrisisLevel.safe,
          date: today,
        );
        if (!mounted) return updatedReport;
        setState(() {
          _statusMessage = 'ส่งความในใจไปเก็บในรายงานแล้ว';
        });
        return updatedReport;
      } else {
        final createdReport = await _client.createReportForUser(
          userId: user.id,
          dailyMood: widget.session.mood.label,
          diaryNote: trimmed,
          cbtCompletionRate: cbtCompletionRate,
          unlockedAnimalToday: unlockedAnimalToday,
          isRestDay: _isRestDay,
          isSosTriggered: widget.session.crisis != CrisisLevel.safe,
          date: today,
        );
        if (!mounted) return createdReport;
        setState(() {
          _statusMessage = 'ส่งความในใจไปเก็บในรายงานแล้ว';
        });
        return createdReport;
      }
    } catch (error) {
      if (updateReportId != null) {
        await _localSyncService.enqueueReportUpdate(
          reportId: updateReportId,
          payload: reportPayload,
        );
      } else {
        await _localSyncService.enqueueReportCreate(
          userId: user.id,
          payload: reportPayload,
        );
      }
      if (!mounted) return null;
      setState(() {
        _statusMessage = 'บันทึกลงรายงานไม่สำเร็จ: $error';
      });
      setState(() {
        _statusMessage =
            'Saved on this device. It will sync to cloud when connection is back.';
      });
      return null;
    }
  }

  Future<ReportEntry> _latestOrGeneratedReport(BackendUser user) async {
    final reports = await _client.fetchReports(userId: user.id);
    if (reports.isNotEmpty) {
      final today = DateTime.now();
      final todayReport = reports.cast<ReportEntry?>().firstWhere(
        (report) => _isSameLocalDay(report?.date, today),
        orElse: () => null,
      );
      return todayReport ?? reports.first;
    }

    return _client.createReportForUser(
      userId: user.id,
      dailyMood: widget.session.mood.label,
      diaryNote: _memoryNote ?? '',
      cbtCompletionRate: _isRestDay
          ? 'Resting'
          : '${_completedQuestIds.length}/${_selectedQuests.length}',
      unlockedAnimalToday: user.unlockedAnimals.isEmpty
          ? ''
          : user.unlockedAnimals.last,
      isRestDay: _isRestDay,
      isSosTriggered: widget.session.crisis != CrisisLevel.safe,
      date: DateTime.now(),
    );
  }

  Future<void> _printDoctorPdf() async {
    final user = _currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'ยังไม่พบผู้ใช้สำหรับสร้าง PDF';
      });
      return;
    }

    setState(() {
      _exportingPdf = true;
      _statusMessage = 'กำลังเตรียม PDF ให้หมอ...';
    });

    try {
      final report = await _latestOrGeneratedReport(user);
      await _doctorPdfService.printDoctorReportPdf(user: user, report: report);
      if (!mounted) return;
      setState(() {
        _statusMessage = 'สร้าง PDF สำหรับหมอเรียบร้อย';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'สร้าง PDF ไม่สำเร็จ: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _exportingPdf = false;
        });
      }
    }
  }

  Future<void> _openMemoryPaper() async {
    final controller = TextEditingController(text: _memoryNote ?? '');
    final reframePrompt = _compassionateSystem.nightPrompt(widget.session.mood);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.55,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF9F0D8), Color(0xFFE8F2EA)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 54,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCDBE8E),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'เขียนความในใจของวันนี้',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF5D4B1D),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E4),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE7D59B)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.pets_rounded,
                              color: Color(0xFFB88928),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reframePrompt,
                                style: const TextStyle(
                                  color: Color(0xFF5D4B1D),
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'ข้อมูลนี้จะถูกเก็บใน PDF สำหรับพิมพ์ให้หมอ คุณเขียนได้ตามปกติ เหมือนเขียนลงสมุดส่วนตัวของวันนี้',
                        style: TextStyle(color: Color(0xFF7A6840)),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _NotebookPaper(controller: controller)),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () async {
                          final note = controller.text.trim();
                          await _saveMemoryNote(note);
                          if (context.mounted && note.isNotEmpty) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('เขียนสำเร็จและเก็บไว้'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD3A948),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  EnergyLevel? _energyFromLabel(String energyLevel) {
    switch (energyLevel) {
      case 'low':
      case 'rest':
        return EnergyLevel.low;
      case 'medium':
        return EnergyLevel.medium;
      case 'high':
        return EnergyLevel.high;
      default:
        return null;
    }
  }

  void _selectQuest(QuestItem quest) {
    if (_selectedQuests.any((item) => item.id == quest.id)) {
      return;
    }

    setState(() {
      _selectedQuests.add(quest);
      _availableQuests.removeWhere((item) => item.id == quest.id);
      widget.session.missionsDone = _selectedQuests.length;
      widget.session.addJournal('เลือกเควส: ${quest.name}', highlight: true);
    });
  }

  void _skipQuest(QuestItem quest) {
    setState(() {
      _skippedQuestIds.add(quest.id);
      _availableQuests.removeWhere((item) => item.id == quest.id);
      widget.session.addJournal('ข้ามเควส: ${quest.name}');
      _statusMessage = 'ข้าม ${quest.name} แล้ว';
    });
  }

  void _removeSelectedQuest(QuestItem quest) {
    setState(() {
      _selectedQuests.removeWhere((item) => item.id == quest.id);
      _completedQuestIds.remove(quest.id);
      _skippedQuestIds.remove(quest.id);
      widget.session.missionsDone = _selectedQuests.length;
      if (_energyLevelFilter == null ||
          _energyLevelFilter == quest.energyLevel) {
        _availableQuests.insert(0, quest);
      }
    });
  }

  void _toggleCompletedQuest(QuestItem quest, bool isCompleted) {
    setState(() {
      if (isCompleted) {
        _completedQuestIds.add(quest.id);
      } else {
        _completedQuestIds.remove(quest.id);
      }
    });
  }

  bool get _canFinishDay => _isRestDay || _completedQuestIds.length >= 3;

  String _completionButtonLabel() {
    if (_isRestDay) {
      return 'จบวันแบบพักใจอย่างปลอดภัย';
    }
    final completed = _completedQuestIds.length;
    final selected = _selectedQuests.length;
    if (completed < 3) {
      return 'สะสมครบ 3 เควส เพื่อจบวัน ($completed/3)';
    }
    return 'จบวันชาร์จพลังใจสำเร็จ! ($completed/$selected)';
  }

  Future<void> _finishDay() async {
    final user = _currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'No user found to finish the day.';
      });
      return;
    }

    final completedQuests = _isRestDay
        ? <String>[]
        : _selectedQuests
              .where((quest) => _completedQuestIds.contains(quest.id))
              .map((quest) => quest.name)
              .toList();

    if (!_isRestDay && completedQuests.length < 3) {
      setState(() {
        _statusMessage =
            'Please complete at least 3 quests before finishing the day.';
      });
      return;
    }

    final selectedQuestNames = _isRestDay
        ? <String>[]
        : _selectedQuests.map((quest) => quest.name).toList();
    final wasRestDay = _isRestDay;
    final finishPayload = <String, dynamic>{
      'selectedQuests': selectedQuestNames,
      'completedQuests': completedQuests,
      'completionRate': _isRestDay
          ? 'Resting'
          : '${completedQuests.length}/${_selectedQuests.length}',
      'energyModeSelected': user.currentEnergyLevel,
      'isRestDay': _isRestDay,
    };

    try {
      final result = await _client.finishQuestDayForUser(
        userId: user.id,
        selectedQuests: selectedQuestNames,
        completedQuests: completedQuests,
        completionRate: _isRestDay
            ? 'Resting'
            : '${completedQuests.length}/${_selectedQuests.length}',
        energyModeSelected: user.currentEnergyLevel,
        isRestDay: _isRestDay,
      );

      if (!mounted) return;
      final compassionateMessage = _compassionateSystem.encounterCopy(
        newAnimals: result.unlockedAnimalsToday,
        completedQuests: completedQuests.length,
        backendMessage: result.companionMessage.isNotEmpty
            ? result.companionMessage
            : result.message,
      );
      setState(() {
        _statusMessage = compassionateMessage;
        _isRestDay = false;
      });
      widget.session.addJournal(
        'จบวัน: $compassionateMessage',
        highlight: true,
      );
      await _auditLog.record(
        type: 'QUEST_DAY_FINISHED',
        detail:
            'selected=${selectedQuestNames.length};completed=${completedQuests.length}',
      );
      await _loadBoard(keepSelection: false);
      if (!wasRestDay && mounted) {
        await _showQuestCompletionDialog(
          selectedCount: selectedQuestNames.length,
          completedCount: completedQuests.length,
        );
      }
    } catch (error) {
      await _localSyncService.enqueueQuestDayFinish(
        userId: user.id,
        payload: finishPayload,
      );
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Saved finish-day locally. It will sync when connection is back.';
      });
      await _auditLog.record(
        type: 'QUEST_DAY_FINISH_QUEUED',
        detail:
            'selected=${selectedQuestNames.length};completed=${completedQuests.length}',
      );
    }
  }

  Future<void> _showQuestCompletionDialog({
    required int selectedCount,
    required int completedCount,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF7FBF7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/island_parts/rejoy_bot.png',
                width: 108,
                height: 108,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 12),
              const Text(
                'โอ้ ยินดีด้วยนะ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF17343C),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'คุณทำภารกิจสำเร็จ $completedCount จาก $selectedCount เควสแล้ว '
                'ดูเหมือนว่าพายุจะเบาลงแล้ว ไปดูกันดีกว่าว่าจะมีสัตว์ตัวไหนแวะเข้ามาบนเกาะของคุณ',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF48636A),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE7B13D),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  widget.onGoToIsland?.call();
                },
                icon: const Icon(Icons.pets_rounded),
                label: const Text('ไปดูเกาะของฉัน'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterLabels = <String?>[null, 'rest', 'low', 'medium', 'high'];
    final selectedCount = _selectedQuests.length;
    final completedCount = _completedQuestIds.length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9F6F5), Color(0xFFF8F7F0)],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF59A8A1),
          onRefresh: () => _loadBoard(forceRefresh: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _MissionsHero(
                user: _currentUser,
                selectedCount: selectedCount,
                completedCount: completedCount,
              ),
              const SizedBox(height: 12),
              Text(
                'ลากการ์ดบนสุดไปทางขวาเพื่อเก็บเควส หรือซ้ายเพื่อข้าม',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF667A85),
                ),
              ),
              const SizedBox(height: 12),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                _StatusPill(message: _statusMessage!),
              ],
              const SizedBox(height: 16),
              _CombinedDailyBoard(
                mood: widget.session.mood,
                energy: widget.session.energy,
                filterLabels: filterLabels,
                energyLevelFilter: _energyLevelFilter,
                onFilterSelected: _setFilter,
                isRestDay: _isRestDay,
                onRestDayChanged: _setRestDay,
                onReload: _loadBoard,
                loading: _loading,
                errorMessage: _errorMessage,
                availableQuests: _availableQuests,
                onAcceptQuest: _selectQuest,
                onSkipQuest: _skipQuest,
                onPreviewEnergy: (quest) {
                  final mappedEnergy = _energyFromLabel(quest.energyLevel);
                  if (mappedEnergy != null) {
                    widget.onEnergySelected(mappedEnergy);
                  }
                },
                selectedQuests: _selectedQuests,
                completedQuestIds: _completedQuestIds,
                onToggleCompleted: _toggleCompletedQuest,
                onRemoveQuest: _removeSelectedQuest,
                completionButtonLabel: _completionButtonLabel(),
                canFinishDay: _canFinishDay,
                onFinishDay: _finishDay,
                memoryNote: _memoryNote,
                onMemoryTap: _openMemoryPaper,
                onPrintDoctorPdf: _printDoctorPdf,
                exportingPdf: _exportingPdf,
                statusMessage: _statusMessage,
                selectedCount: selectedCount,
                completedCount: completedCount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionsHero extends StatelessWidget {
  const _MissionsHero({
    required this.user,
    required this.selectedCount,
    required this.completedCount,
  });

  final BackendUser? user;
  final int selectedCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final unlockedAnimals = user == null || user!.unlockedAnimals.isEmpty
        ? 'ยังไม่มี'
        : user!.unlockedAnimals.take(3).join(', ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FCFB), Color(0xFFE3F3EF)],
        ),
        border: Border.all(color: const Color(0xFFD0E4E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Missions',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF17343C),
                  ),
                ),
              ),
              const _Badge(text: 'Quest Stack'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'กองเควสแบบ Tinder + ช่องเก็บด้านล่าง + คลังความในใจในหน้าเดียว',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4D6A72)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TinyStat(label: 'Selected', value: '$selectedCount'),
              _TinyStat(label: 'Completed', value: '$completedCount'),
              _TinyStat(label: 'Animals', value: unlockedAnimals),
            ],
          ),
        ],
      ),
    );
  }
}

class _CombinedDailyBoard extends StatelessWidget {
  const _CombinedDailyBoard({
    required this.mood,
    required this.energy,
    required this.filterLabels,
    required this.energyLevelFilter,
    required this.onFilterSelected,
    required this.isRestDay,
    required this.onRestDayChanged,
    required this.onReload,
    required this.loading,
    required this.errorMessage,
    required this.availableQuests,
    required this.onAcceptQuest,
    required this.onSkipQuest,
    required this.onPreviewEnergy,
    required this.selectedQuests,
    required this.completedQuestIds,
    required this.onToggleCompleted,
    required this.onRemoveQuest,
    required this.completionButtonLabel,
    required this.canFinishDay,
    required this.onFinishDay,
    required this.memoryNote,
    required this.onMemoryTap,
    required this.onPrintDoctorPdf,
    required this.exportingPdf,
    required this.statusMessage,
    required this.selectedCount,
    required this.completedCount,
  });

  final MoodState mood;
  final EnergyLevel energy;
  final List<String?> filterLabels;
  final String? energyLevelFilter;
  final ValueChanged<String?> onFilterSelected;
  final bool isRestDay;
  final ValueChanged<bool> onRestDayChanged;
  final Future<void> Function() onReload;
  final bool loading;
  final String? errorMessage;
  final List<QuestItem> availableQuests;
  final ValueChanged<QuestItem> onAcceptQuest;
  final ValueChanged<QuestItem> onSkipQuest;
  final ValueChanged<QuestItem> onPreviewEnergy;
  final List<QuestItem> selectedQuests;
  final Set<String> completedQuestIds;
  final ValueChanged2<QuestItem, bool> onToggleCompleted;
  final ValueChanged<QuestItem> onRemoveQuest;
  final String completionButtonLabel;
  final bool canFinishDay;
  final VoidCallback onFinishDay;
  final String? memoryNote;
  final VoidCallback onMemoryTap;
  final VoidCallback onPrintDoctorPdf;
  final bool exportingPdf;
  final String? statusMessage;
  final int selectedCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return _SoftSectionCard(
      title: 'ไดอารี่ชาร์จพลังใจบนเกาะ',
      subtitle: 'รวมเช็กอิน เควส และคลังความในใจไว้ในแผงเดียว',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BoardSectionHeader(
            index: 1,
            title: 'เช็กอินสภาพใจรายวัน',
            action: Icon(Icons.settings, size: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          _MoodStrip(currentMood: mood),
          const SizedBox(height: 10),
          _EnergyChips(
            currentEnergy: energy,
            filterLabels: filterLabels,
            energyLevelFilter: energyLevelFilter,
            onFilterSelected: onFilterSelected,
          ),
          const SizedBox(height: 12),
          _RestingModeCard(enabled: isRestDay, onChanged: onRestDayChanged),
          const SizedBox(height: 16),
          if (isRestDay)
            const _RestingCompanionCard()
          else ...[
            _BoardSectionHeader(
              index: 2,
              title: 'ภารกิจพลังใจประจำวัน',
              action: Text(
                '$selectedCount selected',
                style: const TextStyle(fontSize: 12, color: Color(0xFF657E84)),
              ),
            ),
            const SizedBox(height: 10),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: ReJoyLoadingView(
                  title: 'ยินดีต้อนรับสู่ ReJoy',
                  message: 'กำลังโหลดการ์ดชาร์จพลังใจ...',
                  progress: 0.8,
                  compact: true,
                ),
              )
            else if (errorMessage != null)
              _StatusCard(
                icon: Icons.error_outline,
                title: 'Failed to load quests',
                subtitle: errorMessage!,
                actionLabel: 'Retry',
                onAction: () => onReload(),
              )
            else if (availableQuests.isEmpty)
              _QuestDeckEmptyCompanion(
                selectedCount: selectedCount,
                onReload: onReload,
              )
            else
              _QuestChargeDeck(
                quests: availableQuests,
                onAccept: onAcceptQuest,
                onReject: onSkipQuest,
                onPreviewEnergy: onPreviewEnergy,
              ),
            const SizedBox(height: 14),
            _SelectedQuestsBoard(
              selectedQuests: selectedQuests,
              completedQuestIds: completedQuestIds,
              onToggleCompleted: onToggleCompleted,
              onRemove: onRemoveQuest,
            ),
            const SizedBox(height: 12),
          ],
          _FinishDayButton(
            label: completionButtonLabel,
            enabled: canFinishDay,
            onPressed: onFinishDay,
            subtitle: isRestDay
                ? 'Rest day will be saved as safe recovery.'
                : 'Selected $selectedCount | Completed $completedCount',
          ),
          const SizedBox(height: 16),
          _BoardSectionHeader(
            index: 3,
            title: 'Time Capsule ท้ายวัน',
            action: const Icon(
              Icons.inventory_2_rounded,
              size: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          _TimeCapsuleStats(
            moodLabel: mood.label,
            energyLabel: energy.label,
            completionLabel: isRestDay
                ? 'Resting'
                : '$completedCount/${selectedCount == 0 ? 3 : selectedCount}',
          ),
          const SizedBox(height: 10),
          _MemoryVault(
            notePreview: memoryNote,
            onTap: onMemoryTap,
            onPrintDoctorPdf: onPrintDoctorPdf,
            exportingPdf: exportingPdf,
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: 12),
            _StatusPill(message: statusMessage!),
          ],
        ],
      ),
    );
  }
}

class _BoardSectionHeader extends StatelessWidget {
  const _BoardSectionHeader({
    required this.index,
    required this.title,
    required this.action,
  });

  final int index;
  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$index. $title',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF17343C),
            ),
          ),
        ),
        action,
      ],
    );
  }
}

class _MoodStrip extends StatelessWidget {
  const _MoodStrip({required this.currentMood});

  final MoodState currentMood;

  @override
  Widget build(BuildContext context) {
    final moods = <(MoodState, String, String)>[
      (MoodState.hopeful, 'ลุ้นใจ', '😊'),
      (MoodState.calm, 'นิ่ง', '😌'),
      (MoodState.tired, 'ตึงล้า', '😴'),
      (MoodState.heavy, 'เหงา', '😟'),
      (MoodState.crisis, 'ฉุกเฉิน', '🔥'),
    ];

    return Row(
      children: moods.map((item) {
        final selected = currentMood == item.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFCDEDE7)
                    : const Color(0xFFF2F7F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF7AC0B8)
                      : const Color(0xFFD9E6E4),
                ),
              ),
              child: Column(
                children: [
                  Text(item.$3, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF355A62),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EnergyChips extends StatelessWidget {
  const _EnergyChips({
    required this.currentEnergy,
    required this.filterLabels,
    required this.energyLevelFilter,
    required this.onFilterSelected,
  });

  final EnergyLevel currentEnergy;
  final List<String?> filterLabels;
  final String? energyLevelFilter;
  final ValueChanged<String?> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filterLabels.map((energyLevel) {
        final label = energyLevel == null ? 'All' : energyLevel.toUpperCase();
        final isSelected = energyLevelFilter == energyLevel;

        return ChoiceChip(
          label: Text(
            energyLevel == null ? label : '$label Energy',
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF17343C)
                  : const Color(0xFF5E7178),
              fontWeight: FontWeight.w700,
            ),
          ),
          selected: isSelected,
          selectedColor: const Color(0xFFE3F3EF),
          backgroundColor: const Color(0xFFF2F7F6),
          onSelected: (_) => onFilterSelected(energyLevel),
        );
      }).toList(),
    );
  }
}

class _RestingModeCard extends StatelessWidget {
  const _RestingModeCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFEAF6F0) : const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled ? const Color(0xFF92CDBA) : const Color(0xFFD7E6E3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF87BFAF)
                  : const Color(0xFFE1EAE8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              enabled ? Icons.bedtime_rounded : Icons.spa_rounded,
              color: enabled ? Colors.white : const Color(0xFF69817D),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'วันนี้ขอนั่งนิ่ง ๆ ก่อนนะ',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17343C),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'เปิดเมื่อต้องการพักอย่างปลอดภัย ระบบจะบันทึกเป็น Rest Day ให้หมอเห็น',
                  style: TextStyle(color: Color(0xFF5E7474), fontSize: 12.5),
                ),
              ],
            ),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RestingCompanionCard extends StatelessWidget {
  const _RestingCompanionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6D7A5)),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F1EC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFCFE0D7)),
            ),
            child: const Icon(
              Icons.nightlight_round,
              color: Color(0xFF79A896),
              size: 40,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สัตว์คู่ใจนอนพักอยู่ข้าง ๆ คุณ',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17343C),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'วันนี้ไม่ต้องเลือกเควสก็ได้ การพักนี้จะถูกบันทึกว่าเป็นการดูแลตัวเอง ไม่ใช่การหลีกเลี่ยง',
                  style: TextStyle(color: Color(0xFF657A72), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestChargeDeck extends StatelessWidget {
  const _QuestChargeDeck({
    required this.quests,
    required this.onAccept,
    required this.onReject,
    required this.onPreviewEnergy,
  });

  final List<QuestItem> quests;
  final ValueChanged<QuestItem> onAccept;
  final ValueChanged<QuestItem> onReject;
  final ValueChanged<QuestItem> onPreviewEnergy;

  @override
  Widget build(BuildContext context) {
    final topQuest = quests.isEmpty ? null : quests.first;
    final total = quests.length;

    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: const Color(0xFFDDF4EC).withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E8B84).withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: IconButton(
              onPressed: topQuest == null ? null : () => onReject(topQuest),
              icon: const Icon(Icons.chevron_left_rounded, size: 38),
              color: const Color(0xFF18313A),
            ),
          ),
          Positioned(
            right: 0,
            child: IconButton(
              onPressed: topQuest == null ? null : () => onAccept(topQuest),
              icon: const Icon(Icons.chevron_right_rounded, size: 38),
              color: const Color(0xFF18313A),
            ),
          ),
          Positioned(
            left: 48,
            right: 48,
            top: 26,
            bottom: 34,
            child: GestureDetector(
              onTap: topQuest == null ? null : () => onPreviewEnergy(topQuest),
              onHorizontalDragEnd: (details) {
                if (topQuest == null) return;
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 0) {
                  onAccept(topQuest);
                } else if (velocity < 0) {
                  onReject(topQuest);
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = quests.take(5).length - 1; i >= 1; i--)
                    Transform.translate(
                      offset: Offset(i * 8.0, i * 6.0),
                      child: _ChargeStackSheet(opacity: 1 - (i * 0.08)),
                    ),
                  _ChargeQuestCard(
                    quest: topQuest,
                    position: topQuest == null ? 0 : 1,
                    total: total,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 9,
            child: Text(
              topQuest == null ? '' : 'เลือกได้ไม่จำกัด ปัดขวาเพื่อเก็บเควส',
              style: const TextStyle(
                color: Color(0xFF5E837E),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestDeckEmptyCompanion extends StatelessWidget {
  const _QuestDeckEmptyCompanion({
    required this.selectedCount,
    required this.onReload,
  });

  final int selectedCount;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final hasSelected = selectedCount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF9F4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCFE4DC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E8B84).withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/island_parts/rejoy_bot.png',
            width: 78,
            height: 78,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSelected
                      ? 'พักกองการ์ดไว้ก่อนนะ'
                      : 'วันนี้ยังไม่มีเควสใหม่',
                  style: const TextStyle(
                    color: Color(0xFF17343C),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasSelected
                      ? 'คุณเลือกเควสไว้แล้ว ลองไปทำเท่าที่ไหวก่อนก็พอ ค่อยกลับมารับเพิ่มได้เสมอ ไม่มีอะไรต้องรีบเลยนะ'
                      : 'ลองกดรีเฟรชหรือเปลี่ยนระดับพลังงานได้เลย ถ้ายังไม่พร้อมก็พักกับเราตรงนี้ก่อนได้',
                  style: const TextStyle(
                    color: Color(0xFF557079),
                    height: 1.42,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => onReload(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('ลองรับเควสใหม่'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChargeStackSheet extends StatelessWidget {
  const _ChargeStackSheet({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.45, 1),
      child: Container(
        width: 178,
        height: 126,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargeQuestCard extends StatelessWidget {
  const _ChargeQuestCard({
    required this.quest,
    required this.position,
    required this.total,
  });

  final QuestItem? quest;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      height: 126,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: quest == null
          ? const Center(
              child: Text(
                'No quest',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เควสที่ $position จาก $total',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  quest!.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17343C),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Text(
                    quest!.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF536D66),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      height: 1.22,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _QuestTinderDeck extends StatefulWidget {
  const _QuestTinderDeck({
    required this.quests,
    required this.onAccept,
    required this.onReject,
    required this.onPreviewEnergy,
  });

  final List<QuestItem> quests;
  final ValueChanged<QuestItem> onAccept;
  final ValueChanged<QuestItem> onReject;
  final ValueChanged<QuestItem> onPreviewEnergy;

  @override
  State<_QuestTinderDeck> createState() => _QuestTinderDeckState();
}

class _QuestTinderDeckState extends State<_QuestTinderDeck> {
  static const double _acceptThreshold = 110;
  static const double _rejectThreshold = -110;

  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0;
  bool _swiping = false;

  QuestItem? get _topQuest =>
      widget.quests.isEmpty ? null : widget.quests.first;

  Color _colorFromHex(String hex) {
    final value = hex.replaceAll('#', '');
    if (value.length != 6) {
      return const Color(0xFF7BC8BE);
    }
    return Color(int.parse('FF$value', radix: 16));
  }

  Future<void> _animateCardAway(bool accepted) async {
    final width = MediaQuery.of(context).size.width;
    final targetX = accepted ? width * 1.15 : -width * 1.15;

    setState(() {
      _swiping = true;
      _dragOffset = Offset(targetX, _dragOffset.dy);
      _dragAngle = accepted ? 0.22 : -0.22;
    });

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    setState(() {
      _dragOffset = Offset.zero;
      _dragAngle = 0;
      _swiping = false;
    });
  }

  Future<void> _acceptTop() async {
    final quest = _topQuest;
    if (quest == null || _swiping) return;
    await _animateCardAway(true);
    if (!mounted) return;
    widget.onAccept(quest);
  }

  Future<void> _rejectTop() async {
    final quest = _topQuest;
    if (quest == null || _swiping) return;
    await _animateCardAway(false);
    if (!mounted) return;
    widget.onReject(quest);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_swiping) return;
    setState(() {
      _dragOffset += details.delta;
      _dragAngle = (_dragOffset.dx / 420).clamp(-0.25, 0.25);
    });
  }

  Future<void> _onPanEnd() async {
    if (_swiping) return;
    final quest = _topQuest;
    if (quest == null) return;

    if (_dragOffset.dx >= _acceptThreshold) {
      await _acceptTop();
      return;
    }
    if (_dragOffset.dx <= _rejectThreshold) {
      await _rejectTop();
      return;
    }

    setState(() {
      _dragOffset = Offset.zero;
      _dragAngle = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleQuests = widget.quests.take(3).toList();
    final topQuest = visibleQuests.isEmpty ? null : visibleQuests.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = visibleQuests.length - 1; i >= 0; i--)
                _QuestDeckCard(
                  quest: visibleQuests[i],
                  color: _colorFromHex(visibleQuests[i].color),
                  depth: visibleQuests.length - 1 - i,
                  isTop: i == 0,
                  dragOffset: i == 0 ? _dragOffset : Offset.zero,
                  dragAngle: i == 0 ? _dragAngle : 0,
                  onPanUpdate: i == 0 ? _onPanUpdate : null,
                  onPanEnd: i == 0 ? _onPanEnd : null,
                  onPreviewEnergy: () =>
                      widget.onPreviewEnergy(visibleQuests[i]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton.icon(
              onPressed: _swiping ? null : _rejectTop,
              icon: const Icon(Icons.close),
              label: const Text('Skip'),
            ),
            const Spacer(),
            Text(
              topQuest == null ? '' : 'ลองปัดการ์ดบนสุด',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5F757B)),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _swiping ? null : _acceptTop,
              icon: const Icon(Icons.favorite),
              label: const Text('Take'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuestDeckCard extends StatelessWidget {
  const _QuestDeckCard({
    required this.quest,
    required this.color,
    required this.depth,
    required this.isTop,
    required this.dragOffset,
    required this.dragAngle,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPreviewEnergy,
  });

  final QuestItem quest;
  final Color color;
  final int depth;
  final bool isTop;
  final Offset dragOffset;
  final double dragAngle;
  final ValueChanged<DragUpdateDetails>? onPanUpdate;
  final VoidCallback? onPanEnd;
  final VoidCallback onPreviewEnergy;

  @override
  Widget build(BuildContext context) {
    final scale = 1 - (depth * 0.06);
    final topOffset = depth * 14.0;
    final opacity = (1 - (depth * 0.14)).clamp(0.55, 1.0);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !isTop,
        child: Transform.translate(
          offset: Offset(dragOffset.dx, dragOffset.dy + topOffset),
          child: Transform.rotate(
            angle: isTop ? dragAngle : 0,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: GestureDetector(
                      onPanUpdate: onPanUpdate == null
                          ? null
                          : (details) => onPanUpdate!(details),
                      onPanEnd: onPanEnd == null ? null : (_) => onPanEnd!(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              color.withValues(alpha: 0.16),
                            ],
                          ),
                          border: Border.all(color: const Color(0xFFD7E6E3)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: depth == 0
                              ? _TopQuestCardBody(
                                  quest: quest,
                                  color: color,
                                  onPreviewEnergy: onPreviewEnergy,
                                )
                              : _StackedQuestCardBody(
                                  quest: quest,
                                  color: color,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopQuestCardBody extends StatelessWidget {
  const _TopQuestCardBody({
    required this.quest,
    required this.color,
    required this.onPreviewEnergy,
  });

  final QuestItem quest;
  final Color color;
  final VoidCallback onPreviewEnergy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF17343C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    quest.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF557079),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _EnergyBadge(label: quest.energyLevel.toUpperCase(), color: color),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(label: 'Pastel companion: ${quest.animalId}'),
            _Tag(label: _gentleEnergyLabel(quest.energyLevel)),
            _Tag(label: 'Small step'),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            TextButton.icon(
              onPressed: onPreviewEnergy,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview energy'),
            ),
            const Spacer(),
            const _SwipeHint(label: '← Skip', color: Color(0xFFE37C7C)),
            const SizedBox(width: 10),
            const _SwipeHint(label: 'Take →', color: Color(0xFF68BFA4)),
          ],
        ),
      ],
    );
  }
}

class _StackedQuestCardBody extends StatelessWidget {
  const _StackedQuestCardBody({required this.quest, required this.color});

  final QuestItem quest;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            quest.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17343C),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _EnergyBadge(label: quest.energyLevel.toUpperCase(), color: color),
      ],
    );
  }
}

class _SelectedQuestsBoard extends StatelessWidget {
  const _SelectedQuestsBoard({
    required this.selectedQuests,
    required this.completedQuestIds,
    required this.onToggleCompleted,
    required this.onRemove,
  });

  final List<QuestItem> selectedQuests;
  final Set<String> completedQuestIds;
  final ValueChanged2<QuestItem, bool> onToggleCompleted;
  final ValueChanged<QuestItem> onRemove;

  @override
  Widget build(BuildContext context) {
    return _SoftSectionCard(
      title: 'ช่องเก็บเควสของวันนี้',
      subtitle: 'เก็บเควสได้ไม่จำกัด แล้วติ๊กเฉพาะอันที่ทำสำเร็จ',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (selectedQuests.isEmpty)
            const _EmptyQuestSlot()
          else
            ...selectedQuests.map(
              (quest) => _QuestSlotCard(
                quest: quest,
                checked: completedQuestIds.contains(quest.id),
                onChanged: (value) => onToggleCompleted(quest, value ?? false),
                onRemove: () => onRemove(quest),
              ),
            ),
          if (selectedQuests.isNotEmpty && selectedQuests.length < 3)
            ...List.generate(
              3 - selectedQuests.length,
              (_) => const _EmptyQuestSlot(),
            ),
        ],
      ),
    );
  }
}

class _QuestSlotCard extends StatelessWidget {
  const _QuestSlotCard({
    required this.quest,
    required this.checked,
    required this.onChanged,
    required this.onRemove,
  });

  final QuestItem quest;
  final bool checked;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4E4E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(value: checked, onChanged: onChanged),
              Expanded(
                child: Text(
                  quest.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF20383F),
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close),
                tooltip: 'Remove',
              ),
            ],
          ),
          Text(
            '${quest.energyLevel.toUpperCase()} · ${quest.animalId}',
            style: const TextStyle(color: Color(0xFF607A81), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptyQuestSlot extends StatelessWidget {
  const _EmptyQuestSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFD0CD)),
      ),
      child: const Text(
        'วางเควสที่นี่',
        style: TextStyle(color: Color(0xFF8DA2A2), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FinishDayButton extends StatelessWidget {
  const _FinishDayButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
    required this.subtitle,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: enabled
                ? const Color(0xFFDCA543)
                : const Color(0xFFCAD6D5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: enabled ? onPressed : null,
          child: Text(label, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6A8387)),
        ),
      ],
    );
  }
}

class _SoftSectionCard extends StatelessWidget {
  const _SoftSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFA),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD5E5E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF16323A),
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF5D757B))),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2DE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D7A6)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF6A4A00))),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF3D5F66), fontSize: 12),
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E6E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B858B)),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF18323A),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF17343C),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _EnergyBadge extends StatelessWidget {
  const _EnergyBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD5E5E2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5F757B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17343C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF5D757B)),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _NotebookPaper extends StatelessWidget {
  const _NotebookPaper({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2D1A3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _NotebookPaperPainter()),
            ),
            Positioned(
              left: 28,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: const Color(0xFFE9B3A7)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(44, 28, 22, 18),
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'วันนี้ฉันอยากบอกว่า...',
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.65,
                  color: Color(0xFF463914),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotebookPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFE8DFC4)
      ..strokeWidth = 1;

    for (double y = 58; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TimeCapsuleStats extends StatelessWidget {
  const _TimeCapsuleStats({
    required this.moodLabel,
    required this.energyLabel,
    required this.completionLabel,
  });

  final String moodLabel;
  final String energyLabel;
  final String completionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0E4DD)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Tag(label: 'Mood: $moodLabel'),
          _Tag(label: 'Energy: $energyLabel'),
          _Tag(label: 'CBT: $completionLabel'),
        ],
      ),
    );
  }
}

class _MemoryVault extends StatelessWidget {
  const _MemoryVault({
    required this.notePreview,
    required this.onTap,
    required this.onPrintDoctorPdf,
    required this.exportingPdf,
  });

  final String? notePreview;
  final VoidCallback onTap;
  final VoidCallback onPrintDoctorPdf;
  final bool exportingPdf;

  @override
  Widget build(BuildContext context) {
    final hasNote = notePreview != null && notePreview!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD1E3D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE4D3A4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3B865),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFB98434)),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'คลังสะสมความในใจ',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF17343C),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'ข้อมูลนี้จะถูกเก็บใน PDF สำหรับพิมพ์ให้หมอ',
                          style: TextStyle(
                            color: Color(0xFF6C7F79),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          hasNote
                              ? notePreview!
                              : 'แตะเพื่อเขียนความในใจของวันนี้',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasNote
                                ? const Color(0xFF4B3E1A)
                                : const Color(0xFF9A8B65),
                            height: 1.45,
                            fontStyle: hasNote
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(hasNote ? 'แก้ไขความในใจ' : 'เขียนความในใจ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF416E65),
                    side: const BorderSide(color: Color(0xFFBBD3CB)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: exportingPdf ? null : onPrintDoctorPdf,
                  icon: exportingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(
                    exportingPdf
                        ? 'กำลังสร้าง PDF'
                        : 'พิมพ์ให้หมอ / Export PDF',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD3A948),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef ValueChanged2<T, U> = void Function(T value, U value2);
