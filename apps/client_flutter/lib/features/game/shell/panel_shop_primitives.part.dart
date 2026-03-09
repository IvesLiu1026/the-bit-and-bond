part of '../game_shell_page.dart';

class _PixelShopItemIcon extends StatelessWidget {
  const _PixelShopItemIcon({required this.iconTag, this.size = 20});

  final String iconTag;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = iconTag.trim().toUpperCase();
    final color = switch (normalized) {
      'POTION' => const Color(0xFF42A5F5),
      'TICKET' => const Color(0xFFFFCA28),
      'TOY' => const Color(0xFFAB47BC),
      'FOOD' => const Color(0xFF66BB6A),
      'SCROLL' => const Color(0xFFE57373),
      'COIN' => const Color(0xFFFFD54F),
      _ => const Color(0xFFBCAAA4),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: const Color(0xFF3E2723), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x993E2723),
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          normalized.isEmpty ? '?' : normalized.substring(0, 1),
          style: const TextStyle(
            color: Color(0xFF1A120E),
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
