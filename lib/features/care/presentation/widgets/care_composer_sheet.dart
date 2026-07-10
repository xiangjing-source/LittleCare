import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/care_models.dart';
import '../providers/care_providers.dart';

Future<void> showCareComposer({
  required BuildContext context,
  required String groupId,
  required String fromUserId,
  required String toUserId,
  required String recipientName,
  String? recordId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (_) => CareComposerSheet(
          groupId: groupId,
          fromUserId: fromUserId,
          toUserId: toUserId,
          recipientName: recipientName,
          recordId: recordId,
        ),
  );
}

Future<void> showCareResponse({
  required BuildContext context,
  required CareEvent event,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (_) => CareComposerSheet(
          groupId: event.groupId,
          fromUserId: event.toUserId,
          toUserId: event.fromUserId,
          recipientName: '对方',
          parentCareId: event.id,
          responseMode: true,
        ),
  );
}

class CareComposerSheet extends ConsumerStatefulWidget {
  const CareComposerSheet({
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.recipientName,
    this.recordId,
    this.parentCareId,
    this.responseMode = false,
    super.key,
  });

  final String groupId;
  final String fromUserId;
  final String toUserId;
  final String recipientName;
  final String? recordId;
  final String? parentCareId;
  final bool responseMode;

  @override
  ConsumerState<CareComposerSheet> createState() => _CareComposerSheetState();
}

class _CareComposerSheetState extends ConsumerState<CareComposerSheet> {
  final _custom = TextEditingController();
  String? _selected;
  bool _sending = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choices =
        widget.responseMode ? CarePresets.responses : CarePresets.messages;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.responseMode ? '想怎么回应？' : '给${widget.recipientName}一句关心',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                widget.responseMode
                    ? '可以选一句快速回应，也可以写一句自己的话。'
                    : '关心不需要等到数据发生变化时才表达。',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    choices
                        .map(
                          (message) => ChoiceChip(
                            label: Text(message),
                            selected: _selected == message,
                            onSelected: (selected) {
                              setState(
                                () => _selected = selected ? message : null,
                              );
                            },
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _custom,
                maxLength: 80,
                minLines: 2,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: widget.responseMode ? '或者自定义回应' : '或者写一句自己的话',
                  hintText: widget.responseMode ? '比如：我看到了，放心吧' : '简短、真诚就很好',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _sending || _message.isEmpty ? null : _send,
                icon:
                    _sending
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.favorite_rounded),
                label: Text(widget.responseMode ? '回应' : '送出关心'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _message =>
      _custom.text.trim().isNotEmpty ? _custom.text.trim() : _selected ?? '';

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(careRepositoryProvider)
          .sendCare(
            groupId: widget.groupId,
            fromUserId: widget.fromUserId,
            toUserId: widget.toUserId,
            message: _message,
            type:
                widget.responseMode
                    ? CareType.response
                    : _custom.text.trim().isNotEmpty
                    ? CareType.custom
                    : CareType.preset,
            recordId: widget.recordId,
            parentCareId: widget.parentCareId,
          );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(widget.responseMode ? '回应已送出' : '关心已送出')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('发送没有成功，请检查网络后重试')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
