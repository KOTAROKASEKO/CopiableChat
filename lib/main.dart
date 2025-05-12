import 'dart:io';

import 'package:chatapp/View_profile.dart';
import 'package:chatapp/chat/chat_Thread.dart';
import 'package:chatapp/chat/chatThreadScreen.dart';
import 'package:chatapp/chat/threadModel/chat_thread.dart';
import 'package:chatapp/chat/threadModel/timestamp_adopter.dart';
import 'package:chatapp/user_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'firebase_options.dart'; // FlutterFire CLIによって生成されるべきファイル
import 'package:google_fonts/google_fonts.dart'; // Google Fontsを使用


// ユーザーIDを保存するための変数
void main() async {

  WidgetsFlutterBinding.ensureInitialized();
   // 1. Initialize Firebase FIRST
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();

  
  if (!Hive.isAdapterRegistered(ChatThreadAdapter().typeId)) {
    Hive.registerAdapter(ChatThreadAdapter());
  }
  if (!Hive.isAdapterRegistered(TimestampAdapter().typeId)) {
    Hive.registerAdapter(TimestampAdapter());
  }
  await Hive.openBox<ChatThread>('chatThreadsBox');

  //user id
  User? user = FirebaseAuth.instance.currentUser;
  CurrentUser.updateUser(user);


  ChatService().listenToChatThreads();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Modern Auth UI',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, // Main purple theme color
        scaffoldBackgroundColor: Colors.deepPurple.shade50,
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white, // AppBar text and icon color
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).copyWith(
           displayLarge: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
           titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
           bodyMedium: GoogleFonts.poppins(fontSize: 14),
           labelLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none, // Material 3 スタイルに合わせるか、元のスタイルを維持
          ),
          filled: true,
          // fillColor: Colors.white.withOpacity(0.9), // UserAuthScreenで個別に設定
          contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
        ),
        
         textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.poppins(fontSize: 14.0, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).primaryTextTheme.apply(bodyColor: Colors.white, displayColor: Colors.white)).copyWith(
           displayLarge: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
           titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white70),
           bodyMedium: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
           labelLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          // fillColor: Colors.deepPurple.shade800.withOpacity(0.5), // UserAuthScreenで個別に設定
          contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
          hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
          labelStyle: GoogleFonts.poppins(color: Colors.grey[400]),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            textStyle: GoogleFonts.poppins(fontSize: 16.0, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.poppins(fontSize: 14.0, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      home: const AuthWrapper(), // AuthScreenの代わりにAuthWrapperを使用
    );
  }
}


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 接続状態が待機中の場合、ローディングインジケーターを表示
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // ユーザーがログインしている場合、HomeScreenを表示
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        // ユーザーがログインしていない場合、UserAuthScreenを表示
        return const UserAuthScreen(); // UserAuthScreenに変更
      },
    );
  }
}



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Start with the Profile screen

  static const List<Widget> _widgetOptions = <Widget>[
    ChatThreadsScreen(),   // Index 0
    ProfileScreen(), // Index 1
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack( // To preserve state of screens
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Good for 2-3 items
      ),
    );
  }
}
// import 'package:flutter_svg/flutter_svg.dart'; // SVGを使用する場合

class UserAuthScreen extends StatefulWidget {
  const UserAuthScreen({super.key});

  @override
  State<UserAuthScreen> createState() => _UserAuthScreenState();
}

class _UserAuthScreenState extends State<UserAuthScreen> with SingleTickerProviderStateMixin { // AnimationControllerのために追加
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // サインアップ用に確認パスワードフィールドを追加
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true; // 確認パスワード用

