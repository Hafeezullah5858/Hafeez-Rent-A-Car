import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crypto/crypto.dart';

const gold = Color(0xFFE7B84E);
const bg = Color(0xFF070B10);
const panel = Color(0xFF101923);
const panel2 = Color(0xFF172331);
const muted = Color(0xFF8FA0B3);

String uid() => DateTime.now().microsecondsSinceEpoch.toString();
String money(double n) => 'Rs. ${n.toStringAsFixed(0)}';
String today() => DateTime.now().toIso8601String().substring(0, 10);
String? validEmail(String v) { final x=v.trim(); if(x.isEmpty) return 'Email is required'; if(!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(x)) return 'Enter a valid email address'; return null; }
String? validPhone(String v) { final x=v.replaceAll(RegExp(r'[\s-]'), ''); if(!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(x)) return 'Enter a valid mobile number'; return null; }
String? validCnic(String v) { final x=v.trim(); if(x.isEmpty) return 'CNIC is required'; if(!RegExp(r'^\d{5}-?\d{7}-?\d$').hasMatch(x)) return 'CNIC format: 35202-1234567-1'; return null; }
String? validPassword(String v) { if(v.length<8) return 'Password must be at least 8 characters'; if(!RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(v)) return 'Use letters and numbers in password'; return null; }
double numVal(String s) => double.tryParse(s.replaceAll(',', '').trim()) ?? 0;
String hashPassword(String value) => 'sha256:' + sha256.convert(utf8.encode(value)).toString();
bool passwordMatches(String stored,String value){final hashed=hashPassword(value);return stored==hashed||stored==value;}


class Vehicle {
  String id, name, reg, year, fuel, status, mileage, insuranceExpiry, registrationExpiry, note;
  Vehicle({required this.id, required this.name, required this.reg, required this.year, required this.fuel, required this.status, this.mileage='', this.insuranceExpiry='', this.registrationExpiry='', this.note=''});
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'reg':reg,'year':year,'fuel':fuel,'status':status,'mileage':mileage,'insuranceExpiry':insuranceExpiry,'registrationExpiry':registrationExpiry,'note':note};
  factory Vehicle.fromJson(Map<String,dynamic> j)=>Vehicle(id:j['id']??uid(),name:j['name']??'',reg:j['reg']??'',year:j['year']??'',fuel:j['fuel']??'Petrol',status:j['status']??'Available',mileage:j['mileage']??'',insuranceExpiry:j['insuranceExpiry']??'',registrationExpiry:j['registrationExpiry']??'',note:j['note']??'');
}
class Client {
  String id,name,phone,email,cnic,address,note,licenseNumber,licenseExpiry;
  Client({required this.id,required this.name,required this.phone,required this.email,required this.cnic,required this.address,required this.note,this.licenseNumber='',this.licenseExpiry=''});
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'phone':phone,'email':email,'cnic':cnic,'address':address,'note':note,'licenseNumber':licenseNumber,'licenseExpiry':licenseExpiry};
  factory Client.fromJson(Map<String,dynamic> j)=>Client(id:j['id']??uid(),name:j['name']??'',phone:j['phone']??'',email:j['email']??'',cnic:j['cnic']??'',address:j['address']??'',note:j['note']??'',licenseNumber:j['licenseNumber']??'',licenseExpiry:j['licenseExpiry']??'');
}
class Rental {
  String id,clientId,vehicleId,pickupDate,returnDate,status,note,driverId,paymentMethod,createdAt;
  double dailyRate,total,advance,remaining,securityDeposit;
  Rental({required this.id,required this.clientId,required this.vehicleId,required this.pickupDate,required this.returnDate,required this.status,required this.dailyRate,required this.total,required this.advance,required this.remaining,required this.note,this.driverId='',this.paymentMethod='Cash',this.securityDeposit=0,this.createdAt=''});
  Map<String,dynamic> toJson()=>{'id':id,'clientId':clientId,'vehicleId':vehicleId,'pickupDate':pickupDate,'returnDate':returnDate,'status':status,'dailyRate':dailyRate,'total':total,'advance':advance,'remaining':remaining,'note':note,'driverId':driverId,'paymentMethod':paymentMethod,'securityDeposit':securityDeposit,'createdAt':createdAt};
  factory Rental.fromJson(Map<String,dynamic> j)=>Rental(id:j['id']??uid(),clientId:j['clientId']??'',vehicleId:j['vehicleId']??'',pickupDate:j['pickupDate']??'',returnDate:j['returnDate']??'',status:j['status']??'Active',dailyRate:numVal('${j['dailyRate']??0}'),total:numVal('${j['total']??0}'),advance:numVal('${j['advance']??0}'),remaining:numVal('${j['remaining']??0}'),note:j['note']??'',driverId:j['driverId']??'',paymentMethod:j['paymentMethod']??'Cash',securityDeposit:numVal('${j['securityDeposit']??0}'),createdAt:j['createdAt']??'');
}
class Entry {
  String id,type,vehicle,title,date,note,category,referenceId; double amount;
  Entry({required this.id,required this.type,required this.vehicle,required this.title,required this.amount,required this.date,required this.note,this.category='General',this.referenceId=''});
  Map<String,dynamic> toJson()=>{'id':id,'type':type,'vehicle':vehicle,'title':title,'amount':amount,'date':date,'note':note,'category':category,'referenceId':referenceId};
  factory Entry.fromJson(Map<String,dynamic> j)=>Entry(id:j['id']??uid(),type:j['type']??'Expense',vehicle:j['vehicle']??'General',title:j['title']??'',amount:numVal('${j['amount']??0}'),date:j['date']??today(),note:j['note']??'',category:j['category']??'General',referenceId:j['referenceId']??'');
}

class Ride {
  String id, source, serviceType, vehicleId, driverId, customerName, customerPhone, pickup, dropoff, date, paymentMethod, status, note;
  double distanceKm, fare, platformCommission, fuelExpense, tollExpense, driverExpense, otherExpense;
  Ride({required this.id,required this.source,required this.serviceType,required this.vehicleId,required this.driverId,required this.customerName,required this.customerPhone,required this.pickup,required this.dropoff,required this.date,required this.distanceKm,required this.fare,required this.platformCommission,required this.fuelExpense,required this.tollExpense,required this.driverExpense,required this.otherExpense,required this.paymentMethod,required this.status,required this.note});
  double get totalExpense=>platformCommission+fuelExpense+tollExpense+driverExpense+otherExpense;
  double get netProfit=>fare-totalExpense;
  Map<String,dynamic> toJson()=>{'id':id,'source':source,'serviceType':serviceType,'vehicleId':vehicleId,'driverId':driverId,'customerName':customerName,'customerPhone':customerPhone,'pickup':pickup,'dropoff':dropoff,'date':date,'distanceKm':distanceKm,'fare':fare,'platformCommission':platformCommission,'fuelExpense':fuelExpense,'tollExpense':tollExpense,'driverExpense':driverExpense,'otherExpense':otherExpense,'paymentMethod':paymentMethod,'status':status,'note':note};
  factory Ride.fromJson(Map<String,dynamic> j)=>Ride(id:j['id']??uid(),source:j['source']??'Offline',serviceType:j['serviceType']??'Local Ride',vehicleId:j['vehicleId']??'',driverId:j['driverId']??'',customerName:j['customerName']??'',customerPhone:j['customerPhone']??'',pickup:j['pickup']??'',dropoff:j['dropoff']??'',date:j['date']??today(),distanceKm:numVal('${j['distanceKm']??0}'),fare:numVal('${j['fare']??0}'),platformCommission:numVal('${j['platformCommission']??0}'),fuelExpense:numVal('${j['fuelExpense']??0}'),tollExpense:numVal('${j['tollExpense']??0}'),driverExpense:numVal('${j['driverExpense']??0}'),otherExpense:numVal('${j['otherExpense']??0}'),paymentMethod:j['paymentMethod']??'Cash',status:j['status']??'Completed',note:j['note']??'');
}
class AuthUser {
  String id, name, password, role, phone, email, cnic, address; bool verified;
  AuthUser({required this.id, required this.name, required this.password, required this.role, this.phone = '', this.email = '', this.cnic = '', this.address = '', this.verified = false});
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'password':password,'role':role,'phone':phone,'email':email,'cnic':cnic,'address':address,'verified':verified};
  factory AuthUser.fromJson(Map<String,dynamic> j)=>AuthUser(id:j['id']??'',name:j['name']??'',password:j['password']??'',role:j['role']??'Customer',phone:j['phone']??'',email:j['email']??'',cnic:j['cnic']??'',address:j['address']??'',verified:j['verified']??false);
}

