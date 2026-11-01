import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data.dart';
import 'notifications.dart';

final _fDay = DateFormat('EEEE d MMMM', 'ar');
final _fTime = DateFormat('h:mm a', 'ar');

String fmtDue(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_fDay.format(d)} • ${_fTime.format(d)}';
}

DateTime _at(int days, int hour) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + days, hour);
}

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> confirm(BuildContext c, String title, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true), child: const Text('تأكيد')),
      ],
    ),
  );
  return r ?? false;
}

Future<DateTime?> pickDateTime(BuildContext c, DateTime initial) async {
  final now = DateTime.now();
  final first = DateTime(now.year, now.month, now.day);
  final d = await showDatePicker(
    context: c,
    initialDate: initial.isBefore(first) ? first : initial,
    firstDate: first,
    lastDate: first.add(const Duration(days: 1825)),
  );
  if (d == null || !c.mounted) return null;
  final t = await showTimePicker(
      context: c, initialTime: TimeOfDay.fromDateTime(initial));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

Future<void> openWhatsApp(BuildContext c, String phone) async {
  if (phone.trim().isEmpty) {
    toast(c, 'لا يوجد رقم هاتف لهذا العميل');
    return;
  }
  final cc = await Repo.i.getSetting('cc') ?? '967';
  final ok = await launchUrl(Uri.parse('https://wa.me/${waNumber(phone, cc)}'),
      mode: LaunchMode.externalApplication);
  if (!ok && c.mounted) toast(c, 'تعذّر فتح واتساب');
}

Future<void> callPhone(BuildContext c, String phone) async {
  if (phone.trim().isEmpty) {
    toast(c, 'لا يوجد رقم هاتف لهذا العميل');
    return;
  }
  await launchUrl(Uri(scheme: 'tel', path: phone));
}

// ====================== الصفحة الرئيسية ======================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  static const titles = ['اليوم', 'المواعيد', 'العملاء', 'الإعدادات'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titles[tab])),
      body: IndexedStack(index: tab, children: const [
        TodayPage(),
        AppointmentsPage(),
        ClientsPage(),
        SettingsPage(),
      ]),
      floatingActionButton: tab >= 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                if (tab == 2) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ClientFormPage()));
                } else {
                  followupSheet(context);
                }
              },
              icon: Icon(tab == 2 ? Icons.person_add : Icons.add_alarm),
              label: Text(tab == 2 ? 'عميل جديد' : 'موعد جديد'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'اليوم'),
          NavigationDestination(icon: Icon(Icons.event_note), label: 'المواعيد'),
          NavigationDestination(icon: Icon(Icons.people), label: 'العملاء'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ====================== اليوم ======================
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Repo.i,
      builder: (context, _) {
        final r = Repo.i;
        final cs = Theme.of(context).colorScheme;
        final items = <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(children: [
              _Stat('متأخر', r.overdue.length, Icons.alarm, cs.errorContainer),
              const SizedBox(width: 8),
              _Stat('اليوم', r.today.length, Icons.today, cs.primaryContainer),
              const SizedBox(width: 8),
              _Stat('قادم', r.upcoming.length, Icons.upcoming,
                  cs.secondaryContainer),
            ]),
          ),
        ];
        if (r.overdue.isNotEmpty) {
          items.add(_SectionTitle('متأخرون عن موعد التواصل', cs.error));
          items.addAll(r.overdue.map((f) => FollowupTile(f)));
        }
        if (r.today.isNotEmpty) {
          items.add(_SectionTitle('مواعيد اليوم', cs.primary));
          items.addAll(r.today.map((f) => FollowupTile(f)));
        }
        if (r.overdue.isEmpty && r.today.isEmpty) {
          items.add(const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
                child: Column(children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
              SizedBox(height: 8),
              Text('لا توجد مواعيد لليوم'),
            ])),
          ));
        }
        items.add(const SizedBox(height: 90));
        return ListView(children: items);
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int n;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.n, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text('$n',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label),
          ]),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      );
}

