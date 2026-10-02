enum EarningSource { inDrive, yango, offline, other }
enum EntryType { driving, income, expense }
enum VehicleStatus { available, rented, reserved, maintenance, inactive }
enum RentalStatus { reserved, active, completed, cancelled, overdue }
enum AdminRole { owner, manager, accountant, operator, viewer }

class BusinessSettings {
  final String businessName, phone, email, address, currency, footerNote;
  final double defaultTaxRate;
  final int updatedAtMs;
  const BusinessSettings({this.businessName='Hafeez Rent A Car',this.phone='',this.email='',this.address='',this.currency='PKR',this.footerNote='Thank you for choosing Hafeez Rent A Car.',this.defaultTaxRate=0, this.updatedAtMs=0});
  BusinessSettings copyWith({String? businessName,String? phone,String? email,String? address,String? currency,String? footerNote,double? defaultTaxRate,int? updatedAtMs})=>BusinessSettings(businessName:businessName??this.businessName,phone:phone??this.phone,email:email??this.email,address:address??this.address,currency:currency??this.currency,footerNote:footerNote??this.footerNote,defaultTaxRate:defaultTaxRate??this.defaultTaxRate,updatedAtMs:updatedAtMs??this.updatedAtMs);
  Map<String,dynamic> toMap()=>{'businessName':businessName,'phone':phone,'email':email,'address':address,'currency':currency,'footerNote':footerNote,'defaultTaxRate':defaultTaxRate,'updatedAtMs':updatedAtMs};
  factory BusinessSettings.fromMap(Map<String,dynamic> m)=>BusinessSettings(businessName:'${m['businessName']??'Hafeez Rent A Car'}',phone:'${m['phone']??''}',email:'${m['email']??''}',address:'${m['address']??''}',currency:'${m['currency']??'PKR'}',footerNote:'${m['footerNote']??'Thank you for choosing Hafeez Rent A Car.'}',defaultTaxRate:doubleValue(m['defaultTaxRate']),updatedAtMs:intValue(m['updatedAtMs']));
}

class AuditLog {
  final String id, action, entity, details, actorEmail;
  final DateTime date;
  final int updatedAtMs;
  const AuditLog({required this.id,required this.action,required this.entity,required this.details,this.actorEmail='',required this.date,this.updatedAtMs=0});
  Map<String,dynamic> toMap()=>{'id':id,'action':action,'entity':entity,'details':details,'actorEmail':actorEmail,'date':date.toIso8601String(),'updatedAtMs':updatedAtMs};
  factory AuditLog.fromMap(Map<String,dynamic> m)=>AuditLog(id:'${m['id']??''}',action:'${m['action']??''}',entity:'${m['entity']??''}',details:'${m['details']??''}',actorEmail:'${m['actorEmail']??''}',date:DateTime.tryParse('${m['date']??''}')??DateTime.now(),updatedAtMs:intValue(m['updatedAtMs'],DateTime.now().millisecondsSinceEpoch));
}

enumName(Object value) => value.toString().split('.').last;
EarningSource? earningSourceFrom(String? value) { if(value==null||value.isEmpty)return null; for(final e in EarningSource.values){if(enumName(e)==value)return e;} return EarningSource.other; }
EntryType entryTypeFrom(String? value) => EntryType.values.firstWhere((e) => enumName(e) == value, orElse: () => EntryType.income);
VehicleStatus vehicleStatusFrom(String? value) => VehicleStatus.values.firstWhere((e) => enumName(e) == value, orElse: () => VehicleStatus.available);
RentalStatus rentalStatusFrom(String? value) => RentalStatus.values.firstWhere((e) => enumName(e) == value, orElse: () => RentalStatus.active);
int intValue(dynamic value, [int fallback = 0]) => value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
double doubleValue(dynamic value, [double fallback = 0]) => value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

