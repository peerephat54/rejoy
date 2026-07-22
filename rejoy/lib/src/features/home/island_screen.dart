import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/rejoy_session.dart';
import '../../services/rejoy_api_client.dart';

class IslandScreen extends StatefulWidget {
  const IslandScreen({
    super.key,
    required this.session,
    required this.onMoodSelected,
    required this.onCrisisSelected,
    required this.onChatSelected,
    required this.onSosSelected,
  });

  final ReJoySession session;
  final ValueChanged<MoodState> onMoodSelected;
  final ValueChanged<CrisisLevel> onCrisisSelected;
  final VoidCallback onChatSelected;
  final VoidCallback onSosSelected;

  @override
  State<IslandScreen> createState() => _IslandScreenState();
}

class _IslandScreenState extends State<IslandScreen>
    with SingleTickerProviderStateMixin {
  late final ReJoyApiClient _client;
  late final AnimationController _controller;
  Future<_IslandData>? _islandFuture;
  int? _demoWeatherScore;

  @override
  void initState() {
    super.initState();
    _client = ReJoyApiClient();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _islandFuture = _loadIsland();
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<_IslandData> _loadIsland() async {
    try {
      final profile = await _client.fetchActiveClinicalProfile();
      final latestReport = profile.reports.isEmpty
          ? null
          : profile.reports.first;
      return _IslandData(
        user: profile.user,
        phq9Score:
            latestReport?.phq9Score ?? profile.user.completedQuestsCount % 9,
        animals: profile.user.unlockedAnimals.take(8).toList(),
        animalNicknames: profile.user.animalNicknames,
        backendOnline: true,
        backendLabel: 'DB connected',
      );
    } catch (_) {
      return _IslandData(
        user: null,
        phq9Score: _scoreFromSession(widget.session.mood),
        animals: const [],
        animalNicknames: const {},
        backendOnline: false,
        backendLabel: 'offline preview',
      );
    }
  }

  int _scoreFromSession(MoodState mood) {
    return switch (mood) {
      MoodState.calm => 2,
      MoodState.hopeful => 4,
      MoodState.tired => 9,
      MoodState.heavy => 16,
      MoodState.crisis => 22,
    };
  }

  void _selectDemoWeather(_WeatherPreset preset) {
    widget.onMoodSelected(preset.mood);
    setState(() {
      _demoWeatherScore = preset.phq9Score;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _islandFuture = _loadIsland();
    });
    await _islandFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_IslandData>(
      future: _islandFuture,
      builder: (context, snapshot) {
        final data =
            snapshot.data ??
            _IslandData(
              user: null,
              phq9Score: _scoreFromSession(widget.session.mood),
              animals: const [],
              animalNicknames: const {},
              backendOnline: false,
              backendLabel: 'loading island',
            );
        final displayPhq9Score = _demoWeatherScore ?? data.phq9Score;
        final weather = _IslandWeather.fromPhq9(displayPhq9Score);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: weather.skyColors,
                ),
              ),
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 390),
                          child: Container(
                            height: math.min(
                              MediaQuery.of(context).size.height * 0.84,
                              720,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(34),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.72),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF41616A,
                                  ).withValues(alpha: 0.18),
                                  blurRadius: 34,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(34),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 650),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: Stack(
                                  key: ValueKey(weather.kind),
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: RepaintBoundary(
                                        child: CustomPaint(
                                          painter: _IslandPainter(
                                            weather: weather,
                                            progress: _controller.value,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final bob =
                                              math.sin(
                                                _controller.value * math.pi * 2,
                                              ) *
                                              4;
                                          return Align(
                                            alignment: const Alignment(0, 0.08),
                                            child: Transform.translate(
                                              offset: Offset(0, bob),
                                              child: _IslandAsset(
                                                width:
                                                    constraints.maxWidth * 1.16,
                                                weather: weather,
                                                progress: _controller.value,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      top: 58,
                                      left: -44,
                                      right: -44,
                                      child: _GloomyCloudCanopy(
                                        progress: _controller.value,
                                        weather: weather,
                                      ),
                                    ),
                                    Positioned(
                                      top: 22,
                                      left: 0,
                                      right: 0,
                                      child: _IslandSceneTitle(
                                        weather: weather,
                                      ),
                                    ),
                                    Positioned(
                                      top: 108,
                                      left: 24,
                                      child: _ChatBotPortalButton(
                                        progress: _controller.value,
                                        onPressed: widget.onChatSelected,
                                      ),
                                    ),
                                    Positioned(
                                      top: 82,
                                      right: 30,
                                      child: _LighthousePortalButton(
                                        progress: _controller.value,
                                        onPressed: widget.onSosSelected,
                                      ),
                                    ),
                                    ..._animalWidgets(data, weather),
                                    if (data.animals.isEmpty)
                                      Positioned(
                                        left: 28,
                                        right: 28,
                                        bottom: 82,
                                        child: _EmptyAnimalGuide(
                                          weather: weather,
                                        ),
                                      ),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: RepaintBoundary(
                                          child: CustomPaint(
                                            painter: _FrontWeatherPainter(
                                              weather: weather,
                                              progress: _controller.value,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 390),
                          child: _WeatherModePicker(
                            selectedScore: displayPhq9Score,
                            onSelected: _selectDemoWeather,
                          ),
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
  }

  List<Widget> _animalWidgets(_IslandData data, _IslandWeather weather) {
    final animals = data.animals;
    if (animals.isEmpty) return const [];
    final safeAnimals = animals;
    final positions = [
      const Offset(0.34, 0.49),
      const Offset(0.46, 0.46),
      const Offset(0.56, 0.51),
      const Offset(0.40, 0.58),
      const Offset(0.61, 0.59),
      const Offset(0.30, 0.57),
      const Offset(0.50, 0.61),
      const Offset(0.66, 0.50),
    ];

    return List.generate(math.min(safeAnimals.length, positions.length), (
      index,
    ) {
      final phase = (_controller.value + index * 0.17) % 1;
      final bob = math.sin(phase * math.pi * 2) * 5;
      final sway = math.cos(phase * math.pi * 2) * 4;
      final animal = _PastelAnimal.fromId(safeAnimals[index], index);
      final animalId = safeAnimals[index];
      final nickname = data.animalNicknames[animalId] ?? '';
      final pos = positions[index];

      return Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Transform.translate(
              offset: Offset(
                constraints.maxWidth * pos.dx + sway - 26,
                constraints.maxHeight * pos.dy + bob - 26,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: data.user == null
                      ? null
                      : () => _openAnimalNameDialog(
                          user: data.user!,
                          animalId: animalId,
                          defaultName: animal.name,
                          currentNickname: nickname,
                        ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnimalNameTag(
                        name: nickname.isEmpty ? animal.name : nickname,
                      ),
                      _AnimalSprite(
                        animal: animal,
                        sleepy: weather.kind == _WeatherKind.storm,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Future<void> _openAnimalNameDialog({
    required BackendUser user,
    required String animalId,
    required String defaultName,
    required String currentNickname,
  }) async {
    final controller = TextEditingController(
      text: currentNickname.isEmpty ? defaultName : currentNickname,
    );

    final nickname = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF8FCFB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('ตั้งชื่อเพื่อนบนเกาะ'),
          content: TextField(
            controller: controller,
            maxLength: 24,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'ชื่อสัตว์',
              hintText: 'เช่น มะลิ, เจ้าก้อนเมฆ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('ลบชื่อ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (nickname == null || !mounted) return;

    try {
      await _client.saveAnimalNickname(
        user: user,
        animalId: animalId,
        nickname: nickname,
      );
      if (!mounted) return;
      setState(() {
        _islandFuture = _loadIsland();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกชื่อสัตว์ไม่สำเร็จ: $error')),
      );
    }
  }
}

// ignore: unused_element
class _IslandTopBar extends StatelessWidget {
  const _IslandTopBar({
    required this.weather,
    required this.phq9Score,
    required this.backendOnline,
    required this.backendLabel,
    required this.onRefresh,
  });

  final _IslandWeather weather;
  final int phq9Score;
  final bool backendOnline;
  final String backendLabel;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: weather.badgeColors),
              boxShadow: [
                BoxShadow(
                  color: weather.badgeColors.last.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(weather.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The Island Home',
                  style: TextStyle(
                    color: Color(0xFF17343C),
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${weather.title} • PHQ-9 ล่าสุด $phq9Score/27',
                  style: TextStyle(
                    color: weather.textColor.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: backendLabel,
            child: Icon(
              backendOnline
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              color: backendOnline
                  ? const Color(0xFF3C9C78)
                  : const Color(0xFF9AA5AA),
            ),
          ),
        ],
      ),
    );
  }
}

class _IslandAsset extends StatelessWidget {
  const _IslandAsset({
    required this.width,
    required this.weather,
    required this.progress,
  });

  final double width;
  final _IslandWeather weather;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final isStormy =
        weather.kind == _WeatherKind.storm || weather.kind == _WeatherKind.rain;
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(math.sin(progress * math.pi * 2) * 5, width * 0.29),
          child: CustomPaint(
            size: Size(width * 1.03, width * 0.24),
            painter: _IslandReflectionPainter(
              progress: progress,
              stormy: isStormy,
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(0, width * 0.26),
          child: Container(
            width: width * 0.92,
            height: width * 0.16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF1F3942,
                  ).withValues(alpha: isStormy ? 0.34 : 0.18),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),
        Image.asset(
          'assets/images/island_parts/island_full.png',
          width: width,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ],
    );
  }
}

class _IslandSceneTitle extends StatelessWidget {
  const _IslandSceneTitle({required this.weather});

  final _IslandWeather weather;

  @override
  Widget build(BuildContext context) {
    final isStorm = weather.kind == _WeatherKind.storm;
    final titleColor = isStorm
        ? Colors.white.withValues(alpha: 0.92)
        : const Color(0xFF244954);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'The Island Home',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(
                      alpha: isStorm ? 0.34 : 0.10,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Icon(
            Icons.settings_outlined,
            color: titleColor.withValues(alpha: 0.88),
            size: 31,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: isStorm ? 0.28 : 0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GloomyCloudCanopy extends StatelessWidget {
  const _GloomyCloudCanopy({required this.progress, required this.weather});

  final double progress;
  final _IslandWeather weather;

  @override
  Widget build(BuildContext context) {
    if (weather.kind == _WeatherKind.sunny) {
      return const SizedBox.shrink();
    }
    final cloudAsset = weather.kind == _WeatherKind.cloudy
        ? 'assets/images/island_parts/cloud_neutral.png'
        : 'assets/images/island_parts/cloud_sad.png';
    final stormAlpha = weather.kind == _WeatherKind.cloudy ? 0.70 : 0.86;
    final drift = math.sin(progress * math.pi * 2) * 14;
    return IgnorePointer(
      child: Opacity(
        opacity: stormAlpha,
        child: Transform.translate(
          offset: Offset(drift, 0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 520),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Image.asset(
              cloudAsset,
              key: ValueKey(cloudAsset),
              height: weather.kind == _WeatherKind.cloudy ? 126 : 138,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBotPortalButton extends StatelessWidget {
  const _ChatBotPortalButton({required this.progress, required this.onPressed});

  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bob = math.sin(progress * math.pi * 2) * 6;
    return Tooltip(
      message: 'คุยกับ ReJoy bot',
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onPressed,
        child: Transform.translate(
          offset: Offset(0, bob),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE9FBFF),
                  Color(0xFFD7C8FF),
                  Color(0xFFFFE3D7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF233644).withValues(alpha: 0.34),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.92),
                        const Color(0xFFE5FBFF).withValues(alpha: 0.86),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F8791).withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/images/island_parts/rejoy_bot.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LighthousePortalButton extends StatelessWidget {
  const _LighthousePortalButton({
    required this.progress,
    required this.onPressed,
  });

  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final glow = 0.55 + math.sin(progress * math.pi * 2) * 0.22;
    return Tooltip(
      message: 'เข้า SOS',
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFE4A3).withValues(alpha: glow),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/island_parts/lighthouse.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'SOS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _TinyLighthousePainter extends CustomPainter {
  const _TinyLighthousePainter({required this.glow});

  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final light = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFE8A6).withValues(alpha: glow),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: c + const Offset(0, -24), radius: 44),
          );
    canvas.drawCircle(c + const Offset(0, -24), 44, light);

    final outline = Paint()
      ..color = const Color(0xFF703B35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final tower = Path()
      ..moveTo(c.dx - 15, size.height - 6)
      ..lineTo(c.dx - 10, 30)
      ..quadraticBezierTo(c.dx, 24, c.dx + 10, 30)
      ..lineTo(c.dx + 15, size.height - 6)
      ..close();
    canvas.drawPath(tower, Paint()..color = const Color(0xFFFFF2E4));
    canvas.drawPath(tower, outline);

    for (var i = 0; i < 3; i++) {
      final y = 38.0 + i * 15;
      canvas.drawRect(
        Rect.fromLTWH(c.dx - 12, y, 24, 6),
        Paint()..color = const Color(0xFFE87365),
      );
    }
    final roof = Path()
      ..moveTo(c.dx - 20, 25)
      ..lineTo(c.dx, 6)
      ..lineTo(c.dx + 20, 25)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFE86D61));
    canvas.drawPath(roof, outline);
    canvas.drawCircle(
      c + const Offset(0, -8),
      8,
      Paint()..color = const Color(0xFFFFDC83),
    );
  }

  @override
  bool shouldRepaint(covariant _TinyLighthousePainter oldDelegate) {
    return oldDelegate.glow != glow;
  }
}

// ignore: unused_element
class _SosLighthouseButton extends StatelessWidget {
  const _SosLighthouseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.light_rounded, color: Color(0xFFE76F51), size: 30),
            SizedBox(height: 2),
            Text(
              'SOS',
              style: TextStyle(
                color: Color(0xFF6A3E35),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _IslandStatsStrip extends StatelessWidget {
  const _IslandStatsStrip({
    required this.weather,
    required this.animalCount,
    required this.phq9Score,
  });

  final _IslandWeather weather;
  final int animalCount;
  final int phq9Score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF41616A).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _MiniIslandMetric(
            icon: Icons.water_drop_rounded,
            label: 'Weather',
            value: weather.title,
          ),
          _MiniIslandMetric(
            icon: Icons.pets_rounded,
            label: 'Fauna',
            value: '$animalCount ตัว',
          ),
          _MiniIslandMetric(
            icon: Icons.favorite_rounded,
            label: 'PHQ-9',
            value: '$phq9Score',
          ),
        ],
      ),
    );
  }
}

class _MiniIslandMetric extends StatelessWidget {
  const _MiniIslandMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF62A7A5), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6A8387),
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF20383F),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimalSprite extends StatelessWidget {
  const _AnimalSprite({required this.animal, required this.sleepy});

  final _PastelAnimal animal;
  final bool sleepy;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 260),
      opacity: sleepy ? 0.72 : 1,
      child: Container(
        width: animal.size,
        height: animal.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF23464D).withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Image.asset(
          animal.assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _EmptyAnimalGuide extends StatelessWidget {
  const _EmptyAnimalGuide({required this.weather});

  final _IslandWeather weather;

  @override
  Widget build(BuildContext context) {
    final stormy =
        weather.kind == _WeatherKind.rain || weather.kind == _WeatherKind.storm;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: stormy ? 0.82 : 0.70),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF284D55).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F6F1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: Color(0xFF5F9B91),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'ทำภารกิจเล็ก ๆ ให้ครบ แล้วสัตว์ตัวแรกจะค่อย ๆ เข้ามาพักอาศัยบนเกาะของคุณ',
              style: TextStyle(
                color: Color(0xFF24474E),
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IslandPainter extends CustomPainter {
  const _IslandPainter({required this.weather, required this.progress});

  final _IslandWeather weather;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackdropGlow(canvas, size);
    _drawAtmosphere(canvas, size);
    _drawSea(canvas, size);
    if (weather.kind != _WeatherKind.sunny) _drawRain(canvas, size);
    _drawSoftVignette(canvas, size);
  }

  void _drawBackdropGlow(Canvas canvas, Size size) {
    if (weather.kind == _WeatherKind.storm) {
      final stormShade = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E2735), Color(0xFF6F8796)],
        ).createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, stormShade);
    }

    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.32),
              Colors.white.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.50, size.height * 0.38),
              radius: size.width * 0.56,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.38),
      size.width * 0.56,
      glowPaint,
    );
  }

  void _drawAtmosphere(Canvas canvas, Size size) {
    if (weather.kind == _WeatherKind.storm) {
      for (var i = 0; i < 5; i++) {
        final drift = math.sin(progress * math.pi * 2 + i * 0.72) * 28;
        final x = size.width * (-0.05 + i * 0.28) + drift;
        final y = size.height * (0.10 + (i % 2) * 0.05);
        _drawStormCloud(canvas, Offset(x, y), 1.25 + (i % 3) * 0.18);
      }
    }

    final sunPaint = Paint()
      ..shader =
          RadialGradient(
            colors: weather.kind == _WeatherKind.storm
                ? [Colors.white.withValues(alpha: 0.10), Colors.transparent]
                : [
                    const Color(0xFFFFF2A8).withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.22, size.height * 0.13),
              radius: 96,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.13),
      96,
      sunPaint,
    );

    for (var i = 0; i < 6; i++) {
      final drift = math.sin(progress * math.pi * 2 + i * 0.64) * 34;
      final x = size.width * (0.08 + i * 0.18) + drift;
      final y = size.height * (0.12 + (i % 3) * 0.08);
      _drawCloud(canvas, Offset(x, y), 0.78 + i * 0.04);
    }
  }

  void _drawStormCloud(Canvas canvas, Offset offset, double scale) {
    final shadowPaint = Paint()
      ..color = const Color(0xFF1F2A38).withValues(alpha: 0.54)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final bodyPaint = Paint()
      ..shader =
          const LinearGradient(
            colors: [Color(0xFF303C4D), Color(0xFF556274)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(
            Rect.fromCenter(
              center: offset,
              width: 150 * scale,
              height: 72 * scale,
            ),
          );

    for (final center in [
      offset + Offset(-36 * scale, 4 * scale),
      offset + Offset(0, -10 * scale),
      offset + Offset(38 * scale, 5 * scale),
      offset + Offset(68 * scale, 14 * scale),
    ]) {
      canvas.drawCircle(center + const Offset(0, 6), 36 * scale, shadowPaint);
      canvas.drawCircle(center, 35 * scale, bodyPaint);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: offset + Offset(20 * scale, 18 * scale),
          width: 150 * scale,
          height: 52 * scale,
        ),
        Radius.circular(30 * scale),
      ),
      bodyPaint,
    );
  }

  void _drawCloud(Canvas canvas, Offset offset, double scale) {
    final paint = Paint()
      ..color = weather.cloudColor.withValues(
        alpha: weather.kind == _WeatherKind.sunny ? 0.32 : 0.64,
      );
    canvas.drawOval(
      Rect.fromCenter(center: offset, width: 72 * scale, height: 34 * scale),
      paint,
    );
    canvas.drawCircle(
      offset + Offset(-20 * scale, -8 * scale),
      20 * scale,
      paint,
    );
    canvas.drawCircle(
      offset + Offset(10 * scale, -13 * scale),
      25 * scale,
      paint,
    );
    canvas.drawCircle(
      offset + Offset(33 * scale, -5 * scale),
      17 * scale,
      paint,
    );
  }

  void _drawSea(Canvas canvas, Size size) {
    final seaPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: weather.seaColors,
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.45,
              size.width,
              size.height * 0.55,
            ),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.55),
      seaPaint,
    );

    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.70 + i * 0.045);
      final path = Path();
      for (var x = -20.0; x <= size.width + 20; x += 18) {
        final wave = math.sin((x / 34) + progress * math.pi * 2 + i) * 5;
        if (x == -20) {
          path.moveTo(x, y + wave);
        } else {
          path.lineTo(x, y + wave);
        }
      }
      canvas.drawPath(path, wavePaint);
    }

    final reflectionPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.61 + i * 0.035);
      final path = Path()
        ..moveTo(size.width * 0.25, y)
        ..quadraticBezierTo(
          size.width * 0.50,
          y + math.sin(progress * math.pi * 2 + i) * 8,
          size.width * 0.75,
          y + 3,
        );
      canvas.drawPath(path, reflectionPaint);
    }
  }

  // ignore: unused_element
  void _drawIsland(Canvas canvas, Offset center, Size size) {
    final islandWidth = size.width * 0.72;
    final islandHeight = size.height * 0.20;
    final topCenter = Offset(center.dx, size.height * 0.48);
    final top = _islandTopPath(topCenter, islandWidth, islandHeight);
    final underside = _islandUndersidePath(
      topCenter,
      islandWidth,
      islandHeight,
    );

    final shadowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.black.withValues(alpha: 0.20), Colors.transparent],
          ).createShader(
            Rect.fromCenter(
              center: topCenter + Offset(0, islandHeight * 1.02),
              width: islandWidth * 0.96,
              height: islandHeight * 0.65,
            ),
          );
    canvas.drawOval(
      Rect.fromCenter(
        center: topCenter + Offset(0, islandHeight * 1.03),
        width: islandWidth * 0.95,
        height: islandHeight * 0.52,
      ),
      shadowPaint,
    );

    final undersidePaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B826F), Color(0xFF5E6771)],
          ).createShader(
            Rect.fromCenter(
              center: topCenter + Offset(0, islandHeight * 0.48),
              width: islandWidth,
              height: islandHeight * 1.25,
            ),
          );
    canvas.drawPath(underside, undersidePaint);

    final sideLinePaint = Paint()
      ..color = const Color(0xFF43515A).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 6; i++) {
      final x = topCenter.dx - islandWidth * 0.34 + i * islandWidth * 0.13;
      canvas.drawLine(
        Offset(x, topCenter.dy + islandHeight * 0.32),
        Offset(x - 8, topCenter.dy + islandHeight * (0.70 + (i % 2) * 0.08)),
        sideLinePaint,
      );
    }

    final grassPaint = Paint()
      ..shader =
          const LinearGradient(
            colors: [Color(0xFFC5E7AF), Color(0xFF75B98A), Color(0xFF4F9575)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(
            Rect.fromCenter(
              center: topCenter,
              width: islandWidth,
              height: islandHeight,
            ),
          );
    canvas.drawPath(top, grassPaint);

    final rimPaint = Paint()
      ..color = const Color(0xFF203B39).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawPath(top, rimPaint);

    final grassTexture = Paint()
      ..color = const Color(0xFF325C4D).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 34; i++) {
      final x = topCenter.dx - islandWidth * 0.38 + (i % 17) * islandWidth / 17;
      final y =
          topCenter.dy - islandHeight * 0.20 + (i ~/ 17) * islandHeight * 0.28;
      canvas.drawLine(Offset(x, y), Offset(x + 5, y - 8), grassTexture);
    }

    final pondPaint = Paint()
      ..color = const Color(0xFFA3DCE2).withValues(alpha: 0.92);
    final pondStroke = Paint()
      ..color = const Color(0xFF31525A).withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final pond in [
      Rect.fromCenter(
        center: topCenter + Offset(islandWidth * 0.22, islandHeight * 0.03),
        width: islandWidth * 0.18,
        height: islandHeight * 0.20,
      ),
      Rect.fromCenter(
        center: topCenter + Offset(-islandWidth * 0.12, islandHeight * 0.08),
        width: islandWidth * 0.13,
        height: islandHeight * 0.13,
      ),
      Rect.fromCenter(
        center: topCenter + Offset(islandWidth * 0.02, -islandHeight * 0.12),
        width: islandWidth * 0.12,
        height: islandHeight * 0.11,
      ),
    ]) {
      canvas.drawOval(pond, pondPaint);
      canvas.drawOval(pond, pondStroke);
    }

    final rockPaint = Paint()..color = const Color(0xFFE8EDE0);
    for (final rock in [
      topCenter + Offset(-islandWidth * 0.27, islandHeight * 0.05),
      topCenter + Offset(-islandWidth * 0.02, islandHeight * 0.16),
      topCenter + Offset(islandWidth * 0.12, -islandHeight * 0.18),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: rock, width: 24, height: 11),
        rockPaint,
      );
    }
  }

  Path _islandTopPath(Offset c, double w, double h) {
    return Path()
      ..moveTo(c.dx - w * 0.43, c.dy - h * 0.02)
      ..cubicTo(
        c.dx - w * 0.38,
        c.dy - h * 0.36,
        c.dx - w * 0.16,
        c.dy - h * 0.47,
        c.dx + w * 0.02,
        c.dy - h * 0.42,
      )
      ..cubicTo(
        c.dx + w * 0.28,
        c.dy - h * 0.47,
        c.dx + w * 0.46,
        c.dy - h * 0.25,
        c.dx + w * 0.45,
        c.dy + h * 0.02,
      )
      ..cubicTo(
        c.dx + w * 0.43,
        c.dy + h * 0.35,
        c.dx + w * 0.14,
        c.dy + h * 0.45,
        c.dx - w * 0.08,
        c.dy + h * 0.42,
      )
      ..cubicTo(
        c.dx - w * 0.34,
        c.dy + h * 0.45,
        c.dx - w * 0.50,
        c.dy + h * 0.25,
        c.dx - w * 0.43,
        c.dy - h * 0.02,
      )
      ..close();
  }

  Path _islandUndersidePath(Offset c, double w, double h) {
    return Path()
      ..moveTo(c.dx - w * 0.42, c.dy + h * 0.12)
      ..cubicTo(
        c.dx - w * 0.27,
        c.dy + h * 0.38,
        c.dx + w * 0.26,
        c.dy + h * 0.38,
        c.dx + w * 0.43,
        c.dy + h * 0.10,
      )
      ..cubicTo(
        c.dx + w * 0.36,
        c.dy + h * 0.82,
        c.dx + w * 0.17,
        c.dy + h * 1.03,
        c.dx,
        c.dy + h * 1.10,
      )
      ..cubicTo(
        c.dx - w * 0.18,
        c.dy + h * 1.02,
        c.dx - w * 0.36,
        c.dy + h * 0.78,
        c.dx - w * 0.42,
        c.dy + h * 0.12,
      )
      ..close();
  }

  // ignore: unused_element
  void _drawTree(Canvas canvas, Offset center, Size size) {
    final topCenter = Offset(center.dx, size.height * 0.48);
    final treeBase = topCenter + Offset(-size.width * 0.17, -6);
    final outline = Paint()
      ..color = const Color(0xFF203B39).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final trunk = Paint()..color = const Color(0xFF8D664D);
    final trunkRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: treeBase + const Offset(0, -22),
        width: 18,
        height: 72,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(trunkRect, trunk);
    canvas.drawRRect(trunkRect, outline);

    final leaf = Paint()
      ..shader =
          const LinearGradient(
            colors: [Color(0xFF8ACD93), Color(0xFF3E7257)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(
            Rect.fromCenter(
              center: treeBase + const Offset(-10, -78),
              width: 120,
              height: 90,
            ),
          );
    for (final offset in const [
      Offset(-20, -76),
      Offset(10, -78),
      Offset(-5, -102),
      Offset(-42, -84),
      Offset(32, -88),
    ]) {
      canvas.drawCircle(treeBase + offset, 31, leaf);
      canvas.drawCircle(treeBase + offset, 31, outline);
    }

    final fruitPaint = Paint()..color = const Color(0xFFF28C38);
    canvas.drawCircle(treeBase + const Offset(-18, -48), 8, fruitPaint);
  }

  // ignore: unused_element
  void _drawLighthouse(Canvas canvas, Offset center, Size size) {
    final topCenter = Offset(center.dx, size.height * 0.48);
    final base = topCenter + Offset(size.width * 0.18, -26);
    final white = Paint()..color = const Color(0xFFFFF6E7);
    final red = Paint()..color = const Color(0xFFE86A5A);
    final outline = Paint()
      ..color = const Color(0xFF203B39).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final light = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFEAA7).withValues(alpha: 0.85),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: base + const Offset(0, -52), radius: 58),
          );

    canvas.drawCircle(base + const Offset(0, -52), 58, light);
    final tower = RRect.fromRectAndRadius(
      Rect.fromCenter(center: base, width: 48, height: 126),
      const Radius.circular(15),
    );
    canvas.drawRRect(tower, white);
    canvas.drawRRect(tower, outline);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(base.dx - 24, base.dy - 50 + i * 36, 48, 12),
        red,
      );
    }
    final roof = Path()
      ..moveTo(base.dx - 30, base.dy - 68)
      ..lineTo(base.dx, base.dy - 98)
      ..lineTo(base.dx + 30, base.dy - 68)
      ..close();
    canvas.drawPath(roof, red);
    canvas.drawPath(roof, outline);
    canvas.drawCircle(
      base + const Offset(0, -58),
      9,
      Paint()..color = const Color(0xFFFFD978),
    );
  }

  void _drawRain(Canvas canvas, Size size) {
    final rainPaint = Paint()
      ..color = Colors.white.withValues(
        alpha: weather.kind == _WeatherKind.storm ? 0.36 : 0.24,
      )
      ..strokeWidth = weather.kind == _WeatherKind.storm ? 1.7 : 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 42; i++) {
      final x = (i * 37.0 + progress * 190) % (size.width + 80) - 40;
      final y = (i * 61.0 + progress * 360) % (size.height + 80) - 40;
      canvas.drawLine(Offset(x, y), Offset(x - 12, y + 32), rainPaint);
    }
  }

  void _drawSoftVignette(Canvas canvas, Size size) {
    final vignette = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.transparent,
              const Color(0xFF17343C).withValues(alpha: 0.05),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height * 0.55),
              radius: size.width * 0.78,
            ),
          );
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _IslandPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.weather != weather;
  }
}

