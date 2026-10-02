import 'package:flutter_test/flutter_test.dart';
import 'package:hafeez_rent_a_car/models/models.dart';
import 'package:hafeez_rent_a_car/services/local_store.dart';
import 'package:hafeez_rent_a_car/main.dart';

void main() {
  test('ledger entry round trips through map', () {
    final original = LedgerEntry(
      id: '1',
      accountId: 'a',
      vehicleId: 'v',
      type: EntryType.driving,
      source: EarningSource.inDrive,
      category: 'inDrive',
      amount: 1234.5,
      date: DateTime(2026, 9, 28),
      updatedAtMs: 10,
    );
    final restored = LedgerEntry.fromMap(original.toMap());
    expect(restored.id, original.id);
    expect(restored.amount, original.amount);
    expect(restored.source, EarningSource.inDrive);
    expect(restored.date, original.date);
  });

  test('unknown earning source safely falls back to other', () {
    expect(earningSourceFrom('newPlatform'), EarningSource.other);
    expect(earningSourceFrom(null), isNull);
  });

  test('unknown entry type safely falls back to general income', () {
    expect(entryTypeFrom('futureType'), EntryType.income);
  });

  test('vehicle round trips with update timestamp', () {
    final original = Vehicle(id: 'v1', name: 'BEF-275', plate: 'ABC-123', updatedAtMs: 99);
    final restored = Vehicle.fromMap(original.toMap());
    expect(restored.id, original.id);
    expect(restored.plate, original.plate);
    expect(restored.updatedAtMs, 99);
  });

  test('invalid amount is detectable from imported record', () {
    final restored = LedgerEntry.fromMap({
      'id': 'e1', 'accountId': 'local', 'type': 'income', 'category': 'Test',
      'amount': -5, 'date': '2026-09-28T00:00:00.000', 'updatedAtMs': 1,
    });
    expect(restored.amount, -5);
    expect(restored.amount < 0, isTrue);
  });

test('current schema is the expected production schema', () {
  expect(LocalStore.currentSchema, 16);
});


test('rental calculates remaining balance', () {
  final r = Rental(id: 'r1', customerId: 'c1', vehicleId: 'v1', startAt: DateTime(2026, 9, 1), endAt: DateTime(2026, 9, 4), dailyRate: 5000, totalRent: 15000, paidAmount: 5000);
  expect(r.remaining, 10000);
});

test('vehicle extended profile round trips', () {
  final v = Vehicle(id: 'v1', name: 'Corolla', plate: 'ABC-123', model: 'GLI', year: '2022', color: 'White', fuelType: 'Petrol', currentMileage: 42000, status: VehicleStatus.available, updatedAtMs: 44);
  final x = Vehicle.fromMap(v.toMap());
  expect(x.model, 'GLI');
  expect(x.currentMileage, 42000);
  expect(x.status, VehicleStatus.available);
});


test('rental total payable and deposit balance are calculated correctly', () {
  final r = Rental(
    id: 'r2', customerId: 'c1', vehicleId: 'v1',
    startAt: DateTime(2026, 9, 1), endAt: DateTime(2026, 9, 4),
    dailyRate: 5000, totalRent: 15000, paidAmount: 5000,
    tax: 500, lateFee: 200, damageFee: 300, discount: 100,
    securityDeposit: 10000, depositRefunded: 2500,
  );
  expect(r.totalPayable, 15900);
  expect(r.remaining, 10900);
  expect(r.depositBalance, 7500);
});

test('vehicle period report counts payment transactions once', () {
  final c = AppController();
  c.vehicles = [Vehicle(id: 'v1', name: 'BEF-275', plate: 'BEF-275')];
  c.rentals = [Rental(
    id: 'r1', customerId: 'c1', vehicleId: 'v1',
    startAt: DateTime(2026, 9, 1), endAt: DateTime(2026, 9, 4),
    dailyRate: 5000, totalRent: 15000, paidAmount: 10000,
  )];
  c.payments = [PaymentRecord(
    id: 'p1', rentalId: 'r1', customerId: 'c1', vehicleId: 'v1',
    amount: 10000, date: DateTime(2026, 9, 2), method: 'Cash',
  )];
  final r = c.vehiclePeriodReport('v1', DateTime(2026, 9, 1), DateTime(2026, 9, 30));
  expect(r.rentalCollected, 10000);
  expect(r.income, 10000);
});
}