// ====================== المواعيد ======================
class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        const TabBar(tabs: [
          Tab(text: 'القادمة'),
          Tab(text: 'المتأخرة'),
          Tab(text: 'المنجزة'),
        ]),
        Expanded(
          child: ListenableBuilder(
            listenable: Repo.i,
            builder: (context, _) => TabBarView(children: [
              _FList(Repo.i.upcoming, groupByDay: true),
              _FList(Repo.i.overdue),
              _FList(Repo.i.done),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _FList extends StatelessWidget {
  final List<Followup> list;
  final bool groupByDay;
  const _FList(this.list, {this.groupByDay = false});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return const Center(child: Text('لا توجد عناصر'));
    }
    final children = <Widget>[];
    String? last;
    for (final f in list) {
      if (groupByDay) {
        final d = _fDay.format(DateTime.fromMillisecondsSinceEpoch(f.dueAt));
        if (d != last) {
          children.add(_SectionTitle(d, Theme.of(context).colorScheme.primary));
          last = d;
        }
      }
      children.add(FollowupTile(f));
    }
    children.add(const SizedBox(height: 90));
    return ListView(children: children);
  }
}

class FollowupTile extends StatelessWidget {
  final Followup f;
  final bool linkClient;
  const FollowupTile(this.f, {super.key, this.linkClient = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLate = f.isOverdue;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: linkClient
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ClientDetailsPage(f.clientId)))
            : null,
        onLongPress: f.done ? null : () => _menu(context),
        leading: CircleAvatar(
          backgroundColor: f.done
              ? cs.secondaryContainer
              : isLate
                  ? cs.errorContainer
                  : cs.primaryContainer,
          child: Icon(f.done
              ? Icons.check
              : isLate
                  ? Icons.alarm
                  : Icons.schedule),
        ),
        title: Text(f.clientName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtDue(f.dueAt),
                style: TextStyle(color: isLate ? cs.error : null)),
            if (f.note.isNotEmpty)
              Text(f.note, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (f.done && f.result.isNotEmpty)
              Text('النتيجة: ${f.result}',
                  style: TextStyle(color: cs.primary)),
          ],
        ),
        trailing: f.done
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    tooltip: 'واتساب',
                    icon: const Icon(Icons.chat_outlined),
                    onPressed: () => openWhatsApp(context, f.clientPhone)),
                IconButton(
                    tooltip: 'تسجيل النتيجة',
                    icon: const Icon(Icons.task_alt),
                    onPressed: () => completeSheet(context, f)),
              ]),
      ),
    );
  }

  void _menu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_calendar),
            title: const Text('تعديل / تأجيل الموعد'),
            onTap: () {
              Navigator.pop(context);
              followupSheet(context, edit: f);
            },
          ),
          ListTile(
            leading: const Icon(Icons.task_alt),
            title: const Text('تسجيل نتيجة التواصل'),
            onTap: () {
              Navigator.pop(context);
              completeSheet(context, f);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('حذف الموعد'),
            onTap: () async {
              Navigator.pop(context);
              if (await confirm(context, 'حذف الموعد', 'هل تريد حذف هذا الموعد؟')) {
                await Repo.i.deleteFollowup(f.id!);
              }
            },
          ),
        ]),
      ),
    );
  }
}