class _FrontWeatherPainter extends CustomPainter {
  const _FrontWeatherPainter({required this.weather, required this.progress});

  final _IslandWeather weather;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (weather.kind == _WeatherKind.sunny ||
        weather.kind == _WeatherKind.cloudy) {
      return;
    }

    final rainPaint = Paint()
      ..color = Colors.white.withValues(
        alpha: weather.kind == _WeatherKind.storm ? 0.46 : 0.30,
      )
      ..strokeWidth = weather.kind == _WeatherKind.storm ? 2.1 : 1.5
      ..strokeCap = StrokeCap.round;
    final highlightPaint = Paint()
      ..color = const Color(0xFFCDEBFF).withValues(alpha: 0.22)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (var i = 0; i < 68; i++) {
      final x = (i * 31.0 + progress * 260) % (size.width + 120) - 60;
      final y = (i * 47.0 + progress * 520) % (size.height + 120) - 60;
      final start = Offset(x, y);
      final end = Offset(x - 16, y + 46);
      if (i % 11 == 0) {
        canvas.drawLine(start, end, highlightPaint);
      }
      canvas.drawLine(start, end, rainPaint);
    }

    if (weather.kind == _WeatherKind.storm) {
      final flash = math.sin(progress * math.pi * 8);
      if (flash > 0.86) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = Colors.white.withValues(alpha: 0.05),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FrontWeatherPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.weather != weather;
  }
}