  // ローディング状態の管理
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isGoogleLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isAppleLoading = ValueNotifier<bool>(false);
  // Facebookはオプションなので、ここではローディング状態を追加しません

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
      begin: const Offset(0, 0.5), // Y軸方向に画面の半分の位置から開始
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
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
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // オプション: メール確認を送信
        // User? user = FirebaseAuth.instance.currentUser;
        // await user?.sendEmailVerification();
        // _showErrorSnackbar("Verification email sent. Please check your inbox.");
      }
      // AuthWrapperがナビゲーションを処理
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar(e.message ?? "An unknown authentication error occurred.");
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
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
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
        // webAuthenticationOptions: WebAuthenticationOptions( // Webサポートが必要な場合
        //   clientId: 'YOUR_SERVICE_ID', // Apple Developer Portalで設定したService ID
        //   redirectUri: Uri.parse('https://YOUR_PROJECT_[ID.firebaseapp.com/__/auth/handler](https://ID.firebaseapp.com/__/auth/handler)'),
        // ),
      );
      final OAuthCredential oAuthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );
      await FirebaseAuth.instance.signInWithCredential(oAuthCredential);
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar(e.message ?? "Apple Sign-In failed.");
    } catch (e) {
      _showErrorSnackbar("An unexpected error with Apple Sign-In: ${e.toString()}");
    } finally {
      if (mounted) {
        _isAppleLoading.value = false;
      }
    }
  }

  // Facebookサインインのプレースホルダー (必要に応じて実装)
  Future<void> _signInWithFacebook() async {
    _showErrorSnackbar("Facebook Sign-In is not implemented yet.");
    // firebase_auth と flutter_facebook_auth パッケージを使用して実装
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedContainer( // 背景グラデーションのアニメーション用
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
            height: size.height, // 画面全体の高さを使用
            child: Stack(
              children: [
                // 背景要素 (ユーザー提供のコードから)
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

                // メインコンテンツ (アニメーションを適用)
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
                          // ロゴとタイトル
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
                                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.deepPurple.withOpacity(0.2),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    )
                                  ]
                                ),
                                child: Icon(
                                  Icons.lock_outline_rounded, // よりモダンなアイコン
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
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30), // 以前は40

                          // フォーム
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Email field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    labelStyle: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54),
                                    prefixIcon: Icon(Icons.email_outlined, color: isDark ? Colors.white70 : Colors.grey.shade600),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none, // テーマで設定済みだが、明確化
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? Colors.white.withOpacity(0.1) // ダークモードでの入力フィールド背景
                                        : Colors.black.withOpacity(0.05), // ライトモードでの入力フィールド背景
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!value.contains('@') || !value.contains('.')) { // 簡単なドットチェック追加
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Password field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54),
                                    prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.white70 : Colors.grey.shade600),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: isDark ? Colors.white70 : Colors.grey.shade600
                                      ),
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

                                // Confirm Password Field (Sign Up Mode Only)
                                if (!isLogin) ...[
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
                                    decoration: InputDecoration(
                                      labelText: 'Confirm Password',
                                      labelStyle: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54),
                                      prefixIcon: Icon(Icons.lock_clock_outlined, color: isDark ? Colors.white70 : Colors.grey.shade600),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: isDark ? Colors.white70 : Colors.grey.shade600
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscureConfirmPassword = !_obscureConfirmPassword;
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
                                      onPressed: () {
                                        // パスワード忘れ機能
                                        if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
                                          _showErrorSnackbar("Please enter your email address to reset password.");
                                          return;
                                        }
                                        FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim())
                                          .then((_) => _showErrorSnackbar("Password reset email sent to ${_emailController.text.trim()}."))
                                          .catchError((e) => _showErrorSnackbar("Failed to send reset email: ${e.message}"));
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
                                // Submit button
                                ValueListenableBuilder<bool>(
                                  valueListenable: _isLoading,
                                  builder: (context, isLoading, child) {
                                    return isLoading
                                      ? CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : Colors.deepPurple),
                                        )
                                      : ElevatedButton(
                                          onPressed: _submit,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isDark ? Colors.deepPurple : Colors.indigo,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(double.infinity, 50), // 幅いっぱいに広げる
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: 4,
                                            shadowColor: isDark
                                                ? Colors.deepPurple.shade400.withOpacity(0.5)
                                                : Colors.indigo.shade200.withOpacity(0.5),
                                          ),
                                          child: Text(
                                            isLogin ? 'Sign In' : 'Sign Up',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                  }
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDark ? Colors.white24 : Colors.black12,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or continue with',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: isDark ? Colors.white24 : Colors.black12,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Social buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (Platform.isAndroid) ...[
                                ValueListenableBuilder<bool>(
                                  valueListenable: _isGoogleLoading,
                                  builder: (context, isLoading, _) => isLoading
                                    ? const CircularProgressIndicator(strokeWidth: 2)
                                    : _SocialButton(
                                      // TODO: 'assets/google.png' を実際のGoogleロゴアセットに置き換えてください
                                      iconAsset: 'assets/google.png', // Googleロゴの画像アセット
                                      onPressed: _signInWithGoogle,
                                    ),
                                ),
                                const SizedBox(width: 16),
                              ],
                              if (Platform.isIOS) ...[
                                ValueListenableBuilder<bool>(
                                  valueListenable: _isAppleLoading,
                                  builder: (context, isLoading, _) => isLoading
                                    ? const CircularProgressIndicator(strokeWidth: 2)
                                    : _SocialButton(
                                      // TODO: 'assets/apple.png' を実際のAppleロゴアセットに置き換えてください
                                      iconAsset: 'assets/apple.png', // Appleロゴの画像アセット
                                      onPressed: _signInWithApple,
                                      isAppleIcon: true, // Appleアイコンは背景色を調整する場合があるため
                                    ),
                                ),
                                const SizedBox(width: 16),
                              ],
                              // Facebook (オプション)
                              _SocialButton(
                                iconAsset: 'assets/facebook.png', // Facebookロゴの画像アセット
                                onPressed:(){ 
                                  _signInWithFacebook();
                                  }, // 実装が必要
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          // Toggle auth mode
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLogin
                                    ? "Don't have an account?"
                                    : 'Already have an account?',
                                style: GoogleFonts.poppins(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              TextButton(
                                onPressed: _toggleAuthMode,
                                child: Text(
                                  isLogin ? 'Sign Up' : 'Sign In',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.deepPurple.shade200
                                        : Colors.deepPurple.shade800,
                                    decoration: TextDecoration.underline,
                                    decorationColor: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                           const SizedBox(height: 20), // 下部の余白
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

// ユーザー提供の_SocialButtonを少し変更
class _SocialButton extends StatelessWidget {
  final String iconAsset; // アイコンの画像アセットパス
  final VoidCallback onPressed;
  final bool isAppleIcon; // Appleアイコンの場合、ダークモードで白抜きにするなどの調整用

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
      borderRadius: BorderRadius.circular(24), // より丸みのある形
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          // border: Border.all(
          //   color: isDark ? Colors.white24 : Colors.black12,
          // ),
          borderRadius: BorderRadius.circular(24), // より丸みのある形
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0,2),
            )
          ]
        ),
        child: Image.asset( // アセット画像を使用
          iconAsset,
          width: 24,
          height: 24,
          // Appleアイコンでダークモードの場合、アイコンを白にする例 (アセットが対応している場合)
          // color: isAppleIcon && isDark ? Colors.white : null,
          errorBuilder: (context, error, stackTrace) {
            // アセットが見つからない場合のフォールバック
            return Icon(
              isAppleIcon ? Icons.apple : (iconAsset.contains("google") ? Icons.android_sharp : Icons.facebook), // 仮のアイコン
              size: 24,
              color: isDark ? Colors.white70 : Colors.black54,
            );
          },
        ),
      ),
    );
  }
}
// firebase_options.dart
// このファイルはFlutterFire CLIによって生成されるべきです。
// プロジェクトルートで `flutterfire configure` を実行してください。
// (flutter_firebase_auth_ui_v2 のコメントと同じ内容なので省略)

// **重要**: 上記は `flutterfire configure` によって生成された実際のコンテンツに置き換えてください。
// これは構造を示すための単なるプレースホルダーです。
// これがないと、アプリはFirebaseに接続できません。
//
// firebase_options.dart を生成するには:
// 1. Firebase CLIがインストールされ、ログインしていることを確認します。
// 2. FlutterFire CLIをインストールします: `dart pub global activate flutterfire_cli`
// 3. Flutterプロジェクトのルートで以下を実行します: `flutterfire configure`
//    これにより、Firebaseプロジェクトとプラットフォームを選択するよう案内されます。
