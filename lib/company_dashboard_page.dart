import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

// استيراد صفحة الوظائف الجديدة - تأكد من أن المسار صحيح بالنسبة لمشروعك
import 'CompanyJobsPage.dart';
// قد تحتاج لاستيراد صفحات أخرى إذا قمت بتفعيل بطاقات أخرى
 import 'company_teams_page.dart';

class CompanyDashboardPage extends StatelessWidget {
  final String companyId;   // معرّف الشركة الذي يتم تمريره من الصفحة السابقة
  final String companyName; // اسم الشركة الذي يتم تمريره من الصفحة السابقة

  const CompanyDashboardPage({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    // لون موحد لخلفية البطاقات النشطة
    const Color cardBackgroundColor = Color(0xFFe8f0e5); // يمكنك اختيار هذا اللون أو أي لون آخر
    // ألوان أخرى مستخدمة في التصميم
    const Color iconColor = Color(0xFF697c6b);
    const Color textHeaderColor = Color(0xFF43594c);
    const Color textSubColor = Colors.black87;

    // لطباعة البيانات المستلمة للتأكد (اختياري لأغراض التطوير)
    print("CompanyDashboardPage - Received ID: $companyId, Name: $companyName");

    return Scaffold(
      // لجعل محتوى الجسم يمتد خلف شريط التطبيق الشفاف
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          companyName, // عرض اسم الشركة في العنوان
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent, // شريط تطبيق شفاف
        elevation: 0, // إزالة الظل
        iconTheme: const IconThemeData(color: Colors.white), // لون أيقونة الرجوع
      ),
      body: Stack(
        children: [
          // صورة الخلفية
          Positioned.fill(
            child: Image.asset(
              'assets/images/construction_bg.png', // تأكد من أن هذا الملف موجود في مجلد assets/images
                                                 // وأنه معرّف في pubspec.yaml
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.45), // تعديل شفافية الصورة
              colorBlendMode: BlendMode.darken,     // طريقة دمج اللون مع الصورة
            ),
          ),
          // المحتوى الرئيسي للصفحة
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // محاذاة العناصر في المنتصف أفقيًا
                children: [
                  // مسافة لتعويض ارتفاع شريط التطبيق الشفاف
                  const SizedBox(height: kToolbarHeight - 10),
                  // رسالة ترحيب متحركة
                  FadeInDown(
                    duration: const Duration(milliseconds: 600),
                    child: Text(
                      "Welcome to $companyName!", // استخدام اسم الشركة في الترحيب
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato( // يمكنك تغيير الخط هنا أيضًا
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 2,
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(1, 1),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // نص فرعي متحرك
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    duration: const Duration(milliseconds: 600),
                    child: Text(
                      "Manage your operations and teams easily.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 35), // مسافة إضافية قبل البطاقات
                  // قائمة البطاقات (قابلة للتمرير إذا زاد المحتوى عن الشاشة)
                  Expanded(
                    child: ListView(
                      children: [
                        // بطاقة "My Jobs"
                        _buildNavigationCard(
                          context: context,
                          title: "My Jobs",
                          subtitle: "View and manage company job listings.",
                          icon: Icons.work_outline_rounded,
                          color: cardBackgroundColor, // استخدام اللون الموحد للبطاقة
                          iconColor: iconColor,
                          textHeaderColor: textHeaderColor,
                          textSubColor: textSubColor,
                          onTapAction: () { // الإجراء عند النقر على البطاقة
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CompanyJobsPage( // الانتقال إلى صفحة الوظائف
                                  companyId: companyId,     // تمرير معرّف الشركة
                                  companyName: companyName, // تمرير اسم الشركة
                                ),
                              ),
                            );
                          },
                          animationDelay: 0, // تأخير الأنيميشن للبطاقة الأولى
                        ),
                        const SizedBox(height: 20), // مسافة بين البطاقات
                        // بطاقة "My Teams"
                        _buildNavigationCard(
                          context: context,
                          title: "My Teams",
                          subtitle: "Collaborate and communicate with your team.",
                          icon: Icons.group_work_outlined,
                          color: cardBackgroundColor, // استخدام نفس اللون الموحد للبطاقة
                          iconColor: iconColor,
                          textHeaderColor: textHeaderColor,
                          textSubColor: textSubColor,
                          onTapAction: () {
                            // TODO: قم بتوجيه المستخدم إلى صفحة الفرق عند إنشائها
                            
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (context) => CompanyTeamsPage(companyId: companyId, companyName: '',),
                               ),
                             );
                           
                          },
                          animationDelay: 200, // تأخير الأنيميشن للبطاقة الثانية
                        ),
                        // تم إزالة بطاقة "Company Settings" بناءً على طلبك السابق
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // ودجت مساعد لإنشاء بطاقات التنقل بشكل متكرر
  Widget _buildNavigationCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,         // لون خلفية البطاقة
    required Color iconColor,     // لون الأيقونة
    required Color textHeaderColor, // لون عنوان البطاقة
    required Color textSubColor,  // لون النص الفرعي للبطاقة
    required VoidCallback onTapAction, // الإجراء الذي يتم تنفيذه عند النقر
    required int animationDelay,  // تأخير ظهور الأنيميشن بالمللي ثانية
  }) {
    return FadeInUp( // تأثير ظهور متحرك للأعلى
      delay: Duration(milliseconds: 400 + animationDelay),
      duration: const Duration(milliseconds: 500),
      child: GestureDetector(
        onTap: onTapAction, // تفعيل الإجراء عند النقر
        child: Container(
          margin: const EdgeInsets.only(bottom: 20), // هامش أسفل كل بطاقة
          padding: const EdgeInsets.all(24),        // حشو داخلي للبطاقة
          width: double.infinity,                 // لجعل البطاقة تأخذ كامل العرض المتاح
          decoration: BoxDecoration(
            color: color.withOpacity(0.92),       // لون خلفية البطاقة مع شفافية طفيفة
            borderRadius: BorderRadius.circular(20), // حواف دائرية للبطاقة
            boxShadow: [ // إضافة ظل للبطاقة
              BoxShadow(
                color: Colors.black.withOpacity(0.15), // لون الظل
                blurRadius: 8,                          // مدى ضبابية الظل
                offset: const Offset(0, 4),             // إزاحة الظل (أفقي، عمودي)
              ),
            ],
          ),
          child: Row( // لعرض الأيقونة بجانب النصوص
            children: [
              Icon(icon, size: 32, color: iconColor), // الأيقونة
              const SizedBox(width: 16), // مسافة بين الأيقونة والنصوص
              Expanded( // لجعل النصوص تأخذ المساحة المتبقية
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // محاذاة النصوص إلى اليسار (أو اليمين في RTL)
                  children: [
                    Text( // عنوان البطاقة
                      title,
                      style: GoogleFonts.lato(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: textHeaderColor,
                      ),
                    ),
                    const SizedBox(height: 7), // مسافة بين العنوان والنص الفرعي
                    Text( // النص الفرعي للبطاقة
                      subtitle,
                      style: GoogleFonts.lato(
                        color: textSubColor,
                        fontSize: 14.5,
                      ),
                    )
                  ],
                ),
              ),
              // أيقونة سهم للإشارة إلى إمكانية النقر (اختياري)
              Icon(Icons.arrow_forward_ios_rounded, color: textHeaderColor.withOpacity(0.7), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}