class Vehicle {
  final String id,name,plate,note,model,year,color,fuelType,chassisNumber,engineNumber,insuranceCompany,imagePath;
  final double currentMileage,purchasePrice,marketValue;
  final VehicleStatus status;
  final DateTime? registrationExpiry,insuranceExpiry,tokenExpiry,fitnessExpiry;
  final int schemaVersion,updatedAtMs;
  const Vehicle({required this.id,required this.name,this.plate='',this.note='',this.model='',this.year='',this.color='',this.fuelType='Petrol',this.currentMileage=0,this.status=VehicleStatus.available,this.schemaVersion=5,this.updatedAtMs=0,this.chassisNumber='',this.engineNumber='',this.insuranceCompany='',this.imagePath='',this.purchasePrice=0,this.marketValue=0,this.registrationExpiry,this.insuranceExpiry,this.tokenExpiry,this.fitnessExpiry});
  Vehicle copyWith({String? name,String? plate,String? note,String? model,String? year,String? color,String? fuelType,double? currentMileage,VehicleStatus? status,int? updatedAtMs,String? chassisNumber,String? engineNumber,String? insuranceCompany,String? imagePath,double? purchasePrice,double? marketValue,DateTime? registrationExpiry,DateTime? insuranceExpiry,DateTime? tokenExpiry,DateTime? fitnessExpiry}) => Vehicle(id:id,name:name??this.name,plate:plate??this.plate,note:note??this.note,model:model??this.model,year:year??this.year,color:color??this.color,fuelType:fuelType??this.fuelType,currentMileage:currentMileage??this.currentMileage,status:status??this.status,schemaVersion:schemaVersion,updatedAtMs:updatedAtMs??this.updatedAtMs,chassisNumber:chassisNumber??this.chassisNumber,engineNumber:engineNumber??this.engineNumber,insuranceCompany:insuranceCompany??this.insuranceCompany,imagePath:imagePath??this.imagePath,purchasePrice:purchasePrice??this.purchasePrice,marketValue:marketValue??this.marketValue,registrationExpiry:registrationExpiry??this.registrationExpiry,insuranceExpiry:insuranceExpiry??this.insuranceExpiry,tokenExpiry:tokenExpiry??this.tokenExpiry,fitnessExpiry:fitnessExpiry??this.fitnessExpiry);
  Map<String,dynamic> toMap()=>{'id':id,'name':name,'plate':plate,'note':note,'model':model,'year':year,'color':color,'fuelType':fuelType,'currentMileage':currentMileage,'status':enumName(status),'schemaVersion':schemaVersion,'updatedAtMs':updatedAtMs,'chassisNumber':chassisNumber,'engineNumber':engineNumber,'insuranceCompany':insuranceCompany,'imagePath':imagePath,'purchasePrice':purchasePrice,'marketValue':marketValue,'registrationExpiry':registrationExpiry?.toIso8601String(),'insuranceExpiry':insuranceExpiry?.toIso8601String(),'tokenExpiry':tokenExpiry?.toIso8601String(),'fitnessExpiry':fitnessExpiry?.toIso8601String()};
  factory Vehicle.fromMap(Map<String,dynamic> m)=>Vehicle(id:'${m['id']??''}',name:'${m['name']??'Vehicle'}',plate:'${m['plate']??''}',note:'${m['note']??''}',model:'${m['model']??''}',year:'${m['year']??''}',color:'${m['color']??''}',fuelType:'${m['fuelType']??'Petrol'}',currentMileage:doubleValue(m['currentMileage']),status:vehicleStatusFrom(m['status']?.toString()),schemaVersion:intValue(m['schemaVersion'],1),updatedAtMs:intValue(m['updatedAtMs'],DateTime.now().millisecondsSinceEpoch),chassisNumber:'${m['chassisNumber']??''}',engineNumber:'${m['engineNumber']??''}',insuranceCompany:'${m['insuranceCompany']??''}',imagePath:'${m['imagePath']??''}',purchasePrice:doubleValue(m['purchasePrice']),marketValue:doubleValue(m['marketValue']),registrationExpiry:DateTime.tryParse('${m['registrationExpiry']??''}'),insuranceExpiry:DateTime.tryParse('${m['insuranceExpiry']??''}'),tokenExpiry:DateTime.tryParse('${m['tokenExpiry']??''}'),fitnessExpiry:DateTime.tryParse('${m['fitnessExpiry']??''}'));
}

