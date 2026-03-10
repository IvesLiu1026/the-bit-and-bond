part of '../game_shell_page.dart';

extension _GuildShopPanelStateEditor on _GuildShopPanelState {
  Future<_ShopItemDraft?> _showItemEditorDialog({
    GuildShopItem? initial,
  }) async {
    final strings = AppStrings.of(context);
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
                              initial == null
                                  ? strings.tr(zh: '上架商品', en: 'Publish Item')
                                  : strings.tr(zh: '編輯商品', en: 'Edit Item'),
                              style: const TextStyle(
                                color: AppColors.inkBrown,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ShopField(
                              controller: nameController,
                              label: strings.tr(zh: '名稱', en: 'Name'),
                            ),
                            const SizedBox(height: 8),
                            _ShopField(
                              controller: descriptionController,
                              label: strings.tr(
                                zh: '描述（可留空）',
                                en: 'Description (optional)',
                              ),
                            ),
                            const SizedBox(height: 8),
                            _ShopField(
                              controller: costController,
                              label: strings.tr(zh: '價格（金幣）', en: 'Price'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            _PixelDropdownField<String>(
                              label: strings.tr(zh: '圖示', en: 'Icon'),
                              initialValue: iconTag,
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
                                    label: strings.tr(zh: '取消', en: 'Cancel'),
                                    tone: _StampTone.wood,
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StampButton(
                                    label: strings.tr(zh: '儲存', en: 'Save'),
                                    tone: _StampTone.green,
                                    onPressed: () {
                                      final name = nameController.text.trim();
                                      final cost = int.tryParse(
                                        costController.text.trim(),
                                      );
                                      if (name.isEmpty) {
                                        setLocalState(() {
                                          localError = strings.tr(
                                            zh: '名稱不能空白',
                                            en: 'Name is required.',
                                          );
                                        });
                                        return;
                                      }
                                      if (cost == null || cost < 0) {
                                        setLocalState(() {
                                          localError = strings.tr(
                                            zh: '價格必須是 0 以上整數',
                                            en: 'Price must be a non-negative integer.',
                                          );
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
    return _PixelTextInput(
      controller: controller,
      label: label,
      keyboardType: keyboardType,
    );
  }
}
