part of 'game_shell_page.dart';

class _InventoryPanel extends StatefulWidget {
  const _InventoryPanel({required this.inventoryState, required this.onUse});

  final AsyncValue<List<InventoryItem>> inventoryState;
  final Future<InventoryUseResult> Function({required InventoryItem item})
  onUse;

  @override
  State<_InventoryPanel> createState() => _InventoryPanelState();
}

class _InventoryPanelState extends State<_InventoryPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _consumeController;
  String? _usingItemId;
  String? _highlightItemId;
  String? _errorText;
  String? _successText;

  @override
  void initState() {
    super.initState();
    _consumeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void dispose() {
    _consumeController.dispose();
    super.dispose();
  }

  Future<void> _confirmUse(InventoryItem item) async {
    if (_usingItemId != null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: _OverlayPanel(
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '確認使用道具',
                    style: TextStyle(
                      color: AppColors.inkBrown,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '確定要使用「${item.name}」嗎？',
                    style: const TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StampButton(
                          label: '取消',
                          tone: _StampTone.wood,
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StampButton(
                          label: '確定使用',
                          tone: _StampTone.green,
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _usingItemId = item.itemId;
      _errorText = null;
      _successText = null;
    });

    try {
      final result = await widget.onUse(item: item);
      if (!mounted) {
        return;
      }
      setState(() {
        _successText = '兌換成功！${result.itemName} 剩餘 ${result.remainingQuantity}';
        _highlightItemId = item.itemId;
      });
      _consumeController.forward(from: 0);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '使用失敗：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _usingItemId = null;
        });
      }
    }
  }

  Widget _buildInventoryActionRow({
    required InventoryItem item,
    required bool using,
    required bool stacked,
  }) {
    final quantityChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7DDC9),
        border: Border.all(color: AppColors.woodFrame, width: 2),
      ),
      child: Text(
        'x${item.quantity}',
        style: const TextStyle(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    final useButton = _StampButton(
      label: using ? '處理中' : '使用',
      tone: _StampTone.green,
      onPressed: using ? null : () => _confirmUse(item),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          quantityChip,
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: useButton),
        ],
      );
    }

    return Row(
      children: [
        quantityChip,
        const Spacer(),
        SizedBox(width: 96, child: useButton),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '冒險背包',
          style: TextStyle(
            color: AppColors.inkBrown,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '點擊道具即可核銷。核銷後會同步公告到公會聊天室。',
          style: TextStyle(
            color: AppColors.navyBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _errorText!,
              style: const TextStyle(
                color: AppColors.hpRuby,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        if (_successText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _successText!,
              style: const TextStyle(
                color: AppColors.stampGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        Expanded(
          child: widget.inventoryState.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text(
                    '背包是空的，先去商店兌換一些道具吧。',
                    style: TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = math.max(
                    1,
                    math.min(3, (constraints.maxWidth / 220).floor()),
                  );
                  final mainAxisExtent = switch (crossAxisCount) {
                    1 => 170.0,
                    2 => 206.0,
                    _ => 214.0,
                  };
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      mainAxisExtent: mainAxisExtent,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final using = _usingItemId == item.itemId;
                      return GestureDetector(
                        onTap: using ? null : () => _confirmUse(item),
                        child: AnimatedBuilder(
                          animation: _consumeController,
                          builder: (context, child) {
                            final highlighted = _highlightItemId == item.itemId;
                            final t = highlighted
                                ? Curves.easeOut.transform(
                                    _consumeController.value,
                                  )
                                : 0.0;
                            final scale = highlighted
                                ? (1.0 + (0.08 * (1 - t)))
                                : 1.0;
                            final opacity = highlighted
                                ? (0.75 + (0.25 * t))
                                : 1.0;
                            return Opacity(
                              opacity: opacity,
                              child: Transform.scale(
                                scale: scale,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4ECE1),
                              border: Border.all(
                                color: using
                                    ? AppColors.navyBlue
                                    : const Color(0xFF5D4037),
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xAA3E2723),
                                  offset: Offset(0, 4),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _PixelShopItemIcon(
                                      iconTag: item.iconTag,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.inkBrown,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, cardConstraints) {
                                      final stackedActions =
                                          cardConstraints.maxWidth < 180;
                                      final descriptionMaxLines = stackedActions
                                          ? 2
                                          : 3;
                                      return Text(
                                        item.description?.trim().isNotEmpty ==
                                                true
                                            ? item.description!
                                            : '可於家庭任務流程中核銷',
                                        maxLines: descriptionMaxLines,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.navyBlue,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 6),
                                LayoutBuilder(
                                  builder: (context, cardConstraints) {
                                    return _buildInventoryActionRow(
                                      item: item,
                                      using: using,
                                      stacked: cardConstraints.maxWidth < 180,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: _PixelLoadingBar()),
            error: (err, _) => Center(
              child: Text(
                '背包讀取失敗：$err',
                style: const TextStyle(
                  color: AppColors.hpRuby,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
