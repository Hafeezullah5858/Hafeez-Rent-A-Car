import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Local-first storage with account-scoped keys.
///
/// Data is never removed merely because the app version/schema changes.
/// Legacy keys are copied into the active account namespace on first run,
/// while the original legacy keys are intentionally retained as a safety net.
class LocalStore {
  static const _vehiclesKey = 'vehicles_v2';
  static const _driversKey = 'drivers_v1';
  static const _paymentsKey = 'payments_v1';
  static const _settlementsKey = 'driver_settlements_v1';
  static const _inspectionsKey = 'inspections_v1';
  static const _entriesKey = 'entries_v2';
  static const _schemaKey = 'schema_version';
  static const _deletedEntriesKey = 'deleted_entries_v1';
  static const _ownerKey = 'local_owner_v1';
  static const _upgradeBackupKey = 'upgrade_backup_v1';
  static const _settingsKey='business_settings_v1', _auditKey='audit_logs_v1', _roleKey='admin_role_v1';
  static const currentSchema = 16;

  String _activeOwner = 'local';
  bool _allowLegacyCopy = true;
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String _scope(String key) => '${key}__${base64Url.encode(utf8.encode(_activeOwner)).replaceAll('=', '')}';

  Future<void> activateOwner(String ownerId) async {
    final owner = ownerId.trim().isEmpty ? 'local' : ownerId.trim();
    _activeOwner = owner;
    await migrate();
  }

  Future<void> migrate() async {
    final p = await _prefs;
    final version = p.getInt(_schemaKey) ?? 0;

    // One-time safety snapshot before any schema migration. This is additive;
    // no existing records are deleted or rewritten by the migration itself.
    final upgradeBackupForVersion = '${_upgradeBackupKey}__from_$version';
    if (version < currentSchema && p.getString(upgradeBackupForVersion) == null) {
      final legacyVehicles = p.getStringList(_vehiclesKey);
      final legacyEntries = p.getStringList(_entriesKey);
      final legacyDeleted = p.getStringList(_deletedEntriesKey);
      await p.setString(upgradeBackupForVersion, jsonEncode({
        'fromSchema': version,
        'createdAt': DateTime.now().toIso8601String(),
        'vehicles': legacyVehicles ?? const <String>[],
        'entries': legacyEntries ?? const <String>[],
        'deletedEntryIds': legacyDeleted ?? const <String>[],
      }));
    }

    final scopedVehicles = _scope(_vehiclesKey);
    final scopedEntries = _scope(_entriesKey);
    final scopedDeleted = _scope(_deletedEntriesKey);

    // Preserve existing account-scoped data. If it does not exist yet, copy
    // legacy data once into the active namespace instead of deleting it.
    if (_allowLegacyCopy && !p.containsKey(scopedVehicles)) {
      final legacy = p.getStringList(_vehiclesKey);
      if (legacy != null) await p.setStringList(scopedVehicles, legacy);
    }
    if (_allowLegacyCopy && !p.containsKey(scopedEntries)) {
      final legacy = p.getStringList(_entriesKey);
      if (legacy != null) await p.setStringList(scopedEntries, legacy);
    }
    if (_allowLegacyCopy && !p.containsKey(scopedDeleted)) {
      final legacy = p.getStringList(_deletedEntriesKey);
      await p.setStringList(scopedDeleted, legacy ?? const <String>[]);
    }

    // Keep schema monotonic. Never downgrade a newer local data format.
    if (version < currentSchema) await p.setInt(_schemaKey, currentSchema);
  }

  Future<String> ownerId() async {
    final p = await _prefs;
    return p.getString(_ownerKey) ?? _activeOwner;
  }

  Future<String> role() async { final p=await _prefs; return p.getString(_scope(_roleKey)) ?? 'owner'; }
  Future<void> saveRole(String role) async { final p=await _prefs; await p.setString(_scope(_roleKey), role); }