class Customer {
  final String id,name,fatherName,phone,cnic,address,licenseNumber,note,emergencyContact,cnicFrontPath,cnicBackPath,licensePath,photoPath;
  final DateTime? licenseExpiry;
  final int updatedAtMs;
  const Customer({required this.id,required this.name,this.fatherName='',this.phone='',this.cnic='',this.address='',this.licenseNumber='',this.licenseExpiry,this.note='',this.updatedAtMs=0,this.emergencyContact='',this.cnicFrontPath='',this.cnicBackPath='',this.licensePath='',this.photoPath=''});
  Map<String,dynamic> toMap()=>{'id':id,'name':name,'fatherName':fatherName,'phone':phone,'cnic':cnic,'address':address,'licenseNumber':licenseNumber,'licenseExpiry':licenseExpiry?.toIso8601String(),'note':note,'updatedAtMs':updatedAtMs,'emergencyContact':emergencyContact,'cnicFrontPath':cnicFrontPath,'cnicBackPath':cnicBackPath,'licensePath':licensePath,'photoPath':photoPath};
  factory Customer.fromMap(Map<String,dynamic> m)=>Customer(id:'${m['id']??''}',name:'${m['name']??''}',fatherName:'${m['fatherName']??''}',phone:'${m['phone']??''}',cnic:'${m['cnic']??''}',address:'${m['address']??''}',licenseNumber:'${m['licenseNumber']??''}',licenseExpiry:DateTime.tryParse('${m['licenseExpiry']??''}'),note:'${m['note']??''}',updatedAtMs:intValue(m['updatedAtMs'],DateTime.now().millisecondsSinceEpoch),emergencyContact:'${m['emergencyContact']??''}',cnicFrontPath:'${m['cnicFrontPath']??''}',cnicBackPath:'${m['cnicBackPath']??''}',licensePath:'${m['licensePath']??''}',photoPath:'${m['photoPath']??''}');
}