void main()=>runApp(const HafeezApp());
class HafeezApp extends StatefulWidget{const HafeezApp({super.key});@override State<HafeezApp> createState()=>_AppState();}
class _AppState extends State<HafeezApp>{
 bool ready=false; String role=''; String loggedId=''; String email='admin@hafeezrentacar.com',password='123456';
 List<AuthUser> customers=[],drivers=[];
 List<Vehicle> vehicles=[];List<Client> clients=[];List<Rental> rentals=[];List<Entry> entries=[];List<Ride> rides=[];
 @override void initState(){super.initState();load();}
 Future<void> load() async{final p=await SharedPreferences.getInstance();email=p.getString('admin_email')??email;password=p.getString('admin_password')??password;if(!password.startsWith('sha256:')){password=hashPassword(password);}customers=_decode(p.getStringList('customers'),AuthUser.fromJson);drivers=_decode(p.getStringList('drivers'),AuthUser.fromJson);for(final u in [...customers,...drivers]){if(!u.password.startsWith('sha256:'))u.password=hashPassword(u.password);}vehicles=_decode(p.getStringList('vehicles'),Vehicle.fromJson);clients=_decode(p.getStringList('clients'),Client.fromJson);rentals=_decode(p.getStringList('rentals'),Rental.fromJson);entries=_decode(p.getStringList('entries'),Entry.fromJson);rides=_decode(p.getStringList('rides'),Ride.fromJson);await p.setString('admin_password',password);if(vehicles.isEmpty){vehicles=[Vehicle(id:'1',name:'Suzuki Alto VXR',reg:'BEF-275',year:'2020',fuel:'Petrol',status:'Available'),Vehicle(id:'2',name:'Suzuki Alto VXR+',reg:'BBH-513',year:'2021',fuel:'Petrol',status:'Available'),Vehicle(id:'3',name:'Suzuki Alto VXR',reg:'UD-159',year:'2020',fuel:'Petrol',status:'Available'),Vehicle(id:'4',name:'Suzuki Alto VXR',reg:'BQX-327',year:'2021',fuel:'Petrol',status:'Available')];await save();}role=p.getString('logged_role')??'';loggedId=p.getString('logged_id')??'';setState(()=>ready=true);}
 List<T> _decode<T>(List<String>? xs,T Function(Map<String,dynamic>) f)=>(xs??[]).map((x)=>f(jsonDecode(x))).toList();
 Future<void> save()async{final p=await SharedPreferences.getInstance();await p.setStringList('customers',customers.map((x)=>jsonEncode(x.toJson())).toList());await p.setStringList('drivers',drivers.map((x)=>jsonEncode(x.toJson())).toList());await p.setStringList('vehicles',vehicles.map((x)=>jsonEncode(x.toJson())).toList());await p.setStringList('clients',clients.map((x)=>jsonEncode(x.toJson())).toList());await p.setStringList('rentals',rentals.map((x)=>jsonEncode(x.toJson())).toList());await p.setStringList('entries',entries.map((x)=>jsonEncode(x.toJson())).toList());await p.setStringList('rides',rides.map((x)=>jsonEncode(x.toJson())).toList());await p.setString('admin_email',email);await p.setString('admin_password',password);}
 Future<bool> adminLogin(String e,String pw)async{if(e.trim().toLowerCase()==email.toLowerCase()&&passwordMatches(password,pw)){await _setRole('Admin',email);return true;}return false;}
 Future<bool> userLogin(String id,String pw,String wantedRole)async{final list=wantedRole=='Customer'?customers:drivers;final q=id.trim().toLowerCase();final u=list.where((x)=>x.id.toLowerCase()==q||x.email.toLowerCase()==q).toList();if(u.isNotEmpty&&passwordMatches(u.first.password,pw)){await _setRole(wantedRole,u.first.id);return true;}return false;}
 Future<void> _setRole(String r,String id)async{final p=await SharedPreferences.getInstance();await p.setString('logged_role',r);await p.setString('logged_id',id);setState((){role=r;loggedId=id;});}
 Future<void> logout()async{final p=await SharedPreferences.getInstance();await p.setString('logged_role','');await p.setString('logged_id','');setState((){role='';loggedId='';});}
 Future<bool> signUp(String id,String name,String pw,String wantedRole,String phone,String email,String cnic,String address)async{final list=wantedRole=='Customer'?customers:drivers;if(id.trim().length<4||name.trim().length<3||validPassword(pw)!=null||validEmail(email)!=null||validPhone(phone)!=null||validCnic(cnic)!=null||address.trim().length<8)return false;if(list.any((x)=>x.id.toLowerCase()==id.trim().toLowerCase()||x.email.toLowerCase()==email.trim().toLowerCase()))return false;list.add(AuthUser(id:id.trim(),name:name.trim(),password:hashPassword(pw),role:wantedRole,phone:phone.trim(),email:email.trim().toLowerCase(),cnic:cnic.trim(),address:address.trim()));await save();return true;}
 Future<bool> resetPassword(String id,String newPw,String wantedRole)async{if(newPw.length<6)return false;final list=wantedRole=='Customer'?customers:drivers;final matches=list.where((x)=>x.id.toLowerCase()==id.trim().toLowerCase()).toList();if(matches.isEmpty)return false;matches.first.password=hashPassword(newPw);await save();return true;}
 Future<void> adminChange(String e,String pw)async{email=e;password=hashPassword(pw);await save();setState((){});}
 @override Widget build(BuildContext c){if(!ready)return const Splash();if(role=='Admin')return MaterialApp(debugShowCheckedModeBanner:false,theme:theme,home:Home(app:this));if(role=='Customer')return MaterialApp(debugShowCheckedModeBanner:false,theme:theme,home:CustomerPortal(app:this));if(role=='Driver')return MaterialApp(debugShowCheckedModeBanner:false,theme:theme,home:DriverPortal(app:this));return MaterialApp(debugShowCheckedModeBanner:false,theme:theme,home:RoleHome(app:this));}
}
final theme=ThemeData(useMaterial3:true,brightness:Brightness.dark,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:gold,brightness:Brightness.dark),cardTheme:CardThemeData(color:panel,margin:EdgeInsets.zero,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:const BorderSide(color:Colors.white12)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:const BorderSide(color:Colors.white12)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:const BorderSide(color:gold,width:1.3)),contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14)),appBarTheme:const AppBarTheme(backgroundColor:bg,foregroundColor:Colors.white,elevation:0));
class Splash extends StatelessWidget{const Splash({super.key});@override Widget build(BuildContext c)=>Scaffold(body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Image.asset('assets/hafeez_horizontal_logo.png',width:260),const SizedBox(height:28),const Text('PREMIUM CAR RENTAL & FLEET MANAGEMENT',style:TextStyle(color:muted,fontSize:11,letterSpacing:1.3)),const SizedBox(height:28),const SizedBox(width:110,child:LinearProgressIndicator(color:gold,backgroundColor:Colors.white12))])));}
class Login extends StatefulWidget{final String email;final Future<bool> Function(String,String) onLogin;const Login({super.key,required this.email,required this.onLogin});@override State<Login> createState()=>_LoginState();}
class _LoginState extends State<Login>{final e=TextEditingController(),p=TextEditingController();bool hide=true,busy=false;@override void initState(){super.initState();e.text=widget.email;}@override Widget build(BuildContext c)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Column(children:[const SizedBox(height:20),Image(image:AssetImage('assets/hafeez_horizontal_logo.png'),width:270),const SizedBox(height:28),const Align(alignment:Alignment.centerLeft,child:Text('Welcome Back',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900))),const Align(alignment:Alignment.centerLeft,child:Text('Login to your account to continue',style:TextStyle(color:muted))),const SizedBox(height:24),TextField(controller:e,decoration:const InputDecoration(labelText:'Email Address',prefixIcon:Icon(Icons.alternate_email,color:gold))),const SizedBox(height:12),TextField(controller:p,obscureText:hide,decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline,color:gold),suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide),icon:Icon(hide?Icons.visibility_off:Icons.visibility)))),const SizedBox(height:18),SizedBox(width:double.infinity,height:52,child:FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);final ok=await widget.onLogin(e.text,p.text);if(mounted){setState(()=>busy=false);if(!ok)ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Incorrect email or password.')));}},style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:Text(busy?'Signing in...':'Login'))),const SizedBox(height:20),const Text('Default first-login: admin@hafeezrentacar.com / 123456',style:TextStyle(color:muted,fontSize:11))]))))));}


class RoleHome extends StatelessWidget {
  final _AppState app;
  const RoleHome({super.key, required this.app});
  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const SizedBox(height: 25),
                  const Image(image: AssetImage('assets/hafeez_horizontal_logo.png'), width: 275),
                  const SizedBox(height: 14),
                  const Text('Welcome to Hafeez Rent A Car', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Select your account type to continue', style: TextStyle(color: muted)),
                  const SizedBox(height: 25),
                  RoleCard(icon: Icons.admin_panel_settings, title: 'Admin Login', subtitle: 'Manage fleet, rentals, customers and accounts', onTap: () => openAuth(c, app, 'Admin')),
                  RoleCard(icon: Icons.person_outline, title: 'Customer Login', subtitle: 'Book cars, view rentals and account details', onTap: () => openAuth(c, app, 'Customer')),
                  RoleCard(icon: Icons.drive_eta, title: 'Driver Login', subtitle: 'View assigned work and driver information', onTap: () => openAuth(c, app, 'Driver')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class RoleCard extends StatelessWidget{final IconData icon;final String title,subtitle;final VoidCallback onTap;const RoleCard({super.key,required this.icon,required this.title,required this.subtitle,required this.onTap});@override Widget build(BuildContext c)=>Card(margin:const EdgeInsets.only(bottom:12),child:ListTile(onTap:onTap,contentPadding:const EdgeInsets.all(15),leading:CircleAvatar(radius:25,backgroundColor:gold.withValues(alpha: .15),child:Icon(icon,color:gold)),title:Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),subtitle:Padding(padding:const EdgeInsets.only(top:4),child:Text(subtitle,style:const TextStyle(color:muted,fontSize:11))),trailing:const Icon(Icons.arrow_forward_ios,size:16)));}

void openAuth(BuildContext c,_AppState app,String role)=>Navigator.push(c,MaterialPageRoute(builder:(_)=>AuthPage(app:app,role:role)));

class AuthPage extends StatefulWidget{final _AppState app;final String role;const AuthPage({super.key,required this.app,required this.role});@override State<AuthPage> createState()=>_AuthPageState();}
class _AuthPageState extends State<AuthPage>{final form=GlobalKey<FormState>();late TextEditingController id,name,pw,phone,email,cnic,address,confirm;bool hide=true,busy=false;@override void initState(){super.initState();id=TextEditingController();name=TextEditingController();pw=TextEditingController();phone=TextEditingController();email=TextEditingController();cnic=TextEditingController();address=TextEditingController();confirm=TextEditingController();}
@override void dispose(){for(final x in [id,name,pw,phone,email,cnic,address,confirm])x.dispose();super.dispose();}
String get title=>widget.role=='Admin'?'Admin Login':widget.role=='Customer'?'Customer Login':'Driver Login';
String? req(String v,String label)=>v.trim().isEmpty?'$label is required':null;
Future<void> submit()async{if(form.currentState?.validate()!=true)return;setState(()=>busy=true);bool ok;if(widget.role=='Admin'){ok=await widget.app.adminLogin(email.text,pw.text);}else{ok=await widget.app.userLogin(id.text,pw.text,widget.role);}if(mounted){setState(()=>busy=false);if(ok)Navigator.pop(context);else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Invalid login details. Please check your ID/email and password.')));}}
Future<void> signup()async{if(widget.role=='Admin'){await _adminSignup();return;}final ok=await showDialog<bool>(context:context,builder:(_)=>_SignupDialog(role:widget.role,onCreate:(v)=>widget.app.signUp(v.id,v.name,v.password,widget.role,v.phone,v.email,v.cnic,v.address)));if(mounted&&ok==true)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Account created successfully. You can now login with your ID or email.')));}
Future<void> _adminSignup()async{final e=TextEditingController(text:email.text),p=TextEditingController(),cp=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Admin Sign Up'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:e,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Admin Email')),const SizedBox(height:10),TextField(controller:p,obscureText:true,decoration:const InputDecoration(labelText:'Password (8+ chars, letters + numbers)')),const SizedBox(height:10),TextField(controller:cp,obscureText:true,decoration:const InputDecoration(labelText:'Confirm Password'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:(){if(validEmail(e.text)!=null||validPassword(p.text)!=null||p.text!=cp.text)return;Navigator.pop(context,true);},style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:const Text('Create'))]));if(ok==true){await widget.app.adminChange(e.text.trim().toLowerCase(),p.text);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Admin account updated successfully.')));}}
Future<void> reset()async{final rid=TextEditingController(text:id.text),em=TextEditingController(text:email.text),mobile=TextEditingController(text:phone.text),np=TextEditingController(),cp=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Secure Password Reset'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:rid,decoration:InputDecoration(labelText:widget.role=='Admin'?'Admin ID / Email':'Account ID')),if(widget.role!='Admin')... [const SizedBox(height:10),TextField(controller:em,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Registered Email')),const SizedBox(height:10),TextField(controller:mobile,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Registered Mobile'))],const SizedBox(height:10),TextField(controller:np,obscureText:true,decoration:const InputDecoration(labelText:'New Password')),const SizedBox(height:10),TextField(controller:cp,obscureText:true,decoration:const InputDecoration(labelText:'Confirm New Password'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:(){if(validPassword(np.text)!=null||np.text!=cp.text||rid.text.trim().isEmpty)return;Navigator.pop(context,true);},style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:const Text('Reset'))]));if(ok!=true)return;if(widget.role=='Admin'){if(rid.text.trim().toLowerCase()==widget.app.email.toLowerCase()||em.text.trim().toLowerCase()==widget.app.email.toLowerCase()){await widget.app.adminChange(widget.app.email,np.text);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Admin password reset successfully.')));}else if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Admin email not found.')));}else{final list=widget.role=='Customer'?widget.app.customers:widget.app.drivers;final q=rid.text.trim().toLowerCase();final u=list.where((x)=>(x.id.toLowerCase()==q||x.email.toLowerCase()==q)&&x.email.toLowerCase()==em.text.trim().toLowerCase()&&x.phone.replaceAll(RegExp(r'[\s-]'),'')==mobile.text.replaceAll(RegExp(r'[\s-]'),'')).toList();if(u.isNotEmpty){u.first.password=hashPassword(np.text);await widget.app.save();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Password reset successfully.')));}else if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Verification failed. ID, email and mobile must match your account.')));}}
@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(title)),body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:Form(key:form,child:Column(children:[const SizedBox(height:15),const Image(image:AssetImage('assets/hafeez_horizontal_logo.png'),width:250),const SizedBox(height:22),Text(title,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(widget.role=='Admin'?'Full business administration':widget.role=='Customer'?'Professional customer account':'Professional driver account',style:const TextStyle(color:muted)),const SizedBox(height:24),if(widget.role=='Admin')... [TextFormField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Admin Email',prefixIcon:Icon(Icons.email_outlined,color:gold)),validator:(v)=>validEmail(v??'')),const SizedBox(height:11)] else ... [TextFormField(controller:id,decoration:const InputDecoration(labelText:'Account ID',prefixIcon:Icon(Icons.badge_outlined,color:gold)),validator:(v)=>v!.trim().length<4?'Enter a valid account ID':null)],if(widget.role!='Admin')... [const SizedBox(height:11),TextFormField(controller:pw,obscureText:hide,decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline,color:gold),suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide),icon:Icon(hide?Icons.visibility_off:Icons.visibility))),validator:(v)=>v!.isEmpty?'Password is required':null)] else ... [const SizedBox(height:11),TextFormField(controller:pw,obscureText:hide,decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline,color:gold),suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide),icon:Icon(hide?Icons.visibility_off:Icons.visibility))),validator:(v)=>v!.isEmpty?'Password is required':null)],const SizedBox(height:18),SizedBox(width:double.infinity,height:52,child:FilledButton(onPressed:busy?null:submit,style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:Text(busy?'Signing in...':'Login'))),const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.center,children:[TextButton(onPressed:signup,child:const Text('Sign Up')),const Text('•',style:TextStyle(color:muted)),TextButton(onPressed:reset,child:const Text('Forgot / Reset Password'))]),if(widget.role=='Admin')const Text('Default first login: admin@hafeezrentacar.com / 123456',style:TextStyle(color:muted,fontSize:11),textAlign:TextAlign.center)])))))));}
class SignupValues{final String id,name,password,phone,email,cnic,address;SignupValues(this.id,this.name,this.password,this.phone,this.email,this.cnic,this.address);}
class _SignupDialog extends StatefulWidget{final String role;final Future<bool> Function(SignupValues) onCreate;const _SignupDialog({required this.role,required this.onCreate});@override State<_SignupDialog> createState()=>_SignupDialogState();}
class _SignupDialogState extends State<_SignupDialog>{final form=GlobalKey<FormState>();final id=TextEditingController(),name=TextEditingController(),pw=TextEditingController(),cp=TextEditingController(),phone=TextEditingController(),email=TextEditingController(),cnic=TextEditingController(),address=TextEditingController();bool hide=true,busy=false;@override void dispose(){for(final x in [id,name,pw,cp,phone,email,cnic,address])x.dispose();super.dispose();}Future<void> save()async{if(form.currentState?.validate()!=true)return;setState(()=>busy=true);final ok=await widget.onCreate(SignupValues(id.text.trim(),name.text.trim(),pw.text,phone.text.trim(),email.text.trim().toLowerCase(),cnic.text.trim(),address.text.trim()));if(mounted){setState(()=>busy=false);if(ok)Navigator.pop(context,true);else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Account ID or email already exists, or some information is invalid.')));}}@override Widget build(BuildContext c)=>AlertDialog(title:Text('${widget.role} Sign Up'),content:SizedBox(width:480,child:SingleChildScrollView(child:Form(key:form,child:Column(children:[TextFormField(controller:id,decoration:const InputDecoration(labelText:'Account ID',prefixIcon:Icon(Icons.badge_outlined,color:gold)),validator:(v)=>v!.trim().length<4?'Use at least 4 characters':null),const SizedBox(height:9),TextFormField(controller:name,decoration:const InputDecoration(labelText:'Full Legal Name',prefixIcon:Icon(Icons.person_outline,color:gold)),validator:(v)=>v!.trim().length<3?'Enter full name':null),const SizedBox(height:9),TextFormField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email Address',prefixIcon:Icon(Icons.email_outlined,color:gold)),validator:(v)=>validEmail(v??'')),const SizedBox(height:9),TextFormField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Mobile Number',hintText:'+92 300 1234567',prefixIcon:Icon(Icons.phone_outlined,color:gold)),validator:(v)=>validPhone(v??'')),const SizedBox(height:9),TextFormField(controller:cnic,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'CNIC',hintText:'35202-1234567-1',prefixIcon:Icon(Icons.credit_card_outlined,color:gold)),validator:(v)=>validCnic(v??'')),const SizedBox(height:9),TextFormField(controller:address,maxLines:2,decoration:const InputDecoration(labelText:'Complete Address',prefixIcon:Icon(Icons.location_on_outlined,color:gold)),validator:(v)=>v!.trim().length<8?'Enter complete address':null),const SizedBox(height:9),TextFormField(controller:pw,obscureText:hide,decoration:InputDecoration(labelText:'Password',hintText:'At least 8 characters + number',prefixIcon:const Icon(Icons.lock_outline,color:gold),suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide),icon:Icon(hide?Icons.visibility_off:Icons.visibility))),validator:(v)=>validPassword(v??'')),const SizedBox(height:9),TextFormField(controller:cp,obscureText:true,decoration:const InputDecoration(labelText:'Confirm Password',prefixIcon:Icon(Icons.verified_user_outlined,color:gold)),validator:(v)=>v!=pw.text?'Passwords do not match':null)])))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:busy?null:save,style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:Text(busy?'Creating...':'Create Account'))]);}

class CustomerPortal extends StatelessWidget{
  final _AppState app;
  const CustomerPortal({super.key,required this.app});
  @override Widget build(BuildContext c){
    final u=app.customers.where((x)=>x.id==app.loggedId).toList(); final user=u.isEmpty?null:u.first;
    final client=app.clients.where((x)=>x.email.toLowerCase()==(user?.email??'').toLowerCase()).toList();
    final clientId=client.isEmpty?'':client.first.id;
    final bookings=app.rentals.where((r)=>r.clientId==clientId).toList().reversed.toList();
    final due=bookings.fold(0.0,(v,r)=>v+r.remaining);
    return PortalScaffold(app:app,title:'Customer Portal',name:user?.name??'Customer',icon:Icons.person,children:[
      Row(children:[Expanded(child:MiniStat('My Rentals','${bookings.length}',Icons.calendar_month)),const SizedBox(width:10),Expanded(child:MiniStat('Outstanding',money(due),Icons.payments))]),
      const SizedBox(height:14),
      PortalSection(title:'Available Cars',icon:Icons.directions_car,child:app.vehicles.where((v)=>v.status=='Available').isEmpty?const Text('No cars are currently available.',style:TextStyle(color:muted)):Column(children:[for(final v in app.vehicles.where((v)=>v.status=='Available').take(6)) ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(backgroundColor:Colors.white,child:Icon(Icons.directions_car,color:Colors.black)),title:Text(v.name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${v.reg} • ${v.year} • ${v.fuel}'),trailing:const Text('Available',style:TextStyle(color:Colors.green,fontWeight:FontWeight.w800)))])),
      const SizedBox(height:12),
      PortalSection(title:'My Bookings & Payments',icon:Icons.receipt_long,child:bookings.isEmpty?const Text('No rental history found.',style:TextStyle(color:muted)):Column(children:bookings.take(10).map((r){final v=app.vehicles.where((x)=>x.id==r.vehicleId).toList();return ListTile(contentPadding:EdgeInsets.zero,title:Text(v.isEmpty?'Vehicle':v.first.name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${r.pickupDate} → ${r.returnDate} • ${r.status}\nPaid ${money(r.advance)} • Due ${money(r.remaining)}'),trailing:IconButton(onPressed:()=>invoiceForRental(c,app,r),icon:const Icon(Icons.picture_as_pdf,color:gold)));}).toList())),
      const SizedBox(height:12),
      PortalSection(title:'My Profile',icon:Icons.verified_user,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(user?.email??'-'),Text(user?.phone??'-'),Text('CNIC: ${user?.cnic??'-'}'),Text('Address: ${user?.address??'-'}'),const SizedBox(height:8),Text(user?.verified==true?'✓ Account verified':'Verification pending',style:TextStyle(color:user?.verified==true?Colors.green:Colors.orange,fontWeight:FontWeight.w800))])),
    ]);
  }
}
class DriverPortal extends StatelessWidget{
  final _AppState app;
  const DriverPortal({super.key,required this.app});
  @override Widget build(BuildContext c){
    final u=app.drivers.where((x)=>x.id==app.loggedId).toList(); final user=u.isEmpty?null:u.first;
    final jobs=app.rentals.where((r)=>r.driverId==app.loggedId).toList().reversed.toList();
    final active=jobs.where((r)=>r.status=='Active').length;
    return PortalScaffold(app:app,title:'Driver Portal',name:user?.name??'Driver',icon:Icons.drive_eta,children:[
      Row(children:[Expanded(child:MiniStat('Active Jobs','$active',Icons.assignment)),const SizedBox(width:10),Expanded(child:MiniStat('Total Jobs','${jobs.length}',Icons.history))]),
      const SizedBox(height:14),
      PortalSection(title:'Assigned Jobs',icon:Icons.assignment,child:jobs.isEmpty?const Text('No assignments yet.',style:TextStyle(color:muted)):Column(children:[for(final r in jobs.take(12)) Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(title:Text(app.clients.where((x)=>x.id==r.clientId).isEmpty?'Customer':app.clients.firstWhere((x)=>x.id==r.clientId).name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${r.pickupDate} → ${r.returnDate} • ${r.status}'),trailing:IconButton(onPressed:()=>invoiceForRental(c,app,r),icon:const Icon(Icons.receipt_long,color:gold))))])),
      const SizedBox(height:12),
      PortalSection(title:'Driver Profile',icon:Icons.badge,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(user?.email??'-'),Text(user?.phone??'-'),Text('CNIC: ${user?.cnic??'-'}'),Text('Address: ${user?.address??'-'}'),const SizedBox(height:8),Text(user?.verified==true?'✓ Verified driver':'Verification pending',style:TextStyle(color:user?.verified==true?Colors.green:Colors.orange,fontWeight:FontWeight.w800))])),
    ]);
  }
}
class MiniStat extends StatelessWidget{final String title,value;final IconData icon;const MiniStat(this.title,this.value,this.icon,{super.key});@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[Icon(icon,color:gold),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),Text(title,style:const TextStyle(color:muted,fontSize:11))]))])));}
class PortalSection extends StatelessWidget{final String title;final IconData icon;final Widget child;const PortalSection({super.key,required this.title,required this.icon,required this.child});@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:gold),const SizedBox(width:8),Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))]),const SizedBox(height:10),child])));}

Future<void> invoiceForRental(BuildContext c,_AppState a,Rental r)async{
  final v=a.vehicles.where((x)=>x.id==r.vehicleId).toList(); final cl=a.clients.where((x)=>x.id==r.clientId).toList();
  final doc=pw.Document();
  doc.addPage(pw.Page(build:(_)=>pw.Padding(padding:const pw.EdgeInsets.all(24),child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
    pw.Text('HAFEEZ RENT A CAR',style:pw.TextStyle(fontSize:24,fontWeight:pw.FontWeight.bold)),pw.Text('Rental Invoice / Receipt'),pw.SizedBox(height:18),
    pw.Text('Invoice #: ${r.id}'),pw.Text('Date: ${today()}'),pw.SizedBox(height:10),
    pw.Text('Customer: ${cl.isEmpty?'Customer':cl.first.name}'),pw.Text('Phone: ${cl.isEmpty?'':cl.first.phone}'),pw.Text('Vehicle: ${v.isEmpty?'Vehicle':v.first.name} (${v.isEmpty?'':v.first.reg})'),
    pw.SizedBox(height:14),pw.TableHelper.fromTextArray(headers:['Item','Amount'],data:[['Rental Total',money(r.total)],['Paid',money(r.advance)],['Outstanding',money(r.remaining)],['Security Deposit',money(r.securityDeposit)]]),pw.SizedBox(height:18),pw.Text('Payment Method: ${r.paymentMethod}'),pw.Text('Thank you for choosing Hafeez Rent A Car.'),
  ]))));
  await Printing.sharePdf(bytes:await doc.save(),filename:'hafeez_invoice_${r.id}.pdf');
}
Future<void> agreementForRental(BuildContext c,_AppState a,Rental r)async{
  final v=a.vehicles.where((x)=>x.id==r.vehicleId).toList(); final cl=a.clients.where((x)=>x.id==r.clientId).toList();
  final doc=pw.Document();
  doc.addPage(pw.MultiPage(build:(_)=>[
    pw.Text('HAFEEZ RENT A CAR',style:pw.TextStyle(fontSize:24,fontWeight:pw.FontWeight.bold)),pw.Text('VEHICLE RENTAL AGREEMENT',style:pw.TextStyle(fontSize:16,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:16),
    pw.Text('Customer: ${cl.isEmpty?'Customer':cl.first.name}'),pw.Text('CNIC: ${cl.isEmpty?'':cl.first.cnic}'),pw.Text('Vehicle: ${v.isEmpty?'Vehicle':v.first.name} / ${v.isEmpty?'':v.first.reg}'),pw.Text('Rental Period: ${r.pickupDate} to ${r.returnDate}'),pw.Text('Daily Rate: ${money(r.dailyRate)}'),pw.Text('Total Rent: ${money(r.total)}'),pw.Text('Security Deposit: ${money(r.securityDeposit)}'),
    pw.SizedBox(height:16),pw.Text('Terms & Conditions'),pw.Bullet(text:'Customer is responsible for the vehicle during the rental period.'),pw.Bullet(text:'Vehicle must be returned on the agreed date and in reasonable condition.'),pw.Bullet(text:'Any additional approved charges will be recorded in the account ledger.'),pw.Bullet(text:'All payments and refunds must be documented by Hafeez Rent A Car.'),
    pw.SizedBox(height:40),pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[pw.Text('Customer Signature: __________________'),pw.Text('Authorized Signature: __________________')]),
  ]));
  await Printing.sharePdf(bytes:await doc.save(),filename:'hafeez_agreement_${r.id}.pdf');
}
class PortalTile extends StatelessWidget{final IconData icon;final String title,subtitle;const PortalTile(this.icon,this.title,this.subtitle,{super.key});@override Widget build(BuildContext c)=>Card(margin:const EdgeInsets.only(bottom:10),child:ListTile(leading:Icon(icon,color:gold),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(subtitle,style:const TextStyle(color:muted)),trailing:const Icon(Icons.chevron_right)));}
class PortalScaffold extends StatelessWidget {
  final _AppState app;
  final String title, name;
  final IconData icon;
  final List<Widget> children;
  const PortalScaffold({super.key, required this.app, required this.title, required this.name, required this.icon, required this.children});
  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [IconButton(onPressed: () => app.logout(), icon: const Icon(Icons.logout))]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                CircleAvatar(radius: 27, backgroundColor: gold.withValues(alpha: .15), child: Icon(icon, color: gold)),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Welcome', style: TextStyle(color: muted)),
                  Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class Home extends StatefulWidget{final _AppState app;const Home({super.key,required this.app});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{int index=0;_AppState get a=>widget.app;Future<void> refresh()async{await a.save();setState((){});}String vehicleName(String id)=>a.vehicles.firstWhere((v)=>v.id==id,orElse:()=>Vehicle(id:'',name:'Unknown',reg:'-',year:'',fuel:'',status:'')).name;String clientName(String id)=>a.clients.firstWhere((x)=>x.id==id,orElse:()=>Client(id:'',name:'Unknown',phone:'',email:'',cnic:'',address:'',note:'')).name;
 @override Widget build(BuildContext c){final pages=[Dashboard(a:a,onChange:refresh),FleetPage(a:a,onChange:refresh),RentalsPage(a:a,onChange:refresh,vehicleName:vehicleName,clientName:clientName),ClientsPage(a:a,onChange:refresh),MorePage(a:a,onChange:refresh)];return Scaffold(appBar:AppBar(title:const Text('HAFEEZ RENT A CAR',style:TextStyle(fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:()=>showInfo(c,'Notifications','No new notifications. Rental and maintenance reminders can be added in the next cloud-enabled version.'),icon:const Icon(Icons.notifications_none))]),body:pages[index],bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>index=i),destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Overview'),NavigationDestination(icon:Icon(Icons.directions_car_outlined),selectedIcon:Icon(Icons.directions_car),label:'Fleet'),NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Rentals'),NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'Clients'),NavigationDestination(icon:Icon(Icons.more_horiz),selectedIcon:Icon(Icons.apps),label:'More')]));}
}