  Future<void> setOwnerId(String ownerId) async {
    final owner = ownerId.trim().isEmpty ? 'local' : ownerId.trim();
    final p = await _prefs;
    final previousOwner = p.getString(_ownerKey);
    _activeOwner = owner;
    // Legacy data can only be adopted when this is the first owner ever seen,
    // or when returning to that same owner. Never copy legacy guest data into
    // an unrelated Firebase account.
    _allowLegacyCopy = previousOwner == null || previousOwner == owner;
    await p.setString(_ownerKey, owner);
    await migrate();
  }

  Future<void> clearData() async {
    final p = await _prefs;
    await p.remove(_scope(_vehiclesKey));
    await p.remove(_scope(_entriesKey));
    await p.remove(_scope(_deletedEntriesKey));
    // Legacy keys are deliberately NOT removed. They may still be the only
    // recovery copy for an older installation.
  }

  Future<List<Vehicle>> vehicles() async {
    await migrate();
    final p = await _prefs;
    final raw = p.getStringList(_scope(_vehiclesKey)) ?? <String>[];
    return raw.map((x) => Vehicle.fromMap(jsonDecode(x) as Map<String, dynamic>)).toList();
  }

  Future<List<LedgerEntry>> entries() async {
    await migrate();
    final p = await _prefs;
    final raw = p.getStringList(_scope(_entriesKey)) ?? <String>[];
    return raw.map((x) => LedgerEntry.fromMap(jsonDecode(x) as Map<String, dynamic>)).toList();
  }

  Future<void> saveVehicles(List<Vehicle> items) async {
    final p = await _prefs;
    await p.setStringList(_scope(_vehiclesKey), items.map((x) => jsonEncode(x.toMap())).toList());
    await p.setInt(_schemaKey, currentSchema);
  }

  Future<Set<String>> deletedEntryIds() async {
    await migrate();
    final p = await _prefs;
    return (p.getStringList(_scope(_deletedEntriesKey)) ?? const <String>[]).toSet();
  }

  Future<void> markEntryDeleted(String id) async {
    final p = await _prefs;
    final ids = await deletedEntryIds();
    ids.add(id);
    await p.setStringList(_scope(_deletedEntriesKey), ids.toList());
  }

  Future<void> saveDeletedEntryIds(Set<String> ids) async {
    final p = await _prefs;
    await p.setStringList(_scope(_deletedEntriesKey), ids.toList());
  }

  Future<void> clearDeletedEntry(String id) async {
    final p = await _prefs;
    final ids = await deletedEntryIds();
    ids.remove(id);
    await p.setStringList(_scope(_deletedEntriesKey), ids.toList());
  }

  Future<void> saveEntries(List<LedgerEntry> items) async {
    final p = await _prefs;
    await p.setStringList(_scope(_entriesKey), items.map((x) => jsonEncode(x.toMap())).toList());
    await p.setInt(_schemaKey, currentSchema);
  }