class Rental {
  final String id,customerId,vehicleId,note,pickupLocation,returnLocation,paymentMethod,cancellationReason;
  final DateTime startAt,endAt;
  final DateTime? actualReturnAt;
  final double dailyRate,totalRent,advance,securityDeposit,paidAmount,discount,tax,lateFee,damageFee,extraMileage,mileageLimit,depositRefunded;
  final RentalStatus status;
  final int updatedAtMs;
  const Rental({required this.id,required this.customerId,required this.vehicleId,required this.startAt,required this.endAt,required this.dailyRate,required this.totalRent,this.advance=0,this.securityDeposit=0,this.paidAmount=0,this.status=RentalStatus.active,this.note='',this.updatedAtMs=0,this.pickupLocation='',this.returnLocation='',this.paymentMethod='Cash',this.discount=0,this.tax=0,this.lateFee=0,this.damageFee=0,this.extraMileage=0,this.mileageLimit=0,this.actualReturnAt,this.depositRefunded=0,this.cancellationReason=''});
  double get totalPayable => (totalRent + tax + lateFee + damageFee - discount).clamp(0,double.infinity).toDouble();
  double get remaining => (totalPayable-paidAmount).clamp(0,double.infinity).toDouble();
  double get depositBalance => (securityDeposit-depositRefunded).clamp(0,double.infinity).toDouble();
  Rental copyWith({String? customerId,String? vehicleId,DateTime? startAt,DateTime? endAt,double? dailyRate,double? totalRent,double? advance,double? securityDeposit,double? paidAmount,RentalStatus? status,String? note,int? updatedAtMs,String? pickupLocation,String? returnLocation,String? paymentMethod,double? discount,double? tax,double? lateFee,double? damageFee,double? extraMileage,double? mileageLimit,DateTime? actualReturnAt,double? depositRefunded,String? cancellationReason})=>Rental(id:id,customerId:customerId??this.customerId,vehicleId:vehicleId??this.vehicleId,startAt:startAt??this.startAt,endAt:endAt??this.endAt,dailyRate:dailyRate??this.dailyRate,totalRent:totalRent??this.totalRent,advance:advance??this.advance,securityDeposit:securityDeposit??this.securityDeposit,paidAmount:paidAmount??this.paidAmount,status:status??this.status,note:note??this.note,updatedAtMs:updatedAtMs??this.updatedAtMs,pickupLocation:pickupLocation??this.pickupLocation,returnLocation:returnLocation??this.returnLocation,paymentMethod:paymentMethod??this.paymentMethod,discount:discount??this.discount,tax:tax??this.tax,lateFee:lateFee??this.lateFee,damageFee:damageFee??this.damageFee,extraMileage:extraMileage??this.extraMileage,mileageLimit:mileageLimit??this.mileageLimit,actualReturnAt:actualReturnAt??this.actualReturnAt,depositRefunded:depositRefunded??this.depositRefunded,cancellationReason:cancellationReason??this.cancellationReason);
  Map<String,dynamic> toMap()=>{'id':id,'customerId':customerId,'vehicleId':vehicleId,'startAt':startAt.toIso8601String(),'endAt':endAt.toIso8601String(),'dailyRate':dailyRate,'totalRent':totalRent,'advance':advance,'securityDeposit':securityDeposit,'paidAmount':paidAmount,'status':enumName(status),'note':note,'updatedAtMs':updatedAtMs,'pickupLocation':pickupLocation,'returnLocation':returnLocation,'paymentMethod':paymentMethod,'discount':discount,'tax':tax,'lateFee':lateFee,'damageFee':damageFee,'extraMileage':extraMileage,'mileageLimit':mileageLimit,'actualReturnAt':actualReturnAt?.toIso8601String(),'depositRefunded':depositRefunded,'cancellationReason':cancellationReason};
  factory Rental.fromMap(Map<String,dynamic> m)=>Rental(id:'${m['id']??''}',customerId:'${m['customerId']??''}',vehicleId:'${m['vehicleId']??''}',startAt:DateTime.tryParse('${m['startAt']??''}')??DateTime.now(),endAt:DateTime.tryParse('${m['endAt']??''}')??DateTime.now(),dailyRate:doubleValue(m['dailyRate']),totalRent:doubleValue(m['totalRent']),advance:doubleValue(m['advance']),securityDeposit:doubleValue(m['securityDeposit']),paidAmount:doubleValue(m['paidAmount']),status:rentalStatusFrom(m['status']?.toString()),note:'${m['note']??''}',updatedAtMs:intValue(m['updatedAtMs'],DateTime.now().millisecondsSinceEpoch),pickupLocation:'${m['pickupLocation']??''}',returnLocation:'${m['returnLocation']??''}',paymentMethod:'${m['paymentMethod']??'Cash'}',discount:doubleValue(m['discount']),tax:doubleValue(m['tax']),lateFee:doubleValue(m['lateFee']),damageFee:doubleValue(m['damageFee']),extraMileage:doubleValue(m['extraMileage']),mileageLimit:doubleValue(m['mileageLimit']),actualReturnAt:DateTime.tryParse('${m['actualReturnAt']??''}'),depositRefunded:doubleValue(m['depositRefunded']),cancellationReason:'${m['cancellationReason']??''}');
}

class InspectionRecord {
  final String id, rentalId, vehicleId, stage, fuelLevel, condition, note;
  final double mileage, damageCharge;
  final DateTime date;
  final int updatedAtMs;
  const InspectionRecord({required this.id,required this.rentalId,required this.vehicleId,required this.stage,required this.mileage,this.fuelLevel='Full',this.condition='Good',this.damageCharge=0,this.note='',required this.date,this.updatedAtMs=0});
  Map<String,dynamic> toMap()=>{'id':id,'rentalId':rentalId,'vehicleId':vehicleId,'stage':stage,'mileage':mileage,'fuelLevel':fuelLevel,'condition':condition,'damageCharge':damageCharge,'note':note,'date':date.toIso8601String(),'updatedAtMs':updatedAtMs};
  factory InspectionRecord.fromMap(Map<String,dynamic> m)=>InspectionRecord(id:'${m['id']??''}',rentalId:'${m['rentalId']??''}',vehicleId:'${m['vehicleId']??''}',stage:'${m['stage']??'Return'}',mileage:doubleValue(m['mileage']),fuelLevel:'${m['fuelLevel']??'Full'}',condition:'${m['condition']??'Good'}',damageCharge:doubleValue(m['damageCharge']),note:'${m['note']??''}',date:DateTime.tryParse('${m['date']??''}')??DateTime.now(),updatedAtMs:intValue(m['updatedAtMs'],DateTime.now().millisecondsSinceEpoch));
}

