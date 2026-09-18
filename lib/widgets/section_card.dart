import 'package:flutter/material.dart';

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

  final String? title;
  final Widget child;

  /// Sits on the title's row, for a section that carries an action.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
