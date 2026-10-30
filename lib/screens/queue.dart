import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final AudioService _a = AudioService.instance;
  int _tab = 0; // 0 = whole queue, 1 = up next

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Queue')),
      body: ListenableBuilder(
        listenable: _a,
        builder: (context, _) {
          final q = _a.queue;
          if (q.isEmpty) {
            return const EmptyState(
              icon: Icons.queue_music_rounded,
              title: 'Queue is empty',
              hint: 'Play a song or use "Add to queue" from a song menu.',
            );
          }
          final start = _tab == 0 ? 0 : _a.index + 1;
          final count = (q.length - start).clamp(0, q.length).toInt();
          return Column(
            children: [
              PillChips(
                labels: const ['Now Playing', 'Up Next'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: count == 0
                    ? const EmptyState(
                        icon: Icons.playlist_add_check_rounded,
                        title: 'Nothing up next',
                        hint: 'Add songs to the queue from any song menu.',
                      )
                    : ListView.builder(
                        itemCount: count,
                        itemBuilder: (context, k) {
                          final i = start + k;
                          final t = q[i];
                          final isCurrent = i == _a.index;
                          return InkWell(
                            onTap: () => _a.jumpTo(i),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 7, 8, 7),
                              child: Row(
                                children: [
                                  ArtImage(path: t.path, size: 50, radius: 10),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.niceTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600)),
                                        const SizedBox(height: 3),
                                        Text(t.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12.5, color: c.muted)),
                                      ],
                                    ),
                                  ),
                                  if (isCurrent)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Icon(Icons.graphic_eq_rounded, color: c.accent),
                                    )
                                  else ...[
                                    Text(fmtDur(t.duration), style: TextStyle(fontSize: 12.5, color: c.muted)),
                                    IconButton(
                                      icon: Icon(Icons.close_rounded, color: c.muted, size: 20),
                                      onPressed: () => _a.removeAt(i),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.text,
                        side: BorderSide(color: c.border),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        await _a.stop();
                        if (context.mounted) Navigator.of(context).maybePop();
                      },
                      child: const Text('Clear Queue'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
