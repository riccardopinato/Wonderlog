import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../domain/rediscover_models.dart';

final class JourneyReplayPage extends StatefulWidget {
  const JourneyReplayPage({
    super.key,
    required this.replay,
  });

  final JourneyReplay replay;

  @override
  State<JourneyReplayPage> createState() => _JourneyReplayPageState();
}

final class _JourneyReplayPageState extends State<JourneyReplayPage> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    if (!_playing || widget.replay.slides.length <= 1) return;
    final slide = widget.replay.slides[_index];
    final duration = slide.type == JourneyReplaySlideType.memory
        ? const Duration(milliseconds: 6500)
        : const Duration(milliseconds: 4500);
    _timer = Timer(duration, () {
      if (!mounted || !_playing) return;
      if (_index >= widget.replay.slides.length - 1) {
        setState(() => _playing = false);
        return;
      }
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.replay.slides.length,
              onPageChanged: (value) {
                setState(() => _index = value);
                _schedule();
              },
              itemBuilder: (context, index) =>
                  _ReplaySlide(slide: widget.replay.slides[index]),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: widget.replay.slides.isEmpty
                          ? 0
                          : (_index + 1) / widget.replay.slides.length,
                    ),
                  ),
                  const SizedBox(width: WonderlogSpacing.small),
                  IconButton(
                    color: Colors.white,
                    onPressed: () {
                      setState(() => _playing = !_playing);
                      _schedule();
                    },
                    icon: Icon(
                      _playing ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                  IconButton(
                    color: Colors.white,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
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

final class _ReplaySlide extends StatelessWidget {
  const _ReplaySlide({required this.slide});

  final JourneyReplaySlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(WonderlogSpacing.large),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            switch (slide.type) {
              JourneyReplaySlideType.cover => Icons.flight_takeoff,
              JourneyReplaySlideType.photo => Icons.photo_outlined,
              JourneyReplaySlideType.memory => Icons.auto_stories_outlined,
              JourneyReplaySlideType.place => Icons.place_outlined,
              JourneyReplaySlideType.end => Icons.favorite_outline,
            },
            size: 64,
            color: Colors.white70,
          ),
          const SizedBox(height: WonderlogSpacing.large),
          if ((slide.title ?? '').isNotEmpty)
            Text(
              slide.title!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          if ((slide.subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: WonderlogSpacing.medium),
            Text(
              slide.subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
