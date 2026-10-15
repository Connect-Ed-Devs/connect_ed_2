import 'package:connect_ed_2/classes/personal_task.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// What the sheet hands back: a task to save, or a request to delete [existing].
class PersonalTaskEdit {
  const PersonalTaskEdit.save(this.task) : delete = false;
  const PersonalTaskEdit.delete() : task = null, delete = true;

  final PersonalTask? task;
  final bool delete;
}

/// Opens the add/edit sheet. [existing] is null when adding. [now] pins
/// "today" for the date picker in tests.
Future<PersonalTaskEdit?> showPersonalTaskSheet(
  BuildContext context, {
  PersonalTask? existing,
  DateTime? now,
}) {
  return showModalBottomSheet<PersonalTaskEdit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (context) => _PersonalTaskSheet(existing: existing, now: now),
  );
}

class _PersonalTaskSheet extends StatefulWidget {
  const _PersonalTaskSheet({this.existing, this.now});

  final PersonalTask? existing;
  final DateTime? now;

  @override
  State<_PersonalTaskSheet> createState() => _PersonalTaskSheetState();
}

class _PersonalTaskSheetState extends State<_PersonalTaskSheet> {
  late final TextEditingController _title;
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    final due = existing?.due;
    if (due != null) {
      _date = DateTime(due.year, due.month, due.day);
      if (existing!.hasTime) _time = TimeOfDay.fromDateTime(due);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = widget.now ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _canSave => _title.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? _today,
      firstDate: DateTime(_today.year - 1),
      lastDate: DateTime(_today.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _clearDate() {
    setState(() {
      _date = null;
      _time = null;
    });
  }

  void _save() {
    final date = _date;
    final time = _time;
    final due =
        date == null
            ? null
            : (time == null
                ? date
                : DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                ));
    final id =
        widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    Navigator.pop(
      context,
      PersonalTaskEdit.save(
        PersonalTask(
          id: id,
          title: _title.text.trim(),
          due: due,
          hasTime: due != null && time != null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    final date = _date;
    final time = _time;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editing ? 'Edit task' : 'New task',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _pickDate,
                child: Text(
                  date == null
                      ? 'Set due date'
                      : DateFormat('EEE d MMM').format(date),
                ),
              ),
              if (date != null)
                TextButton(
                  onPressed: _pickTime,
                  child: Text(time == null ? 'Add time' : time.format(context)),
                ),
              const Spacer(),
              if (date != null)
                TextButton(
                  onPressed: _clearDate,
                  child: const Text('Clear date'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (editing)
                TextButton(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        const PersonalTaskEdit.delete(),
                      ),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Delete task'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
