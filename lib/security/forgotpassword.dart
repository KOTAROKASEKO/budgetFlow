import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _isLoading = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _emailController.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _isLoading.value = true;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      _showSnackbar(
          'Password reset link sent to ${_emailController.text.trim()}');
      if (mounted) {
        // Pop back to the login screen after a short delay
        Future.delayed(
            const Duration(seconds: 1), () => Navigator.of(context).pop());
      }
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? 'An error occurred.', isError: true);
    } catch (e) {
      _showSnackbar('An unexpected error occurred.', isError: true);
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true, // Allows body to go behind the AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        height: size.height,
        width: size.width,
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade900,
                    Colors.indigo.shade900,
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade100,
                    Colors.indigo.shade100,
                  ],
                ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 60,
                  color:
                      isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                ),
                const SizedBox(height: 20),
                Text(
                  'Reset Password',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the email associated with your account and we\'ll send a link to reset your password.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.black54),
                      prefixIcon: Icon(Icons.alternate_email_rounded,
                          color: isDark
                              ? Colors.white70
                              : Colors.grey.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty ||
                          !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),
                ValueListenableBuilder<bool>(
                  valueListenable: _isLoading,
                  builder: (context, isLoading, child) {
                    return isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? Colors.white : Colors.deepPurple),
                          ))
                        : ElevatedButton(
                            onPressed: _sendResetLink,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDark ? Colors.deepPurple : Colors.indigo,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              'Send Reset Link',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}