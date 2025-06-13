// lib/aisupport/goal_input/goalInput.dart の内容を想定

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // FilteringTextInputFormatter に必要
import 'package:moneymanager/aisupport/DashBoard_MapTask/Repository_AIRoadMap.dart';
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
  
  // Duration controllers
  // _durationController は ViewModel に渡すための文字列（例："6 Months"）を保持します。
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _durationNumericController = TextEditingController();

  final Color primaryBgColor = const Color(0xFF1C1C2E); // 深いインディゴ
  final Color cardBgColor = const Color(0xFF2A2A3D);    // やや明るいインディゴ
  final Color accentColor = const Color(0xFF00C6B3);    // 鮮やかなティール
  final Color textColorPrimary = Colors.white.withOpacity(0.87);
  final Color textColorSecondary = Colors.white.withOpacity(0.6);
  final Color borderColor = Colors.white.withOpacity(0.15);

  @override
  void initState() {
    super.initState();
    // _loadBannerAd(); //

    // 期間の数値コントローラーを初期化 (例: デフォルトで6ヶ月)
    _durationNumericController.text = "6";
    _updateMainDurationController(6); // 文字列コントローラーも更新

    // 数値コントローラーのリスナーを設定し、数値が変更されたときにメインの期間文字列を更新
    _durationNumericController.addListener(() {
      final text = _durationNumericController.text;
      if (text.isNotEmpty) {
        try {
          int value = int.parse(text);
          if (value < 1) { // 月は1以上であることを保証
            _durationNumericController.text = "1";
            value = 1;
          }
          _updateMainDurationController(value);
        } catch (e) {
          // パースエラーの処理 (FilteringTextInputFormatter が大部分をカバー)
          _durationController.text = ""; // エラー時はメインコントローラーをクリア
        }
      } else {
        _durationController.text = ""; // 数値が空ならメインも空に
      }
    });
  }

  @override
  void dispose() {
    _earnThisYearController.dispose(); //
    _currentSkillController.dispose(); //
    _preferToEarnMoneyController.dispose(); //
    _noteController.dispose(); //
    _durationController.dispose();
    _durationNumericController.dispose();
    // _bannerAd?.dispose(); //
    super.dispose();
  }

  // void _loadBannerAd() {
  //   _bannerAd = BannerAd(
  //     adUnitId: 'ca-app-pub-1761598891234951/7527486247',
  //     request: const AdRequest(), //
  //     size: AdSize.banner, //
  //     listener: BannerAdListener(
  //       onAdLoaded: (ad) {
  //         if (!mounted) return;
  //         setState(() {
  //           _isBannerAdLoaded = true; //
  //         });
  //       },
  //       onAdFailedToLoad: (ad, err) {
  //         ad.dispose();
  //         _isBannerAdLoaded = false; //
  //       },
  //     ),
  //   )..load(); //
  // }

  // 数値の月を "X Month(s)" 形式の文字列に変換し、メインの期間コントローラーを更新
  void _updateMainDurationController(int months) {
    if (months == 1) {
      _durationController.text = "$months Month";
    } else {
      _durationController.text = "$months Months";
    }
  }

  // 月の数を増やす
  void _incrementMonths() {
    int currentValue = int.tryParse(_durationNumericController.text) ?? 0;
    currentValue++;
    _durationNumericController.text = currentValue.toString();
    // リスナーが _updateMainDurationController を呼び出す
  }

  // 月の数を減らす (最小1ヶ月)
  void _decrementMonths() {
    int currentValue = int.tryParse(_durationNumericController.text) ?? 1;
    if (currentValue > 1) {
      currentValue--;
      _durationNumericController.text = currentValue.toString();
      // リスナーが _updateMainDurationController を呼び出す
    }
  }

  // ステッパーボタン（+/-）の汎用ウィジェット
  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Icon(
            icon,
            color: accentColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ラベルが上にある標準的な入力セクションウィジェット
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

  // 期間選択のためのステッパーコントロール付き入力セクション
  Widget _buildDurationStepperSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Goal Duration',
          style: TextStyle(color: textColorSecondary, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStepperButton(icon: Icons.remove, onPressed: _decrementMonths),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _durationNumericController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly], // 数字のみ許可
                textAlign: TextAlign.center,
                style: TextStyle(color: textColorPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Months",
                  hintStyle: TextStyle(
                    color: textColorSecondary.withOpacity(0.7),
                    fontSize: 20,
                    fontWeight: FontWeight.normal,
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                cursorColor: accentColor,
              ),
            ),
            const SizedBox(width: 10),
            _buildStepperButton(icon: Icons.add, onPressed: _incrementMonths),
          ],
        ),
      ],
    );
  }

  // 送信ボタンウィジェット
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
                _durationController.text.isEmpty || 
                _currentSkillController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please fill all required fields: Earnings, Duration, and Skill.")),
              );
              return;
            }

            Navigator.push( //
              context,
              MaterialPageRoute(
                builder: (newContext) {
                  return ChangeNotifierProvider( //
                    create: (_) => PlanCreationViewModel( //
                    repository: Provider.of<AIFinanceRepository>(context, listen: false),
                      initialEarnThisYear: _earnThisYearController.text,
                      initialPlanDuration: _durationController.text,
                      initialCurrentSkill: _currentSkillController.text,
                      initialPreferToEarnMoney: _preferToEarnMoneyController.text,
                      initialNote: _noteController.text,
                    ),
                    child: const PlanCreationScreen(), //
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
                  // if (_isBannerAdLoaded && _bannerAd != null) // バナー広告
                  //   Container(
                  //     alignment: Alignment.center,
                  //     width: _bannerAd!.size.width.toDouble(),
                  //     height: _bannerAd!.size.height.toDouble(),
                  //     child: AdWidget(ad: _bannerAd!),
                  //   ),
                  
                  const SizedBox(height: 24),

                  _buildInputSection(
                    label: 'Target Earnings (RM)',
                    hintText: 'e.g., 10000',
                    controller: _earnThisYearController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 24),

                  _buildDurationStepperSection(), // 新しい期間選択ウィジェット
                  const SizedBox(height: 24),

                  _buildInputSection(
                    label: 'Your Current Primary Skill',
                    hintText: 'e.g., Software Development, Graphic Design',
                    controller: _currentSkillController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  _buildInputSection(
                    label: 'Preferred Way to Earn Money (Optional)',
                    hintText: 'e.g., Freelancing, Online Tutoring',
                    controller: _preferToEarnMoneyController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  _buildInputSection(
                    label: 'Additional Notes (Optional)',
                    hintText: 'Any other details you want to add',
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