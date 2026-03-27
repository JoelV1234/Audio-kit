import 'package:flutter/material.dart';

import '../../services/log_service.dart';

void showTerminalLogDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => const _TerminalLogDialog(),
  );
}

class _TerminalLogDialog extends StatefulWidget {
  const _TerminalLogDialog();

  @override
  State<_TerminalLogDialog> createState() => _TerminalLogDialogState();
}

class _TerminalLogDialogState extends State<_TerminalLogDialog> {
  final ScrollController _scrollController = ScrollController();
  final LogService _logService = LogService();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 700,
        height: 480,
        child: Column(
          children: [
            _buildTitleBar(context),
            Expanded(child: _buildLogArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Process Log',
            style: TextStyle(
              color: Colors.green,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogArea() {
    return StreamBuilder<List<String>>(
      stream: _logService.logStream,
      initialData: _logService.logs,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        _scrollToBottom();
        return Container(
          color: const Color(0xFF1A1A1A),
          child: logs.isEmpty
              ? const Center(
                  child: Text(
                    'No output yet.',
                    style: TextStyle(color: Colors.white38, fontFamily: 'monospace'),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      logs[index],
                      style: const TextStyle(
                        color: Color(0xFFCCCCCC),
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
