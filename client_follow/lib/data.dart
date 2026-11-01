import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'notifications.dart';

/// تحويل الأرقام العربية/الفارسية إلى لاتينية
String normDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    var i = ar.indexOf(c);
    if (i < 0) i = fa.indexOf(c);
    b.write(i >= 0 ? '$i' : c);
  }
  return b.toString();
}

/// تجهيز الرقم لرابط واتساب (wa.me) بحسب رمز الدولة الافتراضي
String waNumber(String phone, String cc) {
  final d = normDigits(phone).replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.startsWith('+')) return d.substring(1);
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith('0')) return cc + d.substring(1);
  if (d.startsWith(cc) && d.length > 9) return d;
  return cc + d;
}

class Client {
  final int? id;
  final String name;
  final String phone;
  final String notes;
  final int createdAt;
  final int? nextDue;

  Client({
    this.id,
    required this.name,
    this.phone = '',
    this.notes = '',
    int? createdAt,
    this.nextDue,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
        'created_at': createdAt,
      };

  factory Client.fromMap(Map<String, Object?> m) => Client(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: (m['phone'] ?? '') as String,
        notes: (m['notes'] ?? '') as String,
        createdAt: m['created_at'] as int?,
        nextDue: m['next_due'] as int?,
      );
}

class Followup {
  final int? id;
  final int clientId;
  final int dueAt;
  final bool done;
  final String note;
  final String result;
  final int? doneAt;
  final String clientName;
  final String clientPhone;

  const Followup({
    this.id,
    required this.clientId,
    required this.dueAt,
    this.done = false,
    this.note = '',
    this.result = '',
    this.doneAt,
    this.clientName = '',
    this.clientPhone = '',
  });

  bool get isOverdue =>
      !done && dueAt < DateTime.now().millisecondsSinceEpoch;

  factory Followup.fromMap(Map<String, Object?> m) => Followup(
        id: m['id'] as int?,
        clientId: m['client_id'] as int,
        dueAt: m['due_at'] as int,
        done: ((m['done'] as int?) ?? 0) == 1,
        note: (m['note'] ?? '') as String,
        result: (m['result'] ?? '') as String,
        doneAt: m['done_at'] as int?,
        clientName: (m['cname'] ?? '') as String,
        clientPhone: (m['cphone'] ?? '') as String,
      );
}

/// طبقة البيانات المحلية (SQLite) + حالة التطبيق
class Repo extends ChangeNotifier {
  Repo._();
  static final Repo i = Repo._();

  late Database db;

