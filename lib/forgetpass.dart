import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( // الألوان تأتي من الثيم
        title: const Text('Forgot Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0), // زيادة الـ padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text( 'Enter your email address below to receive password reset instructions.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16), ),
            const SizedBox(height: 25),
            TextField( keyboardType: TextInputType.emailAddress, decoration: InputDecoration( labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), ), // يستخدم تنسيق الثيم
            ),
            const SizedBox(height: 35),
            ElevatedButton( // يستخدم تنسيق الثيم
              onPressed: () {
                // TODO: استدعاء API إرسال رابط إعادة التعيين
                ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Password reset link sent (simulation).')), );
                Navigator.pop(context);
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }
}