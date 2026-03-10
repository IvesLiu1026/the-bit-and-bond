part of '../../game_shell_page.dart';

extension _PhotoDumpPanelTabs on _PhotoDumpPanelState {
  Widget _buildVaultTab(AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PixelTextInput(
          controller: _captionController,
          label: strings.tr(zh: '照片說明', en: 'Caption'),
          hintText: strings.photoDumpCaptionHint,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PixelButton(
                label: strings.photoDumpCamera,
                tone: PixelTone.blue,
                compact: true,
                onPressed: _working
                    ? null
                    : () => _uploadToVault(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PixelButton(
                label: strings.photoDumpGallery,
                tone: PixelTone.green,
                compact: true,
                onPressed: _working
                    ? null
                    : () => _uploadToVault(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PixelButton(
                label: strings.photoDumpExportSelected,
                tone: PixelTone.gold,
                compact: true,
                onPressed: _working ? null : _exportSelected,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          strings.photoDumpSelectedCount(_selectedVaultIds.length),
          style: PixelTypography.style(
            color: AppColors.inkBrown.withValues(alpha: 0.85),
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _vaultItems.isEmpty
              ? Center(
                  child: Text(
                    strings.photoDumpEmptyVault,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.inkBrown.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: _vaultItems.length,
                  itemBuilder: (context, index) {
                    final item = _vaultItems[index];
                    final selected = _selectedVaultIds.contains(item.id);
                    return _VaultMediaCard(
                      item: item,
                      selected: selected,
                      onTap: () => _toggleVaultSelection(item.id),
                    );
                  },
                ),
        ),
        if (_exports.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final export = _exports[index];
                return PixelPanel(
                  tone: PixelTone.parchment,
                  padding: const EdgeInsets.all(8),
                  cut: 10,
                  shadowDepth: 2,
                  child: SizedBox(
                    width: 170,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          export.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PixelTypography.style(
                            color: AppColors.inkBrown,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${export.style.toUpperCase()} · ${export.assetCount}',
                          style: PixelTypography.style(
                            color: AppColors.inkBrown.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: _exports.length,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOneTimeTab(AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PixelTextInput(
          controller: _recipientController,
          label: strings.tr(zh: '接收者', en: 'Recipient'),
          hintText: strings.photoDumpRecipientHint,
        ),
        const SizedBox(height: 8),
        _PixelTextInput(
          controller: _captionController,
          label: strings.tr(zh: '照片說明', en: 'Caption'),
          hintText: strings.photoDumpCaptionHint,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PixelButton(
                label: strings.photoDumpCamera,
                tone: PixelTone.blue,
                compact: true,
                onPressed: _working
                    ? null
                    : () => _sendOneTime(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PixelButton(
                label: strings.photoDumpGallery,
                tone: PixelTone.green,
                compact: true,
                onPressed: _working
                    ? null
                    : () => _sendOneTime(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          strings.photoDumpInboxTitle,
          style: PixelTypography.style(
            color: AppColors.inkBrown,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _onceInbox.isEmpty
              ? Center(
                  child: Text(
                    strings.photoDumpEmptyInbox,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.inkBrown.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _onceInbox.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _onceInbox[index];
                    final expiresText = item.expiresAt == null
                        ? '-'
                        : _formatTime(item.expiresAt!);
                    return PixelPanel(
                      tone: PixelTone.parchment,
                      padding: const EdgeInsets.all(10),
                      cut: 10,
                      shadowDepth: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.photoDumpFrom(item.senderName),
                            style: PixelTypography.style(
                              color: AppColors.inkBrown,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.encryption.isEncrypted
                                ? strings.encrypted
                                : strings.notEncrypted,
                            style: PixelTypography.style(
                              color: AppColors.inkBrown.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.caption?.trim().isNotEmpty == true
                                ? item.caption!
                                : item.senderPlayerId,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PixelTypography.style(
                              color: AppColors.inkBrown.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            strings.photoDumpExpiresAt(expiresText),
                            style: PixelTypography.style(
                              color: AppColors.inkBrown.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          PixelButton(
                            label: strings.photoDumpOpenOnce,
                            tone: PixelTone.gold,
                            compact: true,
                            onPressed: _working
                                ? null
                                : () => _openOneTime(item),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}
