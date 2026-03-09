part of '../game_shell_page.dart';

extension _GuildShopPanelStateEditor on _GuildShopPanelState {
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