// ====================== نماذج المواعيد ======================
class QuickWhen extends StatelessWidget {
  final ValueChanged<DateTime> onPick;
  const QuickWhen({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final opts = <String, DateTime Function()>{
      'بعد ساعة': () => DateTime.now().add(const Duration(hours: 1)),
      'غدًا': () => _at(1, 10),
      'بعد 3 أيام': () => _at(3, 10),
      'بعد أسبوع': () => _at(7, 10),
    };
    return Wrap(spacing: 8, children: [
      for (final e in opts.entries)
        ActionChip(label: Text(e.key), onPressed: () => onPick(e.value())),
    ]);
  }
}

Future<Client?> pickClient(BuildContext c) async {
  final all = await Repo.i.allClients();
  if (!c.mounted) return null;
  if (all.isEmpty) {
    toast(c, 'أضف عميلًا أولًا');
    return null;
  }
  return showDialog<Client>(context: c, builder: (_) => _PickDialog(all));
}

class _PickDialog extends StatefulWidget {
  final List<Client> all;
  const _PickDialog(this.all);
  @override
  State<_PickDialog> createState() => _PickDialogState();
}

class _PickDialogState extends State<_PickDialog> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final qq = normDigits(q.trim());
    final list = widget.all
        .where((c) => c.name.contains(qq) || c.phone.contains(qq))
        .toList();
    return AlertDialog(
      title: const Text('اختر العميل'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(children: [
          TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'بحث'),
            onChanged: (v) => setState(() => q = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final c in list)
                  ListTile(
                    title: Text(c.name),
                    subtitle: Text(c.phone),
                    onTap: () => Navigator.pop(context, c),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

Future<void> followupSheet(BuildContext c,
    {Client? client, Followup? edit}) async {
  var cl = client;
  if (cl == null && edit == null) {
    cl = await pickClient(c);
    if (cl == null || !c.mounted) return;
  }
  await showModalBottomSheet(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FollowupForm(
      clientId: edit?.clientId ?? cl!.id!,
      clientName: edit?.clientName ?? cl!.name,
      edit: edit,
    ),
  );
}

class _FollowupForm extends StatefulWidget {
  final int clientId;
  final String clientName;
  final Followup? edit;
  const _FollowupForm(
      {required this.clientId, required this.clientName, this.edit});
  @override
  State<_FollowupForm> createState() => _FollowupFormState();
}

class _FollowupFormState extends State<_FollowupForm> {
  late DateTime when;
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    when = widget.edit != null
        ? DateTime.fromMillisecondsSinceEpoch(widget.edit!.dueAt)
        : _at(1, 10);
    note.text = widget.edit?.note ?? '';
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.edit == null) {
      await Repo.i.addFollowup(widget.clientId, when, note.text.trim());
    } else {
      await Repo.i.updateFollowup(widget.edit!.id!, when, note.text.trim());
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.edit == null ? 'موعد جديد' : 'تعديل الموعد',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(widget.clientName),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(fmtDue(when.millisecondsSinceEpoch)),
              onPressed: () async {
                final d = await pickDateTime(context, when);
                if (d != null) setState(() => when = d);
              },
            ),
            const SizedBox(height: 8),
            QuickWhen(onPick: (d) => setState(() => when = d)),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'سبب التواصل / ملاحظة'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }
}

// ====================== تسجيل نتيجة التواصل ======================
Future<void> completeSheet(BuildContext c, Followup f) => showModalBottomSheet(
      context: c,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CompleteSheet(f),
    );

class _CompleteSheet extends StatefulWidget {
  final Followup f;
  const _CompleteSheet(this.f);
  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  static const results = [
    'تم التواصل',
    'لم يرد',
    'مهتم',
    'يحتاج وقتًا',
    'تم الاتفاق',
    'غير مهتم',
  ];
  String? result;
  final note = TextEditingController();
  bool next = true;
  DateTime nextAt = _at(1, 10);

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = [
      if (result != null) result!,
      if (note.text.trim().isNotEmpty) note.text.trim(),
    ].join(' — ');
    await Repo.i.completeFollowup(widget.f.id!, text,
        next: next ? nextAt : null,
        nextNote: next ? 'متابعة بعد: ${result ?? 'التواصل السابق'}' : '');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('نتيجة التواصل مع ${widget.f.clientName}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final r in results)
                ChoiceChip(
                  label: Text(r),
                  selected: result == r,
                  onSelected: (_) => setState(() => result = r),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تحديد موعد متابعة جديد'),
              value: next,
              onChanged: (v) => setState(() => next = v),
            ),
            if (next) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(fmtDue(nextAt.millisecondsSinceEpoch)),
                onPressed: () async {
                  final d = await pickDateTime(context, nextAt);
                  if (d != null) setState(() => nextAt = d);
                },
              ),
              const SizedBox(height: 8),
              QuickWhen(onPick: (d) => setState(() => nextAt = d)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('حفظ النتيجة')),
          ],
        ),
      ),
    );
  }
}

// ====================== العملاء ======================
class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: ctrl,
          onChanged: Repo.i.search,
          decoration: InputDecoration(
            hintText: 'ابحث بالاسم أو رقم الهاتف',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      ctrl.clear();
                      Repo.i.search('');
                      setState(() {});
                    }),
          ),
        ),
      ),
      Expanded(
        child: ListenableBuilder(
          listenable: Repo.i,
          builder: (context, _) {
            final list = Repo.i.clients;
            if (list.isEmpty) {
              return const Center(child: Text('لا يوجد عملاء'));
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ClientDetailsPage(c.id!))),
                    leading: CircleAvatar(
                        child: Text(c.name.isEmpty ? '?' : c.name[0])),
                    title: Text(c.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(c.nextDue == null
                        ? c.phone
                        : '${c.phone}\nالتالي: ${fmtDue(c.nextDue!)}'),
                    isThreeLine: c.nextDue != null,
                    trailing: IconButton(
                      icon: const Icon(Icons.chat_outlined),
                      onPressed: () => openWhatsApp(context, c.phone),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class ClientFormPage extends StatefulWidget {
  final Client? client;
  const ClientFormPage({super.key, this.client});
  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  final _k = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.client?.name);
  late final phone = TextEditingController(text: widget.client?.phone);
  late final notes = TextEditingController(text: widget.client?.notes);

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_k.currentState!.validate()) return;
    final id = await Repo.i.saveClient(Client(
      id: widget.client?.id,
      name: name.text.trim(),
      phone: normDigits(phone.text.trim()),
      notes: notes.text.trim(),
      createdAt: widget.client?.createdAt,
    ));
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.client == null ? 'عميل جديد' : 'تعديل العميل')),
      body: Form(
        key: _k,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'اسم العميل', prefixIcon: Icon(Icons.person)),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone)),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: notes,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'ملاحظات', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('حفظ'),
          ),
        ]),
      ),
    );
  }
}

