import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'models/models.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync.dart';
import 'services/local_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {}
  runApp(HafeezRentApp(firebaseReady: firebaseReady));
}

class AppController extends ChangeNotifier {
  final LocalStore store = LocalStore();
  final Uuid uuid = const Uuid();
  FirebaseCloudSync? _cloud;
  FirebaseCloudSync get cloud => _cloud ??= FirebaseCloudSync();
  List<Vehicle> vehicles = [];
  List<LedgerEntry> entries = [];
  List<Customer> customers = [];
  List<Rental> rentals = [];
  List<MaintenanceRecord> maintenance = [];
  List<FuelRecord> fuel = [];
  List<Driver> drivers = [];
  List<PaymentRecord> payments = [];
  List<DriverSettlement> settlements = [];
  List<InspectionRecord> inspections = [];
  List<AuditLog> audits = [];
  BusinessSettings settings = const BusinessSettings();
  AdminRole role = AdminRole.owner;
  Set<String> deletedEntryIds = {};
  User? user;
  bool firebaseReady = false, loading = true, dark = false;
  String? message;
  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      user = firebaseReady ? AuthService().auth.currentUser : null;
      await store.setOwnerId(user?.uid ?? 'local');
      final savedRole = await store.role();
      role = AdminRole.values.firstWhere(
        (x) => enumName(x) == savedRole,
        orElse: () => AdminRole.owner,
      );
      await reloadLocal();
      if (user != null) {
        try {
          await refreshCloud();
        } catch (_) {
          message = 'Cloud unavailable; local data is safe.';
        }
      }
      if (vehicles.isEmpty) {
        vehicles = [
          Vehicle(
            id: uuid.v4(),
            name: 'BEF-275',
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ];
        await store.saveVehicles(vehicles);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reloadLocal() async {
    vehicles = await store.vehicles();
    entries = await store.entries();
    customers = await store.customers();
    rentals = await store.rentals();
    maintenance = await store.maintenance();
    fuel = await store.fuel();
    drivers = await store.drivers();
    payments = await store.payments();
    settlements = await store.settlements();
    inspections = await store.inspections();
    deletedEntryIds = await store.deletedEntryIds();
    final now = DateTime.now();
    rentals = rentals
        .map(
          (r) => r.status == RentalStatus.active && r.endAt.isBefore(now)
              ? r.copyWith(status: RentalStatus.overdue)
              : r,
        )
        .toList();
  }

  Future<void> saveAll() async {
    await store.saveVehicles(vehicles);
    await store.saveEntries(entries);
    await store.saveCustomers(customers);
    await store.saveRentals(rentals);
    await store.saveMaintenance(maintenance);
    await store.saveFuel(fuel);
    await store.saveDrivers(drivers);
    await store.savePayments(payments);
    await store.saveSettlements(settlements);
    await store.saveInspections(inspections);
    await store.saveSettings(settings);
    await store.saveAudits(audits);
    await store.saveDeletedEntryIds(deletedEntryIds);
  }

  double get income => entries
      .where((e) => e.type != EntryType.expense)
      .fold(0, (s, e) => s + e.amount);
  double get expenses => entries
      .where((e) => e.type == EntryType.expense)
      .fold(0, (s, e) => s + e.amount);
  double get rentalRevenue => rentals.fold(0, (s, r) => s + r.paidAmount);
  double get receivable => rentals.fold(0, (s, r) => s + r.remaining);
  int get activeRentals =>
      rentals.where((r) => r.status == RentalStatus.active).length;
  int get availableCars =>
      vehicles.where((v) => v.status == VehicleStatus.available).length;
  int get overdueRentals => rentals
      .where(
        (r) =>
            r.status == RentalStatus.overdue ||
            (r.status == RentalStatus.active &&
                r.endAt.isBefore(DateTime.now())),
      )
      .length;
  List<Vehicle> get expiringVehicles => vehicles.where((v) {
    final now = DateTime.now();
    final dates = [
      v.registrationExpiry,
      v.insuranceExpiry,
      v.tokenExpiry,
      v.fitnessExpiry,
    ].whereType<DateTime>();
    return dates.any((d) => d.isBefore(now.add(const Duration(days: 30))));
  }).toList();
  List<Customer> get expiringLicenses => customers
      .where(
        (x) =>
            x.licenseExpiry != null &&
            x.licenseExpiry!.isBefore(
              DateTime.now().add(const Duration(days: 30)),
            ),
      )
      .toList();
  double get depositsHeld => rentals
      .where((r) => r.status != RentalStatus.cancelled)
      .fold(0.0, (s, r) => s + r.depositBalance);
  double get rentalGross => rentals.fold(0.0, (s, r) => s + r.totalPayable);
  double get utilization => vehicles.isEmpty
      ? 0
      : rentals
                .where(
                  (r) =>
                      r.status == RentalStatus.active ||
                      r.status == RentalStatus.completed,
                )
                .map((r) => r.vehicleId)
                .toSet()
                .length /
            vehicles.length *
            100;
  double vehicleIncome(String id) {
    final direct = entries
        .where(
          (e) =>
              e.vehicleId == id &&
              e.type != EntryType.expense &&
              e.category.toLowerCase() != 'rental payment',
        )
        .fold(0.0, (s, e) => s + e.amount);
    final collected = payments
        .where((p) => p.vehicleId == id)
        .fold(0.0, (s, p) => s + p.amount);
    final legacy = rentals
        .where(
          (r) => r.vehicleId == id && !payments.any((p) => p.rentalId == r.id),
        )
        .fold(0.0, (s, r) => s + r.paidAmount);
    return direct + collected + legacy;
  }

  double vehicleExpense(String id) =>
      entries
          .where((e) => e.vehicleId == id && e.type == EntryType.expense)
          .fold(0, (s, e) => s + e.amount) +
      fuel.where((f) => f.vehicleId == id).fold(0, (s, f) => s + f.amount) +
      maintenance.where((m) => m.vehicleId == id).fold(0, (s, m) => s + m.cost);
  Vehicle? vehicle(String id) => vehicles.cast<Vehicle?>().firstWhere(
    (v) => v!.id == id,
    orElse: () => null,
  );
  Customer? customer(String id) => customers.cast<Customer?>().firstWhere(
    (v) => v!.id == id,
    orElse: () => null,
  );
  Future<void> persist() async {
    await saveAll();
    if (firebaseReady && user != null) {
      try {
        await cloud.merge(user!.uid, vehicles, entries, deletedEntryIds);
        await cloud.pushBusiness(
          user!.uid,
          customers,
          rentals,
          maintenance,
          fuel,
          drivers,
          payments,
          settlements,
          inspections,
          settings: settings,
          audits: audits.take(300).toList(),
        );
        message = 'Cloud sync complete';
      } catch (_) {
        message = 'Saved locally; cloud sync will retry later';
      }
    }
    notifyListeners();
  }

  Future<void> addVehicle(
    String name,
    String plate, {
    String model = '',
    String year = '',
    String color = '',
    String fuelType = 'Petrol',
    double mileage = 0,
    String chassisNumber = '',
    String engineNumber = '',
    String insuranceCompany = '',
    String note = '',
    double purchasePrice = 0,
    double marketValue = 0,
    DateTime? registrationExpiry,
    DateTime? insuranceExpiry,
    DateTime? tokenExpiry,
    DateTime? fitnessExpiry,
  }) async {
    requireCapability('fleet');
    final n = name.trim(), p = plate.trim();
    if (n.isEmpty) throw const FormatException('Vehicle name is required.');
    if (vehicles.any(
      (v) =>
          v.name.toLowerCase() == n.toLowerCase() &&
          v.plate.toLowerCase() == p.toLowerCase(),
    ))
      throw const FormatException('This vehicle already exists.');
    vehicles = [
      ...vehicles,
      Vehicle(
        id: uuid.v4(),
        name: n,
        plate: p,
        model: model.trim(),
        year: year.trim(),
        color: color.trim(),
        fuelType: fuelType,
        currentMileage: mileage,
        chassisNumber: chassisNumber.trim(),
        engineNumber: engineNumber.trim(),
        insuranceCompany: insuranceCompany.trim(),
        note: note.trim(),
        purchasePrice: purchasePrice,
        marketValue: marketValue,
        registrationExpiry: registrationExpiry,
        insuranceExpiry: insuranceExpiry,
        tokenExpiry: tokenExpiry,
        fitnessExpiry: fitnessExpiry,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    await persist();
  }

  Future<void> updateVehicle(Vehicle old, Vehicle next) async {
    requireCapability('fleet');
    if (next.name.trim().isEmpty)
      throw const FormatException('Vehicle name is required.');
    final duplicate = vehicles.any(
      (v) =>
          v.id != old.id &&
          next.plate.trim().isNotEmpty &&
          v.plate.trim().toLowerCase() == next.plate.trim().toLowerCase(),
    );
    if (duplicate)
      throw const FormatException(
        'Another vehicle already uses this registration number.',
      );
    vehicles = vehicles
        .map(
          (v) => v.id == old.id
              ? next.copyWith(
                  updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                )
              : v,
        )
        .toList();
    await persist();
  }

  Future<void> deleteVehicle(Vehicle v) async {
    requireCapability('fleet');
    if (entries.any((e) => e.vehicleId == v.id) ||
        rentals.any((r) => r.vehicleId == v.id))
      throw const FormatException(
        'This vehicle has records. Keep it and mark it inactive instead.',
      );
    vehicles = vehicles.where((x) => x.id != v.id).toList();
    await persist();
  }

  Future<void> addEntry({
    required EntryType type,
    String? vehicleId,
    EarningSource? source,
    required String category,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    requireCapability('ledger');
    if (!amount.isFinite || amount <= 0)
      throw const FormatException('Amount must be greater than zero.');
    if (category.trim().isEmpty)
      throw const FormatException('Category is required.');
    if (type == EntryType.driving && source == null)
      throw const FormatException('Select a driving platform.');
    entries = [
      ...entries,
      LedgerEntry(
        id: uuid.v4(),
        accountId: user?.uid ?? 'local',
        vehicleId: vehicleId,
        type: type,
        source: type == EntryType.driving ? source : null,
        category: category.trim(),
        amount: amount,
        date: date,
        note: note.trim(),
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    await persist();
  }

  Future<void> updateEntry(
    LedgerEntry old, {
    required EntryType type,
    String? vehicleId,
    EarningSource? source,
    required String category,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    requireCapability('ledger');
    if (!amount.isFinite || amount <= 0)
      throw const FormatException('Amount must be greater than zero.');
    if (category.trim().isEmpty)
      throw const FormatException('Category is required.');
    entries = entries
        .map(
          (e) => e.id == old.id
              ? LedgerEntry(
                  id: e.id,
                  accountId: e.accountId,
                  vehicleId: vehicleId,
                  type: type,
                  source: type == EntryType.driving ? source : null,
                  category: category.trim(),
                  amount: amount,
                  date: date,
                  note: note.trim(),
                  schemaVersion: e.schemaVersion,
                  updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                )
              : e,
        )
        .toList();
    await persist();
  }

  Future<void> deleteEntry(LedgerEntry e) async {
    requireCapability('ledger');
    entries = entries.where((x) => x.id != e.id).toList();
    deletedEntryIds.add(e.id);
    await persist();
  }

  Future<void> addCustomer(Map<String, dynamic> x) async {
    requireCapability('customers');
    customers = [
      ...customers,
      Customer(
        id: uuid.v4(),
        name: x['name'].trim(),
        fatherName: x['father'].trim(),
        phone: x['phone'].trim(),
        cnic: x['cnic'].trim(),
        address: x['address'].trim(),
        licenseNumber: x['license'].trim(),
        licenseExpiry: x['expiry'],
        note: x['note'].trim(),
        emergencyContact: '${x['emergency'] ?? ''}'.trim(),
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    await persist();
  }

  Future<void> updateCustomer(Customer c, Map<String, dynamic> x) async {
    requireCapability('customers');
    customers = customers
        .map(
          (a) => a.id == c.id
              ? Customer(
                  id: c.id,
                  name: x['name'].trim(),
                  fatherName: x['father'].trim(),
                  phone: x['phone'].trim(),
                  cnic: x['cnic'].trim(),
                  address: x['address'].trim(),
                  licenseNumber: x['license'].trim(),
                  licenseExpiry: x['expiry'],
                  note: x['note'].trim(),
                  emergencyContact: '${x['emergency'] ?? ''}'.trim(),
                  updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                )
              : a,
        )
        .toList();
    await persist();
  }

  Future<void> deleteCustomer(Customer c) async {
    requireCapability('customers');
    if (rentals.any((r) => r.customerId == c.id))
      throw const FormatException(
        'This customer has rental history. Keep the customer for records.',
      );
    customers = customers.where((x) => x.id != c.id).toList();
    await persist();
  }

  Future<void> addRental({
    required String customerId,
    required String vehicleId,
    required DateTime start,
    required DateTime end,
    required double rate,
    required double deposit,
    required double paid,
    String note = '',
    String paymentMethod = 'Cash',
  }) async {
    requireCapability('rentals');
    if (start.isAfter(end))
      throw const FormatException('Return date must be after start date.');
    if (rate <= 0)
      throw const FormatException('Daily rent must be greater than zero.');
    if (deposit < 0 || paid < 0)
      throw const FormatException(
        'Deposit and initial payment cannot be negative.',
      );
    if (vehicles.any(
      (v) => v.id == vehicleId && v.status != VehicleStatus.available,
    ))
      throw const FormatException('This vehicle is not available.');
    final overlap = rentals.any(
      (r) =>
          r.vehicleId == vehicleId &&
          r.status != RentalStatus.cancelled &&
          r.status != RentalStatus.completed &&
          start.isBefore(r.endAt) &&
          end.isAfter(r.startAt),
    );
    if (overlap)
      throw const FormatException(
        'This vehicle already has a booking during the selected dates.',
      );
    final days = end.difference(start).inDays.clamp(1, 9999);
    final total = days * rate;
    if (paid > total)
      throw const FormatException(
        'Initial payment cannot be greater than the rental amount.',
      );
    final now = DateTime.now();
    final r = Rental(
      id: uuid.v4(),
      customerId: customerId,
      vehicleId: vehicleId,
      startAt: start,
      endAt: end,
      dailyRate: rate,
      totalRent: total,
      advance: paid,
      securityDeposit: deposit,
      paidAmount: paid,
      status: RentalStatus.active,
      note: note.trim(),
      paymentMethod: paymentMethod.trim().isEmpty
          ? 'Cash'
          : paymentMethod.trim(),
      updatedAtMs: now.millisecondsSinceEpoch,
    );
    rentals = [...rentals, r];
    vehicles = vehicles
        .map(
          (v) =>
              v.id == vehicleId ? v.copyWith(status: VehicleStatus.rented) : v,
        )
        .toList();
    if (paid > 0) {
      payments = [
        ...payments,
        PaymentRecord(
          id: uuid.v4(),
          rentalId: r.id,
          customerId: r.customerId,
          vehicleId: r.vehicleId,
          amount: paid,
          date: now,
          method: r.paymentMethod,
          updatedAtMs: now.millisecondsSinceEpoch,
        ),
      ];
      entries = [
        ...entries,
        LedgerEntry(
          id: uuid.v4(),
          accountId: user?.uid ?? 'local',
          vehicleId: r.vehicleId,
          type: EntryType.income,
          category: 'Rental payment',
          amount: paid,
          date: now,
          note:
              '${r.paymentMethod} • Initial payment • Rental ${r.id.substring(0, 8)}',
          updatedAtMs: now.millisecondsSinceEpoch,
        ),
      ];
    }
    await persist();
  }

  Future<void> updateRentalStatus(Rental r, RentalStatus status) async {
    requireCapability('rentals');
    rentals = rentals
        .map(
          (x) => x.id == r.id
              ? x.copyWith(
                  status: status,
                  updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                )
              : x,
        )
        .toList();
    if (status == RentalStatus.completed || status == RentalStatus.cancelled) {
      vehicles = vehicles
          .map(
            (v) => v.id == r.vehicleId
                ? v.copyWith(status: VehicleStatus.available)
                : v,
          )
          .toList();
    }
    await persist();
  }

  Future<void> addPayment(
    Rental r,
    double amount, {
    String method = 'Cash',
    String reference = '',
    String note = '',
  }) async {
    requireCapability('payments');
    if (amount <= 0)
      throw const FormatException('Payment must be greater than zero.');
    final remaining = r.remaining;
    if (amount > remaining)
      throw const FormatException(
        'Payment cannot be greater than the outstanding balance.',
      );
    final now = DateTime.now();
    final next = r.paidAmount + amount;
    rentals = rentals
        .map(
          (x) => x.id == r.id
              ? x.copyWith(
                  paidAmount: next,
                  updatedAtMs: now.millisecondsSinceEpoch,
                )
              : x,
        )
        .toList();
    payments = [
      ...payments,
      PaymentRecord(
        id: uuid.v4(),
        rentalId: r.id,
        customerId: r.customerId,
        vehicleId: r.vehicleId,
        amount: amount,
        date: now,
        method: method,
        reference: reference.trim(),
        note: note.trim(),
        updatedAtMs: now.millisecondsSinceEpoch,
      ),
    ];
    entries = [
      ...entries,
      LedgerEntry(
        id: uuid.v4(),
        accountId: user?.uid ?? 'local',
        vehicleId: r.vehicleId,
        type: EntryType.income,
        category: 'Rental payment',
        amount: amount,
        date: now,
        note:
            '${method.trim()} • Rental ${r.id.substring(0, 8)}${reference.trim().isEmpty ? '' : ' • ${reference.trim()}'}',
        updatedAtMs: now.millisecondsSinceEpoch,
      ),
    ];
    await persist();
    await addAudit(
      'Payment added',
      'Rental',
      'Rs ${amount.toStringAsFixed(2)} • ${r.id.substring(0, 8)}',
    );
  }

  Future<void> addSettlement({
    required Driver driver,
    required String periodLabel,
    required double grossEarnings,
    double advances = 0,
    double deductions = 0,
    String note = '',
  }) async {
    requireCapability('settlements');
    if (periodLabel.trim().isEmpty)
      throw const FormatException('Settlement period is required.');
    if (grossEarnings < 0 || advances < 0 || deductions < 0)
      throw const FormatException('Settlement amounts cannot be negative.');
    final commission = grossEarnings * driver.commissionRate / 100;
    final now = DateTime.now();
    settlements = [
      ...settlements,
      DriverSettlement(
        id: uuid.v4(),
        driverId: driver.id,
        periodLabel: periodLabel.trim(),
        grossEarnings: grossEarnings,
        salary: driver.salary,
        commission: commission,
        advances: advances,
        deductions: deductions,
        date: now,
        note: note.trim(),
        updatedAtMs: now.millisecondsSinceEpoch,
      ),
    ];
    await persist();
    await addAudit(
      'Settlement created',
      'Driver',
      '${driver.name} • ${periodLabel.trim()}',
    );
  }

  Future<void> addInspection({
    required Rental rental,
    required String stage,
    required double mileage,
    required String fuelLevel,
    required String condition,
    double damageCharge = 0,
    String note = '',
  }) async {
    requireCapability('rentals');
    if (mileage < 0 || damageCharge < 0)
      throw const FormatException(
        'Mileage and damage charge cannot be negative.',
      );
    final now = DateTime.now();
    inspections = [
      ...inspections,
      InspectionRecord(
        id: uuid.v4(),
        rentalId: rental.id,
        vehicleId: rental.vehicleId,
        stage: stage,
        mileage: mileage,
        fuelLevel: fuelLevel,
        condition: condition,
        damageCharge: damageCharge,
        note: note.trim(),
        date: now,
        updatedAtMs: now.millisecondsSinceEpoch,
      ),
    ];
    if (stage == 'Return') {
      rentals = rentals
          .map(
            (x) => x.id == rental.id
                ? x.copyWith(
                    actualReturnAt: now,
                    damageFee: damageCharge,
                    updatedAtMs: now.millisecondsSinceEpoch,
                  )
                : x,
          )
          .toList();
      vehicles = vehicles
          .map(
            (v) => v.id == rental.vehicleId
                ? v.copyWith(
                    currentMileage: mileage,
                    status: VehicleStatus.available,
                    updatedAtMs: now.millisecondsSinceEpoch,
                  )
                : v,
          )
          .toList();
    }
    await persist();
  }

  Future<void> finalizeReturn(
    Rental rental, {
    required double mileage,
    required double damageCharge,
    required double depositRefund,
    String condition = 'Good',
    String fuelLevel = 'Full',
    String note = '',
  }) async {
    requireCapability('rentals');
    if (depositRefund < 0 || depositRefund > rental.depositBalance)
      throw const FormatException(
        'Deposit refund is greater than the available deposit.',
      );
    await addInspection(
      rental: rental,
      stage: 'Return',
      mileage: mileage,
      fuelLevel: fuelLevel,
      condition: condition,
      damageCharge: damageCharge,
      note: note,
    );
    final updated = rentals
        .firstWhere((x) => x.id == rental.id)
        .copyWith(
          depositRefunded: depositRefund,
          status: RentalStatus.completed,
          actualReturnAt: DateTime.now(),
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
    rentals = rentals.map((x) => x.id == rental.id ? updated : x).toList();
    if (depositRefund > 0) {
      entries = [
        ...entries,
        LedgerEntry(
          id: uuid.v4(),
          accountId: user?.uid ?? 'local',
          vehicleId: rental.vehicleId,
          type: EntryType.expense,
          category: 'Security deposit refund',
          amount: depositRefund,
          date: DateTime.now(),
          note: 'Deposit refund • Rental ${rental.id.substring(0, 8)}',
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ];
    }
    await persist();
  }

  String exportCsv() {
    final rows = <List<String>>[
      [
        'Rental ID',
        'Customer',
        'Vehicle',
        'Start',
        'End',
        'Status',
        'Total Payable',
        'Paid',
        'Balance',
      ],
    ];
    for (final r in rentals) {
      rows.add([
        r.id,
        customer(r.customerId)?.name ?? '',
        vehicle(r.vehicleId)?.name ?? '',
        r.startAt.toIso8601String(),
        r.endAt.toIso8601String(),
        enumName(r.status),
        r.totalPayable.toStringAsFixed(2),
        r.paidAmount.toStringAsFixed(2),
        r.remaining.toStringAsFixed(2),
      ]);
    }
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    return rows.map((row) => row.map(q).join(',')).join('\n');
  }

  String exportPaymentsCsv() {
    final rows = <List<String>>[
      [
        'Payment ID',
        'Rental ID',
        'Customer',
        'Vehicle',
        'Date',
        'Method',
        'Reference',
        'Amount',
        'Note',
      ],
    ];
    for (final p in payments) {
      rows.add([
        p.id,
        p.rentalId,
        customer(p.customerId)?.name ?? '',
        vehicle(p.vehicleId)?.name ?? '',
        p.date.toIso8601String(),
        p.method,
        p.reference,
        p.amount.toStringAsFixed(2),
        p.note,
      ]);
    }
    String q(String v) => '"${v.replaceAll('\"', '\"\"')}"';
    return rows.map((row) => row.map(q).join(',')).join('\n');
  }

  String exportVehicleProfitabilityCsv() {
    final rows = <List<String>>[
      [
        'Vehicle',
        'Plate',
        'Income',
        'Expense',
        'Net',
        'Current Mileage',
        'Status',
      ],
    ];
    for (final v in vehicles) {
      final inc = vehicleIncome(v.id);
      final exp = vehicleExpense(v.id);
      rows.add([
        v.name,
        v.plate,
        inc.toStringAsFixed(2),
        exp.toStringAsFixed(2),
        (inc - exp).toStringAsFixed(2),
        v.currentMileage.toStringAsFixed(0),
        enumName(v.status),
      ]);
    }
    String q(String v) => '"${v.replaceAll('\"', '\"\"')}"';
    return rows.map((row) => row.map(q).join(',')).join('\n');
  }

  VehiclePeriodReport vehiclePeriodReport(
    String vehicleId,
    DateTime from,
    DateTime to,
  ) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    final vs = vehicle(vehicleId);
    bool inRange(DateTime d) => !d.isBefore(start) && !d.isAfter(end);
    final vehicleEntries = entries
        .where((e) => e.vehicleId == vehicleId && inRange(e.date))
        .toList();
    final directIncome = vehicleEntries
        .where(
          (e) =>
              e.type != EntryType.expense &&
              e.category.toLowerCase() != 'rental payment',
        )
        .fold(0.0, (s, e) => s + e.amount);
    final ledgerExpenses = vehicleEntries
        .where((e) => e.type == EntryType.expense)
        .fold(0.0, (s, e) => s + e.amount);
    final fuelRecords = fuel
        .where((f) => f.vehicleId == vehicleId && inRange(f.date))
        .toList();
    final maintenanceRecords = maintenance
        .where((m) => m.vehicleId == vehicleId && inRange(m.date))
        .toList();
    final fuelExpense = fuelRecords.fold(0.0, (s, f) => s + f.amount);
    final maintenanceExpense = maintenanceRecords.fold(
      0.0,
      (s, m) => s + m.cost,
    );
    // Rentals are counted when their rental period overlaps the selected range,
    // while cash income is recognized from payment transaction dates.
    final vehicleRentals = rentals
        .where(
          (r) =>
              r.vehicleId == vehicleId &&
              r.status != RentalStatus.cancelled &&
              r.endAt.isAfter(start) &&
              r.startAt.isBefore(end),
        )
        .toList();
    final billedRentals = vehicleRentals
        .where((r) => !r.startAt.isBefore(start) && !r.startAt.isAfter(end))
        .toList();
    final rentalBilled = billedRentals.fold(0.0, (s, r) => s + r.totalPayable);
    final rentalPayments = payments
        .where((p) => p.vehicleId == vehicleId && inRange(p.date))
        .fold(0.0, (s, p) => s + p.amount);
    // Legacy rentals created before payment history existed have no PaymentRecord.
    // Attribute their recorded paidAmount to the rental start date only, avoiding
    // the old bug where one old rental could be counted in every later month.
    final legacyPaid = vehicleRentals
        .where(
          (r) =>
              !payments.any((p) => p.rentalId == r.id) &&
              !r.startAt.isBefore(start) &&
              !r.startAt.isAfter(end),
        )
        .fold(0.0, (s, r) => s + r.paidAmount);
    final collected = rentalPayments + legacyPaid;
    final expenses = ledgerExpenses + fuelExpense + maintenanceExpense;
    final income = directIncome + collected;
    // Historical outstanding is calculated as of the selected period end,
    // rather than using today's balance for an old report.
    double outstanding = 0;
    for (final r in rentals.where(
      (r) =>
          r.vehicleId == vehicleId &&
          r.status != RentalStatus.cancelled &&
          !r.startAt.isAfter(end),
    )) {
      final recordedPayments = payments
          .where((p) => p.rentalId == r.id && !p.date.isAfter(end))
          .fold(0.0, (s, p) => s + p.amount);
      final paidAsOfEnd = payments.any((p) => p.rentalId == r.id)
          ? recordedPayments
          : r.paidAmount;
      outstanding += (r.totalPayable - paidAsOfEnd)
          .clamp(0, double.infinity)
          .toDouble();
    }
    return VehiclePeriodReport(
      vehicle: vs,
      from: start,
      to: end,
      rentalCount: vehicleRentals.length,
      rentalBilled: rentalBilled,
      rentalCollected: collected,
      otherIncome: directIncome,
      ledgerExpenses: ledgerExpenses,
      fuelExpense: fuelExpense,
      maintenanceExpense: maintenanceExpense,
      income: income,
      expenses: expenses,
      net: income - expenses,
      outstanding: outstanding,
      fuelLitres: fuelRecords.fold(0.0, (s, f) => s + f.litres),
      serviceCount: maintenanceRecords.length,
    );
  }

  String exportVehiclePeriodCsv(String vehicleId, DateTime from, DateTime to) {
    final r = vehiclePeriodReport(vehicleId, from, to);
    final v = r.vehicle;
    final rows = <List<String>>[
      ['Hafeez Rent A Car - Vehicle Performance Report'],
      ['Vehicle', v?.name ?? 'Vehicle', 'Plate', v?.plate ?? ''],
      [
        'Period',
        DateFormat('dd MMM yyyy').format(r.from),
        'to',
        DateFormat('dd MMM yyyy').format(r.to),
      ],
      [],
      ['Metric', 'Amount'],
      ['Rental billed', r.rentalBilled.toStringAsFixed(2)],
      ['Rental collected', r.rentalCollected.toStringAsFixed(2)],
      ['Other income', r.otherIncome.toStringAsFixed(2)],
      ['Total income', r.income.toStringAsFixed(2)],
      ['Ledger expenses', r.ledgerExpenses.toStringAsFixed(2)],
      ['Fuel expense', r.fuelExpense.toStringAsFixed(2)],
      ['Maintenance expense', r.maintenanceExpense.toStringAsFixed(2)],
      ['Total expenses', r.expenses.toStringAsFixed(2)],
      ['Net result', r.net.toStringAsFixed(2)],
      [
        'Current outstanding (included rentals)',
        r.outstanding.toStringAsFixed(2),
      ],
      [],
      ['Operational metric', 'Value'],
      ['Rentals', r.rentalCount.toString()],
      ['Fuel litres', r.fuelLitres.toStringAsFixed(2)],
      ['Service records', r.serviceCount.toString()],
    ];
    String q(String x) => '"${x.replaceAll('"', '""')}"';
    return rows.map((row) => row.map(q).join(',')).join('\n');
  }

  Map<String, double> vehicleExpenseBreakdown(
    String vehicleId,
    DateTime from,
    DateTime to,
  ) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    bool inRange(DateTime d) => !d.isBefore(start) && !d.isAfter(end);
    final ledger = entries
        .where(
          (e) =>
              e.vehicleId == vehicleId &&
              e.type == EntryType.expense &&
              inRange(e.date),
        )
        .fold(0.0, (s, e) => s + e.amount);
    final fuelCost = fuel
        .where((f) => f.vehicleId == vehicleId && inRange(f.date))
        .fold(0.0, (s, f) => s + f.amount);
    final maintenanceCost = maintenance
        .where((m) => m.vehicleId == vehicleId && inRange(m.date))
        .fold(0.0, (s, m) => s + m.cost);
    return {
      'Fuel': fuelCost,
      'Maintenance': maintenanceCost,
      'Other expenses': ledger,
    };
  }

  List<Map<String, dynamic>> vehicleMonthlyTrend(
    String vehicleId,
    DateTime from,
    DateTime to,
  ) {
    final out = <Map<String, dynamic>>[];
    var cursor = DateTime(from.year, from.month, 1);
    final last = DateTime(to.year, to.month, 1);
    while (!cursor.isAfter(last)) {
      final next = DateTime(cursor.year, cursor.month + 1, 1);
      final end = next.subtract(const Duration(milliseconds: 1));
      final a = cursor.isBefore(from) ? from : cursor;
      final b = end.isAfter(to) ? to : end;
      final r = vehiclePeriodReport(vehicleId, a, b);
      out.add({
        'label': DateFormat('MMM yy').format(cursor),
        'income': r.income,
        'expense': r.expenses,
        'net': r.net,
      });
      cursor = next;
    }
    return out;
  }

  String exportVehicleComparisonCsv(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    final rows = <List<String>>[
      ['Hafeez Rent A Car - Fleet Vehicle Comparison'],
      [
        'Period',
        DateFormat('dd MMM yyyy').format(start),
        'to',
        DateFormat('dd MMM yyyy').format(end),
      ],
      [],
      [
        'Vehicle',
        'Plate',
        'Rentals',
        'Rental Billed',
        'Rental Collected',
        'Other Income',
        'Total Income',
        'Fuel Expense',
        'Maintenance',
        'Other Expenses',
        'Total Expenses',
        'Net Result',
        'Outstanding',
        'Fuel Litres',
        'Services',
      ],
    ];
    for (final v in vehicles) {
      final r = vehiclePeriodReport(v.id, start, end);
      rows.add([
        v.name,
        v.plate,
        r.rentalCount.toString(),
        r.rentalBilled.toStringAsFixed(2),
        r.rentalCollected.toStringAsFixed(2),
        r.otherIncome.toStringAsFixed(2),
        r.income.toStringAsFixed(2),
        r.fuelExpense.toStringAsFixed(2),
        r.maintenanceExpense.toStringAsFixed(2),
        r.ledgerExpenses.toStringAsFixed(2),
        r.expenses.toStringAsFixed(2),
        r.net.toStringAsFixed(2),
        r.outstanding.toStringAsFixed(2),
        r.fuelLitres.toStringAsFixed(2),
        r.serviceCount.toString(),
      ]);
    }
    String q(String x) => '"${x.replaceAll('"', '""')}"';
    return rows.map((row) => row.map(q).join(',')).join('\n');
  }

  String exportLedgerCsv() {
    final rows = <List<String>>[
      [
        'Entry ID',
        'Date',
        'Type',
        'Category',
        'Vehicle',
        'Source',
        'Amount',
        'Note',
      ],
    ];
    for (final e in entries) {
      rows.add([
        e.id,
        e.date.toIso8601String(),
        enumName(e.type),
        e.category,
        e.vehicleId == null ? '' : (vehicle(e.vehicleId!)?.name ?? ''),
        e.source == null ? '' : enumName(e.source!),
        e.amount.toStringAsFixed(2),
        e.note,
      ]);
    }
    String q(String v) => '"${v.replaceAll('\"', '\"\"')}"';
    return rows.map((row) => row.map(q).join(',')).join('\n');
  }

  Future<void> addMaintenance(MaintenanceRecord r) async {
    requireCapability('fleet');
    if (r.vehicleId.trim().isEmpty)
      throw const FormatException('Select a vehicle.');
    if (!r.cost.isFinite || r.cost <= 0)
      throw const FormatException(
        'Maintenance cost must be greater than zero.',
      );
    if (r.mileage < 0)
      throw const FormatException('Mileage cannot be negative.');
    maintenance = [...maintenance, r];
    await persist();
  }

  Future<void> addFuel(FuelRecord r) async {
    requireCapability('fleet');
    if (r.vehicleId.trim().isEmpty)
      throw const FormatException('Select a vehicle.');
    if (!r.amount.isFinite || r.amount <= 0)
      throw const FormatException('Fuel amount must be greater than zero.');
    if (!r.litres.isFinite || r.litres <= 0)
      throw const FormatException('Fuel litres must be greater than zero.');
    if (r.mileage < 0)
      throw const FormatException('Mileage cannot be negative.');
    fuel = [...fuel, r];
    vehicles = vehicles
        .map(
          (v) => v.id == r.vehicleId
              ? v.copyWith(
                  currentMileage: r.mileage > v.currentMileage
                      ? r.mileage
                      : v.currentMileage,
                )
              : v,
        )
        .toList();
    await persist();
  }

  Future<void> addDriver(Map<String, dynamic> x) async {
    requireCapability('drivers');
    final name = '${x['name'] ?? ''}'.trim();
    if (name.isEmpty) throw const FormatException('Driver name is required.');
    final license = '${x['license'] ?? ''}'.trim();
    if (license.isNotEmpty &&
        drivers.any(
          (d) => d.licenseNumber.toLowerCase() == license.toLowerCase(),
        ))
      throw const FormatException(
        'This driving license is already assigned to another driver.',
      );
    final vehicleId = '${x['vehicleId'] ?? ''}';
    if (vehicleId.isNotEmpty &&
        drivers.any((d) => d.vehicleId == vehicleId && d.active))
      throw const FormatException(
        'This vehicle is already assigned to an active driver.',
      );
    drivers = [
      ...drivers,
      Driver(
        id: uuid.v4(),
        name: name,
        phone: '${x['phone'] ?? ''}'.trim(),
        cnic: '${x['cnic'] ?? ''}'.trim(),
        licenseNumber: license,
        licenseExpiry: x['expiry'],
        address: '${x['address'] ?? ''}'.trim(),
        note: '${x['note'] ?? ''}'.trim(),
        vehicleId: vehicleId,
        salary: (x['salary'] as num?)?.toDouble() ?? 0,
        commissionRate: (x['commission'] as num?)?.toDouble() ?? 0,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    await persist();
  }

  Future<void> updateDriver(Driver old, Map<String, dynamic> x) async {
    requireCapability('drivers');
    final name = '${x['name'] ?? ''}'.trim();
    if (name.isEmpty) throw const FormatException('Driver name is required.');
    final license = '${x['license'] ?? ''}'.trim();
    if (license.isNotEmpty &&
        drivers.any(
          (d) =>
              d.id != old.id &&
              d.licenseNumber.toLowerCase() == license.toLowerCase(),
        ))
      throw const FormatException(
        'This driving license is already assigned to another driver.',
      );
    final vehicleId = '${x['vehicleId'] ?? ''}';
    if (vehicleId.isNotEmpty &&
        drivers.any(
          (d) => d.id != old.id && d.vehicleId == vehicleId && d.active,
        ))
      throw const FormatException(
        'This vehicle is already assigned to an active driver.',
      );
    drivers = drivers
        .map(
          (d) => d.id == old.id
              ? d.copyWith(
                  name: name,
                  phone: '${x['phone'] ?? ''}'.trim(),
                  cnic: '${x['cnic'] ?? ''}'.trim(),
                  licenseNumber: license,
                  licenseExpiry: x['expiry'],
                  address: '${x['address'] ?? ''}'.trim(),
                  note: '${x['note'] ?? ''}'.trim(),
                  vehicleId: vehicleId,
                  salary: (x['salary'] as num?)?.toDouble() ?? 0,
                  commissionRate: (x['commission'] as num?)?.toDouble() ?? 0,
                  active: x['active'] is bool ? x['active'] as bool : true,
                  updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                )
              : d,
        )
        .toList();
    await persist();
  }

  Future<void> deleteDriver(Driver d) async {
    requireCapability('drivers');
    drivers = drivers.where((x) => x.id != d.id).toList();
    await persist();
  }

  Future<void> signIn(String email, String password) async {
    if (!firebaseReady) throw Exception('Firebase is not configured yet.');
    final u = (await AuthService().signIn(email.trim(), password)).user;
    if (u == null) throw const FormatException('Sign-in failed.');
    user = u;
    await store.setOwnerId(u.uid);
    final savedRole = await store.role();
    role = AdminRole.values.firstWhere(
      (x) => enumName(x) == savedRole,
      orElse: () => AdminRole.owner,
    );
    await reloadLocal();
    try {
      final b = await cloud.pullBusiness(u.uid);
      customers = b.customers;
      rentals = b.rentals;
      maintenance = b.maintenance;
      fuel = b.fuel;
      drivers = b.drivers;
      payments = b.payments;
      settlements = b.settlements;
      inspections = b.inspections;
      settings = b.settings;
      audits = b.audits;
      await saveAll();
    } catch (_) {
      message = 'Cloud business data unavailable; local data is safe.';
    }
    notifyListeners();
  }

  Future<void> signUp(String email, String password) async {
    if (!firebaseReady) throw Exception('Firebase is not configured yet.');
    final u = (await AuthService().signUp(email.trim(), password)).user;
    if (u == null) throw const FormatException('Account creation failed.');
    user = u;
    await store.setOwnerId(u.uid);
    role = AdminRole.owner;
    await store.saveRole(role.name);
    await reloadLocal();
    await persist();
  }

  Future<void> signOut() async {
    if (firebaseReady) await AuthService().signOut();
    user = null;
    await store.setOwnerId('local');
    await reloadLocal();
    notifyListeners();
  }

  Future<void> refreshCloud() async {
    if (user == null) throw const FormatException('Sign in first.');
    final r = await cloud.pull(user!.uid);
    final b = await cloud.pullBusiness(user!.uid);
    deletedEntryIds = {...deletedEntryIds, ...r.deleted};
    final vm = <String, Vehicle>{for (final x in r.vehicles) x.id: x};
    for (final x in vehicles) {
      final old = vm[x.id];
      if (old == null || x.updatedAtMs >= old.updatedAtMs) vm[x.id] = x;
    }
    final em = <String, LedgerEntry>{for (final x in r.entries) x.id: x};
    for (final x in entries) {
      if (!deletedEntryIds.contains(x.id)) {
        final old = em[x.id];
        if (old == null || x.updatedAtMs >= old.updatedAtMs) em[x.id] = x;
      }
    }
    Map<String, T> mergeBusiness<T>(
      List<T> local,
      List<T> remote,
      String Function(T) id,
      int Function(T) time,
    ) {
      final map = <String, T>{for (final x in remote) id(x): x};
      for (final x in local) {
        final old = map[id(x)];
        if (old == null || time(x) >= time(old)) map[id(x)] = x;
      }
      return map;
    }

    customers = mergeBusiness(
      customers,
      b.customers,
      (x) => x.id,
      (x) => x.updatedAtMs,
    ).values.toList();
    rentals = mergeBusiness(
      rentals,
      b.rentals,
      (x) => x.id,
      (x) => x.updatedAtMs,
    ).values.toList();
    maintenance = mergeBusiness(
      maintenance,
      b.maintenance,
      (x) => x.id,
      (x) => x.updatedAtMs,
    ).values.toList();
    fuel = mergeBusiness(
      fuel,
      b.fuel,
      (x) => x.id,
      (x) => x.updatedAtMs,
    ).values.toList();
    drivers = mergeBusiness(
      drivers,
      b.drivers,
      (x) => x.id,
      (x) => x.updatedAtMs,
    ).values.toList();
    payments = mergeBusiness(
      payments,
      b.payments,
      (x) => x.id,
      (x) => x.updatedAtMs,
    ).values.toList();
    settlements = mergeBusiness(
      settlements,
      b.settlements,
      (x) => x.id,
      (x) => x.updatedAtMs,
    ).values.toList();
    inspections = mergeBusiness(
      inspections,
      b.inspections,
      (x) => x.id,
      (x) => x.updatedAtMs,
    ).values.toList();
    if (b.settings.updatedAtMs >= settings.updatedAtMs) settings = b.settings;
    audits = mergeBusiness(
      audits,
      b.audits,
      (x) => x.id,
      (x) => x.updatedAtMs,
    ).values.toList()..sort((a, b) => b.date.compareTo(a.date));
    vehicles = vm.values.toList();
    entries = em.values.where((e) => !deletedEntryIds.contains(e.id)).toList();
    await saveAll();
    await cloud.pushBusiness(
      user!.uid,
      customers,
      rentals,
      maintenance,
      fuel,
      drivers,
      payments,
      settlements,
      inspections,
      settings: settings,
      audits: audits.take(300).toList(),
    );
    message = 'Cloud data refreshed';
    notifyListeners();
  }

  bool can(String capability) {
    switch (role) {
      case AdminRole.owner:
        return true;
      case AdminRole.manager:
        return capability != 'settings';
      case AdminRole.accountant:
        return capability == 'payments' ||
            capability == 'reports' ||
            capability == 'settlements' ||
            capability == 'ledger';
      case AdminRole.operator:
        return capability == 'rentals' ||
            capability == 'customers' ||
            capability == 'drivers' ||
            capability == 'fleet';
      case AdminRole.viewer:
        return capability == 'reports';
    }
  }

  void requireCapability(String capability) {
    if (!can(capability))
      throw FormatException(
        'Your ${role.name} role does not have permission for this action.',
      );
  }

  Future<void> saveSettings(BusinessSettings next) async {
    settings = next.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await persist();
  }

  Future<void> addAudit(String action, String entity, String details) async {
    final now = DateTime.now();
    audits = [
      AuditLog(
        id: uuid.v4(),
        action: action,
        entity: entity,
        details: details,
        actorEmail: user?.email ?? 'Local Admin',
        date: now,
        updatedAtMs: now.millisecondsSinceEpoch,
      ),
      ...audits,
    ].take(500).toList();
    await store.saveAudits(audits);
  }

  Future<String> exportBackup() => store.exportJson();
  Future<void> importBackup(String json) async {
    await store.importJson(json);
    await reloadLocal();
    message = 'Backup restored locally';
    notifyListeners();
  }
}

class HafeezRentApp extends StatefulWidget {
  final bool firebaseReady;
  const HafeezRentApp({super.key, required this.firebaseReady});
  @override
  State<HafeezRentApp> createState() => _HafeezRentAppState();
}

class _HafeezRentAppState extends State<HafeezRentApp> {
  final c = AppController();
  @override
  void initState() {
    super.initState();
    c.firebaseReady = widget.firebaseReady;
    c.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: c.dark ? ThemeMode.dark : ThemeMode.light,
      theme: HrcTheme.light(),
      darkTheme: HrcTheme.darkTheme(),
      home: c.loading ? const Splash() : Home(c: c),
    ),
  );
}

class Splash extends StatelessWidget {
  const Splash({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class Home extends StatefulWidget {
  final AppController c;
  const Home({super.key, required this.c});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  static const titles = [
    'Executive Overview',
    'Fleet Management',
    'Driver Management',
    'Customers',
    'Rental Operations',
    'Operations',
    'Business Reports',
    'Document Center',
  ];
  static const icons = [
    Icons.space_dashboard_rounded,
    Icons.directions_car_rounded,
    Icons.badge_rounded,
    Icons.people_alt_rounded,
    Icons.assignment_rounded,
    Icons.build_circle_rounded,
    Icons.analytics_rounded,
    Icons.description_rounded,
  ];

  void select(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(c: widget.c),
      Vehicles(c: widget.c),
      Drivers(c: widget.c),
      Customers(c: widget.c),
      Rentals(c: widget.c),
      Operations(c: widget.c),
      Reports(c: widget.c),
      DocumentCenter(c: widget.c),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: wide ? 24 : 16,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: HrcTheme.ink,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: HrcTheme.gold.withOpacity(.18),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Image.asset('assets/app_icon.png'),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HAFEEZ RENT A CAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  titles[tab],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 14,
                  color: HrcTheme.gold,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.c.role.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6,
                  ),
                ),
              ],
            ),
          ),
          if (widget.c.user != null)
            IconButton(
              tooltip: 'Sync cloud data',
              onPressed: () async {
                try {
                  await widget.c.refreshCloud();
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
              icon: const Icon(Icons.cloud_sync_rounded),
            ),
          IconButton(
            tooltip: 'Notifications & alerts',
            onPressed: () => showAlerts(context, widget.c),
            icon: Badge(
              isLabelVisible: widget.c.overdueRentals > 0,
              label: Text('${widget.c.overdueRentals}'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Theme',
            onPressed: () => setState(() => widget.c.dark = !widget.c.dark),
            icon: Icon(
              widget.c.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Administration',
            onSelected: (v) async {
              if (v == 'account') await showAccount(context, widget.c);
              if (v == 'settings')
                await showBusinessSettings(context, widget.c);
              if (v == 'roles') await showRoles(context, widget.c);
              if (v == 'audit') await showAuditLog(context, widget.c);
              if (v == 'backup') await showBackup(context, widget.c);
              if (v == 'alerts') await showAlerts(context, widget.c);
              if (v == 'about') await showSystemInfo(context, widget.c);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'account', child: Text('Cloud Account')),
              PopupMenuItem(
                value: 'settings',
                child: Text('Business Settings'),
              ),
              PopupMenuItem(
                value: 'roles',
                child: Text('Admin Roles & Permissions'),
              ),
              PopupMenuItem(value: 'audit', child: Text('Audit Log')),
              PopupMenuItem(value: 'backup', child: Text('Backup / Restore')),
              PopupMenuItem(value: 'alerts', child: Text('Alerts & Expiry')),
              PopupMenuItem(value: 'about', child: Text('System Information')),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(
        children: [
          if (wide) _sideNav(context),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: SizedBox(
                    width: double.infinity,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey(tab),
                        child: pages[tab],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: select,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.directions_car_outlined),
                  selectedIcon: Icon(Icons.directions_car_rounded),
                  label: 'Fleet',
                ),
                NavigationDestination(
                  icon: Icon(Icons.badge_outlined),
                  selectedIcon: Icon(Icons.badge_rounded),
                  label: 'Drivers',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline_rounded),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: 'Clients',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment_rounded),
                  label: 'Rentals',
                ),
                NavigationDestination(
                  icon: Icon(Icons.build_circle_outlined),
                  selectedIcon: Icon(Icons.build_circle_rounded),
                  label: 'Ops',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics_rounded),
                  label: 'Reports',
                ),
                NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  selectedIcon: Icon(Icons.description_rounded),
                  label: 'Docs',
                ),
              ],
            ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              backgroundColor: HrcTheme.ink,
              foregroundColor: Colors.white,
              onPressed: () => showEntry(context, widget.c),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New transaction',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .1,
                ),
              ),
            )
          : null,
    );
  }

  Widget _sideNav(BuildContext context) => Container(
    width: 248,
    margin: const EdgeInsets.fromLTRB(16, 0, 0, 16),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: HrcTheme.ink,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Image.asset('assets/app_icon.png'),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTROL CENTER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Fleet operations suite',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < titles.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              selected: tab == i,
              selectedTileColor: HrcTheme.gold.withOpacity(.12),
              leading: Icon(
                icons[i],
                size: 20,
                color: tab == i ? HrcTheme.gold : null,
              ),
              title: Text(
                titles[i].replaceFirst('Executive ', ''),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: tab == i ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
              onTap: () => select(i),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                widget.c.user == null
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_done_rounded,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.c.user == null ? 'Offline-ready' : 'Cloud connected',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class DocumentCenter extends StatefulWidget {
  final AppController c;
  const DocumentCenter({super.key, required this.c});
  @override
  State<DocumentCenter> createState() => _DocumentCenterState();
}

class _DocumentCenterState extends State<DocumentCenter> {
  String q = '';
  String type = 'All';
  @override
  Widget build(BuildContext context) {
    final rentals = widget.c.rentals.where((r) {
      final cu = widget.c.customer(r.customerId);
      final v = widget.c.vehicle(r.vehicleId);
      final hay = '${r.id} ${cu?.name ?? ''} ${v?.name ?? ''} ${v?.plate ?? ''}'
          .toLowerCase();
      return hay.contains(q.toLowerCase());
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _moduleHeader(
          context,
          'Document Center',
          'Professional agreements, receipts and rental settlement documents',
          'Business Settings',
          Icons.description_rounded,
          () => showBusinessSettings(context, widget.c),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _miniKpi(
                context,
                'Agreements',
                '${widget.c.rentals.length}',
                Icons.description_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniKpi(
                context,
                'Receipts',
                '${widget.c.payments.length}',
                Icons.receipt_long_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniKpi(
                context,
                'Returns',
                '${widget.c.inspections.where((x) => x.stage == 'Return').length}',
                Icons.assignment_return_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _surface(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Document templates',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Generate clean, copy-ready business documents from live rental records.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _docAction(
                    context,
                    'Rental Agreement',
                    Icons.description_rounded,
                    () => rentals.isEmpty
                        ? null
                        : showRentalAgreement(context, widget.c, rentals.first),
                  ),
                  _docAction(
                    context,
                    'Payment Receipt',
                    Icons.receipt_long_rounded,
                    () => rentals.isEmpty
                        ? null
                        : showRentalReceipt(context, widget.c, rentals.first),
                  ),
                  _docAction(
                    context,
                    'Return Settlement',
                    Icons.assignment_return_rounded,
                    () => rentals.isEmpty
                        ? null
                        : showReturnSettlement(
                            context,
                            widget.c,
                            rentals.first,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search rental, customer, vehicle or plate',
          ),
        ),
        const SizedBox(height: 12),
        if (rentals.isEmpty)
          _emptyCard(
            context,
            Icons.description_outlined,
            'No rental records',
            'Create a rental first to generate business documents.',
          ),
        ...rentals.map((r) {
          final cu = widget.c.customer(r.customerId);
          final v = widget.c.vehicle(r.vehicleId);
          final pays = widget.c.payments
              .where((p) => p.rentalId == r.id)
              .toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: _surface(context),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: HrcTheme.gold.withOpacity(.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: HrcTheme.gold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cu?.name ?? 'Customer',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${v?.name ?? 'Vehicle'} • ${v?.plate ?? '—'} • ${enumName(r.status)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rs ${money(r.remaining)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          showRentalAgreement(context, widget.c, r),
                      icon: const Icon(Icons.description_outlined, size: 17),
                      label: const Text('Agreement'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showRentalReceipt(context, widget.c, r),
                      icon: const Icon(Icons.receipt_long_outlined, size: 17),
                      label: Text('Receipt (${pays.length})'),
                    ),
                    if (r.actualReturnAt != null)
                      OutlinedButton.icon(
                        onPressed: () =>
                            showReturnDocument(context, widget.c, r),
                        icon: const Icon(
                          Icons.assignment_return_outlined,
                          size: 17,
                        ),
                        label: const Text('Return Settlement'),
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _docAction(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback? onTap,
  ) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

class Dashboard extends StatelessWidget {
  final AppController c;
  const Dashboard({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIncome = c.entries
        .where((e) => e.type != EntryType.expense && !e.date.isBefore(today))
        .fold(0.0, (s, e) => s + e.amount);
    final todayExpense = c.entries
        .where((e) => e.type == EntryType.expense && !e.date.isBefore(today))
        .fold(0.0, (s, e) => s + e.amount);
    final active = c.rentals
        .where((r) => r.status == RentalStatus.active)
        .toList();
    final occupied = c.vehicles.isEmpty
        ? 0
        : ((c.vehicles.length - c.availableCars) / c.vehicles.length * 100)
              .clamp(0, 100)
              .toDouble();
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 18, wide ? 28 : 16, 110),
          children: [
            _executiveHero(context, todayIncome, active.length, occupied),
            const SizedBox(height: 20),
            _sectionTitle(
              context,
              'Business performance',
              DateFormat('EEEE, dd MMM yyyy').format(now),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: wide ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: wide ? 1.65 : 1.55,
              children: [
                _metricCard(
                  context,
                  'Today revenue',
                  'Rs ${money(todayIncome)}',
                  Icons.trending_up_rounded,
                  const Color(0xFF0E9F6E),
                ),
                _metricCard(
                  context,
                  'Today expenses',
                  'Rs ${money(todayExpense)}',
                  Icons.trending_down_rounded,
                  const Color(0xFFE05A47),
                ),
                _metricCard(
                  context,
                  'Receivables',
                  'Rs ${money(c.receivable)}',
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFF4B68D8),
                ),
                _metricCard(
                  context,
                  'Net position',
                  'Rs ${money(c.income - c.expenses)}',
                  Icons.account_balance_rounded,
                  HrcTheme.gold,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _fleetPanel(context, occupied)),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: _alertsPanel(context)),
                ],
              )
            else ...[
              _fleetPanel(context, occupied),
              const SizedBox(height: 14),
              _alertsPanel(context),
            ],
            const SizedBox(height: 20),
            _sectionTitle(context, 'Live rentals', '${active.length} active'),
            const SizedBox(height: 10),
            if (active.isEmpty)
              _emptyCard(
                context,
                Icons.event_available_rounded,
                'No active rentals',
                'Your live rental contracts will appear here.',
              )
            else
              ...active.take(5).map((r) {
                final cu = c.customer(r.customerId);
                final v = c.vehicle(r.vehicleId);
                return Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(14),
                  decoration: _surface(context),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: HrcTheme.gold.withOpacity(.11),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.key_rounded,
                          color: HrcTheme.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v?.name ?? 'Vehicle',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${cu?.name ?? 'Customer'} • ${DateFormat('dd MMM').format(r.endAt)} return',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs ${money(r.remaining)}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'outstanding',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 12),
            _sectionTitle(context, 'Quick actions', 'Common workflows'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quick(
                  context,
                  'New rental',
                  Icons.assignment_add_rounded,
                  () => showRentalDialog(context, c),
                ),
                _quick(
                  context,
                  'Payment',
                  Icons.payments_rounded,
                  () => showPaymentDialog(context, c),
                ),
                _quick(
                  context,
                  'Expense',
                  Icons.receipt_long_rounded,
                  () => showEntry(context, c, type: EntryType.expense),
                ),
                _quick(
                  context,
                  'inDrive',
                  Icons.local_taxi_rounded,
                  () => showEntry(context, c, source: EarningSource.inDrive),
                ),
                _quick(
                  context,
                  'Yango',
                  Icons.directions_car_rounded,
                  () => showEntry(context, c, source: EarningSource.yango),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _executiveHero(
    BuildContext context,
    double revenue,
    int active,
    double occupied,
  ) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [HrcTheme.ink, const Color(0xFF27303B)],
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: HrcTheme.ink.withOpacity(.18),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: HrcTheme.gold.withOpacity(.18),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Image.asset('assets/app_icon.png'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${DateTime.now().hour < 12
                    ? 'morning'
                    : DateTime.now().hour < 18
                    ? 'afternoon'
                    : 'evening'}, Hafeez',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Your fleet at a glance.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Rs ${money(revenue)} revenue today • $active live rentals',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width > 650)
          Container(
            width: 150,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FLEET OCCUPANCY',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${occupied.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: occupied / 100,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(
                      HrcTheme.goldLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _fleetPanel(BuildContext context, double occupied) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _surface(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Fleet health',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            Text(
              '${c.availableCars} available',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(
              width: 86,
              height: 86,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: occupied / 100,
                    strokeWidth: 9,
                    backgroundColor: Theme.of(
                      context,
                    ).dividerColor.withOpacity(.35),
                    valueColor: const AlwaysStoppedAnimation(HrcTheme.gold),
                  ),
                  Text(
                    '${occupied.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  _healthRow(
                    context,
                    'Available',
                    c.availableCars,
                    c.vehicles.length,
                    HrcTheme.gold,
                  ),
                  _healthRow(
                    context,
                    'Active rentals',
                    c.rentals
                        .where((r) => r.status == RentalStatus.active)
                        .length,
                    c.vehicles.length,
                    const Color(0xFF4B68D8),
                  ),
                  _healthRow(
                    context,
                    'Overdue',
                    c.overdueRentals,
                    c.rentals.length,
                    const Color(0xFFE05A47),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _healthRow(
    BuildContext context,
    String label,
    int value,
    int total,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (value / total).clamp(0, 1),
              minHeight: 7,
              backgroundColor: Theme.of(context).dividerColor.withOpacity(.25),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$value',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  Widget _alertsPanel(BuildContext context) {
    final count =
        c.overdueRentals +
        c.expiringLicenses.length +
        c.expiringVehicles.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Attention center',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Icon(
                count == 0
                    ? Icons.verified_rounded
                    : Icons.notifications_active_rounded,
                color: count == 0
                    ? const Color(0xFF0E9F6E)
                    : const Color(0xFFE05A47),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (count == 0)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF0E9F6E),
              ),
              title: Text(
                'Everything looks clear',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('No urgent fleet, license or rental alerts.'),
            )
          else ...[
            if (c.overdueRentals > 0)
              _alertRow(
                context,
                Icons.warning_amber_rounded,
                '${c.overdueRentals} overdue rental(s)',
              ),
            if (c.expiringLicenses.isNotEmpty)
              _alertRow(
                context,
                Icons.badge_rounded,
                '${c.expiringLicenses.length} license(s) expiring',
              ),
            if (c.expiringVehicles.isNotEmpty)
              _alertRow(
                context,
                Icons.description_rounded,
                '${c.expiringVehicles.length} vehicle document(s) expiring',
              ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => showAlerts(context, c),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Open alerts'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertRow(BuildContext context, IconData icon, String text) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE05A47).withOpacity(.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFFE05A47)),
        ),
        title: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      );
}

Widget _metricCard(
  BuildContext context,
  String title,
  String value,
  IconData icon,
  Color accent,
) => Container(
  padding: const EdgeInsets.all(14),
  decoration: _surface(context),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const Spacer(),
        ],
      ),
      const Spacer(),
      Text(
        title,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
      ),
    ],
  ),
);
Widget _quick(
  BuildContext context,
  String title,
  IconData icon,
  VoidCallback onTap,
) => Expanded(
  child: InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: _surface(context),
      child: Column(
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ],
      ),
    ),
  ),
);
Widget _statusPill(String status) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  decoration: BoxDecoration(
    color: const Color(0xFFE8F7EF),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    status,
    style: const TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w900,
      color: Color(0xFF138A57),
    ),
  ),
);
BoxDecoration _surface(BuildContext context) => BoxDecoration(
  color: Theme.of(context).cardColor,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.45)),
  boxShadow: const [
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
  ],
);
Widget _emptyCard(
  BuildContext context,
  IconData icon,
  String title,
  String subtitle,
) => Container(
  padding: const EdgeInsets.all(22),
  decoration: _surface(context),
  child: Row(
    children: [
      Icon(icon, size: 30),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);

class Vehicles extends StatefulWidget {
  final AppController c;
  const Vehicles({super.key, required this.c});
  @override
  State<Vehicles> createState() => _VehiclesState();
}

class _VehiclesState extends State<Vehicles> {
  String q = '';
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final list = widget.c.vehicles.where((v) {
      final hay = '${v.name} ${v.plate} ${v.model}'.toLowerCase();
      final match = hay.contains(q.toLowerCase());
      final f = filter == 'All' || enumName(v.status) == filter;
      return match && f;
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _moduleHeader(
          context,
          'Fleet',
          'Vehicle portfolio, availability, compliance and profitability',
          'Add vehicle',
          Icons.directions_car_rounded,
          () => showVehicleDialog(context, widget.c),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _miniKpi(
                context,
                'Available',
                '${widget.c.availableCars}',
                Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniKpi(
                context,
                'On rent',
                '${widget.c.rentals.where((r) => r.status == RentalStatus.active).length}',
                Icons.key_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniKpi(
                context,
                'Total fleet',
                '${widget.c.vehicles.length}',
                Icons.directions_car_filled_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search vehicle, plate or model',
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 155,
              child: DropdownButtonFormField<String>(
                initialValue: filter,
                items: ['All', ...VehicleStatus.values.map(enumName)]
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (v) => setState(() => filter = v ?? 'All'),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          _emptyCard(
            context,
            Icons.search_off_rounded,
            'No matching vehicles',
            'Try another search or status filter.',
          ),
        ...list.map(
          (v) => InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showVehicleDetails(context, widget.c, v),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _surface(context),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF7F4EE), Color(0xFFE7DED0)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_rounded,
                      size: 38,
                      color: Color(0xFF987438),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                v.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            _statusPill(enumName(v.status)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${v.model.isEmpty ? 'Vehicle' : v.model}${v.year.isEmpty ? '' : ' • ${v.year}'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              v.plate.isEmpty ? 'Plate not set' : v.plate,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Net Rs ${money(widget.c.vehicleIncome(v.id) - widget.c.vehicleExpense(v.id))}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (x) async {
                      if (x == 'details')
                        await showVehicleDetails(context, widget.c, v);
                      if (x == 'edit')
                        await showVehicleDialog(context, widget.c, existing: v);
                      if (x == 'status')
                        await showVehicleStatus(context, widget.c, v);
                      if (x == 'delete') {
                        try {
                          if (await confirm(
                            context,
                            'Delete vehicle?',
                            'Vehicle records are protected.',
                          ))
                            await widget.c.deleteVehicle(v);
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'details',
                        child: Text('Vehicle profile'),
                      ),
                      PopupMenuItem(value: 'edit', child: Text('Edit vehicle')),
                      PopupMenuItem(
                        value: 'status',
                        child: Text('Change status'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _moduleHeader(
  BuildContext context,
  String title,
  String subtitle,
  String action,
  IconData icon,
  VoidCallback onPressed,
) {
  return Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Theme.of(context).colorScheme.surface,
          Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(.55),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Theme.of(context).dividerColor.withOpacity(.55),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: HrcTheme.ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: HrcTheme.gold, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(action),
        ),
      ],
    ),
  );
}

Widget _miniKpi(
  BuildContext context,
  String title,
  String value,
  IconData icon,
) => Container(
  padding: const EdgeInsets.all(12),
  decoration: _surface(context),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18),
      const SizedBox(height: 10),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      Text(
        title,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  ),
);

class Drivers extends StatefulWidget {
  final AppController c;
  const Drivers({super.key, required this.c});
  @override
  State<Drivers> createState() => _DriversState();
}

class _DriversState extends State<Drivers> {
  String q = '';
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final list = widget.c.drivers.where((d) {
      final hay = '${d.name} ${d.phone} ${d.cnic} ${d.licenseNumber}'
          .toLowerCase();
      return hay.contains(q.toLowerCase()) &&
          (filter == 'All' || (filter == 'Active' ? d.active : !d.active));
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _moduleHeader(
          context,
          'Drivers',
          'Driver profiles, assignments, licenses and settlements',
          'Add driver',
          Icons.badge_rounded,
          () => showDriverDialog(context, widget.c),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _miniKpi(
                context,
                'Active',
                '${widget.c.drivers.where((d) => d.active).length}',
                Icons.verified_user_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniKpi(
                context,
                'Assigned',
                '${widget.c.drivers.where((d) => d.active && d.vehicleId.isNotEmpty).length}',
                Icons.link_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniKpi(
                context,
                'Unassigned',
                '${widget.c.drivers.where((d) => d.active && d.vehicleId.isEmpty).length}',
                Icons.person_off_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search driver, phone, CNIC or license',
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 135,
              child: DropdownButtonFormField<String>(
                initialValue: filter,
                items: const ['All', 'Active', 'Inactive']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (v) => setState(() => filter = v ?? 'All'),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          _emptyCard(
            context,
            Icons.search_off_rounded,
            'No matching drivers',
            'Try another search or status filter.',
          ),
        ...list.map((d) {
          final v = d.vehicleId.isEmpty ? null : widget.c.vehicle(d.vehicleId);
          final exp = d.licenseExpiry;
          final expiring =
              exp != null &&
              exp.isBefore(DateTime.now().add(const Duration(days: 30)));
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: _surface(context),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EEE7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.badge_rounded,
                    color: Color(0xFF987438),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          _tinyTag(d.active ? 'Active' : 'Inactive'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.phone.isEmpty ? 'Phone not set' : d.phone,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        v == null
                            ? 'No vehicle assigned'
                            : '${v.name} • ${v.plate.isEmpty ? 'No plate' : v.plate}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (exp != null)
                        Text(
                          'License ${DateFormat('dd MMM yyyy').format(exp)}${expiring ? ' • Expiring soon' : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: expiring
                                ? const Color(0xFFC04A37)
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (x) async {
                    if (x == 'edit')
                      await showDriverDialog(context, widget.c, existing: d);
                    if (x == 'settle')
                      await showDriverSettlementDialog(context, widget.c, d);
                    if (x == 'delete' &&
                        await confirm(
                          context,
                          'Delete driver?',
                          'The driver record will be removed.',
                        ))
                      await widget.c.deleteDriver(d);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit driver')),
                    PopupMenuItem(
                      value: 'settle',
                      child: Text('Create settlement'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class Customers extends StatefulWidget {
  final AppController c;
  const Customers({super.key, required this.c});
  @override
  State<Customers> createState() => _CustomersState();
}

class _CustomersState extends State<Customers> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = cust(widget.c, q);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        _moduleHeader(
          context,
          'Customers',
          'Customer profiles, compliance, rental history and balances',
          'Add customer',
          Icons.people_alt_rounded,
          () => showCustomerDialog(context, widget.c),
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search name, phone or CNIC',
          ),
        ),
        const SizedBox(height: 14),
        ...list.map((x) {
          final rs = widget.c.rentals
              .where((r) => r.customerId == x.id)
              .toList();
          final active = rs
              .where((r) => r.status == RentalStatus.active)
              .length;
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showCustomerDetails(context, widget.c, x),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _surface(context),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFF1ECE2),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF8F6D34),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          x.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          x.phone.isEmpty ? 'No phone' : x.phone,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            _tinyTag('${rs.length} rentals'),
                            const SizedBox(width: 6),
                            if (active > 0) _tinyTag('$active active'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

Widget _tinyTag(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  decoration: BoxDecoration(
    color: const Color(0xFFF4F1EA),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    text,
    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
  ),
);
List<Customer> cust(AppController c, String q) => c.customers
    .where(
      (x) => '${x.name} ${x.phone} ${x.cnic}'.toLowerCase().contains(
        q.toLowerCase(),
      ),
    )
    .toList();

class Rentals extends StatefulWidget {
  final AppController c;
  const Rentals({super.key, required this.c});
  @override
  State<Rentals> createState() => _RentalsState();
}

class _RentalsState extends State<Rentals> {
  String q = '';
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final list = [...widget.c.rentals]
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    final filtered = list.where((r) {
      final cu = widget.c.customer(r.customerId),
          v = widget.c.vehicle(r.vehicleId);
      final hay = '${cu?.name ?? ''} ${v?.name ?? ''} ${v?.plate ?? ''} ${r.id}'
          .toLowerCase();
      return hay.contains(q.toLowerCase()) &&
          (filter == 'All' || enumName(r.status) == filter);
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _moduleHeader(
          context,
          'Rentals',
          'Bookings, payments, balances, agreements and returns',
          'New rental',
          Icons.assignment_rounded,
          () => showRentalDialog(context, widget.c),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _miniKpi(
                context,
                'Active',
                '${widget.c.activeRentals}',
                Icons.key_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniKpi(
                context,
                'Overdue',
                '${widget.c.overdueRentals}',
                Icons.warning_amber_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniKpi(
                context,
                'Receivable',
                'Rs ${money(widget.c.receivable)}',
                Icons.account_balance_wallet_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search customer, vehicle or rental ID',
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 145,
              child: DropdownButtonFormField<String>(
                initialValue: filter,
                items: ['All', ...RentalStatus.values.map(enumName)]
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (v) => setState(() => filter = v ?? 'All'),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          _emptyCard(
            context,
            Icons.search_off_rounded,
            'No matching rentals',
            'Try another search or status filter.',
          ),
        ...filtered.map((r) {
          final cu = widget.c.customer(r.customerId);
          final v = widget.c.vehicle(r.vehicleId);
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showRentalDetails(context, widget.c, r),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _surface(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: r.status == RentalStatus.active
                              ? const Color(0xFFEAF3FF)
                              : const Color(0xFFF3F1EC),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          r.status == RentalStatus.active
                              ? Icons.key_rounded
                              : Icons.assignment_turned_in_rounded,
                          color: r.status == RentalStatus.active
                              ? const Color(0xFF4169C7)
                              : const Color(0xFF7A684E),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v?.name ?? 'Vehicle',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              cu?.name ?? 'Customer',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rs ${money(r.totalPayable)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _tinyTag(enumName(r.status)),
                      const SizedBox(width: 7),
                      Text(
                        '${DateFormat('dd MMM').format(r.startAt)} → ${DateFormat('dd MMM').format(r.endAt)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (r.remaining > 0)
                        Text(
                          'Due Rs ${money(r.remaining)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB04A37),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class Operations extends StatefulWidget {
  final AppController c;
  const Operations({super.key, required this.c});
  @override
  State<Operations> createState() => _OperationsState();
}

class _OperationsState extends State<Operations> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Maintenance'),
                icon: Icon(Icons.build),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Fuel'),
                icon: Icon(Icons.local_gas_station),
              ),
            ],
            selected: {tab},
            onSelectionChanged: (s) => setState(() => tab = s.first),
          ),
        ),
        Expanded(
          child: tab == 0
              ? MaintenanceView(c: widget.c)
              : FuelView(c: widget.c),
        ),
      ],
    );
  }
}

class MaintenanceView extends StatelessWidget {
  final AppController c;
  const MaintenanceView({super.key, required this.c});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () => showMaintenanceDialog(context, c),
          icon: const Icon(Icons.add),
          label: const Text('Add service'),
        ),
      ),
      ...c.maintenance.map((m) {
        final v = c.vehicle(m.vehicleId);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.build),
            title: Text('${v?.name ?? 'Vehicle'} • ${m.type}'),
            subtitle: Text(
              '${DateFormat('dd MMM yyyy').format(m.date)} • ${m.workshop}\nNext: ${DateFormat('dd MMM yyyy').format(m.nextService)}',
            ),
            isThreeLine: true,
            trailing: Text(
              'Rs ${money(m.cost)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      }),
    ],
  );
}

class FuelView extends StatelessWidget {
  final AppController c;
  const FuelView({super.key, required this.c});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () => showFuelDialog(context, c),
          icon: const Icon(Icons.add),
          label: const Text('Add fuel'),
        ),
      ),
      ...c.fuel.map((f) {
        final v = c.vehicle(f.vehicleId);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.local_gas_station),
            title: Text(v?.name ?? 'Vehicle'),
            subtitle: Text(
              '${DateFormat('dd MMM yyyy').format(f.date)} • ${money(f.litres)} L • ${f.station}',
            ),
            trailing: Text(
              'Rs ${money(f.amount)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      }),
    ],
  );
}

class VehiclePeriodReport {
  final Vehicle? vehicle;
  final DateTime from, to;
  final int rentalCount, serviceCount;
  final double rentalBilled,
      rentalCollected,
      otherIncome,
      ledgerExpenses,
      fuelExpense,
      maintenanceExpense,
      income,
      expenses,
      net,
      outstanding,
      fuelLitres;
  const VehiclePeriodReport({
    required this.vehicle,
    required this.from,
    required this.to,
    required this.rentalCount,
    required this.serviceCount,
    required this.rentalBilled,
    required this.rentalCollected,
    required this.otherIncome,
    required this.ledgerExpenses,
    required this.fuelExpense,
    required this.maintenanceExpense,
    required this.income,
    required this.expenses,
    required this.net,
    required this.outstanding,
    required this.fuelLitres,
  });
}

class Reports extends StatelessWidget {
  final AppController c;
  const Reports({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    final net = c.income - c.expenses;
    final maxY =
        [
          c.income,
          c.expenses,
          c.rentalRevenue,
          1.0,
        ].reduce((a, b) => a > b ? a : b) *
        1.2;
    final paymentTotal = c.payments.fold(0.0, (s, p) => s + p.amount);
    final ledgerIncome = c.entries
        .where((e) => e.type != EntryType.expense)
        .fold(0.0, (s, e) => s + e.amount);
    final ledgerExpense = c.entries
        .where((e) => e.type == EntryType.expense)
        .fold(0.0, (s, e) => s + e.amount);
    final orphanRentals = c.rentals
        .where(
          (r) =>
              c.customer(r.customerId) == null ||
              c.vehicle(r.vehicleId) == null,
        )
        .length;
    final unplated = c.vehicles.where((v) => v.plate.trim().isEmpty).length;
    final driverDocs = c.drivers
        .where((d) => d.licenseNumber.trim().isEmpty || d.licenseExpiry == null)
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reports & Control',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Management reporting, reconciliation and operational data exports',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (x) async {
                String csv = '';
                String label = '';
                if (x == 'rentals') {
                  csv = c.exportCsv();
                  label = 'Rental CSV copied.';
                }
                if (x == 'payments') {
                  csv = c.exportPaymentsCsv();
                  label = 'Payment CSV copied.';
                }
                if (x == 'ledger') {
                  csv = c.exportLedgerCsv();
                  label = 'Ledger CSV copied.';
                }
                if (x == 'fleet') {
                  csv = c.exportVehicleProfitabilityCsv();
                  label = 'Fleet profitability CSV copied.';
                }
                await Clipboard.setData(ClipboardData(text: csv));
                if (context.mounted) showError(context, FormatException(label));
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rentals',
                  child: Text('Export rentals CSV'),
                ),
                PopupMenuItem(
                  value: 'payments',
                  child: Text('Export payments CSV'),
                ),
                PopupMenuItem(
                  value: 'ledger',
                  child: Text('Export ledger CSV'),
                ),
                PopupMenuItem(
                  value: 'fleet',
                  child: Text('Export fleet profitability CSV'),
                ),
              ],
              child: const Icon(Icons.file_download_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.sizeOf(context).width > 850 ? 4 : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _reportKpi(context, 'Revenue', c.income, Icons.trending_up_rounded),
            _reportKpi(
              context,
              'Expenses',
              c.expenses,
              Icons.trending_down_rounded,
            ),
            _reportKpi(
              context,
              'Net position',
              net,
              Icons.account_balance_rounded,
            ),
            _reportKpi(
              context,
              'Receivable',
              c.receivable,
              Icons.pending_actions_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          decoration: _surface(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Financial overview',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 230,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: c.income,
                            width: 22,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: c.expenses,
                            width: 22,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 2,
                        barRods: [
                          BarChartRodData(
                            toY: c.rentalRevenue,
                            width: 22,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ],
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, m) => Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              v == 0
                                  ? 'Income'
                                  : v == 1
                                  ? 'Expenses'
                                  : 'Rental paid',
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _surface(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Finance reconciliation',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => showReconciliation(context, c),
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _reconRow(
                context,
                'Payment records',
                paymentTotal,
                Icons.payments_rounded,
              ),
              _reconRow(
                context,
                'Ledger income',
                ledgerIncome,
                Icons.account_balance_wallet_rounded,
              ),
              _reconRow(
                context,
                'Ledger expenses',
                ledgerExpense,
                Icons.receipt_long_rounded,
              ),
              _reconRow(
                context,
                'Rental receivable',
                c.receivable,
                Icons.pending_actions_rounded,
              ),
              const SizedBox(height: 8),
              Text(
                'Payment records should be traceable to rental receipts and ledger entries. Use reconciliation before closing a reporting period.',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _surface(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Data quality checks',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 10),
              _qualityRow(
                context,
                'Orphan rental records',
                orphanRentals,
                orphanRentals == 0,
              ),
              _qualityRow(
                context,
                'Vehicles without registration',
                unplated,
                unplated == 0,
              ),
              _qualityRow(
                context,
                'Drivers missing license data',
                driverDocs,
                driverDocs == 0,
              ),
              _qualityRow(
                context,
                'Overdue rentals',
                c.overdueRentals,
                c.overdueRentals == 0,
              ),
              _qualityRow(
                context,
                'Expiring vehicle documents',
                c.expiringVehicles.length,
                c.expiringVehicles.isEmpty,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showVehicleProfitability(context, c),
                icon: const Icon(Icons.directions_car_rounded),
                label: const Text('Fleet profitability'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showVehiclePeriodReport(context, c),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Vehicle period report'),
              ),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () => showFleetComparison(context, c),
          icon: const Icon(Icons.compare_arrows_rounded),
          label: const Text('All vehicles comparison'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => showVehicleProfitLoss(context, c),
          icon: const Icon(Icons.account_balance_rounded),
          label: const Text('Vehicle P&L & expense breakdown'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showReconciliation(context, c),
          icon: const Icon(Icons.fact_check_rounded),
          label: const Text('Finance reconciliation'),
        ),
      ],
    );
  }
}

Widget _reconRow(
  BuildContext context,
  String label,
  double value,
  IconData icon,
) => Padding(
  padding: const EdgeInsets.only(bottom: 9),
  child: Row(
    children: [
      Icon(icon, size: 17),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      Text(
        'Rs ${money(value)}',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
      ),
    ],
  ),
);
Widget _qualityRow(BuildContext context, String label, int value, bool ok) =>
    ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
        color: ok ? const Color(0xFF0E9F6E) : const Color(0xFFE05A47),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      trailing: Text(
        '$value',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
Widget _infoRow(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 4,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 6,
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 11),
        ),
      ),
    ],
  ),
);

Widget _sectionTitle(BuildContext context, String title, String subtitle) =>
    Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

Widget _reportKpi(
  BuildContext context,
  String label,
  double value,
  IconData icon,
) => Container(
  padding: const EdgeInsets.all(14),
  decoration: _surface(context),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 20),
      const SizedBox(height: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        'Rs ${money(value)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
    ],
  ),
);

DateTime _periodStart(String period) {
  final now = DateTime.now();
  if (period == 'Daily') return DateTime(now.year, now.month, now.day);
  if (period == 'Weekly') {
    final d = DateTime(now.year, now.month, now.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }
  return DateTime(now.year, now.month, 1);
}

DateTime _periodEnd(String period) {
  final now = DateTime.now();
  if (period == 'Daily') return DateTime(now.year, now.month, now.day);
  if (period == 'Weekly') {
    final s = _periodStart(period);
    return s.add(const Duration(days: 6));
  }
  return DateTime(now.year, now.month + 1, 0);
}

Future<void> showVehiclePeriodReport(
  BuildContext context,
  AppController c,
) async {
  if (c.vehicles.isEmpty) {
    showError(context, const FormatException('Add a vehicle first.'));
    return;
  }
  String vehicleId = c.vehicles.first.id;
  String period = 'Monthly';
  DateTime from = _periodStart(period), to = _periodEnd(period);
  await showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Vehicle Performance Report'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Separate daily, weekly or monthly income and expense report for one vehicle.',
                  style: TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: vehicleId,
                  items: c.vehicles
                      .map(
                        (v) => DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.name} • ${v.plate}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) set(() => vehicleId = v);
                  },
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Daily', label: Text('Daily')),
                    ButtonSegment(value: 'Weekly', label: Text('Weekly')),
                    ButtonSegment(value: 'Monthly', label: Text('Monthly')),
                    ButtonSegment(value: 'Custom', label: Text('Custom')),
                  ],
                  selected: {period},
                  onSelectionChanged: (s) async {
                    final p = s.first;
                    set(() => period = p);
                    if (p != 'Custom') {
                      set(() => from = _periodStart(p));
                      set(() => to = _periodEnd(p));
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'From',
                          style: TextStyle(fontSize: 11),
                        ),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(from)),
                        onTap: period == 'Custom'
                            ? () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  initialDate: from,
                                );
                                if (d != null) set(() => from = d);
                              }
                            : null,
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('To', style: TextStyle(fontSize: 11)),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(to)),
                        onTap: period == 'Custom'
                            ? () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  firstDate: from,
                                  lastDate: DateTime(2100),
                                  initialDate: to.isBefore(from) ? from : to,
                                );
                                if (d != null) set(() => to = d);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (_) {
                    final r = c.vehiclePeriodReport(vehicleId, from, to);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _surface(context),
                      child: Column(
                        children: [
                          _reconRow(
                            context,
                            'Rental billed',
                            r.rentalBilled,
                            Icons.receipt_long_rounded,
                          ),
                          _reconRow(
                            context,
                            'Rental collected',
                            r.rentalCollected,
                            Icons.payments_rounded,
                          ),
                          _reconRow(
                            context,
                            'Other income',
                            r.otherIncome,
                            Icons.trending_up_rounded,
                          ),
                          _reconRow(
                            context,
                            'Total income',
                            r.income,
                            Icons.account_balance_wallet_rounded,
                          ),
                          _reconRow(
                            context,
                            'Fuel expense',
                            r.fuelExpense,
                            Icons.local_gas_station_rounded,
                          ),
                          _reconRow(
                            context,
                            'Maintenance',
                            r.maintenanceExpense,
                            Icons.build_rounded,
                          ),
                          _reconRow(
                            context,
                            'Other expenses',
                            r.ledgerExpenses,
                            Icons.receipt_long_rounded,
                          ),
                          _reconRow(
                            context,
                            'Total expenses',
                            r.expenses,
                            Icons.trending_down_rounded,
                          ),
                          _reconRow(
                            context,
                            'NET RESULT',
                            r.net,
                            Icons.account_balance_rounded,
                          ),
                          _reconRow(
                            context,
                            'Current outstanding',
                            r.outstanding,
                            Icons.pending_actions_rounded,
                          ),
                          const Divider(),
                          _infoRow('Rentals', '${r.rentalCount}'),
                          _infoRow(
                            'Fuel',
                            '${r.fuelLitres.toStringAsFixed(1)} L',
                          ),
                          _infoRow('Services', '${r.serviceCount}'),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final csv = c.exportVehiclePeriodCsv(vehicleId, from, to);
              try {
                final dir = await getTemporaryDirectory();
                final v = c.vehicle(vehicleId);
                final file = File(
                  '${dir.path}/vehicle-${(v?.plate.isNotEmpty ?? false) ? v!.plate : v?.name ?? 'report'}-${DateFormat('yyyyMMdd').format(from)}-${DateFormat('yyyyMMdd').format(to)}.csv',
                );
                await file.writeAsString(csv);
                await Share.shareXFiles([
                  XFile(file.path),
                ], text: 'Vehicle performance report');
              } catch (_) {
                await Clipboard.setData(ClipboardData(text: csv));
                if (context.mounted)
                  showSuccessMessage(context, 'CSV copied to clipboard.');
              }
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download CSV'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final r = c.vehiclePeriodReport(vehicleId, from, to);
              await printVehiclePeriodReport(c, r);
            },
            icon: const Icon(Icons.print_rounded),
            label: const Text('Print / PDF'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showVehicleProfitLoss(
  BuildContext context,
  AppController c,
) async {
  if (c.vehicles.isEmpty) {
    showError(context, const FormatException('Add a vehicle first.'));
    return;
  }
  String vehicleId = c.vehicles.first.id;
  String period = 'Monthly';
  DateTime from = _periodStart(period), to = _periodEnd(period);
  await showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Vehicle P&L & Expense Breakdown'),
        content: SizedBox(
          width: 920,
          height: 610,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: vehicleId,
                      decoration: const InputDecoration(labelText: 'Vehicle'),
                      items: c.vehicles
                          .map(
                            (v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                v.plate.isEmpty
                                    ? v.name
                                    : '${v.name} • ${v.plate}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) set(() => vehicleId = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Daily', label: Text('Daily')),
                      ButtonSegment(value: 'Weekly', label: Text('Weekly')),
                      ButtonSegment(value: 'Monthly', label: Text('Monthly')),
                      ButtonSegment(value: 'Custom', label: Text('Custom')),
                    ],
                    selected: {period},
                    onSelectionChanged: (s) {
                      final p = s.first;
                      set(() => period = p);
                      if (p != 'Custom') {
                        set(() => from = _periodStart(p));
                        set(() => to = _periodEnd(p));
                      }
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('From', style: TextStyle(fontSize: 10)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(from)),
                      onTap: period == 'Custom'
                          ? () async {
                              final d = await showDatePicker(
                                context: ctx,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                initialDate: from,
                              );
                              if (d != null) set(() => from = d);
                            }
                          : null,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('To', style: TextStyle(fontSize: 10)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(to)),
                      onTap: period == 'Custom'
                          ? () async {
                              final d = await showDatePicker(
                                context: ctx,
                                firstDate: from,
                                lastDate: DateTime(2100),
                                initialDate: to.isBefore(from) ? from : to,
                              );
                              if (d != null) set(() => to = d);
                            }
                          : null,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Builder(
                  builder: (_) {
                    final r = c.vehiclePeriodReport(vehicleId, from, to);
                    final b = c.vehicleExpenseBreakdown(vehicleId, from, to);
                    final trend = c.vehicleMonthlyTrend(vehicleId, from, to);
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: _surface(context),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _miniKpi(
                                  context,
                                  'Income',
                                  'Rs ${money(r.income)}',
                                  Icons.trending_up_rounded,
                                ),
                                _miniKpi(
                                  context,
                                  'Expenses',
                                  'Rs ${money(r.expenses)}',
                                  Icons.trending_down_rounded,
                                ),
                                _miniKpi(
                                  context,
                                  'Net',
                                  'Rs ${money(r.net)}',
                                  Icons.account_balance_rounded,
                                ),
                                _miniKpi(
                                  context,
                                  'Due',
                                  'Rs ${money(r.outstanding)}',
                                  Icons.pending_actions_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Expense breakdown',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          ...b.entries.map(
                            (e) => _reconRow(
                              context,
                              e.key,
                              e.value,
                              e.key == 'Fuel'
                                  ? Icons.local_gas_station_rounded
                                  : e.key == 'Maintenance'
                                  ? Icons.build_rounded
                                  : Icons.receipt_long_rounded,
                            ),
                          ),
                          const Divider(),
                          _reconRow(
                            context,
                            'Total expenses',
                            r.expenses,
                            Icons.trending_down_rounded,
                          ),
                          _reconRow(
                            context,
                            'NET RESULT',
                            r.net,
                            Icons.account_balance_rounded,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Monthly trend',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          ...trend.map(
                            (m) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                m['label'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Income Rs ${money(m['income'] as double)} • Expense Rs ${money(m['expense'] as double)}',
                              ),
                              trailing: Text(
                                'Net Rs ${money(m['net'] as double)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: (m['net'] as double) >= 0
                                      ? const Color(0xFF0E9F6E)
                                      : const Color(0xFFE05A47),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final r = c.vehiclePeriodReport(vehicleId, from, to);
              final b = c.vehicleExpenseBreakdown(vehicleId, from, to);
              final rows = <String>[
                'Hafeez Rent A Car - Vehicle P&L',
                'Vehicle,${r.vehicle?.name ?? ''},Plate,${r.vehicle?.plate ?? ''}',
                'Period,${DateFormat('dd MMM yyyy').format(from)},to,${DateFormat('dd MMM yyyy').format(to)}',
                '',
                'Metric,Amount',
                'Rental billed,${r.rentalBilled.toStringAsFixed(2)}',
                'Rental collected,${r.rentalCollected.toStringAsFixed(2)}',
                'Other income,${r.otherIncome.toStringAsFixed(2)}',
                'Total income,${r.income.toStringAsFixed(2)}',
                'Fuel expense,${b['Fuel']!.toStringAsFixed(2)}',
                'Maintenance,${b['Maintenance']!.toStringAsFixed(2)}',
                'Other expenses,${b['Other expenses']!.toStringAsFixed(2)}',
                'Total expenses,${r.expenses.toStringAsFixed(2)}',
                'Net result,${r.net.toStringAsFixed(2)}',
                'Outstanding,${r.outstanding.toStringAsFixed(2)}',
              ];
              final dir = await getTemporaryDirectory();
              final file = File(
                '${dir.path}/vehicle-pnl-${DateFormat('yyyyMMdd').format(from)}-${DateFormat('yyyyMMdd').format(to)}.csv',
              );
              await file.writeAsString(rows.join('\n'));
              await Share.shareXFiles([
                XFile(file.path),
              ], text: 'Vehicle P&L report');
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download CSV'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final r = c.vehiclePeriodReport(vehicleId, from, to);
              await printVehiclePeriodReport(c, r);
            },
            icon: const Icon(Icons.print_rounded),
            label: const Text('Print / PDF'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showFleetComparison(BuildContext context, AppController c) async {
  if (c.vehicles.isEmpty) {
    showError(context, const FormatException('Add a vehicle first.'));
    return;
  }
  String period = 'Monthly';
  DateTime from = _periodStart(period), to = _periodEnd(period);
  await showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('All Vehicles Comparison'),
        content: SizedBox(
          width: 900,
          height: 560,
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fleet performance comparison',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Compare every vehicle for the same reporting period.',
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Daily', label: Text('Daily')),
                      ButtonSegment(value: 'Weekly', label: Text('Weekly')),
                      ButtonSegment(value: 'Monthly', label: Text('Monthly')),
                      ButtonSegment(value: 'Custom', label: Text('Custom')),
                    ],
                    selected: {period},
                    onSelectionChanged: (s) async {
                      final p = s.first;
                      set(() => period = p);
                      if (p != 'Custom') {
                        set(() => from = _periodStart(p));
                        set(() => to = _periodEnd(p));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('From', style: TextStyle(fontSize: 10)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(from)),
                      onTap: period == 'Custom'
                          ? () async {
                              final d = await showDatePicker(
                                context: ctx,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                initialDate: from,
                              );
                              if (d != null) set(() => from = d);
                            }
                          : null,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('To', style: TextStyle(fontSize: 10)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(to)),
                      onTap: period == 'Custom'
                          ? () async {
                              final d = await showDatePicker(
                                context: ctx,
                                firstDate: from,
                                lastDate: DateTime(2100),
                                initialDate: to.isBefore(from) ? from : to,
                              );
                              if (d != null) set(() => to = d);
                            }
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Builder(
                  builder: (_) {
                    final reports = c.vehicles
                        .map((v) => c.vehiclePeriodReport(v.id, from, to))
                        .toList();
                    final totalIncome = reports.fold(
                          0.0,
                          (s, r) => s + r.income,
                        ),
                        totalExpense = reports.fold(
                          0.0,
                          (s, r) => s + r.expenses,
                        ),
                        totalNet = totalIncome - totalExpense,
                        totalOutstanding = reports.fold(
                          0.0,
                          (s, r) => s + r.outstanding,
                        );
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: _surface(context),
                          child: Row(
                            children: [
                              _miniKpi(
                                context,
                                'Income',
                                'Rs ${money(totalIncome)}',
                                Icons.trending_up_rounded,
                              ),
                              const SizedBox(width: 8),
                              _miniKpi(
                                context,
                                'Expenses',
                                'Rs ${money(totalExpense)}',
                                Icons.trending_down_rounded,
                              ),
                              const SizedBox(width: 8),
                              _miniKpi(
                                context,
                                'Net',
                                'Rs ${money(totalNet)}',
                                Icons.account_balance_rounded,
                              ),
                              const SizedBox(width: 8),
                              _miniKpi(
                                context,
                                'Due',
                                'Rs ${money(totalOutstanding)}',
                                Icons.pending_actions_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Vehicle')),
                                  DataColumn(label: Text('Rentals')),
                                  DataColumn(label: Text('Income')),
                                  DataColumn(label: Text('Expenses')),
                                  DataColumn(label: Text('Net')),
                                  DataColumn(label: Text('Due')),
                                ],
                                rows: reports.map((r) {
                                  final v = r.vehicle;
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          v == null
                                              ? 'Vehicle'
                                              : (v.plate.isEmpty
                                                    ? v.name
                                                    : '${v.name} • ${v.plate}'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text('${r.rentalCount}')),
                                      DataCell(Text('Rs ${money(r.income)}')),
                                      DataCell(Text('Rs ${money(r.expenses)}')),
                                      DataCell(
                                        Text(
                                          'Rs ${money(r.net)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: r.net >= 0
                                                ? const Color(0xFF0E9F6E)
                                                : const Color(0xFFE05A47),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text('Rs ${money(r.outstanding)}'),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final csv = c.exportVehicleComparisonCsv(from, to);
              try {
                final dir = await getTemporaryDirectory();
                final file = File(
                  '${dir.path}/fleet-comparison-${DateFormat('yyyyMMdd').format(from)}-${DateFormat('yyyyMMdd').format(to)}.csv',
                );
                await file.writeAsString(csv);
                await Share.shareXFiles([
                  XFile(file.path),
                ], text: 'Fleet vehicle comparison');
              } catch (_) {
                await Clipboard.setData(ClipboardData(text: csv));
                if (context.mounted)
                  showSuccessMessage(
                    context,
                    'Comparison CSV copied to clipboard.',
                  );
              }
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download CSV'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await printFleetComparison(c, from, to);
            },
            icon: const Icon(Icons.print_rounded),
            label: const Text('Print / PDF'),
          ),
        ],
      ),
    ),
  );
}

Future<void> printFleetComparison(
  AppController c,
  DateTime from,
  DateTime to,
) async {
  final logo = await _loadPdfLogo();
  final doc = pw.Document();
  final b = c.settings;
  final reports = c.vehicles
      .map((v) => c.vehiclePeriodReport(v.id, from, to))
      .toList();
  final totalIncome = reports.fold(0.0, (s, r) => s + r.income),
      totalExpense = reports.fold(0.0, (s, r) => s + r.expenses),
      totalNet = totalIncome - totalExpense;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (_) => [
        _pdfHeader(
          c,
          'FLEET VEHICLE COMPARISON',
          logo: logo,
          reference:
              'Period ${DateFormat('dd MMM yyyy').format(from)} - ${DateFormat('dd MMM yyyy').format(to)}',
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              children: ['Vehicle', 'Rentals', 'Income', 'Expenses', 'Net']
                  .map(
                    (x) => pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        x,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            ...reports.map(
              (r) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      r.vehicle == null
                          ? 'Vehicle'
                          : (r.vehicle!.plate.isEmpty
                                ? r.vehicle!.name
                                : '${r.vehicle!.name} • ${r.vehicle!.plate}'),
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      '${r.rentalCount}',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      '${b.currency} ${money(r.income)}',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      '${b.currency} ${money(r.expenses)}',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      '${b.currency} ${money(r.net)}',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        _pdfRow('Fleet total income', '${b.currency} ${money(totalIncome)}'),
        _pdfRow('Fleet total expenses', '${b.currency} ${money(totalExpense)}'),
        _pdfRow('Fleet net result', '${b.currency} ${money(totalNet)}'),
        pw.SizedBox(height: 16),
        pw.Text(
          'This report compares each vehicle independently for the selected period. Expenses include ledger expenses, fuel and maintenance.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          b.footerNote,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    ),
  );
  await Printing.sharePdf(
    bytes: await doc.save(),
    filename:
        'fleet-comparison-${DateFormat('yyyyMMdd').format(from)}-${DateFormat('yyyyMMdd').format(to)}.pdf',
  );
}

Future<void> printVehiclePeriodReport(
  AppController c,
  VehiclePeriodReport r,
) async {
  final logo = await _loadPdfLogo();
  final doc = pw.Document();
  final b = c.settings;
  final v = r.vehicle;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        _pdfHeader(
          c,
          'VEHICLE PERFORMANCE REPORT',
          logo: logo,
          reference:
              'Report: VR-${(v?.plate.isNotEmpty ?? false) ? v!.plate : (v?.id.substring(0, 8).toUpperCase() ?? 'REPORT')}',
        ),
        _pdfRow('Vehicle', v?.name ?? '—'),
        _pdfRow('Registration', v?.plate ?? '—'),
        _pdfRow(
          'Period',
          '${DateFormat('dd MMM yyyy').format(r.from)} to ${DateFormat('dd MMM yyyy').format(r.to)}',
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              children: ['Financial metric', 'Amount']
                  .map(
                    (x) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        x,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            ...[
                  ['Rental billed', r.rentalBilled],
                  ['Rental collected', r.rentalCollected],
                  ['Other income', r.otherIncome],
                  ['Total income', r.income],
                  ['Ledger expenses', r.ledgerExpenses],
                  ['Fuel expense', r.fuelExpense],
                  ['Maintenance expense', r.maintenanceExpense],
                  ['Total expenses', r.expenses],
                  ['NET RESULT', r.net],
                  ['Current outstanding', r.outstanding],
                ]
                .map(
                  (x) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '${x[0]}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '${b.currency} ${money(x[1] as double)}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: x[0] == 'NET RESULT'
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ],
        ),
        pw.SizedBox(height: 14),
        _pdfRow('Rental count', '${r.rentalCount}'),
        _pdfRow('Fuel used', '${r.fuelLitres.toStringAsFixed(1)} L'),
        _pdfRow('Service records', '${r.serviceCount}'),
        pw.SizedBox(height: 24),
        pw.Text(
          'This report separates the selected vehicle from the rest of the fleet for the selected reporting period.',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          b.footerNote,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    ),
  );
  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: 'vehicle-performance-${v?.plate ?? 'report'}.pdf',
  );
}

Future<void> showReconciliation(BuildContext context, AppController c) async {
  final paymentTotal = c.payments.fold(0.0, (s, p) => s + p.amount);
  final rentalPaid = c.rentals.fold(0.0, (s, r) => s + r.paidAmount);
  final ledgerIncome = c.entries
      .where((e) => e.type != EntryType.expense)
      .fold(0.0, (s, e) => s + e.amount);
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Finance reconciliation'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Payment transactions', 'Rs ${money(paymentTotal)}'),
            _infoRow('Rental paid totals', 'Rs ${money(rentalPaid)}'),
            _infoRow('Ledger income', 'Rs ${money(ledgerIncome)}'),
            const Divider(),
            _infoRow(
              'Payment vs rental variance',
              'Rs ${money(paymentTotal - rentalPaid)}',
            ),
            _infoRow(
              'Payment vs ledger variance',
              'Rs ${money(paymentTotal - ledgerIncome)}',
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Variances should be investigated before a period is closed. This screen is a control check, not an accounting certification.',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> showVehicleProfitability(
  BuildContext context,
  AppController c,
) async {
  final list = [...c.vehicles]
    ..sort(
      (a, b) => (c.vehicleIncome(b.id) - c.vehicleExpense(b.id)).compareTo(
        c.vehicleIncome(a.id) - c.vehicleExpense(a.id),
      ),
    );

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Fleet profitability'),
      content: SizedBox(
        width: 620,
        height: 480,
        child: list.isEmpty
            ? const Center(child: Text('No vehicles yet.'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final v = list[i];
                  final inc = c.vehicleIncome(v.id);
                  final exp = c.vehicleExpense(v.id);
                  return ListTile(
                    leading: const Icon(Icons.directions_car_rounded),
                    title: Text(
                      '${v.name}${v.plate.isEmpty ? '' : ' • ${v.plate}'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Income Rs ${money(inc)} • Expense Rs ${money(exp)}',
                    ),
                    trailing: Text(
                      'Net Rs ${money(inc - exp)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: inc - exp >= 0
                            ? const Color(0xFF0E9F6E)
                            : const Color(0xFFE05A47),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> showRentalDialog(BuildContext context, AppController c) async {
  final available = c.vehicles
      .where((v) => v.status == VehicleStatus.available)
      .toList();

  if (c.customers.isEmpty || available.isEmpty) {
    showError(
      context,
      const FormatException(
        'Add a customer and keep a vehicle available first.',
      ),
    );
    return;
  }

  String customer = c.customers.first.id;
  String vehicle = available.first.id;
  String paymentMethod = 'Cash';
  DateTime start = DateTime.now();
  DateTime end = DateTime.now().add(const Duration(days: 1));

  final rate = TextEditingController();
  final deposit = TextEditingController();
  final paid = TextEditingController();
  final discount = TextEditingController();
  final tax = TextEditingController();
  final mileageLimit = TextEditingController();
  final pickup = TextEditingController();
  final returnLoc = TextEditingController();
  final note = TextEditingController();

  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('New Rental / Booking'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: customer,
                  items: c.customers
                      .map(
                        (x) =>
                            DropdownMenuItem(value: x.id, child: Text(x.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) set(() => customer = v);
                  },
                  decoration: const InputDecoration(labelText: 'Customer'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: vehicle,
                  items: available
                      .map(
                        (x) => DropdownMenuItem(
                          value: x.id,
                          child: Text('${x.name} ${x.plate}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) set(() => vehicle = v);
                  },
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rate,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Daily rent',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: deposit,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Security deposit',
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: discount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Discount',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: tax,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tax/other',
                        ),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: paid,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Advance / payment',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  items:
                      const [
                            'Cash',
                            'Bank',
                            'Easypaisa',
                            'JazzCash',
                            'Card',
                            'Other',
                          ]
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) set(() => paymentMethod = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                ),
                TextField(
                  controller: mileageLimit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Mileage limit (km, optional)',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pickup,
                        decoration: const InputDecoration(
                          labelText: 'Pickup location',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: returnLoc,
                        decoration: const InputDecoration(
                          labelText: 'Return location',
                        ),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                ListTile(
                  title: const Text('Pickup'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(start)),
                  trailing: TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: start,
                      );
                      if (d != null) set(() => start = d);
                    },
                    child: const Text('Change'),
                  ),
                ),
                ListTile(
                  title: const Text('Return'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(end)),
                  trailing: TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        firstDate: start,
                        lastDate: DateTime(2100),
                        initialDate: end,
                      );
                      if (d != null) set(() => end = d);
                    },
                    child: const Text('Change'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final r = double.tryParse(rate.text.replaceAll(',', '')) ?? 0;
                final dep =
                    double.tryParse(deposit.text.replaceAll(',', '')) ?? 0;
                final pay = double.tryParse(paid.text.replaceAll(',', '')) ?? 0;
                final disc =
                    double.tryParse(discount.text.replaceAll(',', '')) ?? 0;
                final t = double.tryParse(tax.text.replaceAll(',', '')) ?? 0;

                await c.addRental(
                  customerId: customer,
                  vehicleId: vehicle,
                  start: start,
                  end: end,
                  rate: r,
                  deposit: dep,
                  paid: pay,
                  note: note.text,
                );

                final created = c.rentals.last;
                final updated = created.copyWith(
                  discount: disc,
                  tax: t,
                  paymentMethod: paymentMethod,
                  mileageLimit: double.tryParse(mileageLimit.text) ?? 0,
                  pickupLocation: pickup.text,
                  returnLocation: returnLoc.text,
                );
                c.rentals = c.rentals
                    .map((x) => x.id == created.id ? updated : x)
                    .toList();
                await c.persist();

                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) showError(ctx, e);
              }
            },
            child: const Text('Create booking'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showRentalAgreement(
  BuildContext context,
  AppController c,
  Rental r,
) async {
  final cu = c.customer(r.customerId);
  final v = c.vehicle(r.vehicleId);
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Rental Agreement'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HAFEEZ RENT A CAR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _infoRow('Customer', cu?.name ?? '—'),
              _infoRow('Phone', cu?.phone ?? '—'),
              _infoRow('CNIC', cu?.cnic ?? '—'),
              _infoRow('Vehicle', v?.name ?? '—'),
              _infoRow('Registration', v?.plate ?? '—'),
              _infoRow(
                'Rental period',
                '${DateFormat('dd MMM yyyy').format(r.startAt)} → ${DateFormat('dd MMM yyyy').format(r.endAt)}',
              ),
              _infoRow('Daily rate', 'Rs ${money(r.dailyRate)}'),
              _infoRow('Total payable', 'Rs ${money(r.totalPayable)}'),
              _infoRow('Security deposit', 'Rs ${money(r.securityDeposit)}'),
              const SizedBox(height: 12),
              const Divider(),
              const Text(
                'Customer accepts responsibility for the vehicle during the rental period and agrees to the recorded charges, return condition and payment terms.',
                style: TextStyle(fontSize: 11, height: 1.45),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Customer signature: __________________',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Authorized signature: __________________',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> showReturnSettlement(
  BuildContext context,
  AppController c,
  Rental r,
) async {
  final mileage = TextEditingController(
    text: (c.vehicle(r.vehicleId)?.currentMileage ?? 0).toStringAsFixed(0),
  );
  final damage = TextEditingController(text: r.damageFee.toStringAsFixed(0));
  final refund = TextEditingController(
    text: r.depositBalance.toStringAsFixed(0),
  );
  final note = TextEditingController();

  String condition = 'Good';
  String fuel = 'Full';

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Return & Close Rental'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: mileage,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Return mileage (km)',
                    prefixIcon: Icon(Icons.speed_rounded),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: condition,
                  items:
                      const [
                            'Good',
                            'Minor scratches',
                            'Damage noted',
                            'Needs inspection',
                          ]
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) set(() => condition = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Vehicle condition',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: fuel,
                  items: const ['Full', '3/4', '1/2', '1/4', 'Empty']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) set(() => fuel = v);
                  },
                  decoration: const InputDecoration(labelText: 'Fuel level'),
                ),
                TextField(
                  controller: damage,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Damage charge (Rs)',
                  ),
                ),
                TextField(
                  controller: refund,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Deposit refund (Rs)',
                  ),
                ),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Return notes'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Outstanding rent: Rs ${money(r.remaining)} • Deposit available: Rs ${money(r.depositBalance)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final returnedMileage = double.tryParse(mileage.text) ?? 0;
                final damageFee = double.tryParse(damage.text) ?? 0;
                final depositRefund = double.tryParse(refund.text) ?? 0;

                final updated = r.copyWith(
                  actualReturnAt: DateTime.now(),
                  returnMileage: returnedMileage,
                  damageFee: damageFee,
                  depositRefund: depositRefund,
                  returnCondition: condition,
                  returnFuel: fuel,
                  returnNote: note.text,
                  status: RentalStatus.completed,
                );

                c.rentals = c.rentals
                    .map((x) => x.id == r.id ? updated : x)
                    .toList();

                await c.persist();

                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) showError(ctx, e);
              }
            },
            child: const Text('Close Rental'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showEntry(
  BuildContext context,
  AppController c, {
  EntryType type = EntryType.driving,
  EarningSource? source,
  LedgerEntry? existing,
}) async {
  var t = existing?.type ?? type;
  var s = existing?.source ?? source;
  String? v =
      existing?.vehicleId ?? (c.vehicles.isEmpty ? null : c.vehicles.first.id);
  DateTime date = existing?.date ?? DateTime.now();
  final cat = TextEditingController(
        text: existing?.category ?? (source == null ? '' : enumName(source!)),
      ),
      amount = TextEditingController(
        text: existing?.amount.toStringAsFixed(2) ?? '',
      ),
      note = TextEditingController(text: existing?.note ?? '');
  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      t == EntryType.expense
                          ? Icons.receipt_long_rounded
                          : Icons.account_balance_wallet_rounded,
                      color: const Color(0xFFD7B56D),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existing == null
                              ? (t == EntryType.expense
                                    ? 'Add Expense'
                                    : 'Record Income')
                              : 'Edit Transaction',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Keep your business ledger accurate',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _fieldLabel('Transaction type'),
              DropdownButtonFormField<EntryType>(
                initialValue: t,
                items: const [
                  DropdownMenuItem(
                    value: EntryType.driving,
                    child: Text('Driving income'),
                  ),
                  DropdownMenuItem(
                    value: EntryType.income,
                    child: Text('General income'),
                  ),
                  DropdownMenuItem(
                    value: EntryType.expense,
                    child: Text('Business expense'),
                  ),
                ],
                onChanged: (x) {
                  if (x != null)
                    set(() {
                      t = x;
                      if (t != EntryType.driving) s = null;
                    });
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.swap_vert_rounded),
                  hintText: 'Select type',
                ),
              ),
              const SizedBox(height: 12),
              if (c.vehicles.isNotEmpty) ...[
                _fieldLabel('Vehicle'),
                DropdownButtonFormField<String?>(
                  initialValue: v,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No vehicle linked'),
                    ),
                    ...c.vehicles.map(
                      (x) => DropdownMenuItem<String?>(
                        value: x.id,
                        child: Text(
                          '${x.name}${x.plate.isEmpty ? '' : ' • ${x.plate}'}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (x) => set(() => v = x),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.directions_car_filled_rounded),
                    hintText: 'Choose vehicle',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (t == EntryType.driving) ...[
                _fieldLabel('Earning source'),
                DropdownButtonFormField<EarningSource>(
                  initialValue: s,
                  items: EarningSource.values
                      .map(
                        (x) => DropdownMenuItem(
                          value: x,
                          child: Text(enumName(x)),
                        ),
                      )
                      .toList(),
                  onChanged: (x) => set(() => s = x),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.local_taxi_rounded),
                    hintText: 'Choose platform',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _fieldLabel('Category'),
              TextField(
                controller: cat,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                  hintText: 'e.g. Daily driving income',
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel('Amount'),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.payments_rounded),
                  prefixText: 'Rs  ',
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel('Note (optional)'),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.notes_rounded),
                  hintText: 'Add a short reference or note',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded),
                  title: const Text(
                    'Transaction date',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(date)),
                  trailing: TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: date,
                      );
                      if (d != null) set(() => date = d);
                    },
                    child: const Text('Change'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        try {
                          final a =
                              double.tryParse(
                                amount.text.replaceAll(',', ''),
                              ) ??
                              0;
                          if (existing == null)
                            await c.addEntry(
                              type: t,
                              vehicleId: v,
                              source: s,
                              category: cat.text,
                              amount: a,
                              date: date,
                              note: note.text,
                            );
                          else
                            await c.updateEntry(
                              existing,
                              type: t,
                              vehicleId: v,
                              source: s,
                              category: cat.text,
                              amount: a,
                              date: date,
                              note: note.text,
                            );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted && existing == null)
                            await showTransactionSuccess(
                              context,
                              c,
                              t,
                              a,
                              v,
                              s,
                            );
                        } catch (e) {
                          if (ctx.mounted) showError(ctx, e);
                        }
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        existing == null ? 'Save transaction' : 'Update',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _fieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: .2,
    ),
  ),
);

void showSuccessMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

Future<void> showTransactionSuccess(
  BuildContext context,
  AppController c,
  EntryType type,
  double amount,
  String? vehicleId,
  EarningSource? source,
) async {
  final v = vehicleId == null ? null : c.vehicle(vehicleId);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F7EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 38,
              color: Color(0xFF0E9F6E),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            type == EntryType.expense
                ? 'Expense recorded successfully'
                : 'Income recorded successfully',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            v == null ? 'Business ledger updated' : v.name,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${type == EntryType.expense ? '-' : '+'} Rs ${money(amount)}',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: type == EntryType.expense
                  ? const Color(0xFFE05A47)
                  : const Color(0xFF0E9F6E),
            ),
          ),
          if (source != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Source: ${enumName(source)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dashboard updated',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Your latest transaction is now included in the business summary.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showPaymentDialog(BuildContext context, AppController c) async {
  final open = c.rentals
      .where((r) => r.remaining > 0 && r.status != RentalStatus.cancelled)
      .toList();
  if (open.isEmpty) {
    showError(
      context,
      const FormatException(
        'There are no rentals with an outstanding balance.',
      ),
    );
    return;
  }
  String rentalId = open.first.id, method = 'Cash';
  final amount = TextEditingController(),
      reference = TextEditingController(),
      note = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Record Payment'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: rentalId,
                  items: open.map((r) {
                    final cu = c.customer(r.customerId);
                    final v = c.vehicle(r.vehicleId);
                    return DropdownMenuItem(
                      value: r.id,
                      child: Text(
                        '${cu?.name ?? 'Customer'} • ${v?.plate.isEmpty ?? true ? 'Vehicle' : v!.plate} • Due Rs ${money(r.remaining)}',
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) set(() => rentalId = v);
                  },
                  decoration: const InputDecoration(labelText: 'Rental'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'Rs  ',
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  items:
                      const [
                            'Cash',
                            'Bank',
                            'Easypaisa',
                            'JazzCash',
                            'Card',
                            'Other',
                          ]
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) set(() => method = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'Reference / receipt no.',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                final r = c.rentals.firstWhere((x) => x.id == rentalId);
                await c.addPayment(
                  r,
                  double.tryParse(amount.text.replaceAll(',', '')) ?? 0,
                  method: method,
                  reference: reference.text,
                  note: note.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted)
                  showSuccessMessage(context, 'Payment recorded successfully.');
              } catch (e) {
                if (ctx.mounted) showError(ctx, e);
              }
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Record payment'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showVehicleDialog(
  BuildContext context,
  AppController c, {
  Vehicle? existing,
}) async {
  String fuel = existing?.fuelType ?? 'Petrol';
  final name = TextEditingController(text: existing?.name ?? ''),
      plate = TextEditingController(text: existing?.plate ?? ''),
      model = TextEditingController(text: existing?.model ?? ''),
      year = TextEditingController(text: existing?.year ?? ''),
      color = TextEditingController(text: existing?.color ?? ''),
      mileage = TextEditingController(
        text: existing == null
            ? ''
            : existing.currentMileage.toStringAsFixed(0),
      ),
      chassis = TextEditingController(text: existing?.chassisNumber ?? ''),
      engine = TextEditingController(text: existing?.engineNumber ?? ''),
      insurance = TextEditingController(text: existing?.insuranceCompany ?? ''),
      purchase = TextEditingController(
        text: existing?.purchasePrice.toStringAsFixed(0) ?? '',
      ),
      market = TextEditingController(
        text: existing?.marketValue.toStringAsFixed(0) ?? '',
      ),
      note = TextEditingController(text: existing?.note ?? '');
  DateTime? reg = existing?.registrationExpiry,
      ins = existing?.insuranceExpiry,
      token = existing?.tokenExpiry,
      fitness = existing?.fitnessExpiry;
  Future<DateTime?> pick(BuildContext ctx, DateTime? value) async =>
      showDatePicker(
        context: ctx,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: value ?? DateTime.now(),
      );
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(existing == null ? 'Add Vehicle' : 'Edit Vehicle'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: plate,
                        decoration: const InputDecoration(
                          labelText: 'Registration / plate',
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: model,
                        decoration: const InputDecoration(labelText: 'Model'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: year,
                        decoration: const InputDecoration(labelText: 'Year'),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: color,
                        decoration: const InputDecoration(labelText: 'Color'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: fuel,
                        items:
                            const [
                                  'Petrol',
                                  'Diesel',
                                  'Hybrid',
                                  'Electric',
                                  'Other',
                                ]
                                .map(
                                  (x) => DropdownMenuItem(
                                    value: x,
                                    child: Text(x),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) set(() => fuel = v);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Fuel type',
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: mileage,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Current mileage',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: purchase,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Purchase value',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: market,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Market value',
                        ),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: chassis,
                  decoration: const InputDecoration(
                    labelText: 'Chassis number',
                  ),
                ),
                TextField(
                  controller: engine,
                  decoration: const InputDecoration(labelText: 'Engine number'),
                ),
                TextField(
                  controller: insurance,
                  decoration: const InputDecoration(
                    labelText: 'Insurance company',
                  ),
                ),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 8),
                _dateField(
                  ctx,
                  'Registration expiry',
                  reg,
                  (d) => set(() => reg = d),
                ),
                _dateField(
                  ctx,
                  'Insurance expiry',
                  ins,
                  (d) => set(() => ins = d),
                ),
                _dateField(
                  ctx,
                  'Token expiry',
                  token,
                  (d) => set(() => token = d),
                ),
                _dateField(
                  ctx,
                  'Fitness expiry',
                  fitness,
                  (d) => set(() => fitness = d),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final now = DateTime.now().millisecondsSinceEpoch;
                final vals = {
                  'name': name.text,
                  'plate': plate.text,
                  'model': model.text,
                  'year': year.text,
                  'color': color.text,
                  'fuelType': fuel,
                  'mileage':
                      double.tryParse(mileage.text.replaceAll(',', '')) ?? 0,
                  'chassis': chassis.text,
                  'engine': engine.text,
                  'insurance': insurance.text,
                  'purchase':
                      double.tryParse(purchase.text.replaceAll(',', '')) ?? 0,
                  'market':
                      double.tryParse(market.text.replaceAll(',', '')) ?? 0,
                  'note': note.text,
                };
                if (existing == null) {
                  await c.addVehicle(
                    vals['name'] as String,
                    vals['plate'] as String,
                    model: vals['model'] as String,
                    year: vals['year'] as String,
                    color: vals['color'] as String,
                    fuelType: fuel,
                    mileage: vals['mileage'] as double,
                    chassisNumber: vals['chassis'] as String,
                    engineNumber: vals['engine'] as String,
                    insuranceCompany: vals['insurance'] as String,
                    purchasePrice: vals['purchase'] as double,
                    marketValue: vals['market'] as double,
                    note: vals['note'] as String,
                    registrationExpiry: reg,
                    insuranceExpiry: ins,
                    tokenExpiry: token,
                    fitnessExpiry: fitness,
                  );
                } else {
                  await c.updateVehicle(
                    existing,
                    existing.copyWith(
                      name: vals['name'] as String,
                      plate: vals['plate'] as String,
                      model: vals['model'] as String,
                      year: vals['year'] as String,
                      color: vals['color'] as String,
                      fuelType: fuel,
                      currentMileage: vals['mileage'] as double,
                      chassisNumber: vals['chassis'] as String,
                      engineNumber: vals['engine'] as String,
                      insuranceCompany: vals['insurance'] as String,
                      purchasePrice: vals['purchase'] as double,
                      marketValue: vals['market'] as double,
                      note: vals['note'] as String,
                      registrationExpiry: reg,
                      insuranceExpiry: ins,
                      tokenExpiry: token,
                      fitnessExpiry: fitness,
                      updatedAtMs: now,
                    ),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) showError(ctx, e);
              }
            },
            child: Text(existing == null ? 'Create vehicle' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
}

Widget _dateField(
  BuildContext ctx,
  String label,
  DateTime? value,
  ValueChanged<DateTime> onChanged,
) => ListTile(
  contentPadding: EdgeInsets.zero,
  title: Text(label),
  subtitle: Text(
    value == null ? 'Not set' : DateFormat('dd MMM yyyy').format(value),
  ),
  trailing: TextButton(
    onPressed: () async {
      final d = await showDatePicker(
        context: ctx,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: value ?? DateTime.now(),
      );
      if (d != null) onChanged(d);
    },
    child: Text(value == null ? 'Set' : 'Change'),
  ),
);

Future<void> showVehicleStatus(
  BuildContext context,
  AppController c,
  Vehicle v,
) async {
  var selected = v.status;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Vehicle status'),
      content: DropdownButtonFormField<VehicleStatus>(
        initialValue: selected,
        items: VehicleStatus.values
            .map((x) => DropdownMenuItem(value: x, child: Text(enumName(x))))
            .toList(),
        onChanged: (x) {
          if (x != null) selected = x;
        },
        decoration: const InputDecoration(labelText: 'Status'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await c.updateVehicle(v, v.copyWith(status: selected));
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) showError(ctx, e);
            }
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );
}

Future<void> showVehicleDetails(
  BuildContext context,
  AppController c,
  Vehicle v,
) async {
  final matchingDrivers = c.drivers
      .where((d) => d.vehicleId == v.id && d.active)
      .toList();
  final driver = matchingDrivers.isEmpty ? null : matchingDrivers.first;
  final rentals = c.rentals.where((r) => r.vehicleId == v.id).toList();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: HrcTheme.ink,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_rounded,
                    color: HrcTheme.gold,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${v.model.isEmpty ? 'Vehicle' : v.model}${v.plate.isEmpty ? '' : ' • ${v.plate}'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                _statusPill(enumName(v.status)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _miniKpi(
                    context,
                    'Net',
                    'Rs ${money(c.vehicleIncome(v.id) - c.vehicleExpense(v.id))}',
                    Icons.insights_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniKpi(
                    context,
                    'Rentals',
                    '${rentals.length}',
                    Icons.key_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniKpi(
                    context,
                    'Mileage',
                    '${v.currentMileage.toStringAsFixed(0)} km',
                    Icons.speed_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _surface(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vehicle profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    'Registration',
                    v.plate.isEmpty ? 'Not set' : v.plate,
                  ),
                  _infoRow('Color', v.color.isEmpty ? 'Not set' : v.color),
                  _infoRow('Fuel', v.fuelType),
                  _infoRow(
                    'Chassis',
                    v.chassisNumber.isEmpty ? 'Not set' : v.chassisNumber,
                  ),
                  _infoRow(
                    'Engine',
                    v.engineNumber.isEmpty ? 'Not set' : v.engineNumber,
                  ),
                  _infoRow(
                    'Insurance',
                    v.insuranceCompany.isEmpty ? 'Not set' : v.insuranceCompany,
                  ),
                  _infoRow('Assigned driver', driver?.name ?? 'None'),
                  _infoRow('Purchase value', 'Rs ${money(v.purchasePrice)}'),
                  _infoRow('Market value', 'Rs ${money(v.marketValue)}'),
                  _infoRow('Notes', v.note.isEmpty ? '—' : v.note),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showVehicleStatus(context, c, v),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Change status'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showCustomerDialog(
  BuildContext context,
  AppController c, {
  Customer? existing,
}) async {
  DateTime? expiry = existing?.licenseExpiry;
  final name = TextEditingController(text: existing?.name ?? '');
  final father = TextEditingController(text: existing?.fatherName ?? '');
  final phone = TextEditingController(text: existing?.phone ?? '');
  final cnic = TextEditingController(text: existing?.cnic ?? '');
  final license = TextEditingController(text: existing?.licenseNumber ?? '');
  final address = TextEditingController(text: existing?.address ?? '');
  final emergency = TextEditingController(
    text: existing?.emergencyContact ?? '',
  );
  final note = TextEditingController(text: existing?.note ?? '');
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'Add Customer' : 'Edit Customer'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: father,
                      decoration: const InputDecoration(
                        labelText: 'Father name',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: cnic,
                decoration: const InputDecoration(labelText: 'CNIC'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: license,
                      decoration: const InputDecoration(
                        labelText: 'Driving license',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dateField(ctx, 'License expiry', expiry, (d) {
                      expiry = d;
                    }),
                  ),
                ],
              ),
              TextField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: emergency,
                decoration: const InputDecoration(
                  labelText: 'Emergency contact',
                ),
              ),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              final data = {
                'name': name.text,
                'father': father.text,
                'phone': phone.text,
                'cnic': cnic.text,
                'license': license.text,
                'expiry': expiry,
                'address': address.text,
                'emergency': emergency.text,
                'note': note.text,
              };
              if (existing == null)
                await c.addCustomer(data);
              else
                await c.updateCustomer(existing, data);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) showError(ctx, e);
            }
          },
          child: Text(existing == null ? 'Create customer' : 'Save changes'),
        ),
      ],
    ),
  );
}

Future<void> showCustomerDetails(
  BuildContext context,
  AppController c,
  Customer x,
) async {
  final rs = c.rentals.where((r) => r.customerId == x.id).toList()
    ..sort((a, b) => b.startAt.compareTo(a.startAt));
  final paid = rs.fold(0.0, (s, r) => s + r.paidAmount),
      due = rs.fold(0.0, (s, r) => s + r.remaining);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFF1ECE2),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF8F6D34),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        x.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        x.phone.isEmpty ? 'No phone' : x.phone,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _miniKpi(
                    context,
                    'Rentals',
                    '${rs.length}',
                    Icons.key_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniKpi(
                    context,
                    'Paid',
                    'Rs ${money(paid)}',
                    Icons.payments_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniKpi(
                    context,
                    'Due',
                    'Rs ${money(due)}',
                    Icons.pending_actions_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _surface(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    'Father name',
                    x.fatherName.isEmpty ? '—' : x.fatherName,
                  ),
                  _infoRow('CNIC', x.cnic.isEmpty ? 'Not set' : x.cnic),
                  _infoRow(
                    'License',
                    x.licenseNumber.isEmpty ? 'Not set' : x.licenseNumber,
                  ),
                  _infoRow(
                    'License expiry',
                    x.licenseExpiry == null
                        ? 'Not set'
                        : DateFormat('dd MMM yyyy').format(x.licenseExpiry!),
                  ),
                  _infoRow('Address', x.address.isEmpty ? '—' : x.address),
                  _infoRow(
                    'Emergency',
                    x.emergencyContact.isEmpty ? '—' : x.emergencyContact,
                  ),
                  _infoRow('Notes', x.note.isEmpty ? '—' : x.note),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Rental history',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (rs.isEmpty)
              _emptyCard(
                context,
                Icons.history_toggle_off_rounded,
                'No rental history',
                'This customer has not rented a vehicle yet.',
              ),
            ...rs.take(12).map((r) {
              final v = c.vehicle(r.vehicleId);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.key_rounded),
                title: Text(
                  '${v?.name ?? 'Vehicle'} • Rs ${money(r.totalPayable)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${DateFormat('dd MMM yyyy').format(r.startAt)} → ${DateFormat('dd MMM yyyy').format(r.endAt)} • ${enumName(r.status)}',
                ),
                trailing: Text(
                  'Due ${money(r.remaining)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

Future<void> showDriverDialog(
  BuildContext context,
  AppController c, {
  Driver? existing,
}) async {
  final name = TextEditingController(text: existing?.name ?? ''),
      phone = TextEditingController(text: existing?.phone ?? ''),
      cnic = TextEditingController(text: existing?.cnic ?? ''),
      license = TextEditingController(text: existing?.licenseNumber ?? ''),
      address = TextEditingController(text: existing?.address ?? ''),
      salary = TextEditingController(
        text: existing == null ? '' : money(existing.salary),
      ),
      commission = TextEditingController(
        text: existing == null ? '' : money(existing.commissionRate),
      ),
      note = TextEditingController(text: existing?.note ?? '');
  DateTime? expiry = existing?.licenseExpiry;
  String vehicleId = existing?.vehicleId ?? '';
  bool active = existing?.active ?? true;
  await showDialog(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(existing == null ? 'Add driver' : 'Edit driver'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Driver name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                TextField(
                  controller: cnic,
                  decoration: const InputDecoration(
                    labelText: 'CNIC',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                TextField(
                  controller: license,
                  decoration: const InputDecoration(
                    labelText: 'Driving license number',
                    prefixIcon: Icon(Icons.credit_card_rounded),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: vehicleId.isEmpty ? null : vehicleId,
                  decoration: const InputDecoration(
                    labelText: 'Assign vehicle',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No vehicle'),
                    ),
                    ...c.vehicles.map(
                      (v) => DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.name} • ${v.plate}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => set(() => vehicleId = v ?? ''),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    expiry == null
                        ? 'License expiry not set'
                        : DateFormat('dd MMM yyyy').format(expiry!),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate:
                            expiry ??
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) set(() => expiry = d);
                    },
                    child: const Text('Set'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: salary,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monthly salary',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: commission,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Commission %',
                        ),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (v) => set(() => active = v),
                  title: const Text('Active driver'),
                  subtitle: const Text(
                    'Inactive drivers cannot hold a vehicle assignment.',
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                final data = {
                  'name': name.text,
                  'phone': phone.text,
                  'cnic': cnic.text,
                  'license': license.text,
                  'expiry': expiry,
                  'address': address.text,
                  'salary':
                      double.tryParse(salary.text.replaceAll(',', '')) ?? 0,
                  'commission':
                      double.tryParse(commission.text.replaceAll(',', '')) ?? 0,
                  'note': note.text,
                  'vehicleId': active ? vehicleId : '',
                  'active': active,
                };
                if (existing == null)
                  await c.addDriver(data);
                else
                  await c.updateDriver(existing, data);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) showError(ctx, e);
              }
            },
            icon: const Icon(Icons.check_rounded),
            label: Text(existing == null ? 'Save driver' : 'Update'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showAccount(BuildContext context, AppController c) async {
  if (!c.firebaseReady) {
    showError(
      context,
      const FormatException(
        'Firebase is not configured. Local mode is active.',
      ),
    );
    return;
  }
  final email = TextEditingController(text: c.user?.email ?? ''),
      password = TextEditingController();
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(c.user == null ? 'Admin / Cloud Login' : 'Admin Account'),
      content: c.user == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Admin email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_rounded),
                  title: const Text('Signed in'),
                  subtitle: Text(c.user!.email ?? c.user!.uid),
                ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await AuthService().sendPasswordReset(
                        c.user!.email ?? '',
                      );
                      if (context.mounted)
                        showError(
                          context,
                          const FormatException('Password reset email sent.'),
                        );
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                  icon: const Icon(Icons.password_rounded),
                  label: const Text('Send password reset'),
                ),
              ],
            ),
      actions: [
        if (c.user != null)
          FilledButton(
            onPressed: () async {
              await c.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Logout'),
          ),
        if (c.user == null)
          TextButton(
            onPressed: () async {
              try {
                await c.signUp(email.text, password.text);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
            child: const Text('Create admin'),
          ),
        if (c.user == null)
          FilledButton(
            onPressed: () async {
              try {
                await c.signIn(email.text, password.text);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
            child: const Text('Login'),
          ),
      ],
    ),
  );
}

Future<void> showDriverSettlementDialog(
  BuildContext context,
  AppController c,
  Driver d,
) async {
  final period = TextEditingController(
    text: DateFormat('MMMM yyyy').format(DateTime.now()),
  );
  final gross = TextEditingController();
  final advances = TextEditingController();
  final deductions = TextEditingController();
  final note = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Driver settlement • ${d.name}'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: period,
              decoration: const InputDecoration(labelText: 'Settlement period'),
            ),
            TextField(
              controller: gross,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Gross earnings / trips',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: advances,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Advances'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: deductions,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Deductions'),
                  ),
                ),
              ],
            ),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Salary: Rs ${money(d.salary)} • Commission: ${d.commissionRate.toStringAsFixed(2)}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await c.addSettlement(
                driver: d,
                periodLabel: period.text,
                grossEarnings:
                    double.tryParse(gross.text.replaceAll(',', '')) ?? 0,
                advances:
                    double.tryParse(advances.text.replaceAll(',', '')) ?? 0,
                deductions:
                    double.tryParse(deductions.text.replaceAll(',', '')) ?? 0,
                note: note.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) showError(ctx, e);
            }
          },
          child: const Text('Save settlement'),
        ),
      ],
    ),
  );
}

Future<void> showAlerts(BuildContext context, AppController c) async {
  final items = <String>[];
  if (c.overdueRentals > 0)
    items.add('${c.overdueRentals} rental(s) are overdue.');
  if (c.expiringLicenses.isNotEmpty)
    items.add(
      '${c.expiringLicenses.length} driving license(s) expire within 30 days.',
    );
  if (c.expiringVehicles.isNotEmpty)
    items.add(
      '${c.expiringVehicles.length} vehicle(s) have a document expiring within 30 days.',
    );
  final dueService = c.maintenance
      .where(
        (m) => m.nextService.isBefore(
          DateTime.now().add(const Duration(days: 30)),
        ),
      )
      .length;
  if (dueService > 0)
    items.add('$dueService service record(s) are due within 30 days.');
  if (c.receivable > 0)
    items.add('Outstanding customer balance: Rs ${money(c.receivable)}.');
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Alerts & Expiry'),
      content: SizedBox(
        width: 420,
        child: items.isEmpty
            ? const ListTile(
                leading: Icon(Icons.verified_rounded),
                title: Text('All clear'),
                subtitle: Text('No urgent rental, payment or document alerts.'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: items
                    .map(
                      (x) => ListTile(
                        leading: const Icon(Icons.warning_amber_rounded),
                        title: Text(x),
                      ),
                    )
                    .toList(),
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<void> showBusinessSettings(BuildContext context, AppController c) async {
  final s = c.settings;
  final name = TextEditingController(text: s.businessName),
      phone = TextEditingController(text: s.phone),
      email = TextEditingController(text: s.email),
      address = TextEditingController(text: s.address),
      currency = TextEditingController(text: s.currency),
      footer = TextEditingController(text: s.footerNote),
      tax = TextEditingController(text: s.defaultTaxRate.toString());
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Business Settings'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Business name'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Office / business address',
                ),
              ),
              TextField(
                controller: currency,
                decoration: const InputDecoration(labelText: 'Currency'),
              ),
              TextField(
                controller: tax,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Default tax %'),
              ),
              TextField(
                controller: footer,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Receipt footer'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (!c.can('settings')) {
              showError(
                ctx,
                const FormatException(
                  'Your role cannot change business settings.',
                ),
              );
              return;
            }
            try {
              await c.saveSettings(
                s.copyWith(
                  businessName: name.text.trim(),
                  phone: phone.text.trim(),
                  email: email.text.trim(),
                  address: address.text.trim(),
                  currency: currency.text.trim().isEmpty
                      ? 'PKR'
                      : currency.text.trim(),
                  footerNote: footer.text.trim(),
                  defaultTaxRate: double.tryParse(tax.text) ?? 0,
                ),
              );
              await c.addAudit(
                'Settings updated',
                'Business',
                'Business profile settings changed',
              );
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) showError(ctx, e);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> showRoles(BuildContext context, AppController c) async {
  if (c.role != AdminRole.owner) {
    showError(
      context,
      const FormatException('Only the Owner can change admin roles.'),
    );
    return;
  }
  var selected = c.role;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Admin Roles & Permissions'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Role controls the permissions available on this device/account.',
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<AdminRole>(
            value: selected,
            items: AdminRole.values
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.name.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) selected = v;
            },
            decoration: const InputDecoration(labelText: 'Current role'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Owner: full access\nManager: operations and reports\nAccountant: payments, ledger, settlements, reports\nOperator: fleet, drivers, customers, rentals\nViewer: reports only',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            c.role = selected;
            c.store.saveRole(selected.name);
            c.addAudit('Role changed', 'Admin', selected.name.toUpperCase());
            c.notifyListeners();
            Navigator.pop(ctx);
          },
          child: const Text('Apply Role'),
        ),
      ],
    ),
  );
}

Future<void> showAuditLog(BuildContext context, AppController c) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Audit Log'),
      content: SizedBox(
        width: 560,
        height: 480,
        child: c.audits.isEmpty
            ? const Center(child: Text('No audit activity yet.'))
            : ListView.builder(
                itemCount: c.audits.length,
                itemBuilder: (_, i) {
                  final a = c.audits[i];
                  return ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(
                      '${a.action} • ${a.entity}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd MMM yyyy, hh:mm a').format(a.date)}\n${a.details}${a.actorEmail.isEmpty ? '' : '\n${a.actorEmail}'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> showSystemInfo(BuildContext context, AppController c) async {
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Hafeez Rent A Car'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Fleet & Rental Management',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'Offline-ready business data with optional Firebase cloud sync.',
          ),
          SizedBox(height: 8),
          Text(
            'Modules: Fleet • Drivers • Assignments • Customers • Rentals • Payments • Ledger • Maintenance • Fuel • Reports • Backup • Alerts',
          ),
          SizedBox(height: 8),
          Text(
            'Work can continue offline; cloud sync is available when Firebase is configured.',
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> showBackup(BuildContext context, AppController c) async {
  final json = await c.exportBackup();
  final restore = TextEditingController();
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Backup / Restore'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              'Backup now includes vehicles, customers, rentals, payments, maintenance and fuel.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: json),
              maxLines: 6,
              readOnly: true,
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy backup'),
            ),
            TextField(
              controller: restore,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Paste backup JSON'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await c.importBackup(restore.text.trim());
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
          },
          child: const Text('Restore'),
        ),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        e is FormatException
            ? e.message
            : e.toString().replaceFirst('Exception: ', ''),
      ),
    ),
  );
}

String money(double n) => NumberFormat('#,##0.00').format(n);
