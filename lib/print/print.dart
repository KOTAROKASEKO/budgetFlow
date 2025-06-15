import 'package:flutter/foundation.dart';

class D{
  void p(String param){
    if(kDebugMode){
      print('[DEBUG] $param');
    }
  }
}