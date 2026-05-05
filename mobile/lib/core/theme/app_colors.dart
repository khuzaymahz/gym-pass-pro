import 'package:flutter/material.dart';

import 'gp_tokens.dart';

abstract class AppColors {
  static const ink = GP.ink;
  static const paper = GP.paper;
  static const lime = GP.lime;
  static const muted = GP.muted;
  static const surface = GP.bg2;
  static const line = GP.line;
  static const danger = GP.danger;

  static Color get tierSilver => GPTier.silver.color;
  static Color get tierGold => GPTier.gold.color;
  static Color get tierPlatinum => GPTier.platinum.color;
  static Color get tierDiamond => GPTier.diamond.color;
}