class ProActionCard extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color accent; final VoidCallback onTap;
  const ProActionCard({super.key,required this.icon,required this.title,required this.subtitle,required this.accent,required this.onTap});
  @override Widget build(BuildContext c)=>Material(
    color:Colors.transparent,
    child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(gradient:LinearGradient(colors:[panel2,accent.withValues(alpha: .16)]),borderRadius:BorderRadius.circular(18),border:Border.all(color:accent.withValues(alpha: .55)),boxShadow:[BoxShadow(color:accent.withValues(alpha: .12),blurRadius:16,offset:const Offset(0,7))]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
        Container(width:44,height:44,decoration:BoxDecoration(color:accent.withValues(alpha: .16),borderRadius:BorderRadius.circular(14),border:Border.all(color:accent.withValues(alpha: .6)),boxShadow:[BoxShadow(color:accent.withValues(alpha: .18),blurRadius:10)]),child:Icon(icon,color:accent,size:25)),
        const SizedBox(height:10),Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:14)),const SizedBox(height:3),Text(subtitle,style:const TextStyle(color:muted,fontSize:10)),
      ]),
    )),
  );
}
class ProDialogHeader extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color accent;
  const ProDialogHeader({super.key,required this.icon,required this.title,required this.subtitle,required this.accent});
  @override Widget build(BuildContext c)=>Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(gradient:LinearGradient(colors:[panel2,accent.withValues(alpha: .16)]),borderRadius:BorderRadius.circular(16),border:Border.all(color:accent.withValues(alpha: .45))),child:Row(children:[Container(width:46,height:46,decoration:BoxDecoration(color:accent.withValues(alpha: .16),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:accent)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(subtitle,style:const TextStyle(color:muted,fontSize:11))]))]));
}

