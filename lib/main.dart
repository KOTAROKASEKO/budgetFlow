import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import 'package:moneymanager/View_BottomTab.dart';
import 'package:moneymanager/Transaction_Views/analysis/ViewModel.dart';
import 'package:moneymanager/Transaction_Views/dashboard/database/dasboardDB.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/Repository_AIRoadMap.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/ViewModel_AIRoadMap.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/note_repository.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/note_veiwmodel.dart';
import 'package:moneymanager/aisupport/RoadMaps/ViewModel_Roadmap.dart';
import 'package:moneymanager/aisupport/Goal_input/goal_input/goalInputViewModel.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/repository/task_repository.dart';
import 'package:moneymanager/security/Authentication.dart';
import 'package:moneymanager/security/uid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
    
  MobileAds.instance.initialize();

  // Hide navigation bar, but allow it to show on user interaction
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);

  final planRepository = PlanRepository();

  await planRepository.initDb();
  await dashBoardDBManager.init();
    
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (context) => PlanRepository()),
        Provider(create: (context) => NoteRepository()),
        Provider(
          create: (context) => AIFinanceRepository(
            localPlanRepository: context.read<PlanRepository>(),
          ),
        ),
        // ViewModel
        ChangeNotifierProvider(
          create: (context) => NoteViewModel(
            noteRepository: context.read<NoteRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AIFinanceViewModel(
            repository: context.read<AIFinanceRepository>(),
            noteViewModel: context.read<NoteViewModel>(),
          ),
        ),

        
        Provider.value(value: planRepository),
        ChangeNotifierProvider<AnalysisViewModel>(  
            create: (_) => AnalysisViewModel()
            ),
        ChangeNotifierProvider(
          create: (context) => RoadmapViewModel(
            repository: context.read<AIFinanceRepository>(), // or Provider.of<PlanRepository>(context, listen: false)
          ),
        ),

        ChangeNotifierProvider(create: (_) => GoalInputViewModel()),
      ],
      child: const MyApp(),
    ),
  );
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
        scaffoldBackgroundColor: const Color.fromARGB(255, 91, 91, 91),
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
            return const UserAuthScreen();
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Authentication Screen (Login/Sign Up Toggle) ---
