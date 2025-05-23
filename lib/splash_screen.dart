import 'package:flutter/material.dart';
import 'login.dart'; // تأكد من وجود الملف

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/background.jpg',
            fit: BoxFit.cover,
          ),

          // Overlay (dark gradient if needed)
          Container(
            color: Colors.black.withOpacity(0.35),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    const CircleAvatar(
                      radius: 45,
                      backgroundImage: AssetImage('assets/images/logo.jpg'),
                    ),
                    const SizedBox(height: 18),

                    // Project Name
                    const Text(
                      "Professional Crafts",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Features card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFeature(
                            icon: Icons.location_on,
                            title: "GPS System",
                            desc:
                                "Locate service providers and clients easily.",
                          ),
                          _buildFeature(
                            icon: Icons.chat_bubble_outline,
                            title: "Live Chat System",
                            desc:
                                "Instant communication between client and provider.",
                          ),
                          _buildFeature(
                            icon: Icons.groups,
                            title: "Support Teams",
                            desc:
                                "Company-backed support for service quality.",
                          ),
                          _buildFeature(
                            icon: Icons.verified_user_outlined,
                            title: "Rights Protection",
                            desc: "Secure and guaranteed payments.",
                          ),
                          _buildFeature(
                            icon: Icons.receipt_long_outlined,
                            title: "Cash Payment & E-Invoice",
                            desc:
                                "Pay cash, receive invoice on site.",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 35),

                    // Get Started Button
                    SizedBox(
                       width: 180, // أو 200 حسب ما تحب
                       height: 48, // أصغر من السابق 
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A5D52), // Olive color
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Get Started",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2F4F4F), size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F4F4F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
