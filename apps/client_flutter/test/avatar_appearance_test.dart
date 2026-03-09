import 'package:flutter_test/flutter_test.dart';

import 'package:the_bit_and_bond_client/features/avatar/avatar_appearance.dart';

void main() {
  test('avatar appearance round-trips through avatarType encoding', () {
    const original = AvatarAppearance(
      hairStyle: AvatarHairStyle.ponytail,
      clothTone: AvatarClothTone.sapphire,
    );

    final encoded = original.toAvatarType();
    final decoded = AvatarAppearance.fromAvatarType(encoded);

    expect(decoded.hairStyle, original.hairStyle);
    expect(decoded.clothTone, original.clothTone);
  });

  test('legacy avatar types still resolve to valid pixel appearances', () {
    final legacy = <String, AvatarAppearance>{
      'novice': AvatarAppearance.novice,
      'master': const AvatarAppearance(
        hairStyle: AvatarHairStyle.ponytail,
        clothTone: AvatarClothTone.sapphire,
      ),
      'mage': const AvatarAppearance(
        hairStyle: AvatarHairStyle.windswept,
        clothTone: AvatarClothTone.plum,
      ),
    };

    for (final entry in legacy.entries) {
      final resolved = AvatarAppearance.fromAvatarType(entry.key);
      expect(resolved.hairStyle, entry.value.hairStyle);
      expect(resolved.clothTone, entry.value.clothTone);
    }
  });
}
