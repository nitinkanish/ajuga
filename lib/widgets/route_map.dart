import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/activity_bridge.dart';

class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.points,
    this.followUser = false,
    this.height = 240,
  });

  final List<OutdoorPoint> points;
  final bool followUser;
  final double height;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pushRoute();
  }

  Future<void> _pushRoute() async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod<void>('setRoute', {
      'coordinates': [
        for (final p in widget.points) {'lat': p.latitude, 'lon': p.longitude},
      ],
    });
    await channel.invokeMethod<void>('followUser', {
      'follow': widget.followUser,
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = kIsWeb || !Platform.isIOS
        ? const Center(child: Text('Map available on iPhone'))
        : UiKitView(
            viewType: 'aster/route_map',
            creationParams: {
              'coordinates': [
                for (final p in widget.points)
                  {'lat': p.latitude, 'lon': p.longitude},
              ],
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (id) {
              _channel = MethodChannel('aster/route_map_$id');
              _pushRoute();
            },
          );
    return SizedBox(height: widget.height, width: double.infinity, child: child);
  }
}
