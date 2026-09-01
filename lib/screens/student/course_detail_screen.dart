import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/course_model.dart';
import '../../models/batch_model.dart';
import '../../data/mock_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import 'checkout_screen.dart';
import 'my_batches_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late BatchModel _selectedBatch;

  @override
  void initState() {
    super.initState();
    final batches = MockData.batches.where((b) => b.courseId == widget.course.id).toList();
    _selectedBatch = batches.isNotEmpty ? batches.first : MockData.batches.first;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final batches = courseProvider.getBatchesForCourse(widget.course.id);
    final isEnrolled = auth.currentUser.enrolledCourseIds.contains(widget.course.id);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.course.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Hero Banner
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(widget.course.coverImageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      AppTheme.background,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomBadge(text: widget.course.category, variant: BadgeVariant.primary),
                    const SizedBox(height: 8),
                    Text(
                      widget.course.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Course Info & Pricing Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        Formatters.formatCurrency(widget.course.price),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        Formatters.formatCurrency(widget.course.originalPrice),
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 10),
                      CustomBadge(
                        text: "${widget.course.discountPercentage}% OFF",
                        variant: BadgeVariant.success,
                      ),
                      const Spacer(),
                      const Icon(Icons.star, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        "${widget.course.rating} (${widget.course.reviewsCount})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Stats Row
                  Row(
                    children: [
                      _buildCourseStat(Icons.video_library_outlined, "${widget.course.totalLessons} Videos"),
                      _buildCourseStat(Icons.schedule, "${widget.course.totalHours} Hours"),
                      _buildCourseStat(Icons.quiz_outlined, "${widget.course.totalTests} Mock Tests"),
                      _buildCourseStat(Icons.menu_book_outlined, "${widget.course.totalNotes} Notes"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    "About this Crash Course",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.course.description,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  // Course Key Highlights
                  const Text(
                    "What's Included in this Course",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  for (var highlight in widget.course.highlights) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              highlight,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 16),

                  // Available Batches Selection
                  const Text(
                    "Select Your Batch",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (batches.isNotEmpty)
                    for (var batch in batches) ...[
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedBatch = batch;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _selectedBatch.id == batch.id
                                ? AppTheme.primary.withValues(alpha: 0.12)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedBatch.id == batch.id
                                  ? AppTheme.primary
                                  : AppTheme.border,
                              width: _selectedBatch.id == batch.id ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedBatch.id == batch.id
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: _selectedBatch.id == batch.id
                                    ? AppTheme.primary
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      batch.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "⏰ ${batch.timing} • ${batch.medium}",
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                Formatters.formatCurrency(batch.batchPrice),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 16),

                  // Faculty Bio
                  const Text(
                    "Chief Faculty & Mentor",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ModernCard(
                    padding: const EdgeInsets.all(14),
                    backgroundColor: AppTheme.surface,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            widget.course.teacherName.substring(0, 1),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.course.teacherName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Director, Modern Classes Patna • 10+ Years Mentoring",
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80), // bottom bar spacing
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Batch Fee", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  Text(
                    Formatters.formatCurrency(_selectedBatch.batchPrice),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: isEnrolled
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.play_circle_filled, size: 20),
                        label: const Text("Go to My Batch"),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MyBatchesScreen()),
                          );
                        },
                      )
                    : ModernButton(
                        text: "Enroll in Batch Now",
                        icon: Icons.flash_on,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CheckoutScreen(
                                course: widget.course,
                                batch: _selectedBatch,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseStat(IconData icon, String text) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
