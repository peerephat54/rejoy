import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/rejoy_session.dart';
import '../../services/audit_log_service.dart';
import '../../services/performance_telemetry_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({
    super.key,
    required this.session,
    required this.onCrisisSelected,
  });

  final ReJoySession session;
  final ValueChanged<CrisisLevel> onCrisisSelected;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final AuditLogService _auditLog = const AuditLogService();
  final PerformanceTelemetryService _telemetry =
      const PerformanceTelemetryService();
  static const _fallbackLocation = _GeoPoint(
    latitude: 13.7563,
    longitude: 100.5018,
  );

  late _GeoPoint _currentLocation;
  late List<_OfflineCarePlace> _nearestPlaces;
  bool _offlineMode = true;
  bool _loadingLocation = true;
  String _locationSource = 'กำลังค้นหาพิกัดล่าสุด...';

  @override
  void initState() {
    super.initState();
    _auditLog.record(type: 'SOS_OPENED', riskLevel: 'red');
    _currentLocation = _fallbackLocation;
    _nearestPlaces = _rankNearestPlaces(_currentLocation);
    _loadDeviceLocation();
  }

  Future<void> _loadDeviceLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationSource = 'กำลังค้นหาพิกัดล่าสุดจากเครื่อง...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useFallbackLocation(
          'Location service ปิดอยู่ จึงใช้พิกัด fallback เพื่อให้ SOS ยังทำงาน',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _useFallbackLocation(
          'ยังไม่ได้รับสิทธิ์ GPS จึงใช้พิกัด fallback เพื่อให้ SOS ยังทำงาน',
        );
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      final position =
          lastKnown ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          );

      if (!mounted) return;
      final point = _GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      setState(() {
        _currentLocation = point;
        _nearestPlaces = _rankNearestPlaces(point);
        _loadingLocation = false;
        _locationSource = lastKnown == null
            ? 'ใช้ GPS ปัจจุบันจากเครื่อง'
            : 'ใช้ last known GPS จากเครื่อง';
      });
    } catch (_) {
      _useFallbackLocation(
        'อ่าน GPS ไม่สำเร็จ จึงใช้พิกัด fallback เพื่อให้ SOS ยังทำงาน',
      );
    }
  }

  void _useFallbackLocation(String reason) {
    if (!mounted) return;
    setState(() {
      _currentLocation = _fallbackLocation;
      _nearestPlaces = _rankNearestPlaces(_fallbackLocation);
      _loadingLocation = false;
      _locationSource = reason;
    });
  }

  List<_OfflineCarePlace> _rankNearestPlaces(_GeoPoint userLocation) {
    final stopwatch = Stopwatch()..start();
    final ranked = _offlineCarePlaces.map((place) {
      final distanceKm = _haversineDistanceKm(userLocation, place.location);
      final bearingDegrees = _bearingDegrees(userLocation, place.location);
      return place.copyWith(
        distanceKm: distanceKm,
        bearingDegrees: bearingDegrees,
      );
    }).toList()..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    stopwatch.stop();
    unawaited(
      _telemetry.record(
        name: 'offline_haversine_rank',
        elapsedMs: stopwatch.elapsedMilliseconds,
        detail: 'places=${ranked.length};nearest=${ranked.first.name}',
      ),
    );
    return ranked;
  }

  double _haversineDistanceKm(_GeoPoint from, _GeoPoint to) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(to.latitude - from.latitude);
    final dLon = _degreesToRadians(to.longitude - from.longitude);
    final lat1 = _degreesToRadians(from.latitude);
    final lat2 = _degreesToRadians(to.latitude);

    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadiusKm * c;
  }

  double _bearingDegrees(_GeoPoint from, _GeoPoint to) {
    final lat1 = _degreesToRadians(from.latitude);
    final lat2 = _degreesToRadians(to.latitude);
    final dLon = _degreesToRadians(to.longitude - from.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (_radiansToDegrees(math.atan2(y, x)) + 360) % 360;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  double _radiansToDegrees(double radians) => radians * 180 / math.pi;

  void _activateCrisisMode() {
    setState(() {
      _offlineMode = true;
      _nearestPlaces = _rankNearestPlaces(_currentLocation);
    });
    widget.onCrisisSelected(CrisisLevel.urgent);
  }

  @override
  Widget build(BuildContext context) {
    final nearestPlace = _nearestPlaces.first;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF1E8), Color(0xFFE9F7F4)],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            _SosHeader(
              crisis: widget.session.crisis,
              offlineMode: _offlineMode,
              onActivate: _activateCrisisMode,
            ),
            const SizedBox(height: 14),
            _EmergencyActionGrid(nearestPlace: nearestPlace),
            const SizedBox(height: 14),
            _LocationCard(
              location: _currentLocation,
              source: _locationSource,
              loading: _loadingLocation,
              onRefresh: _loadDeviceLocation,
            ),
            const SizedBox(height: 14),
            _OfflineMapCard(
              userLocation: _currentLocation,
              places: _nearestPlaces.take(5).toList(),
              nearestPlace: nearestPlace,
            ),
            const SizedBox(height: 14),
            _NearestCareList(places: _nearestPlaces),
            const SizedBox(height: 14),
            const _SafetyNoteCard(),
          ],
        ),
      ),
    );
  }
}

