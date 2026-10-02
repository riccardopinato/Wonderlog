import 'package:flutter/material.dart';

abstract final class WonderlogSpacing {
  static const double xSmall = 8;
  static const double small = 12;
  static const double medium = 16;
  static const double large = 24;
  static const double xLarge = 32;
}

abstract final class WonderlogRadii {
  static const double small = 12;
  static const double card = 20;
  static const double container = 28;
}

abstract final class WonderlogLayout {
  static const double minInteractiveSize = 48;
  static const double maxContentWidth = 1180;
  static const double railBreakpoint = 840;
}

abstract final class WonderlogColors {
  static const seed = Color(0xFFE85D75);
  static const accent = Color(0xFF7C5CE5);
}
