part of '../../game_shell_page.dart';

class _HabitCreationSection extends StatelessWidget {
  const _HabitCreationSection({
    required this.titleController,
    required this.descriptionController,
    required this.xpController,
    required this.coinsController,
    required this.cadence,
    required this.onCadenceChanged,
    required this.assignedHunterId,
    required this.onAssignedHunterChanged,
    required this.statCategory,
    required this.onStatCategoryChanged,
    required this.hunters,
    required this.submitting,
    required this.onCreateHabit,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController xpController;
  final TextEditingController coinsController;
  final HabitCadence cadence;
  final ValueChanged<HabitCadence> onCadenceChanged;
  final String? assignedHunterId;
  final ValueChanged<String?> onAssignedHunterChanged;
  final QuestStatCategory statCategory;
  final ValueChanged<QuestStatCategory> onStatCategoryChanged;
  final List<HunterProfile> hunters;
  final bool submitting;
  final Future<void> Function() onCreateHabit;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return _ParchmentSection(
      title: strings.tr(zh: '建立習慣挑戰', en: 'Create Habit Challenge'),
      icon: Icons.post_add,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PixelTextInput(
            controller: titleController,
            label: strings.tr(zh: '習慣標題', en: 'Title'),
          ),
          const SizedBox(height: 8),
          _PixelTextInput(
            controller: descriptionController,
            minLines: 2,
            maxLines: 3,
            label: strings.tr(zh: '說明 / proof 提示', en: 'Prompt / proof note'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PixelTextInput(
                  controller: xpController,
                  keyboardType: TextInputType.number,
                  label: 'XP',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PixelTextInput(
                  controller: coinsController,
                  keyboardType: TextInputType.number,
                  label: 'Coins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 180,
                child: _PixelDropdownField<HabitCadence>(
                  label: strings.tr(zh: '頻率', en: 'Cadence'),
                  initialValue: cadence,
                  items: [
                    DropdownMenuItem(
                      value: HabitCadence.daily,
                      child: Text(strings.tr(zh: '每日', en: 'Daily')),
                    ),
                    DropdownMenuItem(
                      value: HabitCadence.weekly,
                      child: Text(strings.tr(zh: '每週', en: 'Weekly')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    onCadenceChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: _PixelDropdownField<String?>(
                  label: strings.tr(zh: '指派給', en: 'Assign to'),
                  initialValue: assignedHunterId,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(strings.tr(zh: '全家可用', en: 'Shared')),
                    ),
                    ...hunters.map(
                      (hunter) => DropdownMenuItem<String?>(
                        value: hunter.id,
                        child: Text(hunter.name),
                      ),
                    ),
                  ],
                  onChanged: onAssignedHunterChanged,
                ),
              ),
              SizedBox(
                width: 220,
                child: _PixelDropdownField<QuestStatCategory>(
                  label: strings.tr(zh: '成長屬性', en: 'Growth Stat'),
                  initialValue: statCategory,
                  items: QuestStatCategory.values
                      .map(
                        (value) => DropdownMenuItem<QuestStatCategory>(
                          value: value,
                          child: Text(
                            _statCategoryLabel(value, strings: strings),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    onStatCategoryChanged(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PixelButton(
            label: submitting
                ? strings.tr(zh: '建立中...', en: 'Creating...')
                : strings.tr(zh: '建立新習慣', en: 'Create Habit'),
            tone: PixelTone.green,
            onPressed: submitting ? null : () => unawaited(onCreateHabit()),
          ),
        ],
      ),
    );
  }
}
