part of 'chen_game.dart';

enum TavernFurnitureType {
  noticeBoard,
  masterDesk,
  guildChest,
  campfireBar,
  guildMerchant,
  wallBookshelf,
  honorBanner,
  trainingDummy,
}

enum TavernVisualTheme { cozyWood, technoMinimal, hotbloodAdventure }

class SandboxRoomSnapshot {
  const SandboxRoomSnapshot({
    required this.id,
    required this.label,
    required this.index,
    required this.isCurrent,
    required this.accentColor,
    required this.floorColor,
    required this.wallColor,
    required this.hasLeftPortal,
    required this.hasRightPortal,
    required this.hasDummy,
    this.playerMarker,
    this.dummyMarker,
  });

  final String id;
  final String label;
  final int index;
  final bool isCurrent;
  final Color accentColor;
  final Color floorColor;
  final Color wallColor;
  final bool hasLeftPortal;
  final bool hasRightPortal;
  final bool hasDummy;
  final Offset? playerMarker;
  final Offset? dummyMarker;
}

class _SandboxRoomPalette {
  const _SandboxRoomPalette({
    required this.backgroundColor,
    required this.wallColor,
    required this.wallShadeColor,
    required this.sideWallColor,
    required this.floorBaseColor,
    required this.floorTileA,
    required this.floorTileB,
    required this.gridLineColor,
    required this.borderColor,
    required this.glowColor,
    required this.portalCoreColor,
    required this.portalRingColor,
    required this.mapAccentColor,
  });

  final Color backgroundColor;
  final Color wallColor;
  final Color wallShadeColor;
  final Color sideWallColor;
  final Color floorBaseColor;
  final Color floorTileA;
  final Color floorTileB;
  final Color gridLineColor;
  final Color borderColor;
  final Color glowColor;
  final Color portalCoreColor;
  final Color portalRingColor;
  final Color mapAccentColor;
}

class _SandboxRoomDefinition {
  const _SandboxRoomDefinition({
    required this.id,
    required this.label,
    required this.palette,
    this.leftPortalTargetIndex,
    this.rightPortalTargetIndex,
    this.hasDummy = false,
  });

  final String id;
  final String label;
  final _SandboxRoomPalette palette;
  final int? leftPortalTargetIndex;
  final int? rightPortalTargetIndex;
  final bool hasDummy;
}

class HunterRealtimePose {
  HunterRealtimePose({
    required this.hunterId,
    required this.x,
    required this.y,
    required this.facing,
    required this.moving,
    required this.updatedAtMs,
  });

  final String hunterId;
  final double x;
  final double y;
  final String facing;
  final bool moving;
  final int updatedAtMs;

  Map<String, dynamic> toClientMessage() {
    return {
      'type': 'pose',
      'hunter_id': hunterId,
      'x': x,
      'y': y,
      'facing': facing,
      'moving': moving,
    };
  }

  static HunterRealtimePose? fromServerJson(Map<String, dynamic> json) {
    final hunterId = json['hunter_id'] as String?;
    final xRaw = json['x'];
    final yRaw = json['y'];
    final facing = (json['facing'] as String?)?.trim();
    final moving = json['moving'] as bool?;
    final updatedAtMs = json['updated_at_ms'];

    if (hunterId == null ||
        xRaw is! num ||
        yRaw is! num ||
        facing == null ||
        moving == null ||
        updatedAtMs is! int) {
      return null;
    }
    return HunterRealtimePose(
      hunterId: hunterId,
      x: xRaw.toDouble(),
      y: yRaw.toDouble(),
      facing: facing,
      moving: moving,
      updatedAtMs: updatedAtMs,
    );
  }
}
