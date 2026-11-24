import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import 'leaderboard_row.dart';
import 'podium.dart';

/// Podium + ranked rows where every player keeps their own tile, keyed by
/// uid. When [entries] changes (e.g. switching Vrienden ↔ Global):
///
/// - players in both lists move to their new place; podium bars change
///   height. No fading.
/// - new players grow up from the bottom of their place; avatar and name
///   fade in.
/// - players that are gone shrink down and disappear.
class AnimatedBoard extends StatefulWidget {
  const AnimatedBoard({super.key, required this.entries, required this.isMe});

  /// Sorted, best first.
  final List<LeaderboardEntry> entries;
  final bool Function(LeaderboardEntry) isMe;

  @override
  State<AnimatedBoard> createState() => _AnimatedBoardState();
}

class _Item {
  _Item(this.entry, this.rank);

  LeaderboardEntry entry;
  int rank;
  bool leaving = false;
}

class _AnimatedBoardState extends State<AnimatedBoard> {
  static const _move = Duration(milliseconds: 450);
  static const _top = 14.0;
  static const _podiumGap = 10.0;
  static const _rowHeight = 54.0;
  static const _rowGap = 8.0;

  final Map<String, _Item> _items = {};
  final Map<String, Timer> _removals = {};

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AnimatedBoard old) {
    super.didUpdateWidget(old);
    if (!identical(old.entries, widget.entries)) _sync();
  }

  void _sync() {
    final current = <String>{};
    for (final (i, e) in widget.entries.indexed) {
      current.add(e.uid);
      _removals.remove(e.uid)?.cancel();
      final item = _items[e.uid];
      if (item == null) {
        _items[e.uid] = _Item(e, i + 1);
      } else {
        item
          ..entry = e
          ..rank = i + 1
          ..leaving = false;
      }
    }
    for (final MapEntry(key: uid, value: item) in _items.entries) {
      if (current.contains(uid) || item.leaving) continue;
      item.leaving = true;
      _removals[uid] = Timer(_move, () {
        if (!mounted) return;
        setState(() {
          _items.remove(uid);
          _removals.remove(uid);
        });
      });
    }
  }

  @override
  void dispose() {
    for (final t in _removals.values) {
      t.cancel();
    }
    super.dispose();
  }

  double get _podiumHeight => PodiumStep.heightFor(1);
  double get _rowsTop => _top + _podiumHeight + 14;

  Rect _slot(int rank, double width) {
    if (rank <= 3) {
      // Visual order: 2nd, 1st, 3rd.
      final offset = switch (rank) {
        1 => 0.0,
        2 => -(PodiumStep.width + _podiumGap),
        _ => PodiumStep.width + _podiumGap,
      };
      final h = PodiumStep.heightFor(rank);
      return Rect.fromLTWH(
        width / 2 + offset - PodiumStep.width / 2,
        _top + _podiumHeight - h,
        PodiumStep.width,
        h,
      );
    }
    return Rect.fromLTWH(
      0,
      _rowsTop + (rank - 4) * (_rowHeight + _rowGap),
      width,
      _rowHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.entries.length;
    final height = count <= 3
        ? _top + _podiumHeight + 16
        : _rowsTop + (count - 3) * (_rowHeight + _rowGap) + 8;

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        // Leaving tiles first, so the ones that stay are drawn on top.
        final items = _items.entries.toList()
          ..sort(
            (a, b) => (a.value.leaving ? 0 : 1) - (b.value.leaving ? 0 : 1),
          );
        return SingleChildScrollView(
          child: AnimatedContainer(
            duration: _move,
            curve: Curves.easeInOutCubic,
            height: height,
            child: Stack(
              children: [
                for (final MapEntry(key: uid, value: item) in items)
                  _BoardTile(
                    key: ValueKey(uid),
                    item: item,
                    slot: _slot(item.rank, width),
                    isMe: !item.leaving && widget.isMe(item.entry),
                    duration: _move,
                    rowWidth: width,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoardTile extends StatefulWidget {
  const _BoardTile({
    super.key,
    required this.item,
    required this.slot,
    required this.isMe,
    required this.duration,
    required this.rowWidth,
  });

  final _Item item;

  /// Rows are laid out at full width and clipped, so they don't squash
  /// while their tile is still narrow (moving off the podium).
  final double rowWidth;
  final Rect slot;
  final bool isMe;
  final Duration duration;

  @override
  State<_BoardTile> createState() => _BoardTileState();
}

class _BoardTileState extends State<_BoardTile> {
  /// False for one frame after a new tile appears, so it can grow from 0.
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final visible = _entered && !item.leaving;
    final slot = widget.slot;
    // Collapsed: zero height at the bottom of its place.
    final rect = visible
        ? slot
        : Rect.fromLTWH(slot.left, slot.bottom, slot.width, 0);
    final onPodium = item.rank <= 3;

    return AnimatedPositioned(
      duration: widget.duration,
      curve: Curves.easeInOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: math.max(0, rect.height),
      child: AnimatedSwitcher(
        // Only when a player moves between podium and rows.
        duration: const Duration(milliseconds: 200),
        child: onPodium
            ? PodiumStep(
                key: const ValueKey('podium'),
                entry: item.entry,
                rank: item.rank,
                contentOpacity: visible ? 1 : 0,
              )
            : AnimatedOpacity(
                key: const ValueKey('row'),
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minHeight: 54,
                    maxHeight: 54,
                    minWidth: widget.rowWidth,
                    maxWidth: widget.rowWidth,
                    child: LeaderboardRow(
                      rank: item.rank,
                      name: item.entry.name,
                      tag: item.entry.tag,
                      wins: item.entry.wins,
                      losses: item.entry.losses,
                      isMe: widget.isMe,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
