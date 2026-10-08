import 'package:flutter/material.dart';
import 'package:miserend/theme/tokens.dart';

/// One block of the church details page and the Névjegy page.
///
/// The page used to alternate hand-rolled `Colors.black12` bands with bare
/// `Card`s, which is why no two sections lined up. Every section now goes
/// through here instead, so adding one does not mean re-deciding the padding.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.trailing,
  });

  /// Around a card standing straight on a page: the screen edge's distance to
  /// the sides, and the theme's half gap above and below (DESIGN.md TK2).
  static const EdgeInsets margin = EdgeInsets.symmetric(
    horizontal: Spacing.l,
    vertical: Spacing.xs,
  );

  final String? title;
  final Widget child;

  /// Sits on the title's row, for a section that carries an action.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: Spacing.s),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