class _IslandReflectionPainter extends CustomPainter {
  const _IslandReflectionPainter({
    required this.progress,
    required this.stormy,
  });

  final double progress;
  final bool stormy;

  @override
  void paint(Canvas canvas, Size size) {
    final waterRing = Paint()
      ..color = Colors.white.withValues(alpha: stormy ? 0.24 : 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final mist = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: stormy ? 0.16 : 0.22),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.46),
        width: size.width * 0.80,
        height: size.height * 0.42,
      ),
      mist,
    );

    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.36 + i * 0.13);
      final phase = progress * math.pi * 2 + i * 0.8;
      final path = Path()..moveTo(size.width * 0.12, y);
      for (var x = size.width * 0.12; x <= size.width * 0.88; x += 24) {
        path.lineTo(x, y + math.sin(x / 28 + phase) * 5);
      }
      canvas.drawPath(path, waterRing);
    }
  }

  @override
  bool shouldRepaint(covariant _IslandReflectionPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.stormy != stormy;
  }
}

class _AnimalNameTag extends StatelessWidget {
  const _AnimalNameTag({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      constraints: const BoxConstraints(maxWidth: 92),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31535A).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF2A4C52),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WeatherModePicker extends StatelessWidget {
  const _WeatherModePicker({
    required this.selectedScore,
    required this.onSelected,
  });

  final int selectedScore;
  final ValueChanged<_WeatherPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF42646B).withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final preset in _WeatherPreset.values)
            _WeatherChip(
              preset: preset,
              selected: preset.matches(selectedScore),
              onTap: () => onSelected(preset),
            ),
        ],
      ),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final _WeatherPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: selected ? 1.04 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? preset.color.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.86)
                    : preset.color.withValues(alpha: 0.28),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: preset.color.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  preset.icon,
                  size: 17,
                  color: selected ? Colors.white : preset.color,
                ),
                const SizedBox(width: 6),
                Text(
                  preset.label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF294B52),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherPreset {
  const _WeatherPreset({
    required this.label,
    required this.icon,
    required this.color,
    required this.phq9Score,
    required this.mood,
  });

  final String label;
  final IconData icon;
  final Color color;
  final int phq9Score;
  final MoodState mood;

  bool matches(int score) => _IslandWeather.fromPhq9(score).kind == weatherKind;

  _WeatherKind get weatherKind => _IslandWeather.fromPhq9(phq9Score).kind;

  static const values = [
    _WeatherPreset(
      label: 'แดดอ่อน',
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFE3AD42),
      phq9Score: 4,
      mood: MoodState.hopeful,
    ),
    _WeatherPreset(
      label: 'เมฆนุ่ม',
      icon: Icons.cloud_rounded,
      color: Color(0xFF7FAEBA),
      phq9Score: 11,
      mood: MoodState.tired,
    ),
    _WeatherPreset(
      label: 'ฝนหนัก',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF668CA2),
      phq9Score: 16,
      mood: MoodState.heavy,
    ),
    _WeatherPreset(
      label: 'พายุ',
      icon: Icons.thunderstorm_rounded,
      color: Color(0xFF59677D),
      phq9Score: 23,
      mood: MoodState.crisis,
    ),
  ];
}

