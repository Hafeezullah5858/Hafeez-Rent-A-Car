from pathlib import Path
p=Path('/mnt/data/hafeez_v4/v63audit/lib/main.dart')
s=p.read_text()
start=s.index('class Home extends StatefulWidget {')
end=s.index('Widget _metricCard(', start)
new=r'''class Home extends StatefulWidget {
  final AppController c;
  const Home({super.key, required this.c});
  @override State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  static const titles = ['Executive Overview', 'Fleet Management', 'Driver Management', 'Customers', 'Rental Operations', 'Operations', 'Business Reports'];
  static const icons = [Icons.space_dashboard_rounded, Icons.directions_car_rounded, Icons.badge_rounded, Icons.people_alt_rounded, Icons.assignment_rounded, Icons.build_circle_rounded, Icons.analytics_rounded];

  void select(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final pages = [Dashboard(c: widget.c), Vehicles(c: widget.c), Drivers(c: widget.c), Customers(c: widget.c), Rentals(c: widget.c), Operations(c: widget.c), Reports(c: widget.c)];
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: wide ? 24 : 16,
        title: Row(children: [
          Container(width: 42, height: 42, padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: HrcTheme.ink, borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: HrcTheme.gold.withOpacity(.18), blurRadius: 14)]), child: Image.asset('assets/app_icon.png')),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('HAFEEZ RENT A CAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            Text(titles[tab], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ]),
        actions: [
          if (widget.c.user != null) IconButton(tooltip: 'Sync cloud data', onPressed: () async { try { await widget.c.refreshCloud(); } catch (e) { if (context.mounted) showError(context, e); } }, icon: const Icon(Icons.cloud_sync_rounded)),
          IconButton(tooltip: 'Notifications & alerts', onPressed: () => showAlerts(context, widget.c), icon: Badge(isLabelVisible: widget.c.overdueRentals > 0, label: Text('${widget.c.overdueRentals}'), child: const Icon(Icons.notifications_none_rounded))),
          IconButton(tooltip: 'Theme', onPressed: () => setState(() => widget.c.dark = !widget.c.dark), icon: Icon(widget.c.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
          PopupMenuButton<String>(
            tooltip: 'Administration',
            onSelected: (v) async { if (v == 'account') await showAccount(context, widget.c); if (v == 'settings') await showBusinessSettings(context, widget.c); if (v == 'roles') await showRoles(context, widget.c); if (v == 'audit') await showAuditLog(context, widget.c); if (v == 'backup') await showBackup(context, widget.c); if (v == 'alerts') await showAlerts(context, widget.c); if (v == 'about') await showSystemInfo(context, widget.c); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'account', child: Text('Cloud Account')),
              PopupMenuItem(value: 'settings', child: Text('Business Settings')),
              PopupMenuItem(value: 'roles', child: Text('Admin Roles & Permissions')),
              PopupMenuItem(value: 'audit', child: Text('Audit Log')),
              PopupMenuItem(value: 'backup', child: Text('Backup / Restore')),
              PopupMenuItem(value: 'alerts', child: Text('Alerts & Expiry')),
              PopupMenuItem(value: 'about', child: Text('System Information')),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(children: [
        if (wide) _sideNav(context),
        Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]))),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: tab, onDestinationSelected: select, labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, destinations: const [
        NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Overview'),
        NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car_rounded), label: 'Fleet'),
        NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge_rounded), label: 'Drivers'),
        NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Clients'),
        NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Rentals'),
        NavigationDestination(icon: Icon(Icons.build_circle_outlined), selectedIcon: Icon(Icons.build_circle_rounded), label: 'Ops'),
        NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics_rounded), label: 'Reports'),
      ]),
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(backgroundColor: HrcTheme.ink, foregroundColor: Colors.white, onPressed: () => showEntry(context, widget.c), icon: const Icon(Icons.add_rounded), label: const Text('New transaction', style: TextStyle(fontWeight: FontWeight.w800))) : null,
    );
  }

  Widget _sideNav(BuildContext context) => Container(width: 232, margin: const EdgeInsets.fromLTRB(16, 0, 0, 16), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.5))), child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(10, 12, 10, 16), child: Row(children: [Container(width: 38, height: 38, padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: HrcTheme.ink, borderRadius: BorderRadius.circular(11)), child: Image.asset('assets/app_icon.png')), const SizedBox(width: 10), const Expanded(child: Text('CONTROL CENTER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)))])),
    for (var i = 0; i < titles.length; i++) Padding(padding: const EdgeInsets.only(bottom: 4), child: ListTile(dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), selected: tab == i, selectedTileColor: HrcTheme.gold.withOpacity(.12), leading: Icon(icons[i], size: 20, color: tab == i ? HrcTheme.gold : null), title: Text(titles[i].replaceFirst('Executive ', ''), style: TextStyle(fontSize: 12, fontWeight: tab == i ? FontWeight.w900 : FontWeight.w600)), onTap: () => select(i))),
    const Spacer(),
    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(widget.c.user == null ? Icons.cloud_off_rounded : Icons.cloud_done_rounded, size: 17), const SizedBox(width: 8), Expanded(child: Text(widget.c.user == null ? 'Local mode' : 'Cloud connected', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)))])),
  ]));
}

class Dashboard extends StatelessWidget {
  final AppController c;
  const Dashboard({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIncome = c.entries.where((e) => e.type != EntryType.expense && !e.date.isBefore(today)).fold(0.0, (s, e) => s + e.amount);
    final todayExpense = c.entries.where((e) => e.type == EntryType.expense && !e.date.isBefore(today)).fold(0.0, (s, e) => s + e.amount);
    final active = c.rentals.where((r) => r.status == RentalStatus.active).toList();
    final occupied = c.vehicles.isEmpty ? 0 : ((c.vehicles.length - c.availableCars) / c.vehicles.length * 100).clamp(0, 100).toDouble();
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 900;
      return ListView(padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 18, wide ? 28 : 16, 110), children: [
        _executiveHero(context, todayIncome, active.length, occupied),
        const SizedBox(height: 20),
        _sectionTitle(context, 'Business performance', DateFormat('EEEE, dd MMM yyyy').format(now)),
        const SizedBox(height: 10),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: wide ? 4 : 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: wide ? 1.65 : 1.55, children: [
          _metricCard(context, 'Today revenue', 'Rs ${money(todayIncome)}', Icons.trending_up_rounded, const Color(0xFF0E9F6E)),
          _metricCard(context, 'Today expenses', 'Rs ${money(todayExpense)}', Icons.trending_down_rounded, const Color(0xFFE05A47)),
          _metricCard(context, 'Receivables', 'Rs ${money(c.receivable)}', Icons.account_balance_wallet_rounded, const Color(0xFF4B68D8)),
          _metricCard(context, 'Net position', 'Rs ${money(c.income - c.expenses)}', Icons.account_balance_rounded, HrcTheme.gold),
        ]),
        const SizedBox(height: 20),
        if (wide) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 6, child: _fleetPanel(context, occupied)),
          const SizedBox(width: 14),
          Expanded(flex: 4, child: _alertsPanel(context)),
        ]) else ...[_fleetPanel(context, occupied), const SizedBox(height: 14), _alertsPanel(context)],
        const SizedBox(height: 20),
        _sectionTitle(context, 'Live rentals', '${active.length} active'),
        const SizedBox(height: 10),
        if (active.isEmpty) _emptyCard(context, Icons.event_available_rounded, 'No active rentals', 'Your live rental contracts will appear here.')
        else ...active.take(5).map((r) { final cu = c.customer(r.customerId); final v = c.vehicle(r.vehicleId); return Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(14), decoration: _surface(context), child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: HrcTheme.gold.withOpacity(.11), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.key_rounded, color: HrcTheme.gold)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v?.name ?? 'Vehicle', style: const TextStyle(fontWeight: FontWeight.w900)), Text('${cu?.name ?? 'Customer'} • ${DateFormat('dd MMM').format(r.endAt)} return', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Rs ${money(r.remaining)}', style: const TextStyle(fontWeight: FontWeight.w900)), Text('outstanding', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))]) ])); }),
        const SizedBox(height: 12),
        _sectionTitle(context, 'Quick actions', 'Common workflows'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _quick(context, 'New rental', Icons.assignment_add_rounded, () => showRental(context, c)),
          _quick(context, 'Payment', Icons.payments_rounded, () => showPayment(context, c)),
          _quick(context, 'Expense', Icons.receipt_long_rounded, () => showEntry(context, c, type: EntryType.expense)),
          _quick(context, 'inDrive', Icons.local_taxi_rounded, () => showEntry(context, c, source: EarningSource.inDrive)),
          _quick(context, 'Yango', Icons.directions_car_rounded, () => showEntry(context, c, source: EarningSource.yango)),
        ]),
      ]);
    });
  }

  Widget _executiveHero(BuildContext context, double revenue, int active, double occupied) => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [HrcTheme.ink, const Color(0xFF27303B)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: HrcTheme.ink.withOpacity(.18), blurRadius: 24, offset: const Offset(0, 10))]), child: Row(children: [Container(width: 54, height: 54, padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: HrcTheme.gold.withOpacity(.18), borderRadius: BorderRadius.circular(16)), child: Image.asset('assets/app_icon.png')), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Good ${DateTime.now().hour < 12 ? 'morning' : DateTime.now().hour < 18 ? 'afternoon' : 'evening'}, Hafeez', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 3), const Text('Your fleet at a glance.', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('Rs ${money(revenue)} revenue today • $active live rentals', style: const TextStyle(color: Colors.white70, fontSize: 12))])), if (MediaQuery.sizeOf(context).width > 650) Container(width: 150, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('FLEET OCCUPANCY', style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 7), Text('${occupied.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: occupied / 100, minHeight: 6, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(HrcTheme.goldLight))) ]))]));

  Widget _fleetPanel(BuildContext context, double occupied) => Container(padding: const EdgeInsets.all(18), decoration: _surface(context), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Expanded(child: Text('Fleet health', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),), Text('${c.availableCars} available', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))]), const SizedBox(height: 14), Row(children: [SizedBox(width: 86, height: 86, child: Stack(alignment: Alignment.center, children: [CircularProgressIndicator(value: occupied / 100, strokeWidth: 9, backgroundColor: Theme.of(context).dividerColor.withOpacity(.35), valueColor: const AlwaysStoppedAnimation(HrcTheme.gold)), Text('${occupied.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))])), const SizedBox(width: 18), Expanded(child: Column(children: [ _healthRow(context, 'Available', c.availableCars, c.vehicles.length, HrcTheme.gold), _healthRow(context, 'Active rentals', c.rentals.where((r)=>r.status==RentalStatus.active).length, c.vehicles.length, const Color(0xFF4B68D8)), _healthRow(context, 'Overdue', c.overdueRentals, c.rentals.length, const Color(0xFFE05A47))]))])]);

  Widget _healthRow(BuildContext context, String label, int value, int total, Color color) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: total == 0 ? 0 : (value / total).clamp(0,1), minHeight: 7, backgroundColor: Theme.of(context).dividerColor.withOpacity(.25), valueColor: AlwaysStoppedAnimation(color)))), const SizedBox(width: 8), Text('$value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))]));

  Widget _alertsPanel(BuildContext context) { final count = c.overdueRentals + c.expiringLicenses.length + c.expiringVehicles.length; return Container(padding: const EdgeInsets.all(18), decoration: _surface(context), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Expanded(child: Text('Attention center', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), Icon(count == 0 ? Icons.verified_rounded : Icons.notifications_active_rounded, color: count == 0 ? const Color(0xFF0E9F6E) : const Color(0xFFE05A47))]), const SizedBox(height: 12), if (count == 0) const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.check_circle_outline_rounded, color: Color(0xFF0E9F6E)), title: Text('Everything looks clear', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('No urgent fleet, license or rental alerts.')) else ...[if(c.overdueRentals>0) _alertRow(context, Icons.warning_amber_rounded, '${c.overdueRentals} overdue rental(s)'), if(c.expiringLicenses.isNotEmpty) _alertRow(context, Icons.badge_rounded, '${c.expiringLicenses.length} license(s) expiring'), if(c.expiringVehicles.isNotEmpty) _alertRow(context, Icons.description_rounded, '${c.expiringVehicles.length} vehicle document(s) expiring')], Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed:()=>showAlerts(context,c), icon:const Icon(Icons.arrow_forward_rounded,size:16), label:const Text('Open alerts')))]); }
  Widget _alertRow(BuildContext context, IconData icon, String text) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Container(width: 34,height:34,decoration:BoxDecoration(color:const Color(0xFFE05A47).withOpacity(.1),borderRadius:BorderRadius.circular(10)),child:Icon(icon,size:17,color:const Color(0xFFE05A47))), title:Text(text,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)));
}

'''
s=s[:start]+new+s[end:]
p.write_text(s)
