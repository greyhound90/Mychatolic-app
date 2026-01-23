import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

void main() {
  testWidgets('Connect to Supabase and read data', (WidgetTester tester) async {
    // WARNING: Do not use hardcoded credentials in production.
    // This is for demonstration purposes only.
    // In a real application, use a secure method to store and access credentials.
    const supabaseUrl = 'https://prmfmmrzhnlltzyxxyhw.supabase.co';
    const supabaseAnonKey = 'sb_publishable_wchTSXIbemCJJgXVebW1VA_rR_WAqPe';

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    final supabase = Supabase.instance.client;
    final data = await supabase.from('posts').select();

    debugPrint(data.toString());
  });
}