class Dashboard extends StatelessWidget{
  final _AppState a; final VoidCallback onChange; const Dashboard({super.key,required this.a,required this.onChange});
  @override Widget build(BuildContext c){
    final income=a.entries.where((x)=>x.type=='Income').fold(0.0,(s,x)=>s+x.amount);
    final exp=a.entries.where((x)=>x.type=='Expense').fold(0.0,(s,x)=>s+x.amount);
    final active=a.rentals.where((x)=>x.status=='Active').length;
    final due=a.rentals.where((x)=>x.remaining>0&&x.status!='Cancelled').fold(0.0,(s,x)=>s+x.remaining);
    final todayDate=DateTime.now(); final weekStart=todayDate.subtract(Duration(days:todayDate.weekday-1));
    double periodSum(String type,DateTime st,DateTime en)=>a.entries.where((e){final d=DateTime.tryParse(e.date);return e.type==type&&d!=null&&!d.isBefore(st)&&!d.isAfter(en);}).fold(0.0,(s,e)=>s+e.amount);
    final dayInc=periodSum('Income',DateTime(todayDate.year,todayDate.month,todayDate.day),DateTime(todayDate.year,todayDate.month,todayDate.day,23,59,59));
    final weekInc=periodSum('Income',weekStart,weekStart.add(const Duration(days:6,hours:23,minutes:59)));
    final monthInc=periodSum('Income',DateTime(todayDate.year,todayDate.month,1),DateTime(todayDate.year,todayDate.month+1,0,23,59,59));
    final yearInc=periodSum('Income',DateTime(todayDate.year,1,1),DateTime(todayDate.year,12,31,23,59,59));
    final rideIncome=a.rides.fold(0.0,(s,r)=>s+r.fare);
    final rideExpense=a.rides.fold(0.0,(s,r)=>s+r.totalExpense);
    final rideProfit=rideIncome-rideExpense;
    return ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Good Morning,',style:TextStyle(color:muted)),const Text('Hafeez Rent A Car',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const Text('Admin Dashboard',style:TextStyle(color:gold)),const SizedBox(height:18),
      GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:1.5,children:[
        Stat('Total Vehicles','${a.vehicles.length}',Icons.directions_car),Stat('Rented Vehicles','${a.vehicles.where((v)=>v.status=='Rented').length}',Icons.key),Stat('Available Vehicles','${a.vehicles.where((v)=>v.status=='Available').length}',Icons.check_circle),Stat('Maintenance','${a.vehicles.where((v)=>v.status=='Maintenance').length}',Icons.build),
        Stat('Total Clients','${a.clients.length}',Icons.people),Stat('Total Income',money(income),Icons.trending_up),Stat('Total Expenses',money(exp),Icons.trending_down),Stat('Net Profit',money(income-exp),Icons.account_balance_wallet)
      ]),
      const SizedBox(height:18),
      const Text('Quick Actions',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      const SizedBox(height:10),
      GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:1.55,children:[
        ProActionCard(icon:Icons.directions_car_filled,title:'Add Car',subtitle:'Add vehicle to fleet',accent:Colors.blueAccent,onTap:()=>vehicleDialog(c,null,a,onChange)),
        ProActionCard(icon:Icons.add_circle,title:'Add Income',subtitle:'Record new income',accent:Colors.greenAccent,onTap:()=>entryDialog(c,null,a,onChange,false)),
        ProActionCard(icon:Icons.remove_circle,title:'Add Expense',subtitle:'Record business expense',accent:Colors.redAccent,onTap:()=>entryDialog(c,null,a,onChange,true)),
        ProActionCard(icon:Icons.local_taxi,title:'Add Ride',subtitle:'Yango / inDrive / Offline / City-to-City',accent:gold,onTap:()=>rideAccounting(c,a,onChange)),
      ]),
      const SizedBox(height:18),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Income Snapshot',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.today,color:gold),title:const Text('Today'),trailing:Text(money(dayInc),style:const TextStyle(color:gold,fontWeight:FontWeight.w900))),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.date_range,color:gold),title:const Text('This Week'),trailing:Text(money(weekInc),style:const TextStyle(color:gold,fontWeight:FontWeight.w900))),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.calendar_month,color:gold),title:const Text('This Month'),trailing:Text(money(monthInc),style:const TextStyle(color:gold,fontWeight:FontWeight.w900))),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.event_note,color:gold),title:const Text('This Year'),trailing:Text(money(yearInc),style:const TextStyle(color:gold,fontWeight:FontWeight.w900)))
      ]))),
      const SizedBox(height:14),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Business Summary',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),
        Text('Outstanding customer balance: ${money(due)}',style:const TextStyle(color:gold,fontWeight:FontWeight.w800)),
        const SizedBox(height:8),Text('Active Rentals: $active'),Text('Completed Rentals: ${a.rentals.where((r)=>r.status=='Completed').length}'),Text('Total Transactions: ${a.entries.length}'),
      ]))),
      const SizedBox(height:14),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Yango / inDrive / Offline / City-to-City',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),Text('Ride Income: ${money(rideIncome)}'),Text('Ride Expenses: ${money(rideExpense)}'),Text('Ride Net Profit: ${money(rideProfit)}',style:TextStyle(color:rideProfit>=0?Colors.green:Colors.redAccent,fontWeight:FontWeight.w900)),Text('Total Rides: ${a.rides.length}'),
      ]))),
      const SizedBox(height:14),
      FilledButton.icon(onPressed:()=>reports(c,a),style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black,padding:const EdgeInsets.all(15)),icon:const Icon(Icons.analytics),label:const Text('Open Full Financial Reports',style:TextStyle(fontWeight:FontWeight.w900))),
    ]);
  }
}
class Stat extends StatelessWidget{final String t,v;final IconData i;const Stat(this.t,this.v,this.i,{super.key});@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Icon(i,color:gold),const SizedBox(height:7),Text(v,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text(t,style:const TextStyle(color:muted,fontSize:11))])));}

class FleetPage extends StatelessWidget {
  final _AppState a; final VoidCallback onChange;
  const FleetPage({super.key, required this.a, required this.onChange});
  @override Widget build(BuildContext c) {
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,10,16,5), child: Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Our Fleet', style: TextStyle(fontSize:23,fontWeight:FontWeight.w900)), Text('Add, edit and manage vehicles', style: TextStyle(color:muted,fontSize:12))])),
        FilledButton.icon(onPressed: ()=>vehicleDialog(c,null,a,onChange), icon: const Icon(Icons.add), label: const Text('Add Car')),
      ])),
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.all(16), itemCount: a.vehicles.length,
        separatorBuilder: (_,__)=>const SizedBox(height:10),
        itemBuilder: (_,i) { final v=a.vehicles[i]; return Card(child: ListTile(
          leading: const CircleAvatar(backgroundColor:Colors.white, child:Icon(Icons.directions_car,color:Colors.black)),
          title: Text(v.name,style:const TextStyle(fontWeight:FontWeight.w800)),
          subtitle: Text('${v.reg} • ${v.year} • ${v.fuel}\n${v.status}',style:const TextStyle(color:muted,fontSize:11)),
          trailing: PopupMenuButton<String>(onSelected:(x) async { if(x=='edit') await vehicleDialog(c,v,a,onChange); if(x=='delete'){a.vehicles.removeAt(i);await onSaveAndSnack(c,a,onChange,'Vehicle deleted');}}, itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'delete',child:Text('Delete'))]),
        ));},
      )),
    ]);
  }
}

