// PROTOTÍPUS — eldobható. Kérdés: hogyan nézzen ki és hol álljon a Névjegyen
// a kezdeti feltöltés letöltési csempéje (spec 0015, Q10)? Három változat a
// meglévő Névjegy oldalon, `--dart-define=PROTOTYPE=true`-val bekapcsolva.
// A váltósáv FENT áll, mert lent épp a lebegő Visszajelzés gombot vizsgáljuk.
import 'package:flutter/material.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/section_card.dart';

const bool prototypeDownloadTile = bool.fromEnvironment('PROTOTYPE');

/// In-memory state of the prototype; nothing is stored.
class PrototypeDownloadState extends ChangeNotifier {
  int variant = 0;
  bool churchOfTheDay = false;
  bool sizeKnown = true;
  bool done = false;

  static const List<String> names = [
    'A — kártya legfelül',
    'B — a mai templom formájában',
    'C — tömör sor',
  ];

  String get size => sizeKnown ? '21,8 MB' : 'kb. 22 MB';

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }
}

/// Where the tile stands relative to the church of the day.
enum TilePlace { aboveChurch, inChurchSlot }

TilePlace placeOf(int variant) =>
    variant == 0 ? TilePlace.aboveChurch : TilePlace.inChurchSlot;

Widget downloadTile(BuildContext context, PrototypeDownloadState state) {
  void start() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('PROTOTÍPUS: itt nyílna a folyamatjelző képernyő'),
    ),
  );
  return switch (state.variant) {
    0 => _VariantA(size: state.size, onStart: start),
    1 => _VariantB(size: state.size, onStart: start),
    _ => _VariantC(size: state.size, onStart: start),
  };
}

const String _explanation =
    'Letöltés nélkül csak a közeli és a már megnézett templomok érhetők el a '
    'keresésben, a Részletes keresőben és a Térképen. Ha meggondoltad magad, '
    'itt egyszer letöltheted az összes templom és mise adatait.';

/// A: a plain section card, always first on the page.
class _VariantA extends StatelessWidget {
  const _VariantA({required this.size, required this.onStart});

  final String size;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Templomok és misék letöltése',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spacing.l,
      children: [
        const Text(_explanation),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.download_rounded),
          label: Text('Letöltés ($size)'),
        ),
      ],
    ),
  );
}

/// B: the church of the day's shape, its blurred placeholder as the picture.
class _VariantB extends StatelessWidget {
  const _VariantB({required this.size, required this.onStart});

  final String size;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Az összes templom egyszerre',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Spacing.s,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.s),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/church_blurred.png',
                    fit: BoxFit.cover,
                  ),
                  Center(
                    child: Icon(
                      Icons.download_for_offline_rounded,
                      size: 64,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            'Templomok és misék letöltése',
            style: theme.textTheme.titleMedium,
          ),
          const Text(_explanation),
          const SizedBox(height: Spacing.s),
          FilledButton(onPressed: onStart, child: Text('Letöltés ($size)')),
        ],
      ),
    );
  }
}

/// C: one row like the miserend.hu link, the action at its end.
class _VariantC extends StatelessWidget {
  const _VariantC({required this.size, required this.onStart});

  final String size;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Card(
    margin: SectionCard.margin,
    child: Padding(
      padding: const EdgeInsets.all(Spacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Spacing.s,
        children: [
          Row(
            spacing: Spacing.l,
            children: [
              const Icon(Icons.cloud_download_outlined),
              Expanded(
                child: Text(
                  'Templomok és misék letöltése',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          Text(
            'Az összes templom a keresésben és a Térképen. $size, egyszer.',
            style: Theme.of(context).textTheme.bodyMedium?.apply(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              onPressed: onStart,
              child: const Text('Letöltés'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The prototype's switcher, pinned under the app bar.
class PrototypeSwitcher extends StatelessWidget {
  const PrototypeSwitcher({super.key, required this.state});

  final PrototypeDownloadState state;

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    const names = PrototypeDownloadState.names;
    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) =>
        FilterChip(
          label: Text(label),
          selected: value,
          onSelected: onChanged,
          visualDensity: VisualDensity.compact,
        );
    return Material(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.s,
          vertical: Spacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  color: fg,
                  icon: const Icon(Icons.chevron_left),
                  onPressed:
                      () => state.update(
                        () =>
                            state.variant =
                                (state.variant - 1 + names.length) %
                                names.length,
                      ),
                ),
                Expanded(
                  child: Text(
                    names[state.variant],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: fg),
                  ),
                ),
                IconButton(
                  color: fg,
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      () => state.update(
                        () =>
                            state.variant = (state.variant + 1) % names.length,
                      ),
                ),
              ],
            ),
            Wrap(
              spacing: Spacing.s,
              children: [
                toggle(
                  'Van mai templom',
                  state.churchOfTheDay,
                  (v) => state.update(() => state.churchOfTheDay = v),
                ),
                toggle(
                  'Méret ismert',
                  state.sizeKnown,
                  (v) => state.update(() => state.sizeKnown = v),
                ),
                toggle(
                  'Letöltve',
                  state.done,
                  (v) => state.update(() => state.done = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
