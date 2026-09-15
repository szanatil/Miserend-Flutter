import 'package:miserend/database/church.dart';
import 'package:miserend/database/mass.dart';

class ChurchWithMasses {

  final Church church;
  final List<Mass> masses;

  /// True when the export is too old to place its masses on the right day, in
  /// which case [masses] is empty whatever the church really holds.
  final bool massesExpired;

  ChurchWithMasses(this.church, this.masses, {this.massesExpired = false});
}
