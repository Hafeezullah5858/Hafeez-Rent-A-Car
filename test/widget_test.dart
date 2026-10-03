import 'package:flutter_test/flutter_test.dart';
import 'package:hafeez_rent_a_car/main.dart';

void main() {
  testWidgets('Hafeez Rent A Car app starts', (tester) async {
    await tester.pumpWidget(const HafeezRentApp(firebaseReady: false));
    await tester.pump();
    expect(find.byType(HafeezRentApp), findsOneWidget);
  });
}
