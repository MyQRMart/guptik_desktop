import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../services/external/postgres_service.dart';

class DesktopContactsScreen extends StatefulWidget {
  const DesktopContactsScreen({super.key});

  @override
  State<DesktopContactsScreen> createState() => _DesktopContactsScreenState();
}

class _DesktopContactsScreenState extends State<DesktopContactsScreen> {
  final _db = PostgresService();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _groups = [];
  Map<String, dynamic>? _selected;
  String _section = 'People';
  String _filter = 'All';
  bool _loading = true;

  static const _cyan = Color(0xFF22D3EE);
  static const _bg = Color(0xFF0F172A);
  static const _panel = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final people = await _db.getPhoneContacts();
    final groups = await _db.getContactGroups();
    if (!mounted) return;
    setState(() {
      _all = people;
      _groups = groups;
      _loading = false;
      if (_selected != null) {
        final id = _selected!['id'];
        Map<String, dynamic>? next;
        for (final c in people) {
          if (c['id'] == id) {
            next = c;
            break;
          }
        }
        _selected = next;
      }
    });
  }

  List<Map<String, dynamic>> _apply(String key, [List<Map<String, dynamic>>? src]) {
    final list = src ?? _all;
    switch (key) {
      case 'Starred':
        return list.where((c) => c['is_starred'] == true).toList();
      case 'Phone':
        return list.where((c) => (c['phones'] as List).isNotEmpty).toList();
      case 'Email':
        return list.where((c) => (c['emails'] as List).isNotEmpty).toList();
      case 'Both':
        return list
            .where((c) => (c['phones'] as List).isNotEmpty && (c['emails'] as List).isNotEmpty)
            .toList();
      case 'Address':
        return list.where((c) => (c['addresses'] as List).isNotEmpty).toList();
      case 'Org':
        return list.where((c) => (c['organization'] as String? ?? '').trim().isNotEmpty).toList();
      case 'MissingPhone':
        return list.where((c) => (c['phones'] as List).isEmpty).toList();
      case 'MissingEmail':
        return list.where((c) => (c['emails'] as List).isEmpty).toList();
      default:
        return list;
    }
  }

  List<Map<String, dynamic>> get _visible {
    var list = _apply(_filter);
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      final blob = [
        c['display_name'],
        c['organization'],
        c['notes'],
        ...(c['phones'] as List).map((p) => (p as Map)['number']),
        ...(c['emails'] as List).map((e) => (e as Map)['address']),
      ].join(' ').toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  String _phone(Map c) {
    final phones = c['phones'] as List;
    if (phones.isEmpty) return '';
    return (phones.first as Map)['number']?.toString() ?? '';
  }

  String _email(Map c) {
    final emails = c['emails'] as List;
    if (emails.isEmpty) return '';
    return (emails.first as Map)['address']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: Row(
        children: [
          NavigationRail(
            backgroundColor: _panel,
            selectedIndex: ['People', 'Lists', 'Tags', 'Segments'].indexOf(_section).clamp(0, 3),
            onDestinationSelected: (i) => setState(() {
              _section = ['People', 'Lists', 'Tags', 'Segments'][i];
              _selected = null;
              _filter = 'All';
              _search.clear();
            }),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: _cyan),
            selectedLabelTextStyle: const TextStyle(color: _cyan, fontSize: 12),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white54, fontSize: 12),
            destinations: const [
              NavigationRailDestination(icon: Icon(LucideIcons.users), label: Text('People')),
              NavigationRailDestination(icon: Icon(LucideIcons.folder), label: Text('Lists')),
              NavigationRailDestination(icon: Icon(LucideIcons.tag), label: Text('Tags')),
              NavigationRailDestination(icon: Icon(LucideIcons.filter), label: Text('Segments')),
            ],
          ),
          const VerticalDivider(width: 1, color: Colors.white10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _cyan))
                : switch (_section) {
                    'Lists' => _setsView(isLists: true),
                    'Tags' => _setsView(isLists: false),
                    'Segments' => _segmentsView(),
                    _ => _peopleView(),
                  },
          ),
        ],
      ),
    );
  }

  Widget _peopleView() {
    final rows = _visible;
    return Column(
      children: [
        _toolbar(
          extra: Wrap(
            spacing: 8,
            children: ['All', 'Starred', 'Phone', 'Email']
                .map((f) => ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: _cyan.withValues(alpha: 0.25),
                      labelStyle: TextStyle(color: _filter == f ? _cyan : Colors.white70),
                      backgroundColor: _panel,
                    ))
                .toList(),
          ),
        ),
        if (_all.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No contacts on this node yet.\nOn the phone: Contacts → cloud icon (or Import/Export → Sync).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
        else
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 340,
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final c = rows[i];
                      final selected = _selected?['id'] == c['id'];
                      return ListTile(
                        selected: selected,
                        selectedTileColor: _cyan.withValues(alpha: 0.12),
                        title: Text(c['display_name']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          [_phone(c), _email(c)].where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: c['is_starred'] == true
                            ? const Icon(Icons.star, color: _cyan, size: 16)
                            : null,
                        onTap: () => setState(() => _selected = c),
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1, color: Colors.white10),
                Expanded(child: _detail()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _setsView({required bool isLists}) {
    final rows = isLists
        ? _groups
            .map((g) => {
                  'name': g['name'],
                  'count': g['contact_count'],
                  'people': _all
                      .where((c) => (c['groups'] as List).map((e) => e.toString()).contains(g['id']?.toString()))
                      .toList(),
                })
            .toList()
        : [
            _tag('Starred', 'Starred'),
            _tag('Has email', 'Email'),
            _tag('Has phone', 'Phone'),
            _tag('Has address', 'Address'),
            _tag('Company', 'Org'),
            ..._groups.map((g) => {
                  'name': g['name'],
                  'count': g['contact_count'],
                  'people': _all
                      .where((c) => (c['groups'] as List).map((e) => e.toString()).contains(g['id']?.toString()))
                      .toList(),
                }),
          ];
    return Column(
      children: [
        _toolbar(title: isLists ? 'Phone groups' : 'Tags'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: rows
                .map((r) => Card(
                      color: _panel,
                      child: ListTile(
                        title: Text(r['name'].toString(), style: const TextStyle(color: Colors.white)),
                        trailing: Text('${r['count'] ?? (r['people'] as List).length}',
                            style: const TextStyle(color: _cyan, fontWeight: FontWeight.bold)),
                        onTap: () => _showPeople(r['name'].toString(), (r['people'] as List).cast<Map<String, dynamic>>()),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _tag(String name, String key) {
    final people = _apply(key);
    return {'name': name, 'count': people.length, 'people': people};
  }

  Widget _segmentsView() {
    final defs = [
      ('Starred', 'Starred'),
      ('Has a phone', 'Phone'),
      ('Has an email', 'Email'),
      ('Phone + email', 'Both'),
      ('Has an address', 'Address'),
      ('Company / org', 'Org'),
      ('Missing phone', 'MissingPhone'),
      ('Missing email', 'MissingEmail'),
    ];
    return Column(
      children: [
        _toolbar(title: 'Live segments from the synced book'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: defs.map((d) {
              final people = _apply(d.$2);
              return Card(
                color: _panel,
                child: ListTile(
                  title: Text(d.$1, style: const TextStyle(color: Colors.white)),
                  trailing: Text('${people.length}', style: const TextStyle(color: _cyan, fontWeight: FontWeight.bold)),
                  onTap: () => _showPeople(d.$1, people),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showPeople(String title, List<Map<String, dynamic>> people) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: Text(title, style: const TextStyle(color: _cyan)),
        content: SizedBox(
          width: 420,
          height: 420,
          child: people.isEmpty
              ? const Center(child: Text('Empty', style: TextStyle(color: Colors.white54)))
              : ListView(
                  children: people
                      .map((c) => ListTile(
                            title: Text(c['display_name']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              [_phone(c), _email(c)].where((s) => s.isNotEmpty).join(' · '),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ))
                      .toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _toolbar({Widget? extra, String? title}) {
    return Container(
      color: _panel,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(title ?? '${_all.length} contacts', style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 16),
          if (_section == 'People')
            SizedBox(
              width: 240,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Search',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Colors.white38, size: 18),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          if (extra != null) ...[const SizedBox(width: 16), extra],
          const Spacer(),
          IconButton(
            tooltip: 'Reload from node DB',
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: _cyan),
          ),
        ],
      ),
    );
  }

  Widget _detail() {
    final c = _selected;
    if (c == null) {
      return const Center(child: Text('Select a contact', style: TextStyle(color: Colors.white38)));
    }
    Widget line(String k, String v) {
      if (v.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.white38))),
            Expanded(child: Text(v, style: const TextStyle(color: Colors.white))),
          ],
        ),
      );
    }

    final phones = (c['phones'] as List).map((p) => '${(p as Map)['label']}: ${p['number']}').join('\n');
    final emails = (c['emails'] as List).map((e) => '${(e as Map)['label']}: ${e['address']}').join('\n');
    final addrs = (c['addresses'] as List).map((a) => (a as Map)['formatted']?.toString() ?? '').where((s) => s.isNotEmpty).join('\n');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text(c['display_name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          line('Phone', phones),
          line('Email', emails),
          line('Address', addrs),
          line('Company', c['organization']?.toString() ?? ''),
          line('Title', c['job_title']?.toString() ?? ''),
          line('Notes', c['notes']?.toString() ?? ''),
          line('Groups', (c['groups'] as List).join(', ')),
          line('Starred', c['is_starred'] == true ? 'Yes' : ''),
        ],
      ),
    );
  }
}
