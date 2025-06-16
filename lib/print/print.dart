import 'package:flutter/foundation.dart';

class D{
  static void p(String param){
    if(kDebugMode){
      print('[DEBUG] $param');
    }
  }
}