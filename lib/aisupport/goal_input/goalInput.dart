
import 'package:flutter/material.dart';
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
  
  bool isLoadingAI = false;

  @override
  void dispose() {
    _earnThisYearController.dispose();
    _currentSkillController.dispose();
    _preferToEarnMoneyController.dispose();
    _noteController.dispose();
    super.dispose();
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
              SizedBox(height: 24),
              _buildInputField(
                controller: _earnThisYearController,
                hintText: 'How much you gonna earn this year?',
                keyboardType: TextInputType.number,
              ),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatWithAIScreen(
                          earnThisYear: _earnThisYearController.text,
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
        color: textBoxColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4), // 影の位置
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