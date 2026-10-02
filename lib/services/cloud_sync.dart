import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirebaseCloudSync {
  final FirebaseFirestore db;
  FirebaseCloudSync([FirebaseFirestore? firestore])
      : db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _vehicles(String uid) =>
      db.collection('users').doc(uid).collection('vehicles');
  CollectionReference<Map<String, dynamic>> _entries(String uid) =>
      db.collection('users').doc(uid).collection('entries');
  CollectionReference<Map<String, dynamic>> _deletions(String uid) =>
      db.collection('users').doc(uid).collection('deletions');

  Future<void> push(String accountId, List<Vehicle> vehicles,
      List<LedgerEntry> entries, Set<String> deletedEntryIds) async {
    final root = db.collection('users').doc(accountId);
    final writes = <void Function(WriteBatch)>[];

    for (final v in vehicles) {
      writes.add((batch) => batch.set(
            _vehicles(accountId).doc(v.id),
            v.toMap(),
            SetOptions(merge: true),
          ));
    }
    for (final e in entries) {
      if (deletedEntryIds.contains(e.id)) continue;
      writes.add((batch) => batch.set(
            _entries(accountId).doc(e.id),
            e.toMap(),
            SetOptions(merge: true),
          ));
    }
    for (final id in deletedEntryIds) {
      writes.add((batch) => batch.set(
            _deletions(accountId).doc(id),
            {'id': id, 'deletedAtMs': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          ));
      writes.add((batch) => batch.delete(_entries(accountId).doc(id)));
    }
    writes.add((batch) => batch.set(
          root,
          {'schemaVersion': 3, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        ));

    // Firestore batches have a 500-operation limit. Keep headroom for future
    // metadata writes so a large ledger can still sync safely.
    for (var i = 0; i < writes.length; i += 400) {
      final batch = db.batch();
      final end = (i + 400 < writes.length) ? i + 400 : writes.length;
      for (var j = i; j < end; j++) {
        writes[j](batch);
      }
      await batch.commit();
    }
  }

  Future<({List<Vehicle> vehicles, List<LedgerEntry> entries, Set<String> deleted})>
      pull(String accountId) async {
    final vs = await _vehicles(accountId).get();
    final es = await _entries(accountId).get();
    final ds = await _deletions(accountId).get();
    return (
      vehicles: vs.docs.map((d) => Vehicle.fromMap(d.data())).toList(),
      entries: es.docs.map((d) => LedgerEntry.fromMap(d.data())).toList(),
      deleted: ds.docs.map((d) => d.id).toSet(),
    );
  }

  Future<void> merge(String accountId, List<Vehicle> localVehicles,
      List<LedgerEntry> localEntries, Set<String> deletedEntryIds) async {
    final remote = await pull(accountId);
    final deleted = {...remote.deleted, ...deletedEntryIds};
    final vehicles = <String, Vehicle>{for (final v in remote.vehicles) v.id: v};
    for (final v in localVehicles) {
      final old = vehicles[v.id];
      if (old == null || v.updatedAtMs >= old.updatedAtMs) vehicles[v.id] = v;
    }
    final entries = <String, LedgerEntry>{for (final e in remote.entries) e.id: e};
    for (final e in localEntries) {
      if (deleted.contains(e.id)) continue;
      final old = entries[e.id];
      if (old == null || e.updatedAtMs >= old.updatedAtMs) entries[e.id] = e;
    }
    entries.removeWhere((id, _) => deleted.contains(id));
    await push(accountId, vehicles.values.toList(), entries.values.toList(), deleted);
  }
  CollectionReference<Map<String,dynamic>> _collection(String uid,String name)=>db.collection('users').doc(uid).collection(name);
  Future<void> pushBusiness(String uid,List<Customer> customers,List<Rental> rentals,List<MaintenanceRecord> maintenance,List<FuelRecord> fuel,List<Driver> drivers,List<PaymentRecord> payments,List<DriverSettlement> settlements,List<InspectionRecord> inspections,{BusinessSettings? settings,List<AuditLog> audits=const []}) async {
    final writes=<void Function(WriteBatch)>[];
    for(final x in customers){writes.add((b)=>b.set(_collection(uid,'customers').doc(x.id),x.toMap(),SetOptions(merge:true)));}
    for(final x in rentals){writes.add((b)=>b.set(_collection(uid,'rentals').doc(x.id),x.toMap(),SetOptions(merge:true)));}
    for(final x in maintenance){writes.add((b)=>b.set(_collection(uid,'maintenance').doc(x.id),x.toMap(),SetOptions(merge:true)));}
    for(final x in fuel){writes.add((b)=>b.set(_collection(uid,'fuel').doc(x.id),x.toMap(),SetOptions(merge:true)));}
    for(final x in drivers){writes.add((b)=>b.set(_collection(uid,'drivers').doc(x.id),x.toMap(),SetOptions(merge:true)));}
    for(final x in payments){writes.add((b)=>b.set(_collection(uid,'payments').doc(x.id),x.toMap(),SetOptions(merge:true)));}
    for(final x in settlements){writes.add((b)=>b.set(_collection(uid,'driver_settlements').doc(x.id),x.toMap(),SetOptions(merge:true)));}
    for(final x in inspections){writes.add((b)=>b.set(_collection(uid,'inspections').doc(x.id),x.toMap(),SetOptions(merge:true)));}
    if(settings!=null){writes.add((b)=>b.set(_collection(uid,'meta').doc('settings'),settings.toMap(),SetOptions(merge:true)));}
    for(final x in audits){writes.add((b)=>b.set(_collection(uid,'audit_logs').doc(x.id),x.toMap(),SetOptions(merge:true)));}
    for(var i=0;i<writes.length;i+=400){final b=db.batch();final end=(i+400<writes.length)?i+400:writes.length;for(var j=i;j<end;j++){writes[j](b);}await b.commit();}
  }
  Future<({List<Customer> customers,List<Rental> rentals,List<MaintenanceRecord> maintenance,List<FuelRecord> fuel,List<Driver> drivers,List<PaymentRecord> payments,List<DriverSettlement> settlements,List<InspectionRecord> inspections,BusinessSettings settings,List<AuditLog> audits})> pullBusiness(String uid) async {
    final c=await _collection(uid,'customers').get();final r=await _collection(uid,'rentals').get();final m=await _collection(uid,'maintenance').get();final f=await _collection(uid,'fuel').get();final d=await _collection(uid,'drivers').get();final p=await _collection(uid,'payments').get();final s=await _collection(uid,'driver_settlements').get();final i=await _collection(uid,'inspections').get();final meta=await _collection(uid,'meta').doc('settings').get();final a=await _collection(uid,'audit_logs').get();
    return (customers:c.docs.map((d)=>Customer.fromMap(d.data())).toList(),rentals:r.docs.map((d)=>Rental.fromMap(d.data())).toList(),maintenance:m.docs.map((d)=>MaintenanceRecord.fromMap(d.data())).toList(),fuel:f.docs.map((d)=>FuelRecord.fromMap(d.data())).toList(),drivers:d.docs.map((d)=>Driver.fromMap(d.data())).toList(),payments:p.docs.map((d)=>PaymentRecord.fromMap(d.data())).toList(),settlements:s.docs.map((d)=>DriverSettlement.fromMap(d.data())).toList(),inspections:i.docs.map((d)=>InspectionRecord.fromMap(d.data())).toList(),settings:meta.exists?BusinessSettings.fromMap(meta.data()!):const BusinessSettings(),audits:a.docs.map((d)=>AuditLog.fromMap(d.data())).toList());
  }

}
