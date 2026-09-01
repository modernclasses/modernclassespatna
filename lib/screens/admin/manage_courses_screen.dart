import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/course_model.dart';
import '../../providers/course_provider.dart';

class ManageCoursesScreen extends StatefulWidget {
  const ManageCoursesScreen({super.key});

  @override
  State<ManageCoursesScreen> createState() => _ManageCoursesScreenState();
}

class _ManageCoursesScreenState extends State<ManageCoursesScreen> {
  void _showAddCourseDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: "Crash Course");
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: "799");
    final originalPriceCtrl = TextEditingController(text: "1999");
    final facultyCtrl = TextEditingController(text: "Madhurendra Kumar Yadav");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Create New Crash Course", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Course Title", hintText: "e.g. BPSC 72nd Target Batch"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: "Category", hintText: "e.g. BPSC / SSC"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Course Description"),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Offer Price (₹)", hintText: "799"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: originalPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Original (₹)", hintText: "1999"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: facultyCtrl,
                decoration: const InputDecoration(labelText: "Assigned Faculty", hintText: "Faculty name"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                final courseProvider = context.read<CourseProvider>();
                final newCourse = CourseModel(
                  id: "crs_${DateTime.now().millisecondsSinceEpoch}",
                  title: titleCtrl.text.trim(),
                  category: categoryCtrl.text.trim(),
                  description: descCtrl.text.trim().isNotEmpty
                      ? descCtrl.text.trim()
                      : "High-impact crash course for competitive candidates.",
                  coverImageUrl: "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800",
                  price: double.tryParse(priceCtrl.text) ?? 799.0,
                  originalPrice: double.tryParse(originalPriceCtrl.text) ?? 1999.0,
                  teacherName: facultyCtrl.text.trim(),
                  teacherId: "tch_001",
                  totalLessons: 40,
                  totalHours: 80,
                  totalTests: 15,
                  totalNotes: 35,
                  highlights: [
                    "Live YouTube Streaming interactive lectures",
                    "Complete digital PDF study material",
                    "Weekly mock test series with ranks",
                  ],
                  batchIds: ["batch_101"],
                  isFeatured: true,
                );

                courseProvider.addCourse(newCourse);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✨ Course added to catalog!"), backgroundColor: AppTheme.success),
                );
              }
            },
            child: const Text("Create Course"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final courses = courseProvider.courses;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Course & Batch Management"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text("Add Course", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddCourseDialog(context),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: courses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final course = courses[index];
          final batches = courseProvider.getBatchesForCourse(course.id);

          return ModernCard(
            padding: const EdgeInsets.all(16),
            backgroundColor: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomBadge(text: course.category, variant: BadgeVariant.primary),
                    Text(
                      Formatters.formatCurrency(course.price),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  course.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Faculty: ${course.teacherName} • ${batches.length} active batches",
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      "${course.totalLessons} Lessons • ${course.totalTests} Tests",
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 30),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Managing batches for ${course.title}")),
                        );
                      },
                      child: const Text("Batches & Pricing", style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
