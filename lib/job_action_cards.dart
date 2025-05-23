import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart'; // تأكد من إضافة الحزمة

class JobActionCards extends StatelessWidget {
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final bool isDeleting;
  final bool isUpdating;

  const JobActionCards({
    super.key,
    required this.onUpdate,
    required this.onDelete,
    this.isDeleting = false,
    this.isUpdating = false,
    // تم إزالة onAdd و isAdding من هنا لأنهما لم يعودا مستخدمين في هذا السياق
  });

  @override
  Widget build(BuildContext context) {
    // ألوان أساسية للبطاقات، يمكن تعديلها لتناسب ثيم التطبيق
    final Color updateColor = Colors.orange.shade700; // لون لزر التعديل
    final Color deleteColor = Colors.red.shade700;    // لون لزر الحذف

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0), // إضافة حشو أفقي
      child: Wrap( // Wrap لتوزيع البطاقات بشكل جيد
        spacing: 16,      // المسافة الأفقية بين البطاقات
        runSpacing: 16,   // المسافة العمودية بين البطاقات في حالة تعدد الأسطر
        alignment: WrapAlignment.center, // محاذاة البطاقات في المنتصف
        children: [
          _buildActionCard(
            context,
            title: isUpdating ? "Updating..." : "Update Job",
            subtitle: "Edit current job details",
            icon: isUpdating ? null : LucideIcons.fileEdit, // أيقونة قلم للتعديل
            isLoading: isUpdating,
            baseColor: updateColor,
            onTap: isUpdating ? () {} : onUpdate, // تعطيل النقر أثناء التحديث
          ),
          _buildActionCard(
            context,
            title: isDeleting ? "Deleting..." : "Delete Job",
            subtitle: "Remove this job posting",
            icon: isDeleting ? null : LucideIcons.trash2, // أيقونة سلة مهملات للحذف
            isLoading: isDeleting,
            baseColor: deleteColor,
            onTap: isDeleting ? () {} : onDelete, // تعطيل النقر أثناء الحذف
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {
    required String title,
    required String subtitle,
    IconData? icon,
    bool isLoading = false,
    required Color baseColor, // اللون الأساسي للبطاقة
    required VoidCallback onTap,
  }) {
    // اشتقاق لون النص لضمان التباين الجيد مع لون الخلفية الفاتح للبطاقة
    // هنا نفترض أن baseColor.withOpacity(0.1) سيكون فاتحًا، لذا النص سيكون داكنًا
    final Color textColor = HSLColor.fromColor(baseColor).withLightness(0.25).toColor(); // لون نص داكن جداً ومشبع
    final Color subtitleTextColor = textColor.withOpacity(0.85);
    final Color iconItselfColor = baseColor; // استخدام اللون الأساسي للأيقونة

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(18), // تعديل ليتناسب مع الشكل
      splashColor: baseColor.withOpacity(0.15),
      highlightColor: baseColor.withOpacity(0.08),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250), // تعديل طفيف للمدة
        curve: Curves.easeInOut,
        // تعديل عرض البطاقة ليكون أكثر استجابة: تأخذ نصف عرض الشاشة ناقص مسافة التباعد
        width: (MediaQuery.of(context).size.width / 2) - (16 * 1.5), // 16 هو الـ spacing، 1.5 لضمان وجود مسافة
        constraints: const BoxConstraints(minHeight: 140, maxHeight: 160, minWidth: 140), // تعديل القيود
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16), // تعديل الحشو
        decoration: BoxDecoration(
          color: baseColor.withOpacity(0.08), // خلفية أخف للبطاقة
          borderRadius: BorderRadius.circular(18), // زيادة دائرية الحواف قليلاً
          border: Border.all(color: baseColor.withOpacity(0.4), width: 1.2), // حدود أرق قليلاً
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.06),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(1, 2),
            )
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 30, // تصغير حجم المؤشر
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2, // سماكة أقل
                  valueColor: AlwaysStoppedAnimation<Color>(iconItselfColor),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 36, color: iconItselfColor), // تصغير حجم الأيقونة قليلاً
            const SizedBox(height: 10), // تقليل المسافة
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lato(
                fontSize: 14.5, // تعديل حجم الخط
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 5), // تقليل المسافة
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lato(
                fontSize: 11, // حجم خط أصغر للوصف
                color: subtitleTextColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}