class _SosHeader extends StatelessWidget {
  const _SosHeader({
    required this.crisis,
    required this.offlineMode,
    required this.onActivate,
  });

  final CrisisLevel crisis;
  final bool offlineMode;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F4C3D).withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFA07A), Color(0xFFE86A5A)],
                  ),
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lighthouse SOS',
                      style: TextStyle(
                        color: Color(0xFF17343C),
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'สถานะ: ${crisis.label} | ${offlineMode ? 'Offline ready' : 'Online'}',
                      style: const TextStyle(
                        color: Color(0xFF607A81),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'หน้าต่างช่วยเหลือฉุกเฉินแบบเร็ว: ตั้งหลักด้วย 5-4-3-2-1, โทร 1323, และดูสถานพยาบาลใกล้ตัว',
            style: TextStyle(color: Color(0xFF31525A), height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onActivate,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE86A5A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.sos_rounded),
              label: const Text('เข้าสู่โหมดวิกฤตออฟไลน์'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyActionGrid extends StatelessWidget {
  const _EmergencyActionGrid({required this.nearestPlace});

  final _OfflineCarePlace nearestPlace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5C2D28), Color(0xFFE86442)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD45A3E).withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.light_rounded, color: Color(0xFFFFE3A4), size: 58),
          const SizedBox(height: 6),
          const Text(
            'หน้าต่างฉุกเฉิน',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black38, blurRadius: 12)],
            ),
          ),
          const Text(
            '(Lighthouse SOS)',
            style: TextStyle(
              color: Color(0xFFFFA36B),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.86,
            children: [
              const _EmergencyTile(
                number: '1',
                title: 'ดึงประสาทกลับมาสัมผัส',
                subtitle: '5-4-3-2-1',
                icon: Icons.visibility_rounded,
                detail: 'เห็น 5 | แตะ 4 | ได้ยิน 3 | กลิ่น 2 | รส 1',
              ),
              const _EmergencyTile(
                number: '2',
                title: 'ติดต่อสายด่วน',
                subtitle: '1323',
                icon: Icons.phone_rounded,
                detail: 'โทรสายด่วนสุขภาพจิตทันที',
                highlight: true,
              ),
              _EmergencyTile(
                number: '3',
                title: 'สถานพยาบาลใกล้ที่สุด',
                subtitle: '${nearestPlace.distanceKm.toStringAsFixed(1)} km',
                icon: Icons.local_hospital_rounded,
                detail: nearestPlace.name,
              ),
              const _EmergencyTile(
                number: '4',
                title: 'ดูแลตนเองเบื้องต้น',
                subtitle: 'หายใจ - น้ำ - เดินช้า ๆ',
                icon: Icons.self_improvement_rounded,
                detail: 'ผ่อนลมหายใจ จิบน้ำ และขยับตัวอย่างนุ่มนวล',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmergencyTile extends StatelessWidget {
  const _EmergencyTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.detail,
    this.highlight = false,
  });

  final String number;
  final String title;
  final String subtitle;
  final IconData icon;
  final String detail;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
          decoration: BoxDecoration(
            color: highlight
                ? const Color(0xFFFF7B45).withValues(alpha: 0.78)
                : Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFF8A65).withValues(alpha: 0.72),
              width: 1.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFFFFE2C8), size: 34),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  height: 1.16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: highlight ? Colors.white : const Color(0xFFFFD1B8),
                  fontWeight: FontWeight.w900,
                  fontSize: highlight ? 27 : 19,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFE6D8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -8,
          left: -6,
          child: CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white,
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF8A3A2A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.source,
    required this.loading,
    required this.onRefresh,
  });

  final _GeoPoint location;
  final String source;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '1. พิกัดล่าสุดบนเครื่อง',
      subtitle:
          'ระบบใช้ GPS ปัจจุบันหรือ last known location ถ้าอ่านไม่ได้จะใช้ fallback เพื่อให้ SOS ยังทำงาน',
      child: Row(
        children: [
          loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded, color: Color(0xFF62A7A5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: Color(0xFF20383F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  source,
                  style: const TextStyle(
                    color: Color(0xFF607A81),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.gps_fixed_rounded),
          ),
        ],
      ),
    );
  }
}