  Future<List<T>> _read<T>(String key, T Function(Map<String,dynamic>) parse) async {
    await migrate();
    final p = await _prefs;
    final raw = p.getStringList(_scope(key)) ?? <String>[];
    return raw.map((x) => parse(Map<String,dynamic>.from(jsonDecode(x) as Map))).toList();
  }
  Future<void> _save<T>(String key, List<T> items, Map<String,dynamic> Function(T) map) async {
    final p = await _prefs;
    await p.setStringList(_scope(key), items.map((x) => jsonEncode(map(x))).toList());
    await p.setInt(_schemaKey, currentSchema);
  }
  static const _customersKey='customers_v1', _rentalsKey='rentals_v1', _maintenanceKey='maintenance_v1', _fuelKey='fuel_v1';
  Future<List<Customer>> customers()=>_read(_customersKey,(m)=>Customer.fromMap(m));
  Future<List<Rental>> rentals()=>_read(_rentalsKey,(m)=>Rental.fromMap(m));
  Future<List<MaintenanceRecord>> maintenance()=>_read(_maintenanceKey,(m)=>MaintenanceRecord.fromMap(m));
  Future<List<FuelRecord>> fuel()=>_read(_fuelKey,(m)=>FuelRecord.fromMap(m));
  Future<List<Driver>> drivers()=>_read(_driversKey,(m)=>Driver.fromMap(m));
  Future<List<PaymentRecord>> payments()=>_read(_paymentsKey,(m)=>PaymentRecord.fromMap(m));
  Future<List<DriverSettlement>> settlements()=>_read(_settlementsKey,(m)=>DriverSettlement.fromMap(m));
  Future<List<InspectionRecord>> inspections()=>_read(_inspectionsKey,(m)=>InspectionRecord.fromMap(m));
  Future<BusinessSettings> settings() async { await migrate(); final p=await _prefs; final raw=p.getString(_scope(_settingsKey)); return raw==null?const BusinessSettings():BusinessSettings.fromMap(Map<String,dynamic>.from(jsonDecode(raw) as Map)); }
  Future<void> saveSettings(BusinessSettings x)=>_saveOne(_settingsKey,x.toMap());
  Future<List<AuditLog>> audits()=>_read(_auditKey,(m)=>AuditLog.fromMap(m));
  Future<void> saveAudits(List<AuditLog> x)=>_save(_auditKey,x,(e)=>e.toMap());
  Future<void> _saveOne(String key,Map<String,dynamic> map) async { final p=await _prefs; await p.setString(_scope(key),jsonEncode(map)); await p.setInt(_schemaKey,currentSchema); }
  Future<void> saveCustomers(List<Customer> x)=>_save(_customersKey,x,(e)=>e.toMap());
  Future<void> saveRentals(List<Rental> x)=>_save(_rentalsKey,x,(e)=>e.toMap());
  Future<void> saveMaintenance(List<MaintenanceRecord> x)=>_save(_maintenanceKey,x,(e)=>e.toMap());
  Future<void> saveFuel(List<FuelRecord> x)=>_save(_fuelKey,x,(e)=>e.toMap());
  Future<void> saveDrivers(List<Driver> x)=>_save(_driversKey,x,(e)=>e.toMap());
  Future<void> savePayments(List<PaymentRecord> x)=>_save(_paymentsKey,x,(e)=>e.toMap());
  Future<void> saveSettlements(List<DriverSettlement> x)=>_save(_settlementsKey,x,(e)=>e.toMap());
  Future<void> saveInspections(List<InspectionRecord> x)=>_save(_inspectionsKey,x,(e)=>e.toMap());

  Future<String> exportJson() async => jsonEncode({
    'app':'Hafeez Rent A Car','schemaVersion':currentSchema,'exportedAt':DateTime.now().toIso8601String(),'accountId':_activeOwner,
    'vehicles':(await vehicles()).map((e)=>e.toMap()).toList(),'entries':(await entries()).map((e)=>e.toMap()).toList(),'deletedEntryIds':(await deletedEntryIds()).toList(),
    'customers':(await customers()).map((e)=>e.toMap()).toList(),'rentals':(await rentals()).map((e)=>e.toMap()).toList(),'maintenance':(await maintenance()).map((e)=>e.toMap()).toList(),'fuel':(await fuel()).map((e)=>e.toMap()).toList(),'drivers':(await drivers()).map((e)=>e.toMap()).toList(),'payments':(await payments()).map((e)=>e.toMap()).toList(),'driverSettlements':(await settlements()).map((e)=>e.toMap()).toList(),'inspections':(await inspections()).map((e)=>e.toMap()).toList(),'settings':(await settings()).toMap(),'auditLogs':(await audits()).map((e)=>e.toMap()).toList(),
  });