class ClientDetailsPage extends StatefulWidget {
  final int id;
  const ClientDetailsPage(this.id, {super.key});
  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  Client? client;
  List<Followup> fs = [];

  @override
  void initState() {
    super.initState();
    Repo.i.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    Repo.i.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final c = await Repo.i.getClient(widget.id);
    final f = await Repo.i.followupsOf(widget.id);
    if (!mounted) return;
    setState(() {
      client = c;
      fs = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = client;
    if (c == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ClientFormPage(client: c))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirm(context, 'حذف العميل',
                  'سيتم حذف العميل وجميع مواعيده نهائيًا.')) {
                await Repo.i.deleteClient(c.id!);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => followupSheet(context, client: c),
        icon: const Icon(Icons.add_alarm),
        label: const Text('موعد جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              CircleAvatar(
                radius: 34,
                child: Text(c.name.isEmpty ? '?' : c.name[0],
                    style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 8),
              Text(c.phone.isEmpty ? 'بدون رقم' : c.phone,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => callPhone(context, c.phone),
                    icon: const Icon(Icons.call),
                    label: const Text('اتصال'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openWhatsApp(context, c.phone),
                    icon: const Icon(Icons.chat),
                    label: const Text('واتساب'),
                  ),
                ),
              ]),
            ]),
          ),
          if (c.notes.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notes),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.notes)),
                ]),
              ),
            ),
          _SectionTitle('سجل المواعيد', Theme.of(context).colorScheme.primary),
          if (fs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('لا توجد مواعيد لهذا العميل')),
            ),
          ...fs.map((f) => FollowupTile(f, linkClient: false)),
        ],
      ),
    );
  }
}

// ====================== الإعدادات ======================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final cc = TextEditingController(text: '967');

  @override
  void initState() {
    super.initState();
    Repo.i.getSetting('cc').then((v) {
      if (v != null && mounted) cc.text = v;
    });
  }

  @override
  void dispose() {
    cc.dispose();
    super.dispose();
  }

  Future<void> _backup() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm', 'en').format(DateTime.now());
    final file = File('${dir.path}/client_follow_backup_$stamp.json');
    await file.writeAsString(await Repo.i.exportJson());
    await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية - متابع العملاء');
  }

  Future<void> _restore() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (r == null || r.files.isEmpty) return;
    if (!mounted) return;
    final ok = await confirm(context, 'استعادة البيانات',
        'سيتم استبدال جميع البيانات الحالية ببيانات النسخة الاحتياطية.');
    if (!ok) return;
    try {
      final f = r.files.single;
      final bytes = f.bytes ?? await File(f.path!).readAsBytes();
      await Repo.i.importJson(utf8.decode(bytes));
      if (mounted) toast(context, 'تمت استعادة البيانات بنجاح');
    } catch (e) {
      if (mounted) toast(context, 'فشلت الاستعادة: ملف غير صالح');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('واتساب', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      TextField(
        controller: cc,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'رمز الدولة الافتراضي (مثال: 967)',
          suffixIcon: IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await Repo.i.setSetting('cc', normDigits(cc.text.trim()));
              if (mounted) toast(context, 'تم الحفظ');
            },
          ),
        ),
      ),
      const Divider(height: 32),
      Text('التنبيهات', style: Theme.of(context).textTheme.titleMedium),
      ListTile(
        leading: const Icon(Icons.notifications_active),
        title: const Text('تجربة التنبيه'),
        onTap: () => Notifs.showNow('متابع العملاء', 'التنبيهات تعمل بشكل سليم'),
      ),
      ListTile(
        leading: const Icon(Icons.refresh),
        title: const Text('إعادة جدولة جميع التنبيهات'),
        onTap: () async {
          await Repo.i.rescheduleAll();
          if (mounted) toast(context, 'تمت إعادة الجدولة');
        },
      ),
      const Divider(height: 32),
      Text('النسخ الاحتياطي', style: Theme.of(context).textTheme.titleMedium),
      ListTile(
        leading: const Icon(Icons.backup),
        title: const Text('إنشاء نسخة احتياطية ومشاركتها'),
        onTap: _backup,
      ),
      ListTile(
        leading: const Icon(Icons.restore),
        title: const Text('استعادة من نسخة احتياطية'),
        onTap: _restore,
      ),
      const Divider(height: 32),
      const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('متابع العملاء'),
        subtitle: Text('الإصدار 1.0.0 • يعمل بدون إنترنت'),
      ),
    ]);
  }
}