class _IslandData {
  const _IslandData({
    required this.user,
    required this.phq9Score,
    required this.animals,
    required this.animalNicknames,
    required this.backendOnline,
    required this.backendLabel,
  });

  final BackendUser? user;
  final int phq9Score;
  final List<String> animals;
  final Map<String, String> animalNicknames;
  final bool backendOnline;
  final String backendLabel;
}

class _PastelAnimal {
  const _PastelAnimal({
    required this.name,
    required this.assetPath,
    required this.size,
  });

  final String name;
  final String assetPath;
  final double size;

  static _PastelAnimal fromId(String id, int index) {
    final normalized = id.toLowerCase();
    if (normalized.contains('red') || normalized.contains('fox')) {
      return const _PastelAnimal(
        name: 'อ้วนแดง',
        assetPath: 'assets/images/island_parts/animal_red_panda.png',
        size: 72,
      );
    }
    if (normalized.contains('capy') || normalized.contains('otter')) {
      return const _PastelAnimal(
        name: 'คาปิลิ้นเปื่อย',
        assetPath: 'assets/images/island_parts/animal_capybara.png',
        size: 76,
      );
    }
    if (normalized.contains('koala')) {
      return const _PastelAnimal(
        name: 'อ้วน',
        assetPath: 'assets/images/island_parts/animal_koala.png',
        size: 70,
      );
    }
    if (normalized.contains('panda')) {
      return const _PastelAnimal(
        name: 'แพนแพน',
        assetPath: 'assets/images/island_parts/animal_panda.png',
        size: 72,
      );
    }
    const fallback = [
      _PastelAnimal(
        name: 'แพนแพน',
        assetPath: 'assets/images/island_parts/animal_panda.png',
        size: 72,
      ),
      _PastelAnimal(
        name: 'อ้วนแดง',
        assetPath: 'assets/images/island_parts/animal_red_panda.png',
        size: 72,
      ),
      _PastelAnimal(
        name: 'คาปิลิ้นเปื่อย',
        assetPath: 'assets/images/island_parts/animal_capybara.png',
        size: 76,
      ),
      _PastelAnimal(
        name: 'อ้วน',
        assetPath: 'assets/images/island_parts/animal_koala.png',
        size: 70,
      ),
    ];
    return fallback[index % fallback.length];
  }
}

