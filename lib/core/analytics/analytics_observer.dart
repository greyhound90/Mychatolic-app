import 'package:flutter/material.dart';
import 'package:mychatolic_app/core/analytics/analytics_service.dart';
import 'package:mychatolic_app/core/analytics/analytics_events.dart';

class AnalyticsObserver extends NavigatorObserver {
  final AnalyticsService analytics;

  AnalyticsObserver(this.analytics);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trackRoute(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _trackRoute(previousRoute);
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _trackRoute(newRoute);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _trackRoute(Route<dynamic> route) {
    final name = _routeName(route);
    if (name == null || name.isEmpty) return;
    analytics.track(
      AnalyticsEvents.screenView,
      screenName: name,
    );
  }

  String? _routeName(Route<dynamic> route) {
    final settings = route.settings;
    if (settings.name != null && settings.name!.isNotEmpty) {
      return settings.name;
    }
    final name = route.runtimeType.toString();
    return name.isNotEmpty ? name : null;
  }
}
