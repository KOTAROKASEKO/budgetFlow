
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:moneymanager/aisupport/goal_input/chatWithAi.dart';

class GoalInputPage extends StatefulWidget {
  const GoalInputPage({super.key});

  @override
  State<GoalInputPage> createState() => _GoalInputPageState();
}

class _GoalInputPageState extends State<GoalInputPage> {
  final TextEditingController _earnThisYearController = TextEditingController();
  final TextEditingController _currentSkillController = TextEditingController();
  final TextEditingController _preferToEarnMoneyController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  bool isLoadingAI = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  

  @override
  void dispose() {
    _earnThisYearController.dispose();
    _currentSkillController.dispose();
    _preferToEarnMoneyController.dispose();
    _noteController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      // Use a test ad unit ID for development
      // For Android: 'ca-app-pub-3940256099942544/6300978111'
      // For iOS: 'ca-app-pub-3940256099942544/2934735716'
      // Replace with your actual Ad Unit ID when ready for production
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Ad Unit ID for Android
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
          print('BannerAd loaded.');
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _isBannerAdLoaded = false; // Set to false if loading fails
          print('BannerAd failed to load: $err');
        },
        // You can add more listeners like onAdOpened, onAdClosed, onAdImpression here
      ),
    )..load(); // Don't forget to call .load()
  }

  @override
  Widget build(BuildContext context) {
    print('GoalInputPage build called');
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Goal Input',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ListView(
            children: [
              const SizedBox(height: 16), // Space below the ad
               if (_isBannerAdLoaded && _bannerAd != null)
                Container( // Use a Container to give the ad a background if desired
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              SizedBox(height: 24),
              Row(
                children:[
                  Expanded(
                    flex: 1,
                    child:_buildInputField(
                      controller: _earnThisYearController,
                      hintText: 'Make how much (RM) ',
                      maxLines: 3,
                      keyboardType: TextInputType.number,
                    ),
                  ),
              const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child:_buildInputField(
                      controller: _durationController,
                      hintText: 'How many months',
                      maxLines: 2,
                      keyboardType: TextInputType.number,
                    )
                  ),
              ]),
              const SizedBox(height: 24),
              _buildInputField(
                controller: _currentSkillController,
                hintText: 'What is your current skill?',
                maxLines: 4,
                 keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 24),
              _buildInputField(
                controller: _preferToEarnMoneyController,
                hintText: 'Is there any way you prefer to earn money?',
                maxLines: 4,
                keyboardType: TextInputType.multiline
              ),
              const SizedBox(height: 24),
              _buildInputField(
                controller: _noteController,
                hintText: 'Any additional note',
                maxLines: 4,
                keyboardType: TextInputType.multiline
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async{
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatWithAIScreen(
                          earnThisYear: _earnThisYearController.text,
                          duration: _durationController.text,
                          currentSkill: _currentSkillController.text,
                          preferToEarnMoney: _preferToEarnMoneyController.text,
                          note: _noteController.text,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2), // 鮮やかな紫
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'start',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24), // Space below the button
              // Space below the ad
            ],
          ),
        ),
      ),
    );
  }

  Widget loadingAiresponseView() {
  // This widget is now only responsible for displaying the UI.
  return Container(
    padding: const EdgeInsets.all(32.0),
    decoration: const BoxDecoration(
      // The shape is primarily controlled by showModalBottomSheet's shape property.
      // You can still set a color here if needed, but ensure it matches.
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)), // Matches the sheet's shape
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.5),
                blurRadius: 12.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/robotChan.gif', // Ensure this path is correct
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error_outline, size: 60, color: Colors.grey);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
        ),
        const SizedBox(height: 20),
        const Text(
          'Generating your financial plan...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color.fromARGB(255, 50, 50, 50),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16), // Bottom padding
      ],
    ),
  );
}
  
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    var textBoxColor = Colors.black;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          width: 2,
          color: Colors.deepPurple
          ),
        color: textBoxColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        
        fillColor: textBoxColor,
        hintText: hintText,
        hintStyle: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 18,
        fontWeight: FontWeight.w500,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      cursorColor: Colors.blueAccent,
      ),
    );
  }
  // Sample function to get response from ChatGPT using OpenAI API
  
}