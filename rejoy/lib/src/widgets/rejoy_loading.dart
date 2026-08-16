import 'package:flutter/material.dart';

class ReJoyLoadingScreen extends StatelessWidget {
  const ReJoyLoadingScreen({
    super.key,
    this.title = 'ยินดีต้อนรับสู่ ReJoy',
    this.message = 'กำลังเตรียมเกาะและข้อมูลของคุณ...',
    this.progress = 0.8,
  });

  final String title;
  final String message;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ReJoyLoadingView(
        title: title,
        message: message,
        progress: progress,
      ),
    );
  }
}

class ReJoyLoadingView extends StatefulWidget {
  const ReJoyLoadingView({
    super.key,
    this.title = 'ยินดีต้อนรับสู่ ReJoy',
    this.message = 'กำลังเตรียมเกาะและข้อมูลของคุณ...',
    this.progress = 0.8,
    this.compact = false,
  });

  final String title;
  final String message;
  final double progress;
  final bool compact;

  @override
  State<ReJoyLoadingView> createState() => _ReJoyLoadingViewState();
}

class _ReJoyLoadingViewState extends State<ReJoyLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 220.0 : double.infinity;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC7E9FF), Color(0xFFEDEBFF), Color(0xFFFFDDEB)],
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pulse = 1 + (_controller.value * 0.055);
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6BAEA8).withValues(alpha: 0.13),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 22 : 30,
                  vertical: widget.compact ? 20 : 30,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF17343C),
                        fontSize: widget.compact ? 16 : 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: widget.compact ? 18 : 30),
                    Transform.scale(
                      scale: pulse,
                      child: CustomPaint(
                        size: Size(
                          widget.compact ? 108 : 168,
                          widget.compact ? 96 : 150,
                        ),
                        painter: _HeartPainter(),
                      ),
                    ),
                    SizedBox(height: widget.compact ? 16 : 22),
                    SizedBox(
                      width: widget.compact ? 150 : 190,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: widget.compact ? 5 : 6,
                          value: widget.progress.clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFD9DEE5),
                          color: const Color(0xFFFFBFD5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'โหลดแล้ว ${(widget.progress * 100).round()}%',
                      style: TextStyle(
                        color: const Color(0xFF17343C),
                        fontSize: widget.compact ? 12 : 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF526D73),
                          fontSize: widget.compact ? 11 : 13,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFC8D9)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height * 0.90)
      ..cubicTo(
        size.width * 0.08,
        size.height * 0.52,
        size.width * 0.03,
        size.height * 0.19,
        size.width * 0.31,
        size.height * 0.12,
      )
      ..cubicTo(
        size.width * 0.43,
        size.height * 0.09,
        size.width * 0.50,
        size.height * 0.18,
        size.width / 2,
        size.height * 0.27,
      )
      ..cubicTo(
        size.width * 0.50,
        size.height * 0.18,
        size.width * 0.57,
        size.height * 0.09,
        size.width * 0.69,
        size.height * 0.12,
      )
      ..cubicTo(
        size.width * 0.97,
        size.height * 0.19,
        size.width * 0.92,
        size.height * 0.52,
        size.width / 2,
        size.height * 0.90,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
