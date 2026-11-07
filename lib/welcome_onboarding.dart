// The welcome pop-up shown the first time someone uses the app (after logging in for the first time, or entering
// guest mode). It is a short set of pages the user swipes through, or steps through with Next and Back.
//
// To change what it says, edit welcomePages below: add, remove or reorder pages, or change their text and icons.

import 'package:flutter/material.dart';

class OnboardingPage {
  final IconData icon;
  final String title;
  final String body;

  const OnboardingPage({required this.icon, required this.title, required this.body});
}

// TODO: replace this placeholder text with the real explanation.
const List<OnboardingPage> welcomePages = [
  OnboardingPage(
    icon: Icons.waving_hand,
    title: 'Welcome to NetGauge Games',
    body: 'This is placeholder text for the welcome page. Use this page to introduce the app and the project, '
        'and to say what players can expect.\n\n'
        'Swipe left, or tap Next, to keep reading.',
  ),
  OnboardingPage(
    icon: Icons.sports_esports,
    title: 'Play games, measure the internet',
    body: 'This is placeholder text explaining how the games work. While you play, the app measures your internet '
        'speed and records where the measurement was taken.\n\n'
        'Explain here how to start a game, what the goal is, and how long a game takes.',
  ),
  OnboardingPage(
    icon: Icons.map,
    title: 'See the bigger picture',
    body: 'This is placeholder text about the map and community statistics. Measurements from players are combined '
        'to show how internet quality varies from place to place.\n\n'
        'Explain here what the heat map shows and how to open it.',
  ),
  OnboardingPage(
    icon: Icons.lock_outline,
    title: 'Your data and privacy',
    body: 'This is placeholder text about privacy. Explain here what is collected, what is shared anonymously, '
        'and how guests differ from people with an account.\n\n'
        "That's it. Tap Get Started to begin!",
  ),
];

// Shows the welcome pop-up and completes when the user closes it (by finishing, skipping, or the back button).
Future<void> showWelcomeOnboarding(BuildContext context, {List<OnboardingPage> pages = welcomePages}) {
  return showDialog<void>(
    context: context,
    // the pop-up is closed with its own buttons, so a stray tap outside does not lose the user's place
    barrierDismissible: false,
    builder: (dialogContext) => WelcomeDialog(pages: pages),
  );
}

class WelcomeDialog extends StatefulWidget {
  final List<OnboardingPage> pages;

  const WelcomeDialog({super.key, required this.pages});

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  final PageController _controller = PageController();
  int _page = 0;

  bool get _isFirst => _page == 0;
  bool get _isLast => _page == widget.pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _close() => Navigator.of(context).pop();

  Widget _buildPage(OnboardingPage page) {
    final colors = Theme.of(context).colorScheme;
    // each page scrolls on its own, so longer text still fits on a small screen
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Icon(page.icon, size: 72, color: colors.primary),
          const SizedBox(height: 20),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(page.body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildDots() {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.pages.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _page ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i == _page ? colors.primary : colors.outlineVariant,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: (height * 0.75).clamp(380.0, 600.0)),
        child: Column(
          children: [
            // keeps its space on the last page so the pages do not shift
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Visibility(
                  visible: !_isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(onPressed: _close, child: const Text('Skip')),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: [for (final page in widget.pages) _buildPage(page)],
              ),
            ),
            const SizedBox(height: 8),
            _buildDots(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  // Back keeps its space on the first page so Next stays in the same place
                  Visibility(
                    visible: !_isFirst,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(onPressed: () => _goTo(_page - 1), child: const Text('Back')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isLast ? _close : () => _goTo(_page + 1),
                    child: Text(_isLast ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
