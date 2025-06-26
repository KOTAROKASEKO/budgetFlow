// lib/aisupport/goal_input/goalInput.dart の内容を想定

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // FilteringTextInputFormatter に必要
import 'package:moneymanager/aisupport/DashBoard_MapTask/Repository_DashBoard.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/View_PlanCreation.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/ViewModel_Plan_Creation.dart';
import 'package:provider/provider.dart';

class GoalInputPage extends StatefulWidget {
  const GoalInputPage({super.key}); //

  @override
  State<GoalInputPage> createState() => _GoalInputPageState();
}

class _GoalInputPageState extends State<GoalInputPage> {
  // Controllers for text fields
  final TextEditingController _earnThisYearController = TextEditingController(); //
  final TextEditingController _currentSkillController = TextEditingController(); //
  final TextEditingController _preferToEarnMoneyController = TextEditingController(); //
  final TextEditingController _noteController = TextEditingController(); //
  
  final Color primaryBgColor = const Color(0xFF1C1C2E); // 深いインディゴ
  final Color cardBgColor = const Color(0xFF2A2A3D);    // やや明るいインディゴ
  final Color accentColor = Colors.deepPurple;    // 鮮やかなティール
  final Color textColorPrimary = Colors.white.withOpacity(0.87);
  final Color textColorSecondary = Colors.white.withOpacity(0.6);
  final Color borderColor = Colors.white.withOpacity(0.15);

  @override
  void initState() {
    super.initState();

    }

  @override
  void dispose() {
    _earnThisYearController.dispose();
    _currentSkillController.dispose();
    _preferToEarnMoneyController.dispose();
    _noteController.dispose();
    // _bannerAd?.dispose(); //
    super.dispose();
  }

 
  Widget _buildInputSection({
    required String label,
    required String hintText,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: textColorSecondary, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          style: TextStyle(color: textColorPrimary, fontSize: 18),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: textColorSecondary.withOpacity(0.7), fontSize: 18),
            filled: true,
            fillColor: cardBgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          cursorColor: accentColor,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            // 入力検証 (GoalInputViewModel の validateInputs を参考に)
            // 例: _earnThisYearController.text.isEmpty や _durationController.text.isEmpty など
            if (_earnThisYearController.text.isEmpty || 
                _currentSkillController.text.isEmpty ||
                _preferToEarnMoneyController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please fill all required fields: Earnings, Duration, and Skill.")),
              );
              return;
            }

            // MODIFIED: Changed Navigator.push to Navigator.pushReplacement
            Navigator.pushReplacement( 
              context,
              MaterialPageRoute(
                builder: (newContext) {
                  return ChangeNotifierProvider(
                    create: (_) => PlanCreationViewModel(
                    repository: Provider.of<AIFinanceRepository>(context, listen: false),
                      initialEarnThisYear: _earnThisYearController.text,
                      initialCurrentSkill: _currentSkillController.text,
                      initialPreferToEarnMoney: _preferToEarnMoneyController.text,
                      initialNote: _noteController.text,
                    ),
                    child: const PlanCreationScreen(),
                  );
                },
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 5,
            shadowColor: accentColor.withOpacity(0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Create My Plan',
                style: TextStyle(
                  color: ThemeData.estimateBrightnessForColor(accentColor) == Brightness.light 
                         ? Colors.black 
                         : Colors.white, // ボタンのテキスト色をアクセントカラーの明るさに応じて調整
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded, 
                color: ThemeData.estimateBrightnessForColor(accentColor) == Brightness.light 
                       ? Colors.black 
                       : Colors.white,
                size: 20
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBgColor,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Set Your Goal', // AppBarのタイトル
          style: TextStyle(color: textColorPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryBgColor, // AppBarの背景色
        elevation: 0, // AppBarの影
        leading: IconButton( // AppBarの戻るボタン
          icon: Icon(Icons.arrow_back_ios_new, color: textColorPrimary),
          onPressed: () {
            Navigator.pop(context); //
          },
        ),
      ),
      body: SafeArea(
        child: Column( // ListViewと固定ボタンのためにColumnを使用
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                children: [
                  const SizedBox(height: 16),
                  
                  
                  const SizedBox(height: 24),

                  _buildInputSection(
                    label: 'Target Earnings (RM)',
                    hintText: 'e.g., 10000',
                    controller: _earnThisYearController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 24),

                  _buildInputSection(
                    label: 'Your Current Primary Skill',
                    keyboardType: TextInputType.multiline,
                    hintText: 'e.g., Software Development, Graphic Design',
                    controller: _currentSkillController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  _buildInputSection(
                    label: 'Preferred Way to Earn Money (Optional)',
                    hintText: 'e.g., Freelancing, Online Tutoring',
                    keyboardType: TextInputType.multiline,
                    controller: _preferToEarnMoneyController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  _buildInputSection(
                    label: 'Additional Notes (Optional)',
                    hintText: 'Any other details you want to add',
                    keyboardType: TextInputType.multiline,
                    controller: _noteController,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 30), // ボタンの前のスペース
                ],
              ),
            ),
            _buildSubmitButton(context), // 画面下部の送信ボタン
            const SizedBox(height: 24), // ボタン下のパディング
          ],
        ),
      ),
    );
  }
}