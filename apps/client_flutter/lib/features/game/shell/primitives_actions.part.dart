part of '../game_shell_page.dart';

class _StampButton extends StatefulWidget {
  const _StampButton({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.tone,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final _StampTone tone;
  final VoidCallback? onPressed;

  @override
  State<_StampButton> createState() => _StampButtonState();
}

class _StampButtonState extends State<_StampButton> {
  @override
  Widget build(BuildContext context) {
    final leading =
        widget.iconWidget ??
        (widget.icon == null
            ? null
            : _PixelLabelGlyph(glyph: _iconGlyph(widget.icon!)));
    final button = PixelButton(
      label: widget.label,
      tone: _pixelToneForStampTone(widget.tone),
      compact: true,
      minWidth: kPixelButtonCompactWidth,
      maxWidth: kPixelButtonCompactWidth,
      leading: leading == null
          ? null
          : IconTheme(data: const IconThemeData(size: 18), child: leading),
      onPressed: widget.onPressed,
    );
    return Align(alignment: Alignment.center, widthFactor: 1, child: button);
  }
}

String _iconGlyph(IconData icon) {
  if (icon == Icons.groups_rounded) {
    return 'FRD';
  }
  if (icon == Icons.construction_rounded) {
    return 'TOOL';
  }
  if (icon == Icons.local_fire_department) {
    return 'FIR';
  }
  if (icon == Icons.refresh) {
    return 'REF';
  }
  if (icon == Icons.person_add_alt_1) {
    return 'ADD';
  }
  if (icon == Icons.mail_outline_rounded) {
    return 'MAIL';
  }
  if (icon == Icons.check_circle || icon == Icons.check_circle_rounded) {
    return 'OK';
  }
  if (icon == Icons.cancel || icon == Icons.close_rounded) {
    return 'NO';
  }
  if (icon == Icons.post_add) {
    return 'NEW';
  }
  if (icon == Icons.campaign) {
    return 'HORN';
  }
  if (icon == Icons.send_rounded) {
    return 'SEND';
  }
  if (icon == Icons.logout || icon == Icons.login_rounded) {
    return 'GO';
  }
  if (icon == Icons.touch_app_rounded) {
    return 'ACT';
  }
  if (icon == Icons.bookmark_add_rounded) {
    return 'SAVE';
  }
  if (icon == Icons.auto_awesome) {
    return 'STAR';
  }
  if (icon == Icons.inventory_2) {
    return 'BOX';
  }
  if (icon == Icons.badge_rounded || icon == Icons.badge) {
    return 'ID';
  }
  if (icon == Icons.menu_book_rounded) {
    return 'SC';
  }
  return 'UI';
}

PixelTone _pixelToneForStampTone(_StampTone tone) {
  return switch (tone) {
    _StampTone.wood => PixelTone.wood,
    _StampTone.green => PixelTone.green,
    _StampTone.ruby => PixelTone.ruby,
    _StampTone.blue => PixelTone.blue,
  };
}

PixelTone _pixelToneForTint(Color tint) {
  if (tint == AppColors.hpRuby) {
    return PixelTone.ruby;
  }
  if (tint == AppColors.apSapphire) {
    return PixelTone.blue;
  }
  if (tint == AppColors.stampGreen) {
    return PixelTone.green;
  }
  return PixelTone.gold;
}

Color _statCategoryColor(QuestStatCategory category) {
  return switch (category) {
    QuestStatCategory.strength => const Color(0xFFD84343),
    QuestStatCategory.intelligence => AppColors.apSapphire,
    QuestStatCategory.agility => const Color(0xFF2E7D32),
    QuestStatCategory.vitality => const Color(0xFF8E24AA),
    QuestStatCategory.charisma => const Color(0xFFF57C00),
    QuestStatCategory.none => AppColors.woodFrame,
  };
}

String _statCategoryLabel(QuestStatCategory category, {AppStrings? strings}) {
  final zhLabel = switch (category) {
    QuestStatCategory.strength => 'STR 力量',
    QuestStatCategory.intelligence => 'INT 智力',
    QuestStatCategory.agility => 'AGI 敏捷',
    QuestStatCategory.vitality => 'VIT 耐力',
    QuestStatCategory.charisma => 'CHA 魅力',
    QuestStatCategory.none => 'NONE 未分類',
  };
  final enLabel = switch (category) {
    QuestStatCategory.strength => 'STR Strength',
    QuestStatCategory.intelligence => 'INT Intelligence',
    QuestStatCategory.agility => 'AGI Agility',
    QuestStatCategory.vitality => 'VIT Vitality',
    QuestStatCategory.charisma => 'CHA Charisma',
    QuestStatCategory.none => 'NONE Unassigned',
  };
  return strings?.tr(zh: zhLabel, en: enLabel) ?? zhLabel;
}
