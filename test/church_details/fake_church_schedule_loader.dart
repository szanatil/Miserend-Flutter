import 'package:miserend/church_details/church_page_data.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/church.dart';

/// Lets the details page open without a database or a network call. It
/// answers with [page] from the cache and from the API alike: an empty page
/// unless one is given.
class FakeChurchScheduleLoader extends ChurchScheduleLoader {
  FakeChurchScheduleLoader([ChurchPageData? page])
    : page =
          page ??
          ChurchPageData(
            church: null,
            massesByDay: List.generate(
              ChurchScheduleLoader.scheduleDays,
              (_) => <CachedMass>[],
            ),
            scheduleIsFresh: false,
            confessionLive: false,
          );

  final ChurchPageData page;

  @override
  Future<ChurchPageData> loadCached(int churchId, DateTime today) async => page;

  @override
  Future<ChurchPageData> refresh(Church church, DateTime today) async => page;
}