class _OfflineMapCard extends StatelessWidget {
  const _OfflineMapCard({
    required this.userLocation,
    required this.places,
    required this.nearestPlace,
  });

  final _GeoPoint userLocation;
  final List<_OfflineCarePlace> places;
  final _OfflineCarePlace nearestPlace;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '2. แผนที่ออฟไลน์แบบย่อ',
      subtitle:
          'แสดงทิศทางจากพิกัดของเราไปยังสถานพยาบาลใกล้สุด โดยคำนวณบนเครื่องทั้งหมด',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CustomPaint(
              painter: _OfflineMapPainter(
                userLocation: userLocation,
                places: places,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9C46A)),
            ),
            child: Row(
              children: [
                Transform.rotate(
                  angle: _degreesToRadians(nearestPlace.bearingDegrees),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Color(0xFFE08A2E),
                    size: 34,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ใกล้สุด: ${nearestPlace.name}',
                        style: const TextStyle(
                          color: Color(0xFF17343C),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${nearestPlace.distanceKm.toStringAsFixed(1)} กม. | ไปทาง${nearestPlace.directionLabel} (${nearestPlace.bearingDegrees.toStringAsFixed(0)}°)',
                        style: const TextStyle(color: Color(0xFF607A81)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
}

class _NearestCareList extends StatelessWidget {
  const _NearestCareList({required this.places});

  final List<_OfflineCarePlace> places;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '4. สถานพยาบาลใกล้ที่สุด',
      subtitle: 'เรียงจากระยะ Haversine โดยไม่ใช้อินเทอร์เน็ต',
      child: Column(
        children: places.take(5).map((place) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FCFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD5E6E3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_hospital_rounded,
                  color: Color(0xFFE86A5A),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          color: Color(0xFF20383F),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${place.province} | ${place.type} | ไปทาง${place.directionLabel}',
                        style: const TextStyle(color: Color(0xFF607A81)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${place.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: Color(0xFF17343C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SafetyNoteCard extends StatelessWidget {
  const _SafetyNoteCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      title: 'หมายเหตุความปลอดภัย',
      subtitle:
          'ในเหตุฉุกเฉินจริง ให้ติดต่อคนใกล้ตัวหรือบริการฉุกเฉินทันที แอปนี้ช่วยประคองการตัดสินใจ ไม่ใช่บริการแพทย์ฉุกเฉิน',
      child: Text(
        'ตอนนี้ระบบคำนวณพิกัดและทิศทางออฟไลน์ได้แล้ว ขั้นต่อไปก่อนใช้ภาคสนามคือขยาย local database ให้ครอบคลุมพื้นที่เป้าหมาย และทดสอบ GPS permission บนอุปกรณ์ Android จริง',
        style: TextStyle(color: Color(0xFF20383F), height: 1.45),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31525A).withValues(alpha: 0.07),
            blurRadius: 20,
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
              color: Color(0xFF17343C),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF607A81), height: 1.35),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _OfflineMapPainter extends CustomPainter {
  const _OfflineMapPainter({required this.userLocation, required this.places});

  final _GeoPoint userLocation;
  final List<_OfflineCarePlace> places;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEAF8F4), Color(0xFFD7EBF4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    final gridPaint = Paint()
      ..color = const Color(0xFF8FB7B5).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final routePaint = Paint()
      ..color = const Color(0xFFE08A2E).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final userPaint = Paint()..color = const Color(0xFF62A7A5);
    final placePaint = Paint()..color = const Color(0xFFE86A5A);

    final cardRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );
    canvas.drawRRect(cardRect, backgroundPaint);

    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, gridPaint);
    }
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      gridPaint,
    );

    if (places.isEmpty) return;

    final maxDistance = places
        .map((place) => place.distanceKm)
        .fold<double>(0.1, math.max);

    for (final place in places.reversed) {
      final angle = _degreesToRadians(place.bearingDegrees - 90);
      final normalizedDistance = (place.distanceKm / maxDistance).clamp(
        0.18,
        1.0,
      );
      final point = Offset(
        center.dx + math.cos(angle) * radius * normalizedDistance,
        center.dy + math.sin(angle) * radius * normalizedDistance,
      );

      if (place == places.first) {
        canvas.drawLine(center, point, routePaint);
      }

      canvas.drawCircle(point, place == places.first ? 9 : 6, placePaint);
      canvas.drawCircle(
        point,
        place == places.first ? 14 : 10,
        Paint()
          ..color = const Color(0xFFE86A5A).withValues(alpha: 0.16)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawCircle(
      center,
      18,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(center, 11, userPaint);

    _drawLabel(canvas, 'N', Offset(center.dx, center.dy - radius - 18));
    _drawLabel(canvas, 'คุณ', Offset(center.dx, center.dy + 24));
    _drawLabel(canvas, 'nearest', Offset(18, 16));
  }

  void _drawLabel(Canvas canvas, String label, Offset offset) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF31525A),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(offset.dx - textPainter.width / 2, offset.dy),
    );
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant _OfflineMapPainter oldDelegate) {
    return oldDelegate.userLocation != userLocation ||
        oldDelegate.places != places;
  }
}

class _GeoPoint {
  const _GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class _OfflineCarePlace {
  const _OfflineCarePlace({
    required this.name,
    required this.province,
    required this.type,
    required this.location,
    this.distanceKm = 0,
    this.bearingDegrees = 0,
  });

  final String name;
  final String province;
  final String type;
  final _GeoPoint location;
  final double distanceKm;
  final double bearingDegrees;

  String get directionLabel {
    const directions = [
      'เหนือ',
      'ตะวันออกเฉียงเหนือ',
      'ตะวันออก',
      'ตะวันออกเฉียงใต้',
      'ใต้',
      'ตะวันตกเฉียงใต้',
      'ตะวันตก',
      'ตะวันตกเฉียงเหนือ',
    ];
    final index = ((bearingDegrees + 22.5) ~/ 45) % 8;
    return directions[index];
  }

  _OfflineCarePlace copyWith({double? distanceKm, double? bearingDegrees}) {
    return _OfflineCarePlace(
      name: name,
      province: province,
      type: type,
      location: location,
      distanceKm: distanceKm ?? this.distanceKm,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
    );
  }
}

const _offlineCarePlaces = [
  _OfflineCarePlace(
    name: 'โรงพยาบาลวชิระภูเก็ต',
    province: 'ภูเก็ต',
    type: 'โรงพยาบาลรัฐ/ฉุกเฉิน',
    location: _GeoPoint(latitude: 7.8974264, longitude: 98.3830121),
  ),
  _OfflineCarePlace(
    name: 'Bangkok Hospital Phuket - Mental Health Center',
    province: 'ภูเก็ต',
    type: 'เอกชน/ศูนย์สุขภาพจิต',
    location: _GeoPoint(latitude: 7.9039384, longitude: 98.3757990),
  ),
  _OfflineCarePlace(
    name: 'โรงพยาบาลดีบุก',
    province: 'ภูเก็ต',
    type: 'เอกชน/ฉุกเฉิน',
    location: _GeoPoint(latitude: 7.8719169, longitude: 98.3601895),
  ),
  _OfflineCarePlace(
    name: 'โรงพยาบาลมิชชั่น ภูเก็ต',
    province: 'ภูเก็ต',
    type: 'เอกชน/ฉุกเฉิน',
    location: _GeoPoint(latitude: 7.9065293, longitude: 98.3909854),
  ),
  _OfflineCarePlace(
    name: 'โรงพยาบาลจิตเวชสงขลาราชนครินทร์',
    province: 'สงขลา',
    type: 'จิตเวช/กรมสุขภาพจิต',
    location: _GeoPoint(latitude: 7.17879, longitude: 100.61376),
  ),
  _OfflineCarePlace(
    name: 'โรงพยาบาลสงขลานครินทร์ - คลินิกจิตเวช',
    province: 'สงขลา',
    type: 'มหาวิทยาลัย/คลินิกจิตเวช',
    location: _GeoPoint(latitude: 7.0066733, longitude: 100.4946672),
  ),
  _OfflineCarePlace(
    name: 'โรงพยาบาลหาดใหญ่',
    province: 'สงขลา',
    type: 'โรงพยาบาลรัฐ/ฉุกเฉิน',
    location: _GeoPoint(latitude: 7.0166654, longitude: 100.4674503),
  ),
  _OfflineCarePlace(
    name: 'โรงพยาบาลสงขลา',
    province: 'สงขลา',
    type: 'โรงพยาบาลรัฐ/ฉุกเฉิน',
    location: _GeoPoint(latitude: 7.1406664, longitude: 100.5642533),
  ),
  _OfflineCarePlace(
    name: 'Bangkok Hospital Hat Yai',
    province: 'สงขลา',
    type: 'เอกชน/ฉุกเฉิน',
    location: _GeoPoint(latitude: 7.0160263, longitude: 100.4864657),
  ),
  _OfflineCarePlace(
    name: 'โรงพยาบาลราษฎร์ยินดี',
    province: 'สงขลา',
    type: 'เอกชน/ฉุกเฉิน',
    location: _GeoPoint(latitude: 7.00073, longitude: 100.48041),
  ),
];
