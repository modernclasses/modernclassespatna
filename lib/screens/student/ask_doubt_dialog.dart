import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/modern_button.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doubt_provider.dart';

class AskDoubtDialog extends StatefulWidget {
  const AskDoubtDialog({super.key});

  @override
  State<AskDoubtDialog> createState() => _AskDoubtDialogState();
}

class _AskDoubtDialogState extends State<AskDoubtDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedSubject = "Bihar History";
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();

  final List<String> _subjects = [
    "Bihar History",
    "Polity",
    "General Science",
    "Mathematics",
    "Current Affairs",
    "Reasoning",
  ];

  @override
  void dispose() {
    _topicController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  void _submitDoubt() {
    if (_formKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      final doubtProvider = context.read<DoubtProvider>();

      doubtProvider.askNewDoubt(
        studentId: auth.currentUser.id,
        studentName: auth.currentUser.name,
        subject: _selectedSubject,
        topic: _topicController.text.trim(),
        questionText: _questionController.text.trim(),
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ Doubt submitted! Madhurendra Sir & faculty will answer shortly."),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Ask a Doubt",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Subject Dropdown
              const Text("Subject", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _selectedSubject,
                dropdownColor: AppTheme.surfaceLight,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _subjects
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedSubject = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // Topic Input
              const Text("Topic / Chapter", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _topicController,
                decoration: const InputDecoration(
                  hintText: "e.g. 1857 Revolt / Newton's 2nd Law",
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Please enter topic" : null,
              ),
              const SizedBox(height: 14),

              // Question Detail
              const Text("Your Question / Doubt Details", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _questionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Explain clearly what concept or step you are stuck on...",
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Please enter your doubt" : null,
              ),
              const SizedBox(height: 20),

              ModernButton(
                text: "Post Doubt for Faculty",
                width: double.infinity,
                onPressed: _submitDoubt,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
