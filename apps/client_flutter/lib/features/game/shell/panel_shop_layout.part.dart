part of '../game_shell_page.dart';

extension _GuildShopPanelStateLayout on _GuildShopPanelState {
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
        _StampButton(
          label: editing ? '處理中' : '編輯',
          tone: _StampTone.blue,
          iconWidget: const _PixelLabelGlyph(glyph: 'EDT'),
          onPressed: editing ? null : () => _editItem(item),
        ),
        _StampButton(
          label: item.isActive ? '下架' : '已下架',
          tone: item.isActive ? _StampTone.ruby : _StampTone.wood,
          iconWidget: const _PixelLabelGlyph(glyph: 'OFF'),
          onPressed: editing || !item.isActive
              ? null
              : () => _deactivateItem(item),
        ),
      ];
      if (compactCard) {
        return Wrap(spacing: 6, runSpacing: 6, children: actions);
      }
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: actions,
      );
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
    return purchaseButton;
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
          manageButton,
          if (_manageMode) const SizedBox(height: 8),
          if (_manageMode) createButton,
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [manageButton, if (_manageMode) createButton],
    );
  }
}
