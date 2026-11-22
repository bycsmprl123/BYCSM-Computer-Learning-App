import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Firestore-backed in-app notice centre. Push notifications are intentionally
/// not claimed here; this page is the reliable inbox until FCM is configured.
class NoticesPage extends StatefulWidget {
  final bool isAdmin;
  const NoticesPage({super.key, required this.isAdmin});
  @override State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  final db = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _markRead(String noticeId) async {
    if (uid.isEmpty) return;
    await db.collection('noticeReads').doc('${uid}_$noticeId').set({
      'uid': uid, 'noticeId': noticeId, 'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _compose({DocumentSnapshot<Map<String, dynamic>>? existing}) async {
    final old = existing?.data() ?? {};
    final title = TextEditingController(text: old['title'] ?? '');
    final body = TextEditingController(text: old['body'] ?? '');
    final course = TextEditingController(text: old['courseTitle'] ?? '');
    String category = old['category'] ?? 'Announcement';
    bool published = old['published'] ?? true;
    final form = GlobalKey<FormState>();
    final categories = ['Announcement', 'Live Class', 'Exam', 'Notes', 'Certificate'];
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: Text(existing == null ? 'Create notice' : 'Edit notice'),
        content: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Notice title'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null),
          TextFormField(controller: body, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Message / details'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Message required' : null),
          TextFormField(controller: course, decoration: const InputDecoration(labelText: 'Course (optional)', hintText: 'e.g. ADCA')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: categories.contains(category) ? category : categories.first, decoration: const InputDecoration(labelText: 'Notice type'), items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setDialog(() => category = v ?? categories.first)),
          SwitchListTile(title: const Text('Published / visible to students'), value: published, onChanged: (v) => setDialog(() => published = v)),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState?.validate() ?? false) Navigator.pop(ctx, true); }, child: const Text('Save'))],
      )));
    if (ok != true) return;
    final data = {'title': title.text.trim(), 'body': body.text.trim(), 'courseTitle': course.text.trim(), 'category': category, 'published': published, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': uid};
    if (existing == null) { data['createdAt'] = FieldValue.serverTimestamp(); data['createdBy'] = uid; await db.collection('notices').add(data); }
    else { await existing.reference.update(data); }
  }

  Future<void> _delete(String id) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete notice?'), content: const Text('This notice will be removed.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (yes == true) await db.collection('notices').doc(id).delete();
  }

  Widget _noticeCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final readRef = db.collection('noticeReads').doc('${uid}_${doc.id}');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: readRef.snapshots(), builder: (context, readSnap) {
      final isRead = readSnap.data?.exists ?? false;
      final cat = (d['category'] ?? 'Announcement').toString();
      final icon = switch (cat) { 'Live Class' => Icons.video_call, 'Exam' => Icons.quiz, 'Notes' => Icons.picture_as_pdf, 'Certificate' => Icons.workspace_premium, _ => Icons.campaign };
      return Card(child: ListTile(isThreeLine: true, leading: CircleAvatar(child: Icon(icon)), title: Text(d['title'] ?? 'Notice', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)), subtitle: Text('$cat${(d['courseTitle'] ?? '').toString().isNotEmpty ? ' • ${d['courseTitle']}' : ''}\n${d['body'] ?? ''}', maxLines: 5, overflow: TextOverflow.ellipsis), trailing: widget.isAdmin ? PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _compose(existing: doc); if (v == 'delete') _delete(doc.id); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]) : (isRead ? const Icon(Icons.done, color: Colors.green) : const Icon(Icons.circle, size: 10, color: Colors.blue)), onTap: () async { if (!widget.isAdmin) await _markRead(doc.id); if (!mounted) return; showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(d['title'] ?? 'Notice'), content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text('${d['category'] ?? 'Announcement'}${(d['courseTitle'] ?? '').toString().isNotEmpty ? ' • ${d['courseTitle']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 12), Text(d['body'] ?? ''), const SizedBox(height: 12), Text('Posted: ${_date(d['createdAt'])}', style: Theme.of(context).textTheme.bodySmall)])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))])); }}));
    });
  }
  String _date(dynamic value) { if (value is Timestamp) return value.toDate().toLocal().toString().split('.').first; return 'Recently'; }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.isAdmin ? 'Notice Management' : 'Notifications')), floatingActionButton: widget.isAdmin ? FloatingActionButton.extended(onPressed: () => _compose(), icon: const Icon(Icons.add), label: const Text('New notice')) : null, body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: db.collection('notices').orderBy('createdAt', descending: true).snapshots(), builder: (context, snap) { if (snap.hasError) return Center(child: Text('Could not load notices: ${snap.error}')); if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final docs = snap.data!.docs.where((d) => widget.isAdmin || d.data()['published'] == true).toList(); if (docs.isEmpty) return const Center(child: Text('No notices yet.')); return ListView(padding: const EdgeInsets.all(12), children: docs.map(_noticeCard).toList()); }));
}