class ClientsPage extends StatelessWidget {
  final _AppState a; final VoidCallback onChange;
  const ClientsPage({super.key,required this.a,required this.onChange});
  @override Widget build(BuildContext c) {
    return Column(children: [
      Padding(padding:const EdgeInsets.fromLTRB(16,10,16,5),child:Row(children:[
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Clients',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),Text('Customer profiles and rental history',style:TextStyle(color:muted,fontSize:12))])),
        FilledButton.icon(onPressed:()=>clientDialog(c,null,a,onChange),icon:const Icon(Icons.person_add),label:const Text('Add')),
      ])),
      Expanded(child:ListView.separated(padding:const EdgeInsets.all(16),itemCount:a.clients.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(_,i){final x=a.clients[i];final count=a.rentals.where((r)=>r.clientId==x.id).length;return Card(child:ListTile(onTap:()=>clientDetails(c,x,a),leading:CircleAvatar(backgroundColor:gold.withValues(alpha: .15),child:const Icon(Icons.person,color:gold)),title:Text(x.name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${x.phone} • ${x.email}\n${x.cnic} • Rentals: $count',style:const TextStyle(color:muted,fontSize:11)),trailing:PopupMenuButton<String>(onSelected:(v)async{if(v=='edit')await clientDialog(c,x,a,onChange);if(v=='delete'){a.clients.removeAt(i);await onSaveAndSnack(c,a,onChange,'Client deleted');}},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'delete',child:Text('Delete'))])));}))
    ]);
  }
}

class RentalsPage extends StatelessWidget{final _AppState a;final VoidCallback onChange;final String Function(String) vehicleName,clientName;const RentalsPage({super.key,required this.a,required this.onChange,required this.vehicleName,required this.clientName});@override Widget build(BuildContext c){final active=a.rentals.where((r)=>r.status=='Active').toList();return Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,10,16,5),child:Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Rentals',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),Text('Bookings, payments and returns',style:TextStyle(color:muted,fontSize:12))])),FilledButton.icon(onPressed:()=>rentalDialog(c,null,a,onChange),icon:const Icon(Icons.add),label:const Text('New Rental'))])),Expanded(child:ListView.separated(padding:const EdgeInsets.all(16),itemCount:active.length,separatorBuilder:(_,__)=>const SizedBox(height:9),itemBuilder:(_,i){final r=active[i];return Card(child:ListTile(onTap:()=>rentalDetails(c,r,a,onChange),leading:const CircleAvatar(backgroundColor:gold,child:Icon(Icons.key,color:Colors.black)),title:Text(clientName(r.clientId),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${vehicleName(r.vehicleId)}\n${r.pickupDate} → ${r.returnDate}\nTotal ${money(r.total)} • Due ${money(r.remaining)}',style:const TextStyle(color:muted,fontSize:11)),trailing:const Icon(Icons.chevron_right)));})),if(active.isEmpty)const Padding(padding:EdgeInsets.all(35),child:Text('No active rentals',style:TextStyle(color:muted))) ]);}}

