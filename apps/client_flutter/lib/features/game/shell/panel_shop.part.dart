part of '../game_shell_page.dart';

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
  int? _optimisticCoinsOnHand;
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

  @override
  void didUpdateWidget(covariant _GuildShopPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latestCoins = widget.progressionState.maybeWhen(
      data: (progression) => progression.coins,
      orElse: () => null,
    );
    if (_optimisticCoinsOnHand != null && latestCoins == _optimisticCoinsOnHand) {
      _optimisticCoinsOnHand = null;
    }
  }

  Future<void> _buyItem(GuildShopItem item, int currentCoins) async {
    final strings = AppStrings.of(context);
    if (_buyingItemId != null) {
      return;
    }
    if (currentCoins < item.costCoins) {
      _triggerInsufficient(
        strings.tr(
          zh: '金幣不足，先完成生活任務再來兌換吧',
          en: 'Not enough coins. Finish some life tasks first.',
        ),
      );
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
        _optimisticCoinsOnHand = math.max(0, currentCoins - result.spentCoins);
        _successText = result.replayed
            ? strings.tr(
                zh: '偵測到重複點擊，已沿用上次購買結果',
                en: 'Duplicate tap detected. Reused the previous purchase result.',
              )
            : strings.tr(
                zh: '購買成功：${result.item.name} x${result.inventoryQuantity}',
                en: 'Purchase complete: ${result.item.name} x${result.inventoryQuantity}',
              );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final text = error.toString();
      if (text.contains('coins not enough')) {
        _triggerInsufficient(
          strings.tr(
            zh: '金幣不足，先完成生活任務再來兌換吧',
            en: 'Not enough coins. Finish some life tasks first.',
          ),
        );
      } else {
        setState(() {
          _errorText = strings.tr(
            zh: '購買失敗：$error',
            en: 'Purchase failed: $error',
          );
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
    final strings = AppStrings.of(context);
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
        _errorText = strings.tr(
          zh: '切換管理模式失敗：$error',
          en: 'Failed to toggle manage mode: $error',
        );
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
    final strings = AppStrings.of(context);
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
        _successText = strings.tr(
          zh: '已上架商品：${created.name}',
          en: 'Item published: ${created.name}',
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = strings.tr(
          zh: '上架失敗：$error',
          en: 'Failed to publish item: $error',
        );
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
    final strings = AppStrings.of(context);
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
        _successText = strings.tr(
          zh: '已更新商品：${updated.name}',
          en: 'Item updated: ${updated.name}',
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = strings.tr(zh: '更新失敗：$error', en: 'Update failed: $error');
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
    final strings = AppStrings.of(context);
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
        _successText = strings.tr(
          zh: '已下架商品：${item.name}',
          en: 'Item deactivated: ${item.name}',
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = strings.tr(
          zh: '下架失敗：$error',
          en: 'Deactivate failed: $error',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _editingItemId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final int currentCoins =
        _optimisticCoinsOnHand ??
        widget.progressionState.maybeWhen<int>(
          data: (progression) => progression.coins,
          orElse: () => 0,
        );

    return Column(
      key: AppTestIds.rewardsPanelKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.tr(zh: '獎勵兌換站', en: 'Reward Station'),
          style: const TextStyle(
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
                key: AppTestIds.rewardsCoinsLabelKey,
                strings.tr(
                  zh: '目前持有金幣：$currentCoins',
                  en: 'Coins on hand: $currentCoins',
                ),
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
              key: AppTestIds.rewardsSuccessTextKey,
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
                return Center(
                  child: Text(
                    strings.tr(
                      zh: '獎勵站暫時沒有可兌換的內容，稍後再回來看看。',
                      en: 'No rewards are available right now. Please check back soon.',
                    ),
                    style: const TextStyle(
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
                      key: AppTestIds.rewardItemCard(item.id),
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
                strings.tr(zh: '商店讀取失敗：$err', en: 'Shop load failed: $err'),
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