class PaymentRecord {
  final String id, rentalId, customerId, vehicleId, method, reference, note;
  final double amount;
  final DateTime date;
  final int updatedAtMs;
  const PaymentRecord({required this.id,required this.rentalId,required this.customerId,required this.vehicleId,required this.amount,required this.date,this.method='Cash',this.reference='',this.note='',this.updatedAtMs=0});
  Map<String,dynamic> toMap()=>{'id':id,'rentalId':rentalId,'customerId':customerId,'vehicleId':vehicleId,'amount':amount,'date':date.toIso8601String(),'method':method,'reference':reference,'note':note,'updatedAtMs':updatedAtMs};
  factory PaymentRecord.fromMap(Map<String,dynamic> m)=>PaymentRecord(id:'${m['id']??''}',rentalId:'${m['rentalId']??''}',customerId:'${m['customerId']??''}',vehicleId:'${m['vehicleId']??''}',amount:doubleValue(m['amount']),date:DateTime.tryParse('${m['date']??''}')??DateTime.now(),method:'${m['method']??'Cash'}',reference:'${m['reference']??''}',note:'${m['note']??''}',updatedAtMs:intValue(m['updatedAtMs'],DateTime.now().millisecondsSinceEpoch));
}

class DriverSettlement {
  final String id, driverId, periodLabel, note;
  final double grossEarnings, salary, commission, advances, deductions;
  final DateTime date;
  final int updatedAtMs;
  const DriverSettlement({required this.id,required this.driverId,required this.periodLabel,required this.grossEarnings,this.salary=0,this.commission=0,this.advances=0,this.deductions=0,required this.date,this.note='',this.updatedAtMs=0});
  double get netPayable => (salary + commission + grossEarnings - advances - deductions).clamp(0,double.infinity).toDouble();
  Map<String,dynamic> toMap()=>{'id':id,'driverId':driverId,'periodLabel':periodLabel,'grossEarnings':grossEarnings,'salary':salary,'commission':commission,'advances':advances,'deductions':deductions,'date':date.toIso8601String(),'note':note,'updatedAtMs':updatedAtMs};
  factory DriverSettlement.fromMap(Map<String,dynamic> m)=>DriverSettlement(id:'${m['id']??''}',driverId:'${m['driverId']??''}',periodLabel:'${m['periodLabel']??''}',grossEarnings:doubleValue(m['grossEarnings']),salary:doubleValue(m['salary']),commission:doubleValue(m['commission']),advances:doubleValue(m['advances']),deductions:doubleValue(m['deductions']),date:DateTime.tryParse('${m['date']??''}')??DateTime.now(),note:'${m['note']??''}',updatedAtMs:intValue(m['updatedAtMs'],DateTime.now().millisecondsSinceEpoch));
}

