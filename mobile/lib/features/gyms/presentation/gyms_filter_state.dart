import 'package:flutter_riverpod/flutter_riverpod.dart';

final gymsCategoryFilterProvider = StateProvider<String>((_) => 'all');
final gymsSearchQueryProvider = StateProvider<String>((_) => '');

/// Set of tier keys the user has toggled on in the filter sheet. Empty means
/// "don't filter by tier" (show all four) — same semantic as "all" in the
/// category filter, but modelled as a set so the UI can render multi-select
/// chips that coexist with the category dropdown.
final gymsTierFilterProvider = StateProvider<Set<String>>((_) => <String>{});

/// True when the user wants to see only the gyms they've favorited from the
/// detail page heart toggle. The heart button on the gyms list header drives
/// this; pairs with [favoritedGymsProvider] to define the filter.
final gymsFavoritesOnlyProvider = StateProvider<bool>((_) => false);

/// One-shot flag: true means the next mount of /explore should auto-
/// expand the sheet to mid (so the gym list is visible). Set by the
/// home page before navigating from "SEE ALL" or a category tile —
/// the member arrived *expecting* to see a list, so the sheet
/// shouldn't sit at peek and make them tap to open it. Reset to
/// false right after the explore page applies it, so re-entering
/// /explore via the bottom-nav stays at the default peek state.
final exploreSheetOpenOnArrivalProvider = StateProvider<bool>((_) => false);
