import 'package:flutter/material.dart';

/// The app's own colour roles, the ones Material's [ColorScheme] has no slot
/// for (DESIGN.md SZ3). Each has a light and a dark value; a widget reaches
/// them through `Theme.of(context).extension<MiserendColors>()!`.
@immutable
class MiserendColors extends ThemeExtension<MiserendColors> {
  const MiserendColors({
    required this.occasionTime,
    required this.onOccasionTime,
    required this.occasionTimeContainer,
    required this.onOccasionTimeContainer,
    required this.serverErrorContainer,
    required this.onServerErrorContainer,
    required this.serverErrorIcon,
    required this.userLocation,
    required this.onUserLocation,
    required this.mapOverlay,
  });

  /// The values for [scheme]'s brightness. [mapOverlay] is drawn from the
  /// scheme's `surface`, so it follows the mode with it.
  factory MiserendColors.forScheme(ColorScheme scheme) {
    final overlay = scheme.surface.withValues(alpha: 0.7);
    return switch (scheme.brightness) {
      Brightness.light => MiserendColors(
        occasionTime: const Color(0xFFFF8C00),
        onOccasionTime: const Color(0xFF2E1500),
        occasionTimeContainer: const Color(0xFFFFDCC2),
        onOccasionTimeContainer: const Color(0xFF2E1500),
        serverErrorContainer: const Color(0xFFFFE0B2),
        onServerErrorContainer: const Color(0xFF2E1500),
        serverErrorIcon: const Color(0xFFB45309),
        userLocation: const Color(0xFF1A73E8),
        onUserLocation: const Color(0xFFFFFFFF),
        mapOverlay: overlay,
      ),
      Brightness.dark => MiserendColors(
        occasionTime: const Color(0xFFFF8C00),
        onOccasionTime: const Color(0xFF2E1500),
        occasionTimeContainer: const Color(0xFF6E3900),
        onOccasionTimeContainer: const Color(0xFFFFDCC2),
        serverErrorContainer: const Color(0xFF5A3300),
        onServerErrorContainer: const Color(0xFFFFDCC2),
        serverErrorIcon: const Color(0xFFFFB870),
        userLocation: const Color(0xFF1A73E8),
        onUserLocation: const Color(0xFFFFFFFF),
        mapOverlay: overlay,
      ),
    };
  }

  /// The filled orange behind the time of an occasion that is going on now.
  /// Orange marks a time and nothing else (SZ4).
  final Color occasionTime;

  /// Text and icons on [occasionTime].
  final Color onOccasionTime;

  /// Behind the time chip.
  final Color occasionTimeContainer;

  /// Text on [occasionTimeContainer].
  final Color onOccasionTimeContainer;

  /// Behind what a server error leaves on screen: the strip, the map's card
  /// (CONTEXT.md, „Szerverhiba").
  final Color serverErrorContainer;

  /// Text on [serverErrorContainer].
  final Color onServerErrorContainer;

  /// The server error's icon on [serverErrorContainer]; as an icon it needs
  /// 3:1, not 4.5:1 (AM1).
  final Color serverErrorIcon;

  /// The dot of the user's own position on the map (spec 0006).
  final Color userLocation;

  /// The ring around [userLocation]'s dot.
  final Color onUserLocation;

  /// Behind the map's attribution, so that it reads over any tile (KO17).
  final Color mapOverlay;

  @override
  MiserendColors copyWith({
    Color? occasionTime,
    Color? onOccasionTime,
    Color? occasionTimeContainer,
    Color? onOccasionTimeContainer,
    Color? serverErrorContainer,
    Color? onServerErrorContainer,
    Color? serverErrorIcon,
    Color? userLocation,
    Color? onUserLocation,
    Color? mapOverlay,
  }) {
    return MiserendColors(
      occasionTime: occasionTime ?? this.occasionTime,
      onOccasionTime: onOccasionTime ?? this.onOccasionTime,
      occasionTimeContainer:
          occasionTimeContainer ?? this.occasionTimeContainer,
      onOccasionTimeContainer:
          onOccasionTimeContainer ?? this.onOccasionTimeContainer,
      serverErrorContainer: serverErrorContainer ?? this.serverErrorContainer,
      onServerErrorContainer:
          onServerErrorContainer ?? this.onServerErrorContainer,
      serverErrorIcon: serverErrorIcon ?? this.serverErrorIcon,
      userLocation: userLocation ?? this.userLocation,
      onUserLocation: onUserLocation ?? this.onUserLocation,
      mapOverlay: mapOverlay ?? this.mapOverlay,
    );
  }

  @override
  MiserendColors lerp(MiserendColors? other, double t) {
    if (other == null) return this;
    return MiserendColors(
      occasionTime: Color.lerp(occasionTime, other.occasionTime, t)!,
      onOccasionTime: Color.lerp(onOccasionTime, other.onOccasionTime, t)!,
      occasionTimeContainer:
          Color.lerp(occasionTimeContainer, other.occasionTimeContainer, t)!,
      onOccasionTimeContainer:
          Color.lerp(
            onOccasionTimeContainer,
            other.onOccasionTimeContainer,
            t,
          )!,
      serverErrorContainer:
          Color.lerp(serverErrorContainer, other.serverErrorContainer, t)!,
      onServerErrorContainer:
          Color.lerp(onServerErrorContainer, other.onServerErrorContainer, t)!,
      serverErrorIcon: Color.lerp(serverErrorIcon, other.serverErrorIcon, t)!,
      userLocation: Color.lerp(userLocation, other.userLocation, t)!,
      onUserLocation: Color.lerp(onUserLocation, other.onUserLocation, t)!,
      mapOverlay: Color.lerp(mapOverlay, other.mapOverlay, t)!,
    );
  }
}
