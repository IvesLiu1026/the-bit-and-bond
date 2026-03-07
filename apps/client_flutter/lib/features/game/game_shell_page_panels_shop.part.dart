part of 'game_shell_page.dart';

class _GuildShopPanel extends StatefulWidget {
  const _GuildShopPanel({
    required this.shopState,
    required this.progressionState,
    required this.isMaster,
    required this.onBuy,
    required this.onManageModeChanged,
    required this.onCreateItem,
    required this.onUpdateItem,
    required this.onDeactivateItem,
  });

  final AsyncValue<List<GuildShopItem>> shopState;
  final AsyncValue<Progression> progressionState;
  final bool isMaster;
  final Future<ShopPurchaseResult> Function(GuildShopItem item) onBuy;
  final Future<void> Function(bool enabled) onManageModeChanged;
  final Future<GuildShopItem> Function({
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  })
  onCreateItem;
  final Future<GuildShopItem> Function({
    required String itemId,
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  })
  onUpdateItem;
  final Future<void> Function(String itemId) onDeactivateItem;

  @override
  State<_GuildShopPanel> createState() => _GuildShopPanelState();
}

class _GuildShopPanelState extends State<_GuildShopPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  String? _buyingItemId;
  String? _editingItemId;
  bool _switchingMode = false;
  bool _manageMode = false;
  String? _errorText;
  String? _successText;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _buyItem(GuildShopItem item, int currentCoins) async {
    if (_buyingItemId != null) {
      return;
    }
    if (currentCoins < item.costCoins) {
      _triggerInsufficient('金幣不足，請先完成懸賞任務');
      return;
    }

    setState(() {
      _buyingItemId = item.id;
      _errorText = null;
      _successText = null;
    });

    try {
      final result = await widget.onBuy(item);
      if (!mounted) {
        return;
      }
      setState(() {
        _successText = result.replayed
            ? '偵測到重複點擊，已沿用上次購買結果'
            : '購買成功：${result.item.name} x${result.inventoryQuantity}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final text = error.toString();
      if (text.contains('coins not enough')) {
        _triggerInsufficient('金幣不足，請先完成懸賞任務');
      } else {
        setState(() {
          _errorText = '購買失敗：$error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _buyingItemId = null;
        });
      }
    }
  }

  void _triggerInsufficient(String message) {
    setState(() {
      _errorText = message;
      _successText = null;
    });
    _shakeController.forward(from: 0);
  }

  Future<void> _toggleManageMode() async {
    if (_switchingMode) {
      return;
    }
    final next = !_manageMode;
    setState(() {
      _switchingMode = true;
      _errorText = null;
      _successText = null;
    });
    try {
      await widget.onManageModeChanged(next);
      if (!mounted) {
        return;
      }
      setState(() {
        _manageMode = next;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '切換管理模式失敗：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _switchingMode = false;
        });
      }
    }
  }

  Future<void> _createItem() async {
    final draft = await _showItemEditorDialog();
    if (draft == null) {
      return;
    }
    setState(() {
      _editingItemId = 'new';
      _errorText = null;
      _successText = null;
    });
    try {
      final created = await widget.onCreateItem(
        name: draft.name,
        description: draft.description,
        costCoins: draft.costCoins,
        iconTag: draft.iconTag,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _successText = '已上架商品：${created.name}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '上架失敗：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _editingItemId = null;
        });
      }
    }
  }

  Future<void> _editItem(GuildShopItem item) async {
    final draft = await _showItemEditorDialog(initial: item);
    if (draft == null) {
      return;
    }
    setState(() {
      _editingItemId = item.id;
      _errorText = null;
      _successText = null;
    });
    try {
      final updated = await widget.onUpdateItem(
        itemId: item.id,
        name: draft.name,
        description: draft.description,
        costCoins: draft.costCoins,
        iconTag: draft.iconTag,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _successText = '已更新商品：${updated.name}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '更新失敗：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _editingItemId = null;
        });
      }
    }
  }

  Future<void> _deactivateItem(GuildShopItem item) async {
    if (!item.isActive) {
      return;
    }
    setState(() {
      _editingItemId = item.id;
      _errorText = null;
      _successText = null;
    });
    try {
      await widget.onDeactivateItem(item.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _successText = '已下架商品：${item.name}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '下架失敗：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _editingItemId = null;
        });
      }
    }
  }

  Future<_ShopItemDraft?> _showItemEditorDialog({
    GuildShopItem? initial,
  }) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    final costController = TextEditingController(
      text: initial?.costCoins.toString() ?? '10',
    );
    String iconTag = (initial?.iconTag ?? 'TICKET').toUpperCase();
    String? localError;

    final result = await showDialog<_ShopItemDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final media = MediaQuery.of(dialogContext);
            final maxWidth = math.min(420.0, media.size.width - 24);
            final maxHeight = math.max(
              260.0,
              media.size.height -
                  media.padding.vertical -
                  media.viewInsets.vertical -
                  24,
            );
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: media.viewInsets,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: _OverlayPanel(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              initial == null ? '上架商品' : '編輯商品',
                              style: const TextStyle(
                                color: AppColors.inkBrown,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ShopField(controller: nameController, label: '名稱'),
                            const SizedBox(height: 8),
                            _ShopField(
                              controller: descriptionController,
                              label: '描述（可留空）',
                            ),
                            const SizedBox(height: 8),
                            _ShopField(
                              controller: costController,
                              label: '價格（金幣）',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: iconTag,
                              decoration: const InputDecoration(
                                labelText: '圖示',
                                filled: true,
                                fillColor: Color(0xFFE7DDC9),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.woodFrame,
                                    width: 2.2,
                                  ),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'TICKET',
                                  child: Text('TICKET'),
                                ),
                                DropdownMenuItem(
                                  value: 'POTION',
                                  child: Text('POTION'),
                                ),
                                DropdownMenuItem(
                                  value: 'TOY',
                                  child: Text('TOY'),
                                ),
                                DropdownMenuItem(
                                  value: 'FOOD',
                                  child: Text('FOOD'),
                                ),
                                DropdownMenuItem(
                                  value: 'SCROLL',
                                  child: Text('SCROLL'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setLocalState(() {
                                  iconTag = value;
                                });
                              },
                            ),
                            if (localError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                localError!,
                                style: const TextStyle(
                                  color: AppColors.hpRuby,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _StampButton(
                                    label: '取消',
                                    tone: _StampTone.wood,
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StampButton(
                                    label: '儲存',
                                    tone: _StampTone.green,
                                    onPressed: () {
                                      final name = nameController.text.trim();
                                      final cost = int.tryParse(
                                        costController.text.trim(),
                                      );
                                      if (name.isEmpty) {
                                        setLocalState(() {
                                          localError = '名稱不能空白';
                                        });
                                        return;
                                      }
                                      if (cost == null || cost < 0) {
                                        setLocalState(() {
                                          localError = '價格必須是 0 以上整數';
                                        });
                                        return;
                                      }
                                      Navigator.of(dialogContext).pop(
                                        _ShopItemDraft(
                                          name: name,
                                          description:
                                              descriptionController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : descriptionController.text
                                                    .trim(),
                                          costCoins: cost,
                                          iconTag: iconTag,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    costController.dispose();
    return result;
  }

  Widget _buildItemActions({
    required GuildShopItem item,
    required bool compactCard,
    required bool buying,
    required bool editing,
    required bool affordable,
    required int currentCoins,
  }) {
    if (_manageMode) {
      final actions = <Widget>[
        Expanded(
          child: _StampButton(
            label: editing ? '處理中' : '編輯',
            tone: _StampTone.blue,
            iconWidget: const _PixelLabelGlyph(glyph: 'EDT'),
            onPressed: editing ? null : () => _editItem(item),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StampButton(
            label: item.isActive ? '下架' : '已下架',
            tone: item.isActive ? _StampTone.ruby : _StampTone.wood,
            iconWidget: const _PixelLabelGlyph(glyph: 'OFF'),
            onPressed: editing || !item.isActive
                ? null
                : () => _deactivateItem(item),
          ),
        ),
      ];
      if (compactCard) {
        return Row(children: actions);
      }
      return SizedBox(width: 196, child: Row(children: actions));
    }

    final purchaseButton = _StampButton(
      label: buying ? '購買中' : '購買',
      tone: affordable ? _StampTone.green : _StampTone.ruby,
      iconWidget: const _PixelLabelGlyph(glyph: 'BUY'),
      onPressed: buying ? null : () => _buyItem(item, currentCoins),
    );
    if (compactCard) {
      return purchaseButton;
    }
    return SizedBox(width: 108, child: purchaseButton);
  }

  Widget _buildItemContent({
    required GuildShopItem item,
    required bool compactCard,
    required bool buying,
    required bool editing,
    required bool affordable,
    required int currentCoins,
  }) {
    final detailColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: const TextStyle(
            color: AppColors.inkBrown,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        if (item.description != null && item.description!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              item.description!,
              style: const TextStyle(
                color: AppColors.navyBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const _PixelShopItemIcon(iconTag: 'COIN', size: 16),
            const SizedBox(width: 5),
            Text(
              '${item.costCoins}',
              style: const TextStyle(
                color: AppColors.inkBrown,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        if (_manageMode) ...[
          const SizedBox(height: 6),
          Text(
            item.isActive ? '狀態：上架中' : '狀態：已下架',
            style: TextStyle(
              color: item.isActive ? AppColors.stampGreen : AppColors.hpRuby,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
    final actionPanel = _buildItemActions(
      item: item,
      compactCard: compactCard,
      buying: buying,
      editing: editing,
      affordable: affordable,
      currentCoins: currentCoins,
    );

    if (compactCard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PixelShopItemIcon(iconTag: item.iconTag),
              const SizedBox(width: 10),
              Expanded(child: detailColumn),
            ],
          ),
          const SizedBox(height: 10),
          actionPanel,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PixelShopItemIcon(iconTag: item.iconTag),
        const SizedBox(width: 10),
        Expanded(child: detailColumn),
        const SizedBox(width: 8),
        actionPanel,
      ],
    );
  }

  Widget _buildMasterControls(BoxConstraints constraints) {
    final stacked = constraints.maxWidth < 440;
    final manageButton = _StampButton(
      label: _switchingMode ? '切換中...' : (_manageMode ? '返回購買' : '管理商品'),
      tone: _StampTone.wood,
      iconWidget: const _PixelLabelGlyph(glyph: 'CFG'),
      onPressed: _switchingMode ? null : _toggleManageMode,
    );
    final createButton = _StampButton(
      label: _editingItemId == 'new' ? '上架中' : '新增商品',
      tone: _StampTone.green,
      iconWidget: const _PixelLabelGlyph(glyph: 'NEW'),
      onPressed: _editingItemId == null ? _createItem : null,
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: double.infinity, child: manageButton),
          if (_manageMode) const SizedBox(height: 8),
          if (_manageMode)
            SizedBox(width: double.infinity, child: createButton),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: manageButton),
        if (_manageMode) const SizedBox(width: 8),
        if (_manageMode) Expanded(child: createButton),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCoins = widget.progressionState.maybeWhen(
      data: (progression) => progression.coins,
      orElse: () => 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '公會商店',
          style: TextStyle(
            color: AppColors.inkBrown,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.isMaster)
          LayoutBuilder(
            builder: (context, constraints) {
              return _buildMasterControls(constraints);
            },
          ),
        if (widget.isMaster) const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8EED7),
            border: Border.all(color: const Color(0xFF7B5A3C), width: 2.6),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA3E2723),
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              const _PixelShopItemIcon(iconTag: 'COIN'),
              const SizedBox(width: 8),
              Text(
                '目前持有金幣：$currentCoins',
                style: const TextStyle(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
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
          child: widget.shopState.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text(
                    '商店暫無商品，稍後再來逛逛。',
                    style: TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final buying = _buyingItemId == item.id;
                  final editing = _editingItemId == item.id;
                  final affordable = currentCoins >= item.costCoins;
                  return AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      final shaking =
                          !affordable && _shakeController.isAnimating;
                      final dx = shaking
                          ? (math.sin(_shakeController.value * math.pi * 8) * 8)
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4ECE1),
                        border: Border.all(
                          color: affordable
                              ? const Color(0xFF5D4037)
                              : const Color(0xFFB71C1C),
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compactCard =
                              constraints.maxWidth < (_manageMode ? 460 : 360);
                          return _buildItemContent(
                            item: item,
                            compactCard: compactCard,
                            buying: buying,
                            editing: editing,
                            affordable: affordable,
                            currentCoins: currentCoins,
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: _PixelLoadingBar()),
            error: (err, _) => Center(
              child: Text(
                '商店讀取失敗：$err',
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

class _ShopItemDraft {
  const _ShopItemDraft({
    required this.name,
    required this.description,
    required this.costCoins,
    required this.iconTag,
  });

  final String name;
  final String? description;
  final int costCoins;
  final String iconTag;
}

class _ShopField extends StatelessWidget {
  const _ShopField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFE7DDC9),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.woodFrame, width: 2.2),
        ),
      ),
    );
  }
}

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