class _IslandWeather {
  const _IslandWeather({
    required this.kind,
    required this.title,
    required this.message,
    required this.skyColors,
    required this.seaColors,
    required this.cloudColor,
    required this.textColor,
    required this.badgeColors,
    required this.icon,
  });

  final _WeatherKind kind;
  final String title;
  final String message;
  final List<Color> skyColors;
  final List<Color> seaColors;
  final Color cloudColor;
  final Color textColor;
  final List<Color> badgeColors;
  final IconData icon;

  static _IslandWeather fromPhq9(int score) {
    if (score >= 20) {
      return const _IslandWeather(
        kind: _WeatherKind.storm,
        title: 'Storm watch',
        message:
            'วันนี้เกาะมีพายุแรงนะ เราอยู่ใกล้ ๆ กันก่อนก็พอ ไม่ต้องฝืนสดใส',
        skyColors: [Color(0xFF46566D), Color(0xFF8597A6), Color(0xFFB6C7CF)],
        seaColors: [Color(0xFF58707E), Color(0xFF8299A4)],
        cloudColor: Color(0xFF4B5667),
        textColor: Color(0xFF17343C),
        badgeColors: [Color(0xFF7C8CA1), Color(0xFF46566D)],
        icon: Icons.thunderstorm_rounded,
      );
    }
    if (score >= 15) {
      return const _IslandWeather(
        kind: _WeatherKind.rain,
        title: 'Heavy rain',
        message:
            'ฝนลงบนเกาะเยอะหน่อย แต่ต้นไม้ยังอยู่ตรงนี้ สัตว์ก็พักข้าง ๆ คุณ',
        skyColors: [Color(0xFF7E91A2), Color(0xFFB8CCD4), Color(0xFFDDECEB)],
        seaColors: [Color(0xFF6F93A0), Color(0xFF9CB9BE)],
        cloudColor: Color(0xFF677586),
        textColor: Color(0xFF17343C),
        badgeColors: [Color(0xFF8FB3C1), Color(0xFF627B8B)],
        icon: Icons.water_drop_rounded,
      );
    }
    if (score >= 10) {
      return const _IslandWeather(
        kind: _WeatherKind.cloudy,
        title: 'Soft cloudy',
        message:
            'วันนี้เมฆเยอะ แต่ยังมีแสงนุ่ม ๆ ลอดลงมา เราค่อย ๆ เดินบนเกาะกัน',
        skyColors: [Color(0xFFB8D7E3), Color(0xFFD9ECEB), Color(0xFFF4F4E8)],
        seaColors: [Color(0xFF86C5CC), Color(0xFFB7DADC)],
        cloudColor: Color(0xFFA8B8C0),
        textColor: Color(0xFF17343C),
        badgeColors: [Color(0xFFAED7E2), Color(0xFF7DA9B5)],
        icon: Icons.cloud_rounded,
      );
    }
    return const _IslandWeather(
      kind: _WeatherKind.sunny,
      title: 'Pastel breeze',
      message: 'วันนี้เกาะแดดอ่อน ลมพอดี สัตว์ตัวน้อยออกมาเดินเล่นแล้วนะ',
      skyColors: [Color(0xFFAEE7F8), Color(0xFFE1F6ED), Color(0xFFFFF3D6)],
      seaColors: [Color(0xFF8DD9DF), Color(0xFFBDEBE5)],
      cloudColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF17343C),
      badgeColors: [Color(0xFFFFD982), Color(0xFF78CDBF)],
      icon: Icons.wb_sunny_rounded,
    );
  }
}

enum _WeatherKind { sunny, cloudy, rain, storm }
