import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:moneymanager/View_BottomTab.dart';
import 'package:moneymanager/security/forgotpassword.dart';
import 'package:moneymanager/security/uid.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class UserAuthScreen extends StatefulWidget {
  const UserAuthScreen({super.key});

  @override
  State<UserAuthScreen> createState() => _UserAuthScreenState();
}

class _UserAuthScreenState extends State<UserAuthScreen>
    with SingleTickerProviderStateMixin {
  // AnimationControllerのために追加
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController =
      TextEditingController(); // サインアップ用に確認パスワードフィールドを追加
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true; // 確認パスワード用

  // ローディング状態の管理
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isGoogleLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isAppleLoading = ValueNotifier<bool>(false);

  // アニメーション用
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // 少し長めのアニメーション
    );

    // 下から上へのスライドアニメーション
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), // Y軸方向に画面の半分の位置から開始
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn, // スムーズなイージング
    ));

    // フェードインアニメーション
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward(); // アニメーションを開始
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _isLoading.dispose();
    _isGoogleLoading.dispose();
    _isAppleLoading.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      isLogin = !isLogin;
      _formKey.currentState?.reset();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      // アニメーションをリセットして再実行
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // 既存のスナックバーを隠す
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating, // モダンなフローティングスタイル
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }



  Future<void> enteringAccount() async {
    userId.initUid();
    // Use a custom PageRouteBuilder for slide transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const BottomTab(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0); // Slide from right to left
          const end = Offset.zero;
          const curve = Curves.ease;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final slideAnimation = animation.drive(tween);

          // Slide out the current screen to the left
          final reverseTween = Tween(begin: Offset.zero, end: const Offset(-1.0, 0.0))
              .chain(CurveTween(curve: curve));
          final slideOutAnimation = secondaryAnimation.drive(reverseTween);

          return Stack(
            children: [
              SlideTransition(
                position: slideOutAnimation,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: SizedBox.expand(),
                ),
              ),
              SlideTransition(
                position: slideAnimation,
                child: child,
              ),
            ],
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    _isLoading.value = true;

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        enteringAccount();
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        enteringAccount();
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar(
          e.message ?? "An unknown authentication error occurred.");
    } catch (e) {
      _showErrorSnackbar("An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    _isGoogleLoading.value = true;
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _isGoogleLoading.value = false;
        return; // ユーザーがキャンセル
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      enteringAccount();
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar(e.message ?? "Google Sign-In failed.");
    } catch (e) {
      _showErrorSnackbar("An unexpected error with Google Sign-In.");
      print("error: $e"); // デバッグ用
    } finally {
      if (mounted) {
        _isGoogleLoading.value = false;
      }
    }
  }

  Future<void> _signInWithApple() async {
    _isAppleLoading.value = true;
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final OAuthCredential oAuthCredential =
          OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );
      await FirebaseAuth.instance.signInWithCredential(oAuthCredential);
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar(e.message ?? "Apple Sign-In failed.");
    } catch (e) {
      _showErrorSnackbar(
          "An unexpected error with Apple Sign-In: ${e.toString()}");
    } finally {
      if (mounted) {
        _isAppleLoading.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
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
        child: SingleChildScrollView(
          child: SizedBox(
            height: size.height,
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.deepPurple.withOpacity(0.3)
                          : Colors.deepPurple.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.indigo.withOpacity(0.3)
                          : Colors.indigo.withOpacity(0.1),
                    ),
                  ),
                ),
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.deepPurple.shade800
                                        : Colors.deepPurple.shade200,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black.withOpacity(0.3)
                                            : Colors.deepPurple
                                                .withOpacity(0.2),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      )
                                    ]),
                                child: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 40,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.deepPurple.shade800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isLogin ? 'Welcome Back' : 'Create Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                isLogin
                                    ? 'Sign in to continue'
                                    : 'Join us to get started',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: GoogleFonts.poppins(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    labelStyle: GoogleFonts.poppins(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54),
                                    prefixIcon: Icon(Icons.email_outlined,
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
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!value.contains('@') ||
                                        !value.contains('.')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: GoogleFonts.poppins(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: GoogleFonts.poppins(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54),
                                    prefixIcon: Icon(Icons.lock_outline,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade600),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey.shade600),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
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
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                if (!isLogin) ...[
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: GoogleFonts.poppins(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87),
                                    decoration: InputDecoration(
                                      labelText: 'Confirm Password',
                                      labelStyle: GoogleFonts.poppins(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54),
                                      prefixIcon: Icon(
                                          Icons.lock_clock_outlined,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey.shade600),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey.shade600),
                                        onPressed: () {
                                          setState(() {
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword;
                                          });
                                        },
                                      ),
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
                                          value.trim().isEmpty) {
                                        return 'Please confirm your password';
                                      }
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                if (isLogin) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: (){
                                        Navigator.of(context).push(
                                          PageRouteBuilder(
                                            pageBuilder: (context, animation, secondaryAnimation) => ForgotPasswordScreen(),
                                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                              const begin = Offset(1.0, 0.0);
                                              const end = Offset.zero;
                                              const curve = Curves.ease;
                                              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                              return SlideTransition(
                                                position: animation.drive(tween),
                                                child: child,
                                              );
                                            },
                                            opaque: false,
                                            barrierDismissible: true,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Forgot Password?',
                                        style: GoogleFonts.poppins(
                                          color: isDark
                                              ? Colors.deepPurple.shade200
                                              : Colors.deepPurple.shade800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                ValueListenableBuilder<bool>(
                                    valueListenable: _isLoading,
                                    builder: (context, isLoading, child) {
                                      return isLoading
                                          ? CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      isDark
                                                          ? Colors.white
                                                          : Colors.deepPurple),
                                            )
                                          : ElevatedButton(
                                              onPressed: _submit,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isDark
                                                    ? Colors.deepPurple
                                                    : Colors.indigo,
                                                foregroundColor: Colors.white,
                                                minimumSize: const Size(
                                                    double.infinity,
                                                    50),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                elevation: 4,
                                                shadowColor: isDark
                                                    ? Colors.deepPurple.shade400
                                                        .withOpacity(0.5)
                                                    : Colors.indigo.shade200
                                                        .withOpacity(0.5),
                                              ),
                                              child: Text(
                                                isLogin ? 'Sign In' : 'Sign Up',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                    }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color:
                                      isDark ? Colors.white24 : Colors.black12,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or continue with',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color:
                                      isDark ? Colors.white24 : Colors.black12,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (Platform.isAndroid) ...[
                                ValueListenableBuilder<bool>(
                                  valueListenable: _isGoogleLoading,
                                  builder: (context, isLoading, _) => isLoading
                                      ? const CircularProgressIndicator(
                                          strokeWidth: 2)
                                      : _SocialButton(
                                          iconAsset:
                                              'assets/google.png',
                                          onPressed: _signInWithGoogle,
                                        ),
                                ),
                                const SizedBox(width: 16),
                              ],
                              if (Platform.isIOS) ...[
                                ValueListenableBuilder<bool>(
                                  valueListenable: _isAppleLoading,
                                  builder: (context, isLoading, _) => isLoading
                                      ? const CircularProgressIndicator(
                                          strokeWidth: 2)
                                      : _SocialButton(
                                          iconAsset:
                                              'assets/apple.png',
                                          onPressed: _signInWithApple,
                                          isAppleIcon:
                                              true,
                                        ),
                                ),
                                const SizedBox(width: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLogin
                                    ? "Don't have an account?"
                                    : 'Already have an account?',
                                style: GoogleFonts.poppins(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              TextButton(
                                onPressed: _toggleAuthMode,
                                child: Text(
                                  isLogin ? 'Sign Up' : 'Sign Up',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.deepPurple.shade200
                                        : Colors.deepPurple.shade800,
                                    decoration: TextDecoration.underline,
                                    decorationColor: isDark
                                        ? Colors.deepPurple.shade200
                                        : Colors.deepPurple.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String iconAsset;
  final VoidCallback onPressed;
  final bool isAppleIcon;

  const _SocialButton({
    required this.iconAsset,
    required this.onPressed,
    this.isAppleIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              )
            ]),
        child: Image.asset(
          iconAsset,
          width: 24,
          height: 24,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              isAppleIcon
                  ? Icons.apple
                  : (iconAsset.contains("google")
                      ? Icons.android_sharp
                      : Icons.facebook),
              size: 24,
              color: isDark ? Colors.white70 : Colors.black54,
            );
          },
        ),
      ),
    );
  }
}