  Future<void> importJson(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup must be a JSON object.');
    }
    final schema = (decoded['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schema < 1 || schema > currentSchema) {
      throw FormatException('Unsupported backup schema: $schema');
    }
    final rawVehicles = decoded['vehicles'];
    final rawEntries = decoded['entries'];
    if (rawVehicles is! List || rawEntries is! List) {
      throw const FormatException('Backup is missing vehicles or entries.');
    }
    final vs = <Vehicle>[];
    final vehicleIds = <String>{};
    for (final item in rawVehicles) {
      if (item is! Map) throw const FormatException('Backup contains an invalid vehicle record.');
      final vehicle = Vehicle.fromMap(Map<String, dynamic>.from(item));
      if (vehicle.id.trim().isEmpty || vehicle.name.trim().isEmpty) {
        throw const FormatException('Backup contains an invalid vehicle.');
      }
      if (!vehicleIds.add(vehicle.id)) {
        throw const FormatException('Backup contains duplicate vehicle IDs.');
      }
      vs.add(vehicle);
    }
    final es = <LedgerEntry>[];
    final entryIds = <String>{};
    for (final item in rawEntries) {
      if (item is! Map) throw const FormatException('Backup contains an invalid transaction record.');
      final entry = LedgerEntry.fromMap(Map<String, dynamic>.from(item));
      if (entry.id.trim().isEmpty || !entry.amount.isFinite || entry.amount <= 0) {
        throw const FormatException('Backup contains an invalid transaction.');
      }
      if (!entryIds.add(entry.id)) {
        throw const FormatException('Backup contains duplicate transaction IDs.');
      }
      if (entry.vehicleId != null && !vehicleIds.contains(entry.vehicleId)) {
        throw const FormatException('Backup contains a transaction for an unknown vehicle.');
      }
      if (entry.type == EntryType.driving && entry.source == null) {
        throw const FormatException('Backup contains a driving transaction without a source.');
      }
      es.add(entry);
    }
    final rawDeleted = decoded['deletedEntryIds'];
    if (rawDeleted != null && rawDeleted is! List) throw const FormatException('Backup contains invalid deletion records.');

    // Make a recovery copy of the current account before replacing it.
    final p = await _prefs;
    await p.setString('${_upgradeBackupKey}__before_restore', await exportJson());

    await saveVehicles(vs);
    await saveEntries(es);
    await p.setStringList(_scope(_deletedEntriesKey), ((rawDeleted as List?) ?? const []).map((e) => e.toString()).toList());
    final customersRaw=decoded['customers']; final rentalsRaw=decoded['rentals']; final maintenanceRaw=decoded['maintenance']; final fuelRaw=decoded['fuel']; final driversRaw=decoded['drivers']; final paymentsRaw=decoded['payments']; final settlementsRaw=decoded['driverSettlements'];
    if(customersRaw is List) await saveCustomers(customersRaw.whereType<Map>().map((m)=>Customer.fromMap(Map<String,dynamic>.from(m))).toList());
    if(rentalsRaw is List) await saveRentals(rentalsRaw.whereType<Map>().map((m)=>Rental.fromMap(Map<String,dynamic>.from(m))).toList());
    if(maintenanceRaw is List) await saveMaintenance(maintenanceRaw.whereType<Map>().map((m)=>MaintenanceRecord.fromMap(Map<String,dynamic>.from(m))).toList());
    if(fuelRaw is List) await saveFuel(fuelRaw.whereType<Map>().map((m)=>FuelRecord.fromMap(Map<String,dynamic>.from(m))).toList());
    if(driversRaw is List) await saveDrivers(driversRaw.whereType<Map>().map((m)=>Driver.fromMap(Map<String,dynamic>.from(m))).toList());
    if(paymentsRaw is List) await savePayments(paymentsRaw.whereType<Map>().map((m)=>PaymentRecord.fromMap(Map<String,dynamic>.from(m))).toList());
    if(settlementsRaw is List) await saveSettlements(settlementsRaw.whereType<Map>().map((m)=>DriverSettlement.fromMap(Map<String,dynamic>.from(m))).toList());
    final settingsRaw=decoded['settings']; if(settingsRaw is Map) await saveSettings(BusinessSettings.fromMap(Map<String,dynamic>.from(settingsRaw)));
    final auditRaw=decoded['auditLogs']; if(auditRaw is List) await saveAudits(auditRaw.whereType<Map>().map((m)=>AuditLog.fromMap(Map<String,dynamic>.from(m))).toList());
    final inspectionsRaw = decoded['inspections'];
    if(inspectionsRaw is List) await saveInspections(inspectionsRaw.whereType<Map>().map((m)=>InspectionRecord.fromMap(Map<String,dynamic>.from(m))).toList());
  }
}
