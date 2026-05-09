import '../../../../l10n/app_localizations.dart';

/// Maps a backend category key (`gym`, `crossfit`, `martial`, `yoga`)
/// to its localized label. Used by both the floating selected-gym
/// card and the list-row beneath the bottom sheet, so both surfaces
/// agree on copy.
String localizedCategory(AppLocalizations l, String key) {
  switch (key) {
    case 'gym':
      return l.gymsCategoryGym;
    case 'crossfit':
      return l.gymsCategoryCrossfit;
    case 'martial':
      return l.gymsCategoryMartial;
    case 'yoga':
      return l.gymsCategoryYoga;
    default:
      return key;
  }
}

/// Formats a metres distance into the localized "X km" string. Below
/// 1000 m we show one decimal (`0.4 km`); at or above 10 km we round
/// to whole km (`12 km`); in between we round to the nearest km
/// (`3 km`). Walking icon is the caller's responsibility.
String formatDistance(double meters, AppLocalizations l) {
  if (meters < 1000) {
    final km = (meters / 1000).toStringAsFixed(1);
    return l.exploreDistanceKm(km);
  }
  final km =
      meters >= 10000 ? meters ~/ 1000 : (meters / 1000).round();
  return l.exploreDistanceKm('$km');
}