  List<Followup> overdue = [];
  List<Followup> today = [];
  List<Followup> upcoming = [];
  List<Followup> done = [];
  List<Client> clients = [];
  String query = '';

  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'client_follow.db');
    db = await openDatabase(
      path,
      version: 1,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE clients(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT,
            notes TEXT,
            created_at INTEGER
          )''');
        await d.execute('''
          CREATE TABLE followups(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
            due_at INTEGER NOT NULL,
            note TEXT,
            done INTEGER NOT NULL DEFAULT 0,
            result TEXT,
            done_at INTEGER
          )''');
        await d.execute('CREATE INDEX idx_f_due ON followups(done, due_at)');
        await d.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
      },
    );
    await reload();
  }

  // ---------- الاستعلامات ----------
  static const _sel =
      'SELECT f.*, c.name AS cname, c.phone AS cphone FROM followups f '
      'JOIN clients c ON c.id = f.client_id';

  Future<List<Followup>> _fq(String where, List<Object?> args,
      {String order = 'f.due_at ASC'}) async {
    final rows = await db.rawQuery('$_sel WHERE $where ORDER BY $order', args);
    return rows.map(Followup.fromMap).toList();
  }

  Future<void> reload() async {
    final n = DateTime.now();
    final s = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
    final e = DateTime(n.year, n.month, n.day + 1).millisecondsSinceEpoch;
    overdue = await _fq('f.done=0 AND f.due_at<?', [s]);
    today = await _fq('f.done=0 AND f.due_at>=? AND f.due_at<?', [s, e]);
    upcoming = await _fq('f.done=0 AND f.due_at>=?', [e]);
    done = await _fq('f.done=1', [], order: 'f.done_at DESC LIMIT 200');
    await _loadClients();
    notifyListeners();
  }

  Future<void> _loadClients() async {
    final q = '%${normDigits(query.trim())}%';
    final rows = await db.rawQuery(
      'SELECT c.*, (SELECT MIN(due_at) FROM followups '
      'WHERE client_id=c.id AND done=0) AS next_due '
      'FROM clients c WHERE c.name LIKE ? OR c.phone LIKE ? '
      'ORDER BY c.name COLLATE NOCASE',
      [q, q],
    );
    clients = rows.map(Client.fromMap).toList();
  }

  Future<void> search(String q) async {
    query = q;
    await _loadClients();
    notifyListeners();
  }

  Future<List<Client>> allClients() async {
    final rows = await db.query('clients', orderBy: 'name COLLATE NOCASE');
    return rows.map(Client.fromMap).toList();
  }

  Future<Client?> getClient(int id) async {
    final rows = await db.query('clients', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : Client.fromMap(rows.first);
  }

  Future<List<Followup>> followupsOf(int clientId) =>
      _fq('f.client_id=?', [clientId], order: 'f.done ASC, f.due_at DESC');

  // ---------- العملاء ----------
  Future<int> saveClient(Client c) async {
    int id;
    if (c.id == null) {
      id = await db.insert('clients', c.toMap()..remove('id'));
    } else {
      await db.update('clients', c.toMap()..remove('id'),
          where: 'id=?', whereArgs: [c.id]);
      id = c.id!;
    }
    await reload();
    return id;
  }

  Future<void> deleteClient(int id) async {
    final rows = await db.query('followups',
        columns: ['id'], where: 'client_id=? AND done=0', whereArgs: [id]);
    for (final r in rows) {
      await Notifs.cancel(r['id'] as int);
    }
    await db.delete('followups', where: 'client_id=?', whereArgs: [id]);
    await db.delete('clients', where: 'id=?', whereArgs: [id]);
    await reload();
  }

  // ---------- المواعيد ----------
  Future<int> addFollowup(int clientId, DateTime due, String note) async {
    final id = await db.insert('followups', {
      'client_id': clientId,
      'due_at': due.millisecondsSinceEpoch,
      'note': note,
      'done': 0,
    });
    await _schedule(id);
    await reload();
    return id;
  }

  Future<void> updateFollowup(int id, DateTime due, String note) async {
    await db.update(
        'followups', {'due_at': due.millisecondsSinceEpoch, 'note': note},
        where: 'id=?', whereArgs: [id]);
    await Notifs.cancel(id);
    await _schedule(id);
    await reload();
  }

  Future<void> deleteFollowup(int id) async {
    await Notifs.cancel(id);
    await db.delete('followups', where: 'id=?', whereArgs: [id]);
    await reload();
  }

  Future<void> completeFollowup(int id, String result,
      {DateTime? next, String nextNote = ''}) async {
    final rows = await db.query('followups',
        columns: ['client_id'], where: 'id=?', whereArgs: [id]);
    await db.update(
        'followups',
        {
          'done': 1,
          'result': result,
          'done_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id=?',
        whereArgs: [id]);
    await Notifs.cancel(id);
    if (next != null && rows.isNotEmpty) {
      await addFollowup(rows.first['client_id'] as int, next, nextNote);
    } else {
      await reload();
    }
  }

  Future<void> _schedule(int id) async {
    final rows = await _fq('f.id=?', [id]);
    if (rows.isEmpty || rows.first.done) return;
    final f = rows.first;
    await Notifs.schedule(
      id,
      'موعد متابعة: ${f.clientName}',
      f.note.isEmpty ? 'حان موعد التواصل مع العميل' : f.note,
      DateTime.fromMillisecondsSinceEpoch(f.dueAt),
    );
  }

  Future<void> rescheduleAll() async {
    await Notifs.cancelAll();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _fq('f.done=0 AND f.due_at>?', [now]);
    for (final f in rows) {
      await Notifs.schedule(
        f.id!,
        'موعد متابعة: ${f.clientName}',
        f.note.isEmpty ? 'حان موعد التواصل مع العميل' : f.note,
        DateTime.fromMillisecondsSinceEpoch(f.dueAt),
      );
    }
  }

  // ---------- الإعدادات ----------
  Future<String?> getSetting(String k) async {
    final r = await db.query('settings', where: 'key=?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setSetting(String k, String v) => db.insert(
      'settings', {'key': k, 'value': v},
      conflictAlgorithm: ConflictAlgorithm.replace);

  // ---------- النسخ الاحتياطي ----------
  Future<String> exportJson() async {
    return jsonEncode({
      'app': 'client_follow',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'clients': await db.query('clients'),
      'followups': await db.query('followups'),
    });
  }

  Future<void> importJson(String s) async {
    final m = jsonDecode(s);
    if (m is! Map || m['app'] != 'client_follow') {
      throw const FormatException('ملف النسخة الاحتياطية غير صالح');
    }
    await db.transaction((t) async {
      await t.delete('followups');
      await t.delete('clients');
      final b = t.batch();
      for (final e in (m['clients'] as List)) {
        b.insert('clients', Map<String, Object?>.from(e as Map));
      }
      for (final e in (m['followups'] as List)) {
        b.insert('followups', Map<String, Object?>.from(e as Map));
      }
      await b.commit(noResult: true);
    });
    await rescheduleAll();
    await reload();
  }
}