class MorePage extends StatelessWidget{final _AppState a;final VoidCallback onChange;const MorePage({super.key,required this.a,required this.onChange});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Management',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),const SizedBox(height:12),MoreTile(Icons.account_balance_wallet,'Income & Expenses',()=>ledger(c,a,onChange,false)),MoreTile(Icons.local_taxi,'Yango / inDrive / Offline / City-to-City Rides',()=>rideAccounting(c,a,onChange)),MoreTile(Icons.build,'Maintenance & Fuel',()=>ledger(c,a,onChange,true)),MoreTile(Icons.analytics,'Reports',()=>reports(c,a)),MoreTile(Icons.bar_chart,'Vehicle Profitability',()=>vehicleProfitability(c,a)),MoreTile(Icons.verified_user,'Customer & Driver Verification',()=>verificationPage(c,a)),MoreTile(Icons.warning_amber,'Expiry & Reminder Center',()=>expiryAlerts(c,a)),MoreTile(Icons.backup,'Backup Business Data',()=>backupData(c,a)),MoreTile(Icons.settings,'Administration',()=>adminDialog(c,a)),MoreTile(Icons.business,'Business Settings',()=>businessDialog(c)),MoreTile(Icons.logout,'Logout',()=>confirm(c,'Logout?','Are you sure you want to logout?',()=>a.logout()),danger:true)]);}
class MoreTile extends StatelessWidget{final IconData i;final String t;final VoidCallback on;final bool danger;const MoreTile(this.i,this.t,this.on,{super.key,this.danger=false});@override Widget build(BuildContext c)=>Card(margin:const EdgeInsets.only(bottom:9),child:ListTile(onTap:on,leading:Icon(i,color:danger?Colors.redAccent:gold),title:Text(t,style:const TextStyle(fontWeight:FontWeight.w700)),trailing:const Icon(Icons.chevron_right)));}

Future<void> vehicleDialog(BuildContext c, Vehicle? old, _AppState a, VoidCallback refresh) async {
  final n=TextEditingController(text:old?.name??''), r=TextEditingController(text:old?.reg??''), y=TextEditingController(text:old?.year??''), mileage=TextEditingController(text:old?.mileage??''), ins=TextEditingController(text:old?.insuranceExpiry??''), regExp=TextEditingController(text:old?.registrationExpiry??''), note=TextEditingController(text:old?.note??'');
  String fuel=old?.fuel??'Petrol', status=old?.status??'Available';
  final form=GlobalKey<FormState>();
  final ok=await showDialog<bool>(context:c,builder:(_)=>AlertDialog(
    backgroundColor:panel, elevation:24, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
    title:ProDialogHeader(icon:Icons.directions_car_filled,title:old==null?'Add Car':'Edit Car',subtitle:'Add a professional vehicle to your fleet',accent:Colors.blueAccent),
    content:SizedBox(width:480,child:SingleChildScrollView(child:Form(key:form,child:Column(children:[
      TextFormField(controller:n,decoration:const InputDecoration(labelText:'Make & Model',prefixIcon:Icon(Icons.directions_car,color:gold)),validator:(v)=>v!.trim().length<3?'Enter vehicle make and model':null),
      const SizedBox(height:10),
      TextFormField(controller:r,textCapitalization:TextCapitalization.characters,decoration:const InputDecoration(labelText:'Registration Number',hintText:'LEA-1234',prefixIcon:Icon(Icons.confirmation_number_outlined,color:gold)),validator:(v)=>v!.trim().length<3?'Enter registration number':null),
      const SizedBox(height:10),
      TextFormField(controller:y,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Manufacturing / Model Year',prefixIcon:Icon(Icons.calendar_today_outlined,color:gold)),validator:(v){final z=int.tryParse(v??'');return z==null||z<1980||z>DateTime.now().year+1?'Enter a valid year':null;}),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(initialValue:fuel,decoration:const InputDecoration(labelText:'Fuel Type'),items:['Petrol','Diesel','Hybrid','Electric'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>fuel=x!),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(initialValue:status,decoration:const InputDecoration(labelText:'Vehicle Status'),items:['Available','Rented','Maintenance'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>status=x!),
      const SizedBox(height:10),TextFormField(controller:mileage,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Current Mileage (KM)',prefixIcon:Icon(Icons.speed,color:gold))),
      const SizedBox(height:10),TextFormField(controller:ins,decoration:const InputDecoration(labelText:'Insurance Expiry (YYYY-MM-DD)',prefixIcon:Icon(Icons.security,color:gold))),
      const SizedBox(height:10),TextFormField(controller:regExp,decoration:const InputDecoration(labelText:'Registration/Token Expiry',prefixIcon:Icon(Icons.event_available,color:gold))),
      const SizedBox(height:10),TextFormField(controller:note,maxLines:2,decoration:const InputDecoration(labelText:'Vehicle Notes',prefixIcon:Icon(Icons.notes,color:gold))),
    ])))),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:(){if(form.currentState?.validate()==true)Navigator.pop(c,true);},style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:const Text('Save Vehicle'))],
  ));
  if(ok!=true)return;
  final v=Vehicle(id:old?.id??uid(),name:n.text.trim(),reg:r.text.trim().toUpperCase(),year:y.text.trim(),fuel:fuel,status:status,mileage:mileage.text.trim(),insuranceExpiry:ins.text.trim(),registrationExpiry:regExp.text.trim(),note:note.text.trim());
  if(old==null)a.vehicles.add(v);else a.vehicles[a.vehicles.indexWhere((x)=>x.id==old.id)]=v;
  await a.save();refresh();
}
Future<void> clientDialog(BuildContext c, Client? old, _AppState a, VoidCallback refresh) async {
  final n=TextEditingController(text:old?.name??''), p=TextEditingController(text:old?.phone??''), em=TextEditingController(text:old?.email??''), cn=TextEditingController(text:old?.cnic??''), ad=TextEditingController(text:old?.address??''), no=TextEditingController(text:old?.note??''), lic=TextEditingController(text:old?.licenseNumber??''), licExp=TextEditingController(text:old?.licenseExpiry??'');
  final form=GlobalKey<FormState>();
  final ok=await showDialog<bool>(context:c,builder:(_)=>AlertDialog(
    title:Text(old==null?'Add Customer':'Edit Customer'),
    content:SizedBox(width:480,child:SingleChildScrollView(child:Form(key:form,child:Column(children:[
      TextFormField(controller:n,decoration:const InputDecoration(labelText:'Full Legal Name',prefixIcon:Icon(Icons.person_outline,color:gold)),validator:(v)=>v!.trim().length<3?'Enter full name':null),
      const SizedBox(height:9),
      TextFormField(controller:em,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email Address',prefixIcon:Icon(Icons.email_outlined,color:gold)),validator:(v)=>validEmail(v??'')),
      const SizedBox(height:9),
      TextFormField(controller:p,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Mobile Number',hintText:'+92 300 1234567',prefixIcon:Icon(Icons.phone_outlined,color:gold)),validator:(v)=>validPhone(v??'')),
      const SizedBox(height:9),
      TextFormField(controller:cn,decoration:const InputDecoration(labelText:'CNIC',hintText:'35202-1234567-1',prefixIcon:Icon(Icons.credit_card_outlined,color:gold)),validator:(v)=>validCnic(v??'')),
      const SizedBox(height:9),
      TextFormField(controller:ad,maxLines:2,decoration:const InputDecoration(labelText:'Complete Address',prefixIcon:Icon(Icons.location_on_outlined,color:gold)),validator:(v)=>v!.trim().length<8?'Enter complete address':null),
      const SizedBox(height:9),
      TextFormField(controller:lic,decoration:const InputDecoration(labelText:'Driving License Number',prefixIcon:Icon(Icons.badge,color:gold))),
      const SizedBox(height:9),
      TextFormField(controller:licExp,decoration:const InputDecoration(labelText:'License Expiry (YYYY-MM-DD)',prefixIcon:Icon(Icons.event,color:gold))),
      const SizedBox(height:9),
      TextFormField(controller:no,maxLines:2,decoration:const InputDecoration(labelText:'Notes / Additional Information',prefixIcon:Icon(Icons.notes_outlined,color:gold))),
    ])))),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:(){if(form.currentState?.validate()==true)Navigator.pop(c,true);},style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:const Text('Save Customer'))],
  ));
  if(ok!=true)return;
  final x=Client(id:old?.id??uid(),name:n.text.trim(),phone:p.text.trim(),email:em.text.trim().toLowerCase(),cnic:cn.text.trim(),address:ad.text.trim(),note:no.text.trim(),licenseNumber:lic.text.trim(),licenseExpiry:licExp.text.trim());
  if(old==null)a.clients.add(x);else a.clients[a.clients.indexWhere((z)=>z.id==old.id)]=x;
  await a.save();refresh();
}

Future<void> rentalDialog(BuildContext c, Rental? old, _AppState a, VoidCallback refresh) async {
  if (a.clients.isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Please add a client first.'))); return; }
  final avail = a.vehicles.where((v)=>v.status=='Available'||(old!=null&&v.id==old.vehicleId)).toList();
  if (avail.isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('No available vehicles.'))); return; }
  String client=old?.clientId??a.clients.first.id, vehicle=old?.vehicleId??avail.first.id;
  final rate=TextEditingController(text:'${old?.dailyRate??3000}'), advance=TextEditingController(text:'${old?.advance??0}'), deposit=TextEditingController(text:'${old?.securityDeposit??0}'), note=TextEditingController(text:old?.note??'');
  String driver=old?.driverId??''; String paymentMethod=old?.paymentMethod??'Cash';
  DateTime pickup=DateTime.tryParse(old?.pickupDate??'')??DateTime.now();
  DateTime ret=DateTime.tryParse(old?.returnDate??'')??DateTime.now().add(const Duration(days:1));
  final ok=await showDialog<bool>(context:c,builder:(_)=>StatefulBuilder(builder:(ctx,setState){
    final days=ret.difference(pickup).inDays.clamp(1,999); final total=numVal(rate.text)*days; final rem=total-numVal(advance.text);
    return AlertDialog(title:Text(old==null?'New Rental':'Edit Rental'),content:SingleChildScrollView(child:Column(children:[
      DropdownButtonFormField<String>(initialValue:client,decoration:const InputDecoration(labelText:'Client'),items:a.clients.map((x)=>DropdownMenuItem(value:x.id,child:Text(x.name))).toList(),onChanged:(x)=>setState(()=>client=x!)),
      const SizedBox(height:9),DropdownButtonFormField<String>(initialValue:vehicle,decoration:const InputDecoration(labelText:'Vehicle'),items:avail.map((x)=>DropdownMenuItem(value:x.id,child:Text('${x.name} • ${x.reg}'))).toList(),onChanged:(x)=>setState(()=>vehicle=x!)),
      const SizedBox(height:9),DropdownButtonFormField<String>(initialValue:driver.isEmpty?null:driver,decoration:const InputDecoration(labelText:'Assigned Driver (optional)',prefixIcon:Icon(Icons.drive_eta,color:gold)),items:[const DropdownMenuItem<String>(value:'',child:Text('No driver assigned')), ...a.drivers.map((x)=>DropdownMenuItem(value:x.id,child:Text(x.name)))],onChanged:(x)=>setState(()=>driver=x??'')),
      const SizedBox(height:9),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Pickup Date'),subtitle:Text(pickup.toString().substring(0,10)),onTap:()async{final d=await showDatePicker(context:ctx,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDate:pickup);if(d!=null)setState(()=>pickup=d);}),
      ListTile(contentPadding:EdgeInsets.zero,title:const Text('Return Date'),subtitle:Text(ret.toString().substring(0,10)),onTap:()async{final d=await showDatePicker(context:ctx,firstDate:pickup,lastDate:DateTime(2100),initialDate:ret);if(d!=null)setState(()=>ret=d);}),
      TextField(controller:rate,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Daily Rent (Rs.)'),onChanged:(_)=>setState((){})),
      const SizedBox(height:9),TextField(controller:advance,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Advance Payment (Rs.)'),onChanged:(_)=>setState((){})),
      const SizedBox(height:9),TextField(controller:deposit,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Security Deposit (Rs.)')),
      const SizedBox(height:9),DropdownButtonFormField<String>(initialValue:paymentMethod,decoration:const InputDecoration(labelText:'Payment Method'),items:['Cash','Bank Transfer','Card','JazzCash','Easypaisa'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>paymentMethod=x!)),
      const SizedBox(height:9),TextField(controller:note,decoration:const InputDecoration(labelText:'Notes')),
      const SizedBox(height:12),Align(alignment:Alignment.centerLeft,child:Text('Total: ${money(total)} • Remaining: ${money(rem)}',style:const TextStyle(color:gold,fontWeight:FontWeight.w900))),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:const Text('Save Rental'))]);
  }));
  if(ok!=true)return;
  final days=ret.difference(pickup).inDays.clamp(1,999); final total=numVal(rate.text)*days; final adv=numVal(advance.text);
  if(adv>total){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Advance cannot be greater than total rent.')));return;}
  if(old==null){
    a.rentals.add(Rental(id:uid(),clientId:client,vehicleId:vehicle,pickupDate:pickup.toString().substring(0,10),returnDate:ret.toString().substring(0,10),status:'Active',dailyRate:numVal(rate.text),total:total,advance:adv,remaining:total-adv,note:note.text.trim(),driverId:driver,paymentMethod:paymentMethod,securityDeposit:numVal(deposit.text),createdAt:today()));
    final v=a.vehicles.firstWhere((x)=>x.id==vehicle); v.status='Rented';
    if(adv>0)a.entries.add(Entry(id:uid(),type:'Income',vehicle:v.reg,title:'Rental advance',amount:adv,date:today(),note:'Rental advance',category:'Rental Advance',referenceId:a.rentals.last.id));
  } else {
    final r=a.rentals.firstWhere((x)=>x.id==old.id); final oldVehicle=r.vehicleId; a.entries.removeWhere((e)=>e.referenceId==r.id&&e.category=='Rental Advance');
    r.clientId=client;r.vehicleId=vehicle;r.pickupDate=pickup.toString().substring(0,10);r.returnDate=ret.toString().substring(0,10);r.dailyRate=numVal(rate.text);r.total=total;r.advance=adv;r.remaining=total-adv;r.note=note.text.trim();r.driverId=driver;r.paymentMethod=paymentMethod;r.securityDeposit=numVal(deposit.text);
    if(oldVehicle!=vehicle){a.vehicles.firstWhere((v)=>v.id==oldVehicle).status='Available';a.vehicles.firstWhere((v)=>v.id==vehicle).status='Rented';}
    if(adv>0)a.entries.add(Entry(id:uid(),type:'Income',vehicle:a.vehicles.firstWhere((v)=>v.id==vehicle).reg,title:'Rental advance',amount:adv,date:today(),note:'Rental advance',category:'Rental Advance',referenceId:r.id));
  }
  await a.save(); refresh();
}

Future<void> rentalDetails(BuildContext c,Rental r,_AppState a,VoidCallback refresh)async{final v=a.vehicles.firstWhere((x)=>x.id==r.vehicleId);final cl=a.clients.firstWhere((x)=>x.id==r.clientId);await showModalBottomSheet(context:c,isScrollControlled:true,backgroundColor:panel,builder:(_)=>Padding(padding:const EdgeInsets.all(20),child:Wrap(children:[Text('${cl.name} — ${v.name}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:10),Text('Vehicle: ${v.reg}'),Text('Period: ${r.pickupDate} → ${r.returnDate}'),Text('Total: ${money(r.total)}'),Text('Paid: ${money(r.advance)}'),Text('Remaining: ${money(r.remaining)}',style:const TextStyle(color:gold,fontWeight:FontWeight.w900)),if(r.note.isNotEmpty)Text('Note: ${r.note}'),const SizedBox(height:16),Wrap(spacing:8,children:[FilledButton.icon(onPressed:()=>paymentDialog(c,r,a,refresh),icon:const Icon(Icons.payments),label:const Text('Receive Payment')),OutlinedButton.icon(onPressed:()=>rentalDialog(c,r,a,refresh),icon:const Icon(Icons.edit),label:const Text('Edit')),OutlinedButton.icon(onPressed:()=>invoiceForRental(c,a,r),icon:const Icon(Icons.receipt_long),label:const Text('Invoice')),OutlinedButton.icon(onPressed:()=>agreementForRental(c,a,r),icon:const Icon(Icons.description),label:const Text('Agreement')),FilledButton.icon(onPressed:()=>returnRental(c,r,a,refresh),icon:const Icon(Icons.assignment_return),label:const Text('Return Vehicle'),style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black))])])));}
Future<void> paymentDialog(BuildContext c,Rental r,_AppState a,VoidCallback refresh)async{final x=TextEditingController();final ok=await showDialog<bool>(context:c,builder:(_)=>AlertDialog(title:const Text('Receive Payment'),content:TextField(controller:x,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Amount (Max ${money(r.remaining)})')),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:const Text('Receive'))]));if(ok!=true)return;final pay=numVal(x.text);if(pay<=0||pay>r.remaining){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Enter a valid payment amount.')));return;}r.advance+=pay;r.remaining-=pay;a.entries.add(Entry(id:uid(),type:'Income',vehicle:a.vehicles.firstWhere((v)=>v.id==r.vehicleId).reg,title:'Rental payment',amount:pay,date:today(),note:'Payment from customer',category:'Rental Payment',referenceId:r.id));await a.save();refresh();}
Future<void> returnRental(BuildContext c,Rental r,_AppState a,VoidCallback refresh)async{final ok=await confirmAction(c,'Return Vehicle','Mark this rental completed and vehicle available?');if(!ok)return;r.status='Completed';a.vehicles.firstWhere((v)=>v.id==r.vehicleId).status='Available';await a.save();refresh();Navigator.pop(c);}

Future<void> clientDetails(BuildContext c,Client x,_AppState a)async{final rs=a.rentals.where((r)=>r.clientId==x.id).toList().reversed.toList();showModalBottomSheet(context:c,isScrollControlled:true,backgroundColor:panel,builder:(_)=>DraggableScrollableSheet(expand:false,builder:(_,sc)=>ListView(controller:sc,padding:const EdgeInsets.all(20),children:[Text(x.name,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),Text(x.phone),Text('CNIC: ${x.cnic}'),Text('Address: ${x.address}'),const SizedBox(height:18),const Text('Rental History',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),...rs.map((r)=>ListTile(title:Text(a.vehicles.firstWhere((v)=>v.id==r.vehicleId).reg),subtitle:Text('${r.pickupDate} → ${r.returnDate} • ${r.status}'),trailing:Text(money(r.total))))])));}

Future<void> rideAccounting(BuildContext c,_AppState a,VoidCallback refresh)async{await showModalBottomSheet(context:c,isScrollControlled:true,backgroundColor:Colors.transparent,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(28))),builder:(_)=>RideAccountingSheet(a:a,refresh:refresh));}

class RideAccountingSheet extends StatefulWidget{final _AppState a;final VoidCallback refresh;const RideAccountingSheet({super.key,required this.a,required this.refresh});@override State<RideAccountingSheet> createState()=>_RideAccountingState();}
class _RideAccountingState extends State<RideAccountingSheet>{
  @override Widget build(BuildContext c){
    final rides=widget.a.rides.reversed.toList();
    final income=rides.fold(0.0,(s,r)=>s+r.fare);
    final exp=rides.fold(0.0,(s,r)=>s+r.totalExpense);
    return SafeArea(child:DraggableScrollableSheet(expand:false,initialChildSize:.92,minChildSize:.5,maxChildSize:.98,builder:(_,sc)=>Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,14,8,8),child:Row(children:[const Expanded(child:Text('Ride Accounting',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900))),IconButton(onPressed:()=>rideDialog(c,null,widget.a,widget.refresh),icon:const Icon(Icons.add,color:gold))])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Row(children:[Expanded(child:Stat('Ride Income',money(income),Icons.trending_up)),const SizedBox(width:8),Expanded(child:Stat('Ride Expense',money(exp),Icons.trending_down)),const SizedBox(width:8),Expanded(child:Stat('Net Profit',money(income-exp),Icons.account_balance_wallet))])),
      const SizedBox(height:8),
      Expanded(child:ListView(padding:const EdgeInsets.all(16),controller:sc,children:[for(final r in rides) Card(child:ListTile(onTap:()=>rideDialog(c,r,widget.a,widget.refresh),leading:CircleAvatar(backgroundColor:gold.withValues(alpha: .15),child:Icon(r.source=='Yango'?Icons.local_taxi:r.source=='inDrive'?Icons.route:Icons.directions_car,color:gold)),title:Text('${r.source} • ${r.serviceType}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${r.date} • ${widget.a.vehicles.where((x)=>x.id==r.vehicleId).isEmpty?'No vehicle':widget.a.vehicles.firstWhere((x)=>x.id==r.vehicleId).reg}\n${r.pickup} → ${r.dropoff}\nIncome ${money(r.fare)} • Expense ${money(r.totalExpense)}',style:const TextStyle(color:muted,fontSize:11)),trailing:Text(money(r.netProfit),style:TextStyle(color:r.netProfit>=0?Colors.green:Colors.redAccent,fontWeight:FontWeight.w900))))]))
    ])));
  }

}
Future<void> rideDialog(BuildContext c,Ride? old,_AppState a,VoidCallback refresh)async{
  String source=old?.source??'Yango';
  String service=old?.serviceType??'Local Ride';
  String vehicle=old?.vehicleId??(a.vehicles.isEmpty?'':a.vehicles.first.id);
  String driver=old?.driverId??'';
  String payment=old?.paymentMethod??'Cash';
  final customer=TextEditingController(text:old?.customerName??'');
  final phone=TextEditingController(text:old?.customerPhone??'');
  final pickup=TextEditingController(text:old?.pickup??'');
  final dropoff=TextEditingController(text:old?.dropoff??'');
  final km=TextEditingController(text:'${old?.distanceKm??0}');
  final fare=TextEditingController(text:'${old?.fare??0}');
  final commission=TextEditingController(text:'${old?.platformCommission??0}');
  final fuel=TextEditingController(text:'${old?.fuelExpense??0}');
  final toll=TextEditingController(text:'${old?.tollExpense??0}');
  final driverExp=TextEditingController(text:'${old?.driverExpense??0}');
  final other=TextEditingController(text:'${old?.otherExpense??0}');
  final note=TextEditingController(text:old?.note??'');
  DateTime date=DateTime.tryParse(old?.date??'')??DateTime.now();
  final ok=await showDialog<bool>(context:c,builder:(_)=>StatefulBuilder(builder:(ctx,setState){
    final net=numVal(fare.text)-numVal(commission.text)-numVal(fuel.text)-numVal(toll.text)-numVal(driverExp.text)-numVal(other.text);
    return AlertDialog(backgroundColor:panel,elevation:24,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),title:ProDialogHeader(icon:Icons.local_taxi,title:old==null?'Add Ride':'Edit Ride',subtitle:'Yango • inDrive • Offline • City-to-City',accent:gold),content:SizedBox(width:520,child:SingleChildScrollView(child:Column(children:[
      DropdownButtonFormField<String>(initialValue:source,decoration:const InputDecoration(labelText:'Ride Source'),items:['Yango','inDrive','Offline','Direct Booking'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>source=x!)),
      const SizedBox(height:8),DropdownButtonFormField<String>(initialValue:service,decoration:const InputDecoration(labelText:'Service Type'),items:['Local Ride','City-to-City'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>service=x!)),
      const SizedBox(height:8),if(a.vehicles.isNotEmpty)DropdownButtonFormField<String>(initialValue:vehicle.isEmpty?null:vehicle,decoration:const InputDecoration(labelText:'Vehicle'),items:a.vehicles.map((x)=>DropdownMenuItem(value:x.id,child:Text('${x.name} • ${x.reg}'))).toList(),onChanged:(x)=>setState(()=>vehicle=x??'')),
      const SizedBox(height:8),DropdownButtonFormField<String>(initialValue:driver.isEmpty?null:driver,decoration:const InputDecoration(labelText:'Driver (optional)'),items:[const DropdownMenuItem<String>(value:'',child:Text('No driver')), ...a.drivers.map((x)=>DropdownMenuItem(value:x.id,child:Text(x.name)))],onChanged:(x)=>setState(()=>driver=x??'')),
      const SizedBox(height:8),TextField(controller:customer,decoration:const InputDecoration(labelText:'Customer Name')),const SizedBox(height:8),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Customer Mobile')),
      const SizedBox(height:8),TextField(controller:pickup,decoration:const InputDecoration(labelText:'Pickup / From')),const SizedBox(height:8),TextField(controller:dropoff,decoration:const InputDecoration(labelText:'Drop-off / To')),
      const SizedBox(height:8),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Ride Date'),subtitle:Text(date.toString().substring(0,10)),onTap:()async{final d=await showDatePicker(context:ctx,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDate:date);if(d!=null)setState(()=>date=d);}),
      TextField(controller:km,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Distance (KM)')),const SizedBox(height:8),TextField(controller:fare,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Fare / Income (Rs.)'),onChanged:(_)=>setState((){})),
      const SizedBox(height:8),TextField(controller:commission,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'$source Commission / Platform Fee (Rs.)'),onChanged:(_)=>setState((){})),
      const SizedBox(height:8),TextField(controller:fuel,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Fuel Expense (Rs.)'),onChanged:(_)=>setState((){})),
      const SizedBox(height:8),TextField(controller:toll,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Toll / Motorway / Parking (Rs.)'),onChanged:(_)=>setState((){})),
      const SizedBox(height:8),TextField(controller:driverExp,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Driver Expense / Share (Rs.)'),onChanged:(_)=>setState((){})),
      const SizedBox(height:8),TextField(controller:other,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Other Expense (Rs.)'),onChanged:(_)=>setState((){})),
      const SizedBox(height:8),DropdownButtonFormField<String>(initialValue:payment,decoration:const InputDecoration(labelText:'Payment Method'),items:['Cash','Bank Transfer','Card','JazzCash','Easypaisa'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>payment=x!)),
      const SizedBox(height:8),TextField(controller:note,decoration:const InputDecoration(labelText:'Notes')),const SizedBox(height:10),Align(alignment:Alignment.centerLeft,child:Text('Net Profit: ${money(net)}',style:TextStyle(color:net>=0?Colors.green:Colors.redAccent,fontWeight:FontWeight.w900)))
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:const Text('Save Ride'))]);
  }));
  if(ok!=true||numVal(fare.text)<=0)return;
  final id=old?.id??uid();
  final ride=Ride(id:id,source:source,serviceType:service,vehicleId:vehicle,driverId:driver,customerName:customer.text.trim(),customerPhone:phone.text.trim(),pickup:pickup.text.trim(),dropoff:dropoff.text.trim(),date:date.toString().substring(0,10),distanceKm:numVal(km.text),fare:numVal(fare.text),platformCommission:numVal(commission.text),fuelExpense:numVal(fuel.text),tollExpense:numVal(toll.text),driverExpense:numVal(driverExp.text),otherExpense:numVal(other.text),paymentMethod:payment,status:'Completed',note:note.text.trim());
  a.entries.removeWhere((e)=>e.referenceId==id);
  final v=a.vehicles.where((x)=>x.id==vehicle).toList();
  final reg=v.isEmpty?'General':v.first.reg;
  a.entries.add(Entry(id:uid(),type:'Income',vehicle:reg,title:'Ride Income • $source • $service',amount:ride.fare,date:ride.date,note:'${ride.pickup} → ${ride.dropoff}',category:'Ride Income',referenceId:id));
  final expenses=[['Platform Commission',ride.platformCommission],['Fuel',ride.fuelExpense],['Toll / Parking',ride.tollExpense],['Driver Expense',ride.driverExpense],['Other Ride Expense',ride.otherExpense]];
  for(final x in expenses){final amount=x[1] as double;if(amount>0)a.entries.add(Entry(id:uid(),type:'Expense',vehicle:reg,title:'Ride Expense • ${x[0]}',amount:amount,date:ride.date,note:'$source • $service • ${ride.pickup} → ${ride.dropoff}',category:'Ride Expense',referenceId:id));}
  if(old==null)a.rides.add(ride);else a.rides[a.rides.indexWhere((x)=>x.id==id)]=ride;
  await a.save();refresh();
}

Future<void> ledger(BuildContext c,_AppState a,VoidCallback refresh,bool expensesOnly)async{await showModalBottomSheet(context:c,isScrollControlled:true,backgroundColor:panel,builder:(_)=>LedgerSheet(a:a,refresh:refresh,expensesOnly:expensesOnly));}
class LedgerSheet extends StatefulWidget{final _AppState a;final VoidCallback refresh;final bool expensesOnly;const LedgerSheet({super.key,required this.a,required this.refresh,required this.expensesOnly});@override State<LedgerSheet> createState()=>_LedgerState();}
class _LedgerState extends State<LedgerSheet> {
  @override Widget build(BuildContext c) {
    final es=widget.a.entries.where((e)=>!widget.expensesOnly||e.type=='Expense').toList().reversed.toList();
    return SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
      Row(children:[Expanded(child:Text(widget.expensesOnly?'Maintenance & Fuel':'Income & Expenses',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900))),IconButton(onPressed:()=>entryDialog(c,null,widget.a,widget.refresh,widget.expensesOnly),icon:const Icon(Icons.add,color:gold))]),
      const SizedBox(height:10),
      Expanded(child:ListView(children:[for(final e in es) Card(child:ListTile(title:Text(e.title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${e.vehicle} • ${e.date}\n${e.note}',style:const TextStyle(color:muted,fontSize:11)),trailing:Text(money(e.amount),style:TextStyle(color:e.type=='Income'?Colors.green:Colors.redAccent,fontWeight:FontWeight.w900))))]))
    ])));
  }
}
Future<void> entryDialog(BuildContext c,Entry? old,_AppState a,VoidCallback refresh,bool expenseOnly)async{final title=TextEditingController(text:old?.title??''),amt=TextEditingController(text:'${old?.amount??''}'),note=TextEditingController(text:old?.note??'');String type=expenseOnly?'Expense':(old?.type??'Income');String vehicle=old?.vehicle??'General';final ok=await showDialog<bool>(context:c,builder:(_)=>AlertDialog(backgroundColor:panel,elevation:24,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),title:ProDialogHeader(icon:expenseOnly?Icons.remove_circle:Icons.add_circle,title:old==null?(expenseOnly?'Add Expense':'Add Income'):'Edit Record',subtitle:expenseOnly?'Record a business expense':'Record a new income entry',accent:expenseOnly?Colors.redAccent:Colors.greenAccent),content:SingleChildScrollView(child:Column(children:[if(!expenseOnly)DropdownButtonFormField(initialValue:type,items:['Income','Expense'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>type=x!,decoration:const InputDecoration(labelText:'Type')),const SizedBox(height:8),DropdownButtonFormField(initialValue:vehicle,items:[...a.vehicles.map((v)=>DropdownMenuItem(value:v.reg,child:Text(v.reg))),const DropdownMenuItem(value:'General',child:Text('General'))],onChanged:(x)=>vehicle=x!,decoration:const InputDecoration(labelText:'Vehicle')),const SizedBox(height:8),TextField(controller:title,decoration:const InputDecoration(labelText:'Title')),const SizedBox(height:8),TextField(controller:amt,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount')),const SizedBox(height:8),TextField(controller:note,decoration:const InputDecoration(labelText:'Note'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:const Text('Save'))]));if(ok!=true||title.text.trim().isEmpty||numVal(amt.text)<=0)return;a.entries.add(Entry(id:uid(),type:type,vehicle:vehicle,title:title.text.trim(),amount:numVal(amt.text),date:today(),note:note.text.trim()));await a.save();refresh();}

Future<void> reports(BuildContext c,_AppState a)async{
  await Navigator.of(c).push(MaterialPageRoute(builder:(_)=>ReportsPage(a:a)));
}
class ReportsPage extends StatefulWidget{
  final _AppState a; const ReportsPage({super.key,required this.a});
  @override State<ReportsPage> createState()=>_ReportsPageState();
}
class _ReportsPageState extends State<ReportsPage>{
  int period=2; DateTime selected=DateTime.now(); DateTime? from; DateTime? to;
  DateTime _start(){
    if(period==0)return DateTime(selected.year,selected.month,selected.day);
    if(period==1){final d=DateTime(selected.year,selected.month,selected.day);return d.subtract(Duration(days:d.weekday-1));}
    if(period==2)return DateTime(selected.year,selected.month,1);
    if(period==3)return DateTime(selected.year,1,1);
    return DateTime(from?.year??selected.year,from?.month??selected.month,from?.day??selected.day);
  }
  DateTime _end(){
    if(period==0)return DateTime(selected.year,selected.month,selected.day,23,59,59);
    if(period==1)return _start().add(const Duration(days:6,hours:23,minutes:59,seconds:59));
    if(period==2)return DateTime(selected.year,selected.month+1,0,23,59,59);
    if(period==3)return DateTime(selected.year,12,31,23,59,59);
    return DateTime(to?.year??selected.year,to?.month??selected.month,to?.day??selected.day,23,59,59);
  }
  List<Entry> get filtered{
    final st=_start(),en=_end();
    return widget.a.entries.where((e){final d=DateTime.tryParse(e.date);return d!=null&&!d.isBefore(st)&&!d.isAfter(en);}).toList();
  }
  String rangeText(){final f=_start(),t=_end();return '${f.toString().substring(0,10)}  →  ${t.toString().substring(0,10)}';}
  double sum(String type)=>filtered.where((e)=>e.type==type).fold(0.0,(v,e)=>v+e.amount);
  Future<void> pickDate()async{final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDate:selected);if(d!=null)setState(()=>selected=d);}
  Future<void> pickCustom(bool isFrom)async{final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDate:isFrom?(from??selected):(to??selected));if(d!=null)setState(()=>isFrom?from=d:to=d);}
  Future<void> exportPdf()async{
    final inc=sum('Income'),exp=sum('Expense');
    final doc=pw.Document();
    doc.addPage(pw.MultiPage(build:(_)=>[
      pw.Text('HAFEEZ RENT A CAR',style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold)),
      pw.SizedBox(height:6),pw.Text('Financial Report'),
      pw.Text('Period: ${rangeText()}'),pw.SizedBox(height:14),
      pw.Text('Total Income: ${money(inc)}'),
      pw.Text('Total Expenses: ${money(exp)}'),
      pw.Text('Net Profit: ${money(inc-exp)}'),
      pw.Text('Total Transactions: ${filtered.length}'),
      pw.Text('Rentals: ${widget.a.rentals.where((r){final d=DateTime.tryParse(r.pickupDate);return d!=null&&!d.isBefore(_start())&&!d.isAfter(_end());}).length}'),
      pw.SizedBox(height:16),
      pw.TableHelper.fromTextArray(headers:['Date','Type','Vehicle','Description','Amount'],data:filtered.map((e)=>[e.date,e.type,e.vehicle,e.title,money(e.amount)]).toList()),
    ]));
    await Printing.sharePdf(bytes:await doc.save(),filename:'hafeez_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }
  Future<void> exportExcel()async{
    final book=Excel.createExcel(); final sheet=book['Financial Report'];
    sheet.appendRow([TextCellValue('HAFEEZ RENT A CAR')]);
    sheet.appendRow([TextCellValue('Financial Report')]);
    sheet.appendRow([TextCellValue('Period'),TextCellValue(rangeText())]);
    sheet.appendRow([TextCellValue('Total Income'),DoubleCellValue(sum('Income'))]);
    sheet.appendRow([TextCellValue('Total Expenses'),DoubleCellValue(sum('Expense'))]);
    sheet.appendRow([TextCellValue('Net Profit'),DoubleCellValue(sum('Income')-sum('Expense'))]);
    sheet.appendRow([TextCellValue('Total Transactions'),IntCellValue(filtered.length)]);
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('Date'),TextCellValue('Type'),TextCellValue('Vehicle'),TextCellValue('Description'),TextCellValue('Amount')]);
    for(final e in filtered){sheet.appendRow([TextCellValue(e.date),TextCellValue(e.type),TextCellValue(e.vehicle),TextCellValue(e.title),DoubleCellValue(e.amount)]);}
    final bytes=book.encode(); if(bytes==null)return;
    final dir=await getTemporaryDirectory(); final file=File('${dir.path}/hafeez_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)],text:'Hafeez Rent A Car Financial Report');
  }
  @override Widget build(BuildContext c){
    final inc=sum('Income'),exp=sum('Expense');
    return Scaffold(appBar:AppBar(title:const Text('Financial Reports',style:TextStyle(fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:exportPdf,icon:const Icon(Icons.picture_as_pdf,color:Colors.redAccent)),IconButton(onPressed:exportExcel,icon:const Icon(Icons.table_view,color:Colors.green))]),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        const Text('Income, Expenses & Profit',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),
        const Text('Daily, weekly, monthly, yearly and custom reports',style:TextStyle(color:muted)),
        const SizedBox(height:16),
        Wrap(spacing:8,runSpacing:8,children:List.generate(5,(i)=>ChoiceChip(label:Text(['Daily','Weekly','Monthly','Yearly','Custom'][i]),selected:period==i,onSelected:(_){setState(()=>period=i);},selectedColor:gold,labelStyle:TextStyle(color:period==i?Colors.black:Colors.white,fontWeight:FontWeight.w700)))),
        const SizedBox(height:12),
        Card(child:ListTile(leading:const Icon(Icons.date_range,color:gold),title:Text(period==4?'Custom date range':'Report period'),subtitle:Text(period==4?'${from==null?'Start':from.toString().substring(0,10)}  →  ${to==null?'End':to.toString().substring(0,10)}':rangeText()),onTap:period==4?null:pickDate,trailing:period==4?Wrap(children:[IconButton(onPressed:()=>pickCustom(true),icon:const Icon(Icons.calendar_today)),IconButton(onPressed:()=>pickCustom(false),icon:const Icon(Icons.event))]):null)),
        const SizedBox(height:14),
        GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:1.55,children:[Stat('Total Income',money(inc),Icons.trending_up),Stat('Total Expenses',money(exp),Icons.trending_down),Stat('Net Profit',money(inc-exp),Icons.account_balance_wallet),Stat('Transactions','${filtered.length}',Icons.receipt_long)]),
        const SizedBox(height:16),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Download Report',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text('Period: ${rangeText()}',style:const TextStyle(color:muted)),
          const SizedBox(height:12),Row(children:[Expanded(child:FilledButton.icon(onPressed:exportPdf,style:FilledButton.styleFrom(backgroundColor:Colors.redAccent),icon:const Icon(Icons.picture_as_pdf),label:const Text('PDF'))),const SizedBox(width:10),Expanded(child:FilledButton.icon(onPressed:exportExcel,style:FilledButton.styleFrom(backgroundColor:Colors.green),icon:const Icon(Icons.table_view),label:const Text('Excel')))])
        ]))),
        const SizedBox(height:16),const Text('Transactions',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),
        ...filtered.reversed.map((e)=>Card(child:ListTile(title:Text(e.title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${e.date} • ${e.vehicle} • ${e.type}',style:const TextStyle(color:muted,fontSize:11)),trailing:Text(money(e.amount),style:TextStyle(color:e.type=='Income'?Colors.green:Colors.redAccent,fontWeight:FontWeight.w900)))))
      ]));
  }
}
Future<void> backupData(BuildContext c,_AppState a)async{
  final payload=jsonEncode({'version':'5.2.0','exportedAt':DateTime.now().toIso8601String(),'adminEmail':a.email,'customers':a.customers.map((x)=>x.toJson()).toList(),'drivers':a.drivers.map((x)=>x.toJson()).toList(),'vehicles':a.vehicles.map((x)=>x.toJson()).toList(),'clients':a.clients.map((x)=>x.toJson()).toList(),'rentals':a.rentals.map((x)=>x.toJson()).toList(),'entries':a.entries.map((x)=>x.toJson()).toList(),'rides':a.rides.map((x)=>x.toJson()).toList()});
  final dir=await getTemporaryDirectory();final file=File('${dir.path}/hafeez_business_backup_${DateTime.now().millisecondsSinceEpoch}.json');await file.writeAsString(payload);await Share.shareXFiles([XFile(file.path)],text:'Hafeez Rent A Car business backup');
}
Future<void> vehicleProfitability(BuildContext c,_AppState a)async{
  await showModalBottomSheet(context:c,isScrollControlled:true,backgroundColor:panel,builder:(_)=>DraggableScrollableSheet(expand:false,builder:(_,sc){return ListView(controller:sc,padding:const EdgeInsets.all(18),children:[const Text('Vehicle Profitability',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:10),...a.vehicles.map((v){final inc=a.entries.where((e)=>e.type=='Income'&&e.vehicle==v.reg).fold(0.0,(s,e)=>s+e.amount);final exp=a.entries.where((e)=>e.type=='Expense'&&e.vehicle==v.reg).fold(0.0,(s,e)=>s+e.amount);return Card(child:ListTile(title:Text(v.name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${v.reg} • Income ${money(inc)} • Expense ${money(exp)}'),trailing:Text(money(inc-exp),style:TextStyle(color:inc-exp>=0?Colors.green:Colors.redAccent,fontWeight:FontWeight.w900))));})]);}));
}
Future<void> verificationPage(BuildContext c,_AppState a)async{
  await showModalBottomSheet(context:c,isScrollControlled:true,backgroundColor:panel,builder:(_)=>StatefulBuilder(builder:(ctx,setState){return SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[const Text('Account Verification',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:10),const Text('Local verification flag is for admin record-keeping. Real email/SMS OTP requires Firebase/Supabase configuration.',style:TextStyle(color:muted)),const SizedBox(height:12),...a.customers.map((u)=>SwitchListTile(title:Text(u.name),subtitle:Text('Customer • ${u.email}'),value:u.verified,onChanged:(v)async{u.verified=v;await a.save();setState((){});})),...a.drivers.map((u)=>SwitchListTile(title:Text(u.name),subtitle:Text('Driver • ${u.email}'),value:u.verified,onChanged:(v)async{u.verified=v;await a.save();setState((){});})),]));}));
}
Future<void> expiryAlerts(BuildContext c,_AppState a)async{
  final items=<String>[];final now=DateTime.now();
  for(final v in a.vehicles){for(final pair in {'Insurance':v.insuranceExpiry,'Registration':v.registrationExpiry}.entries){final d=DateTime.tryParse(pair.value);if(d!=null&&d.difference(now).inDays<=30)items.add('${pair.key}: ${v.name} (${v.reg}) → ${pair.value}');}}
  for(final x in a.clients){final d=DateTime.tryParse(x.licenseExpiry);if(d!=null&&d.difference(now).inDays<=30)items.add('License: ${x.name} → ${x.licenseExpiry}');}
  await showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('Expiry & Reminder Center'),content:SizedBox(width:480,child:items.isEmpty?const Text('No expiry records within the next 30 days.'):ListView(shrinkWrap:true,children:items.map((x)=>ListTile(leading:const Icon(Icons.warning_amber,color:Colors.orange),title:Text(x))).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))]));
}

Future<void> adminDialog(BuildContext c,_AppState a)async{final e=TextEditingController(text:a.email),p=TextEditingController();final ok=await showDialog<bool>(context:c,builder:(_)=>AlertDialog(title:const Text('Administration'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:e,decoration:const InputDecoration(labelText:'Admin Email')),const SizedBox(height:10),TextField(controller:p,obscureText:true,decoration:const InputDecoration(labelText:'New Password (6+ chars)'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:const Text('Save'))]));if(ok==true&&e.text.contains('@')&&p.text.length>=6){await a.adminChange(e.text.trim(),p.text);ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Admin credentials updated.')));}}
Future<void> businessDialog(BuildContext c){return showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('Business Settings'),content:const Text('Hafeez Rent A Car\nPremium car rental & fleet management\n\nCurrent build stores business records locally on this device. Cloud sync, WhatsApp, PDF invoices and multi-user access require a backend/service connection.'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))]));}
Future<void> confirm(BuildContext c,String title,String msg,VoidCallback yes)=>showDialog(context:c,builder:(_)=>AlertDialog(title:Text(title),content:Text(msg),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:(){Navigator.pop(c);yes();},style:FilledButton.styleFrom(backgroundColor:Colors.redAccent),child:const Text('Confirm'))]));
Future<bool> confirmAction(BuildContext c,String title,String msg)async=>await showDialog<bool>(context:c,builder:(_)=>AlertDialog(title:Text(title),content:Text(msg),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:Colors.black),child:const Text('Confirm'))]))??false;
Future<void> showInfo(BuildContext c,String title,String msg)=>showDialog(context:c,builder:(_)=>AlertDialog(title:Text(title),content:Text(msg),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))]));
Future<void> onSaveAndSnack(BuildContext c,_AppState a,VoidCallback refresh,String msg)async{await a.save();refresh();ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(msg)));}