class MaintenanceRecord { final String id,vehicleId,type,workshop,note; final double cost,mileage; final DateTime date,nextService; final int updatedAtMs; const MaintenanceRecord({required this.id,required this.vehicleId,required this.type,required this.cost,required this.date,this.mileage=0,this.workshop='',this.nextService=const DateTime(2100),this.note='',this.updatedAtMs=0}); Map<String,dynamic> toMap()=>{'id':id,'vehicleId':vehicleId,'type':type,'cost':cost,'date':date.toIso8601String(),'mileage':mileage,'workshop':workshop,'nextService':nextService.toIso8601String(),'note':note,'updatedAtMs':updatedAtMs}; factory MaintenanceRecord.fromMap(Map<String,dynamic> m)=>MaintenanceRecord(id:'${m['id']??''}',vehicleId:'${m['vehicleId']??''}',type:'${m['type']??'Service'}',cost:doubleValue(m['cost']),date:DateTime.tryParse('${m['date']??''}')??DateTime.now(),mileage:doubleValue(m['mileage']),workshop:'${m['workshop']??''}',nextService:DateTime.tryParse('${m['nextService']??''}')??DateTime(2100),note:'${m['note']??''}',updatedAtMs:intValue(m['updatedAtMs'],DateTime.now().millisecondsSinceEpoch)); }
class FuelRecord { final String id,vehicleId,station,note; final double litres,amount,mileage; final DateTime date; final int updatedAtMs; const FuelRecord({required this.id,required this.vehicleId,required this.litres,required this.amount,required this.date,this.mileage=0,this.station='',this.note='',this.updatedAtMs=0}); Map<String,dynamic> toMap()=>{'id':id,'vehicleId':vehicleId,'litres':litres,'amount':amount,'date':date.toIso8601String(),'mileage':mileage,'station':station,'note':note,'updatedAtMs':updatedAtMs}; factory FuelRecord.fromMap(Map<String,dynamic> m)=>FuelRecord(id:'${m['id']??''}',vehicleId:'${m['vehicleId']??''}',litres:doubleValue(m['litres']),amount:doubleValue(m['amount']),date:DateTime.tryParse('${m['date']??''}')??DateTime.now(),mileage:doubleValue(m['mileage']),station:'${m['station']??''}',note:'${m['note']??''}',updatedAtMs:intValue(m['updatedAtMs'],DateTime.now().millisecondsSinceEpoch)); }


class Driver {
  final String id, name, phone, cnic, licenseNumber, address, note, vehicleId;
  final DateTime? licenseExpiry;
  final double salary, commissionRate;
  final bool active;
  final int updatedAtMs;
  const Driver({required this.id, required this.name, this.phone='', this.cnic='', this.licenseNumber='', this.licenseExpiry, this.address='', this.note='', this.vehicleId='', this.salary=0, this.commissionRate=0, this.active=true, this.updatedAtMs=0});
  Driver copyWith({String? name,String? phone,String? cnic,String? licenseNumber,DateTime? licenseExpiry,String? address,String? note,String? vehicleId,double? salary,double? commissionRate,bool? active,int? updatedAtMs}) => Driver(id:id,name:name??this.name,phone:phone??this.phone,cnic:cnic??this.cnic,licenseNumber:licenseNumber??this.licenseNumber,licenseExpiry:licenseExpiry??this.licenseExpiry,address:address??this.address,note:note??this.note,vehicleId:vehicleId??this.vehicleId,salary:salary??this.salary,commissionRate:commissionRate??this.commissionRate,active:active??this.active,updatedAtMs:updatedAtMs??this.updatedAtMs);
  Map<String,dynamic> toMap()=>{'id':id,'name':name,'phone':phone,'cnic':cnic,'licenseNumber':licenseNumber,'licenseExpiry':licenseExpiry?.toIso8601String(),'address':address,'note':note,'vehicleId':vehicleId,'salary':salary,'commissionRate':commissionRate,'active':active,'updatedAtMs':updatedAtMs};
  factory Driver.fromMap(Map<String,dynamic> m)=>Driver(id:'${m['id']??''}',name:'${m['name']??''}',phone:'${m['phone']??''}',cnic:'${m['cnic']??''}',licenseNumber:'${m['licenseNumber']??''}',licenseExpiry:DateTime.tryParse('${m['licenseExpiry']??''}'),address:'${m['address']??''}',note:'${m['note']??''}',vehicleId:'${m['vehicleId']??''}',salary:doubleValue(m['salary']),commissionRate:doubleValue(m['commissionRate']),active:m['active'] is bool ? m['active'] as bool : true,updatedAtMs:intValue(m['updatedAtMs'],DateTime.now().millisecondsSinceEpoch));
}
