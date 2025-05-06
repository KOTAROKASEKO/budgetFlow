import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:moneymanager/View_BottomTab.dart';
import 'package:moneymanager/firebase_options.dart';
import 'package:moneymanager/uid/uid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hide navigation bar, but allow it to show on user interaction
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);


  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      
      title: 'Flutter Firebase Auth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Modern theme elements
        scaffoldBackgroundColor: Colors.grey[100],
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.deepPurple,
          accentColor: Colors.amberAccent,
          brightness: Brightness.light,
        ).copyWith(secondary: Colors.amberAccent),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none, // No border shown by default
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.red[700]!, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.red[700]!, width: 2.0),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, // Text color
            backgroundColor: Colors.deepPurple, // Button background color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple, // Text color
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[100], // Match scaffold background
          elevation: 0, // No shadow
          iconTheme: const IconThemeData(color: Colors.deepPurple),
          titleTextStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // --- Initial Route ---
      // Use a StreamBuilder to listen to auth state changes
      // and show AuthScreen or HomeScreen accordingly.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a loading indicator while checking auth state
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            userId.initUid();
            // User is logged in, navigate to HomeScreen
            return const BottomTab();
          } else {
            // User is not logged in, show AuthScreen
            return const AuthScreen();
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Authentication Screen (Login/Sign Up Toggle) ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true; // To toggle between Login and Sign Up

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  // --- Function to handle Authentication ---
  Future<void> _submitAuthForm(
      String email, String password, BuildContext ctx) async {
    UserCredential userCredential;
    try {
      // Show loading indicator
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      if (_isLogin) {
        // --- Log in user ---
        // Replace with your actual Firebase login logic
        print('Attempting login with Email: $email'); // Placeholder
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        userId.initUid();
        print('Login successful: ${userCredential.user?.uid}'); // Placeholder
      } else {
        // --- Sign up user ---
        // Replace with your actual Firebase sign up logic
        print('Attempting signup with Email: $email'); // Placeholder
        userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        userId.initUid();
        print('Signup successful: ${userCredential.user?.uid}'); // Placeholder
        // Optionally: Send verification email, save extra user data to Firestore, etc.
      }

      // --- Navigation on Success ---
      // Pop the loading indicator
      Navigator.of(ctx, rootNavigator: true).pop();

      // Navigate to HomeScreen - We don't need explicit navigation here
      // because the StreamBuilder in main.dart will automatically rebuild
      // and show the HomeScreen when the auth state changes.

    } on FirebaseAuthException catch (err) {
      // Pop the loading indicator
      Navigator.of(ctx, rootNavigator: true).pop();

      String message = 'An error occurred, please check your credentials!';
      if (err.message != null) {
        message = err.message!;
      }
      print('FirebaseAuthException: ${err.code} - ${err.message}'); // Log error

      // --- Show Error Message ---
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(ctx).colorScheme.error,
        ),
      );
    } catch (err) {
      // Pop the loading indicator
      Navigator.of(ctx, rootNavigator: true).pop();
      print('Generic Error: $err'); // Log error

      // --- Show Generic Error Message ---
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('Authentication failed. Please try again later.'),
          backgroundColor: Theme.of(ctx).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: deviceSize.width * 0.9, // Responsive width
            constraints: const BoxConstraints(maxWidth: 400), // Max width
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 8.0,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // --- App Logo/Title (Optional) ---
                    Icon(
                      Icons.lock_outline,
                      size: 60,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLogin ? 'Welcome Back!' : 'Create Account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? 'Log in to continue'
                          : 'Sign up to get started',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // --- Auth Form ---
                    AuthForm(
                      isLogin: _isLogin,
                      submitFn: _submitAuthForm,
                    ),
                    const SizedBox(height: 16),
                    // --- Toggle Button ---
                    TextButton(
                      onPressed: _toggleAuthMode,
                      child: Text(
                        _isLogin
                            ? 'Don\'t have an account? Sign Up'
                            : 'Already have an account? Log In',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Authentication Form Widget (Email, Password, etc.) ---
class AuthForm extends StatefulWidget {
  final bool isLogin;
  final Future<void> Function(
      String email, String password, BuildContext ctx) submitFn;

  const AuthForm({super.key, required this.isLogin, required this.submitFn});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _trySubmit() {
    final isValid = _formKey.currentState?.validate();
    FocusScope.of(context).unfocus(); // Close keyboard

    if (isValid == true) {
      _formKey.currentState?.save();
      // Call the submission function passed from AuthScreen
      widget.submitFn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        context, // Pass context for showing dialogs/snackbars
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // --- Email Field ---
          TextFormField(
            key: const ValueKey('email'),
            controller: _emailController,
            validator: (value) {
              if (value == null || value.isEmpty || !value.contains('@')) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          // --- Password Field ---
          TextFormField(
            key: const ValueKey('password'),
            controller: _passwordController,
            validator: (value) {
              if (value == null || value.isEmpty || value.length < 7) {
                return 'Password must be at least 7 characters long.';
              }
              return null;
            },
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            textInputAction:
                widget.isLogin ? TextInputAction.done : TextInputAction.next,
            onFieldSubmitted: (_) {
              if (widget.isLogin) {
                _trySubmit();
              }
            },
          ),
          // --- Confirm Password Field (Sign Up only) ---
          if (!widget.isLogin) ...[
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('confirm_password'),
              controller: _confirmPasswordController,
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match!';
                }
                return null;
              },
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                _trySubmit();
              },
            ),
          ],
          const SizedBox(height: 24),
          // --- Submit Button ---
          SizedBox(
            width: double.infinity, // Make button full width
            child: ElevatedButton(
              onPressed: _trySubmit,
              child: Text(widget.isLogin ? 'Log In' : 'Sign Up'),
            ),
          ),
        ],
      ),
    );
  }
}

