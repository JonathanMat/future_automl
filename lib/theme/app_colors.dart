import 'package:flutter/material.dart';

/// All colours from the Spell Duel design.
abstract final class AppColors {
  // Backgrounds
  static const backdrop = Color(0xFF07060F);
  static const background = Color(0xFF0E0B1F);
  static const surface = Color(0xFF1A1533);
  static const surfaceRaised = Color(0xFF2E2560);
  static const surfaceRaisedShadow = Color(0xFF1C1640);
  static const track = Color(0xFF2A2350);
  static const trackOff = Color(0xFF3A3366);
  static const feedDeep = Color(0xFF120E26);
  static const hexInner = Color(0xFF150F2E);
  static const overlay = Color(0xB3080614); // rgba(8,6,20,.7)

  static const border = Color(0x0FFFFFFF); // white 6%
  static const borderStrong = Color(0x14FFFFFF); // white 8%
  static const borderInput = Color(0x1AFFFFFF); // white 10%

  // Text
  static const text = Color(0xFFF4F1FF);
  static const textSoft = Color(0xFFC8C3E3);
  static const textMuted = Color(0xFFA39DC4);
  static const textFeed = Color(0xFFB9B2DD);
  static const textHint = Color(0xFF8F88B5);
  static const lavender = Color(0xFFC9B8FF);
  static const lavenderLight = Color(0xFFE3DEFF);

  // Accents
  static const gold = Color(0xFFFFB020);
  static const goldShadow = Color(0xFFC27800);
  static const goldInk = Color(0xFF2A1600);
  static const goldLight = Color(0xFFFFD978);
  static const goldNumber = Color(0xFFFFE29A);
  static const goldNumberShadow = Color(0xFFE08A00);
  static const goldNumberDeep = Color(0xFF8A4B00);
  static const goldTitleShadow = Color(0xFF8A5400);

  static const purple = Color(0xFF7B4DF0);
  static const purpleShadow = Color(0xFF4A2BAE);
  static const violet = Color(0xFF8B5CF6);
  static const shieldPip = Color(0xFF8B7CFF);

  static const green = Color(0xFF3DDC97);
  static const greenShadow = Color(0xFF1E8F5E);
  static const greenInk = Color(0xFF06281A);

  static const red = Color(0xFFFF3D62);
  static const redSoft = Color(0xFFFF5D7A);
  static const redDeep = Color(0xFF8A0F2A);

  static const teal = Color(0xFF1E9E8A);
  static const tealShadow = Color(0xFF0F6B5C);
  static const tealBorder = Color(0x7334C7AE);

  static const orangeText = Color(0xFFFF9A57);
  static const silver = Color(0xFFC8C3E3);
  static const bronze = Color(0xFFD98B4E);

  /// Avatar colours, picked from a player's name.
  static const avatars = <Color>[
    Color(0xFF7B4DF0),
    Color(0xFF1E9E8A),
    Color(0xFFD9467A),
    Color(0xFFE0732B),
    Color(0xFF2F7FD9),
    Color(0xFF3E9B4F),
    Color(0xFFC24DB8),
    Color(0xFF8A6A3A),
  ];

  /// The darker "3D" edge under an avatar tile.
  static Color shadowOf(Color c) => Color.lerp(c, Colors.black, 0.4) ?? c;
}
