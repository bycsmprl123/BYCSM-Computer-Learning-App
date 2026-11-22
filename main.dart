import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'firebase_config.dart';
import 'firebase_options.dart';
import 'services/student_auth_service.dart';
import 'notices.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (firebaseConfigured) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(const BYCSMApp());
}

class BYCSMApp extends StatelessWidget {
  const BYCSMApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BYCSM Computer Learning',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1558bd)),
          useMaterial3: true,
        ),
        home: const AuthPage(),
      );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final mobile = TextEditingController();
  final studentId = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  StudentAuthService? _auth;
  StudentAuthService get auth => _auth ??= StudentAuthService();
  bool registering = false;
  bool busy = false;
  bool showPassword = false;

  @override
  void initState() {
    super.initState();
    if (firebaseConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSession());
    }
  }

  Future<void> _restoreSession() async {
    if (!mounted || auth.currentUser == null) return;
    try {
      final account = await auth.currentAccount();
      if (mounted) _enter(account);
    } catch (_) {
      // A missing/inactive profile is shown through the normal login form.
    }
  }

  void _enter(StudentAccount account) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomePage(account: account)),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!firebaseConfigured) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      if (registering) {
        final account = await auth.register(
          fullName: name.text,
          mobile: mobile.text,
          password: password.text,
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Registration successful!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Student ID. Keep it safe for login:'),
                const SizedBox(height: 10),
                SelectableText(account.studentId,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Name: ${account.fullName}'),
              ],
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Continue')),
            ],
          ),
        );
        if (mounted) _enter(account);
      } else {
        final account = await auth.login(studentId: studentId.text, password: password.text);
        if (mounted) _enter(account);
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_authError(e.code));
    } on FirebaseException catch (e) {
      _showMessage('Cloud database error: ${e.message ?? e.code}');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'This Student ID is already used. Try registering again.';
      case 'invalid-email': return 'Student ID format is not valid.';
      case 'weak-password': return 'Use a password with at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': return 'Student ID or password is incorrect.';
      case 'too-many-requests': return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed': return 'Internet connection failed. Please check your network.';
      default: return 'Authentication failed ($code). Please try again.';
    }
  }

  Widget _field(TextEditingController controller, String label,
      {bool secret = false, TextInputType keyboard = TextInputType.text,
      String? Function(String?)? validator, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: secret && !showPassword,
        keyboardType: keyboard,
        textCapitalization: secret ? TextCapitalization.none : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          suffixIcon: secret
              ? IconButton(
                  icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => showPassword = !showPassword),
                )
              : null,
        ),
        validator: validator,
      ),
    );
  }

  @override
  void dispose() {
    name.dispose(); mobile.dispose(); studentId.dispose(); password.dispose(); confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/bycsm_logo.jpg', height: 142, fit: BoxFit.contain),
                    const Text('BYCSM Computer Learning', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('Bharatiya Yuva Computer Saksharata Mission', textAlign: TextAlign.center),
                    const SizedBox(height: 22),
                    if (!firebaseConfigured) ...[
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Firebase setup required', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 6),
                            Text('Student signup/login is coded, but this app has not been connected to a Firebase project. Follow docs/FIREBASE_SETUP.md, then enable firebaseConfigured in lib/firebase_config.dart.'),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Login')),
                        ButtonSegment(value: true, label: Text('Create account')),
                      ],
                      selected: {registering},
                      onSelectionChanged: busy ? null : (s) => setState(() => registering = s.first),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: formKey,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (registering) _field(name, 'Full name', validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null),
                        if (registering) _field(mobile, 'Mobile number (optional)', keyboard: TextInputType.phone),
                        if (!registering) _field(studentId, 'Student ID', hint: 'BYCSM-26-ABC234', validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter Student ID' : null),
                        _field(password, 'Password', secret: true, validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null),
                        if (registering) _field(confirmPassword, 'Confirm password', secret: true, validator: (v) => v != password.text ? 'Passwords do not match' : null),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    FilledButton.icon(
                      onPressed: (!firebaseConfigured || busy) ? null : _submit,
                      icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                      label: Text(busy ? 'Please wait…' : registering ? 'Create Student Account' : 'Login'),
                    ),
                    const SizedBox(height: 10),
                    const Text('Student ID is issued automatically after registration. Password is used only for login.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class Course {
  final String id;
  final String title, subtitle, level, duration, fee;
  final List<String> syllabus;
  const Course(this.title, this.subtitle, this.level, this.duration, {this.id = '', this.fee = '', this.syllabus = const []});
  factory Course.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Course(d['title'] ?? 'Course', d['subtitle'] ?? '', d['level'] ?? '', d['duration'] ?? '', id: doc.id, fee: d['fee']?.toString() ?? '', syllabus: (d['syllabus'] as List? ?? []).map((e) => e.toString()).toList());
  }
}

const courseList = [
  Course('CCA', 'Computer basics, typing, Windows and Office', 'Beginner', '3–6 months'),
  Course('DCA', 'Office applications, internet and practical skills', 'Foundation', '6 months'),
  Course('ADCA', 'Advanced Office, database, web and programming', 'Advanced', '1 year'),
  Course('Tally with GST', 'Accounting basics, vouchers, GST and reports', 'Accounting', 'Course duration varies'),
  Course('Python', 'Programming fundamentals and projects', 'Programming', 'Course duration varies'),
  Course('AI & Generative AI', 'AI basics, responsible use and productivity tools', 'AI', 'Course duration varies'),
  Course('HTML & CSS', 'Create and style websites', 'Web', 'Course duration varies'),
  Course('C / C++', 'Programming logic and fundamentals', 'Programming', 'Course duration varies'),
];

class HomePage extends StatefulWidget {
  final StudentAccount account;
  const HomePage({super.key, required this.account});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int selected = 0;
  StudentAuthService? _auth;
  StudentAuthService get auth => _auth ??= StudentAuthService();

  Widget feature(String title, String subtitle, IconData icon) {
    VoidCallback action = () {
      if (title.toLowerCase().contains('password')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()));
      } else if (title.toLowerCase().contains('profile')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfilePage(account: widget.account)));
      } else if (title.toLowerCase().contains('digital student id')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StudentIdCardPage(account: widget.account)));
      } else if (title.toLowerCase().contains('live class') || title == 'Classes') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LiveClassesPage(isAdmin: widget.account.isAdmin)));
      } else if (title.toLowerCase().contains('recorded')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RecordedVideosPage(isAdmin: widget.account.isAdmin)));
      } else if (title.toLowerCase().contains('mcq')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ExamsPage(isAdmin: widget.account.isAdmin)));
      } else if (title.toLowerCase().contains('notes')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => NotesPage(isAdmin: widget.account.isAdmin)));
      } else if (title.toLowerCase().contains('certificate')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CertificatesPage(isAdmin: widget.account.isAdmin, account: widget.account)));
      } else if (title.toLowerCase().contains('attendance')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => AttendancePage(isAdmin: widget.account.isAdmin, account: widget.account)));
      } else if (title.toLowerCase().contains('progress') || title.toLowerCase().contains('enrollment')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProgressPage(account: widget.account))); 
      } else {
        showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text('$title will be connected to the student learning database in a later build.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
      }
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: action,
      ),
    );
  }

  Widget courseTile(Course course) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.school),
        title: Text(course.title),
        subtitle: Text('${course.subtitle}\n${course.level} • ${course.duration}${course.fee.isNotEmpty ? ' • Fee: ₹${course.fee}' : ''}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => CourseDetailPage(course: course),
        )),
      ),
    );
  }


  Future<void> _logout() async {
    if (firebaseConfigured) await auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('BYCSM Learning'), actions: [
          IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout)),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) => setState(() => selected = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Courses'),
            NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Learning'),
            NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), label: 'Admin'),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (selected == 0) ...[
            Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(
              padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Welcome, ${widget.account.fullName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5), Text('Student ID: ${widget.account.studentId}'),
                const SizedBox(height: 4), const Text('Learn, practice and grow with BYCSM.'),
              ]))),
            const SizedBox(height: 10),
            feature('Notifications', 'Announcements, classes, exams and notes notices', Icons.notifications_active_outlined),
            feature('My Profile', 'View and update your contact details', Icons.account_circle_outlined),
            feature('Change Password', 'Update your account password securely', Icons.lock_outline),
            feature('Settings & Help', 'About BYCSM, FAQs and support contacts', Icons.settings_outlined),
            const SizedBox(height: 14),
            const Text('Your Learning', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text('Enrolled: 0')), Chip(label: Text('Classes: 0')), Chip(label: Text('Exams: 0')), Chip(label: Text('Certificates: 0'))]),
            feature('Digital Student ID', 'View and print your QR student card', Icons.badge_outlined),
            feature('Live Classes', 'View upcoming class schedules', Icons.video_call),
            feature('Attendance', 'View your attendance history and percentage', Icons.fact_check),
            feature('Recorded Videos', 'Watch lesson recordings', Icons.play_circle),
            feature('MCQ Exams', 'Practice and test your knowledge', Icons.quiz),
            feature('Notes & PDFs', 'Study material library', Icons.picture_as_pdf),
          ] else if (selected == 1) ...[
            const Text('Course Catalog', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firebaseConfigured ? FirebaseFirestore.instance.collection('courses').where('active', isEqualTo: true).snapshots() : null,
              builder: (context, snap) {
                if (!firebaseConfigured || (snap.hasData && snap.data!.docs.isEmpty)) return Column(children: courseList.map(courseTile).toList());
                if (snap.hasError) return Text('Course database error: ${snap.error}');
                if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                return Column(children: snap.data!.docs.map(Course.fromDoc).map(courseTile).toList());
              },
            ),
          ] else if (selected == 2) ...[
            const Text('Learning Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            feature('Notifications', 'Announcements, classes, exams and notes notices', Icons.notifications_active_outlined),
            feature('Live Classes', 'Schedule and meeting links', Icons.video_call),
            feature('Recorded Videos', 'Video lesson library', Icons.video_library),
            feature('MCQ Exams', 'Practice exams and results', Icons.quiz),
            feature('Notes / PDFs', 'Downloadable learning resources', Icons.file_download),
            feature('Certificates', 'Course completion certificates', Icons.workspace_premium),
            feature('My Progress', 'Enrollment, learning progress and results', Icons.trending_up),
            feature('Attendance', 'View attendance history and percentage', Icons.fact_check),
            feature('My Profile', 'Edit your profile details', Icons.account_circle_outlined),
            feature('Change Password', 'Update your account password securely', Icons.lock_outline),
            feature('Settings & Help', 'About BYCSM, FAQs and support contacts', Icons.settings_outlined),
          ] else ...[
            const Text('Admin Console', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (!widget.account.isAdmin) const Card(child: ListTile(
              leading: Icon(Icons.lock_outline), title: Text('Admin access restricted'),
              subtitle: Text('Only an account added to Firebase adminUsers can manage centre data.'),
            )) else ...[
              const Text('Admin account verified. Manage students, courses and live class schedules.'),
              ListTile(leading: const Icon(Icons.notifications_active), title: const Text('Notice management'), subtitle: const Text('Create announcements for students'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesPage(isAdmin: true)))),
              ListTile(leading: const Icon(Icons.people), title: const Text('Student management'), subtitle: const Text('View registered student accounts'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminStudentsPage()))),
              ListTile(leading: const Icon(Icons.library_add), title: const Text('Course management'), subtitle: const Text('Add/edit/delete course catalog'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCoursesPage()))),
              Card(child: ListTile(leading: const Icon(Icons.calendar_month), title: const Text('Live class management'), subtitle: const Text('Schedule, edit and delete classes'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveClassesPage(isAdmin: true))))),
              Card(child: ListTile(leading: const Icon(Icons.video_library), title: const Text('Recorded video management'), subtitle: const Text('Add/edit lessons and video links'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRecordedVideosPage())))),
              Card(child: ListTile(leading: const Icon(Icons.quiz), title: const Text('Exam management'), subtitle: const Text('Create MCQ exams and review results'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamsPage(isAdmin: true))))),
              Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('Notes / PDF management'), subtitle: const Text('Add, edit and remove study material links'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesPage(isAdmin: true))))),
              Card(child: ListTile(leading: const Icon(Icons.workspace_premium), title: const Text('Certificate management'), subtitle: const Text('Issue and review certificates'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CertificatesPage(isAdmin: true, account: widget.account))))),
              Card(child: ListTile(leading: const Icon(Icons.trending_up), title: const Text('Enrollment & Progress'), subtitle: const Text('Enroll students and update progress'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEnrollmentPage())))),
              Card(child: ListTile(leading: const Icon(Icons.fact_check), title: const Text('Attendance Management'), subtitle: const Text('Create class attendance and mark Present / Absent / Late'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendancePage(isAdmin: true, account: widget.account))))),
            ],
          ],
        ]),
      );
}




// v1.7: Re-authenticate before changing password. Passwords are managed by Firebase Auth.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}
class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final formKey = GlobalKey<FormState>();
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  bool reveal = false;
  Future<void> _save() async {
    if (!firebaseConfigured || !(formKey.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      await StudentAuthService().changePassword(currentPassword: current.text, newPassword: next.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));
      current.clear(); next.clear(); confirm.clear();
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-login-credentials'
          ? 'Current password is incorrect. Please try again.'
          : e.code == 'weak-password' ? 'Choose a stronger password (minimum 6 characters).' : 'Could not change password: ${e.message ?? e.code}';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override void dispose() { current.dispose(); next.dispose(); confirm.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change Password')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.security, size: 64),
      const SizedBox(height: 12),
      const Text('Secure your account', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Enter your current password, then choose a new password. Firebase verifies your current password before saving.', textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Form(key: formKey, child: Column(children: [
        TextFormField(controller: current, obscureText: !reveal, decoration: InputDecoration(labelText: 'Current password', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(reveal ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => reveal = !reveal)),), validator: (v) => (v == null || v.isEmpty) ? 'Enter current password' : null),
        const SizedBox(height: 12),
        TextFormField(controller: next, obscureText: !reveal, decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()), validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null),
        const SizedBox(height: 12),
        TextFormField(controller: confirm, obscureText: !reveal, decoration: const InputDecoration(labelText: 'Confirm new password', border: OutlineInputBorder()), validator: (v) => v != next.text ? 'Passwords do not match' : null),
      ])),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: busy ? null : _save, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(busy ? 'Updating…' : 'Update Password')),
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('Forgot your password?', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text('Student accounts currently sign in with a Student ID and an internal login email, so an automated email-reset link cannot be delivered. Contact the BYCSM administrator for identity verification and a reset. A verified recovery email/phone can be added in a future update.'),
      ]))),
    ]),
  );
}

// v1.6: Student profile page. Students may edit personal contact fields only.
class StudentProfilePage extends StatefulWidget {
  final StudentAccount account;
  const StudentProfilePage({super.key, required this.account});
  @override State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _guardian = TextEditingController();
  final _photoUrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  String _status = 'active';

  @override void dispose() {
    _name.dispose(); _mobile.dispose(); _address.dispose(); _guardian.dispose(); _photoUrl.dispose();
    super.dispose();
  }

  void _fill(Map<String, dynamic> data) {
    if (_loaded) return;
    _name.text = (data['fullName'] ?? widget.account.fullName).toString();
    _mobile.text = (data['mobile'] ?? '').toString();
    _address.text = (data['address'] ?? '').toString();
    _guardian.text = (data['guardianName'] ?? '').toString();
    _photoUrl.text = (data['photoUrl'] ?? '').toString();
    _status = (data['status'] ?? 'active').toString();
    _loaded = true;
  }

  Future<void> _save() async {
    if (!firebaseConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect Firebase to save your profile.')));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('students').doc(widget.account.uid).update({
        'fullName': _name.text.trim(),
        'mobile': _mobile.text.trim(),
        'address': _address.text.trim(),
        'guardianName': _guardian.text.trim(),
        'photoUrl': _photoUrl.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save profile: $e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Widget _textField(TextEditingController c, String label, {int lines = 1, TextInputType keyboard = TextInputType.text, String? Function(String?)? validator}) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: c, maxLines: lines, keyboardType: keyboard, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), validator: validator));

  @override Widget build(BuildContext context) {
    if (!firebaseConfigured) return Scaffold(appBar: AppBar(title: const Text('My Profile')), body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Firebase is not configured yet. Profile editing will be available after setup.'))));
    return Scaffold(appBar: AppBar(title: const Text('My Profile')), body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('students').doc(widget.account.uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Profile error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (!snap.data!.exists) return const Center(child: Text('Student profile was not found.'));
        final data = snap.data!.data()!; _fill(data);
        final photo = _photoUrl.text.trim();
        return ListView(padding: const EdgeInsets.all(16), children: [
          Center(child: Column(children: [
            CircleAvatar(radius: 46, backgroundImage: photo.startsWith('https://') ? NetworkImage(photo) : null, child: photo.startsWith('https://') ? null : const Icon(Icons.person, size: 48)),
            const SizedBox(height: 8), Text(widget.account.studentId, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Account status: $_status'),
          ])),
          const SizedBox(height: 20),
          Form(key: _formKey, child: Column(children: [
            _textField(_name, 'Student Name', validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
            _textField(_mobile, 'Mobile Number', keyboard: TextInputType.phone, validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid mobile number' : null),
            _textField(_guardian, 'Guardian Name'),
            _textField(_address, 'Address', lines: 3),
            _textField(_photoUrl, 'Profile Photo URL (https)', validator: (v) => (v != null && v.isNotEmpty && !v.startsWith('https://')) ? 'Photo URL must begin with https://' : null),
            const Align(alignment: Alignment.centerLeft, child: Text('Student ID, account status, and role are read-only. Photo upload will be added later.')),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: Text(_saving ? 'Saving…' : 'Save Profile'))),
          ])),
        ]);
      },
    ));
  }
}


// v1.5: Digital Student ID card with QR payload and print/save PDF support.
class StudentIdCardPage extends StatelessWidget {
  final StudentAccount account;
  const StudentIdCardPage({super.key, required this.account});

  String get qrPayload => 'BYCSM-STUDENT|${account.studentId}';

  Future<void> _printCard() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Center(child:
      pw.Container(width: 340, height: 210, padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue900, width: 2), borderRadius: pw.BorderRadius.circular(12)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('BHARATIYA YUVA COMPUTER SAKSHARATA MISSION', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('STUDENT ID CARD', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10), pw.Text('Name: ${account.fullName}', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 5), pw.Text('Student ID: ${account.studentId}', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 5), pw.Text('Centre: BYCSM', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 5), pw.Text('Issued: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 10)),
            ])),
            pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qrPayload, width: 90, height: 90),
          ]),
          pw.Text('Scan QR to read Student ID • Keep this card safe', style: const pw.TextStyle(fontSize: 9)),
        ]))));
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Digital Student ID')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        const Icon(Icons.school, size: 42),
        const Text('BHARATIYA YUVA COMPUTER SAKSHARATA MISSION', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('DIGITAL STUDENT ID CARD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Text(account.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        SelectableText(account.studentId, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 14),
        QrImageView(data: qrPayload, size: 180, backgroundColor: Colors.white, semanticsLabel: 'BYCSM Student ID QR code'),
        const SizedBox(height: 8),
        const Text('QR contains your BYCSM Student ID only.'),
      ]))),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: _printCard, icon: const Icon(Icons.print), label: const Text('Print / Save ID Card PDF')),
      const SizedBox(height: 8),
      const Text('This QR is a local identification payload. Online verification is not active until a public verification service is deployed.', style: TextStyle(fontSize: 12)),
    ]),
  );
}

class AttendancePage extends StatefulWidget {
  final bool isAdmin;
  final StudentAccount account;
  const AttendancePage({super.key, required this.isAdmin, required this.account});
  @override State<AttendancePage> createState() => _AttendancePageState();
}
class _AttendancePageState extends State<AttendancePage> {
  final db = FirebaseFirestore.instance;
  final studentUid = TextEditingController();
  final studentId = TextEditingController();
  String status = 'Present';
  bool busy = false;

  Future<void> _createSession() async {
    final title = TextEditingController();
    final course = TextEditingController();
    final date = TextEditingController(text: DateTime.now().toIso8601String().substring(0,10));
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Create attendance session'),
      content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Class/session title'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter title' : null),
        TextFormField(controller: course, decoration: const InputDecoration(labelText: 'Course name')),
        TextFormField(controller: date, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'), validator: (v) { try { DateTime.parse((v ?? '').trim()); return null; } catch (_) { return 'Enter valid date'; }}),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () { if(form.currentState!.validate()) Navigator.pop(ctx,true); }, child: const Text('Create'))]));
    if (ok == true) {
      await db.collection('attendanceSessions').add({'title': title.text.trim(), 'courseTitle': course.text.trim(), 'sessionDate': date.text.trim(), 'createdBy': widget.account.uid, 'createdAt': FieldValue.serverTimestamp(), 'active': true});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance session created.')));
    }
    title.dispose(); course.dispose(); date.dispose();
  }

  Future<void> _markAttendance(String sessionId, Map<String,dynamic> session) async {
    if (studentUid.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter student UID first.'))); return; }
    setState(() => busy = true);
    try {
      final student = await db.collection('students').doc(studentUid.text.trim()).get();
      if (!student.exists) throw Exception('Student UID not found.');
      final recordId = '${sessionId}_${studentUid.text.trim()}';
      await db.collection('attendanceRecords').doc(recordId).set({
        'sessionId': sessionId, 'uid': studentUid.text.trim(), 'studentId': student.data()?['studentId'] ?? studentId.text.trim(),
        'studentName': student.data()?['fullName'] ?? 'Student', 'status': status, 'sessionTitle': session['title'] ?? '',
        'courseTitle': session['courseTitle'] ?? '', 'sessionDate': session['sessionDate'] ?? '',
        'markedBy': widget.account.uid, 'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge:true));
      studentUid.clear(); studentId.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved.')));
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance failed: $e'))); }
    if(mounted) setState(() => busy = false);
  }

  Widget _recordCard(Map<String,dynamic> d) {
    final st = (d['status'] ?? 'Present').toString();
    final icon = st == 'Present' ? Icons.check_circle : st == 'Late' ? Icons.schedule : Icons.cancel;
    return Card(child: ListTile(leading: Icon(icon), title: Text(d['sessionTitle'] ?? 'Class'), subtitle: Text('${d['courseTitle'] ?? ''} • ${d['sessionDate'] ?? ''}\n$st'), isThreeLine: true, trailing: widget.isAdmin ? Text(d['studentName'] ?? '') : null));
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.isAdmin ? 'Attendance Management' : 'My Attendance')),
    body: !firebaseConfigured ? const Center(child: Text('Connect Firebase to use attendance.')) :
      ListView(padding: const EdgeInsets.all(12), children: [
        if(widget.isAdmin) ...[
          FilledButton.icon(onPressed: _createSession, icon: const Icon(Icons.add), label: const Text('Create attendance session')),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: db.collection('attendanceSessions').where('active', isEqualTo: true).snapshots(), builder: (context,snap) {
            if(snap.hasError) return Text('Session load error: ${snap.error}'); if(!snap.hasData) return const Center(child:CircularProgressIndicator());
            if(snap.data!.docs.isEmpty) return const Card(child: Padding(padding:EdgeInsets.all(16),child:Text('No sessions yet. Create a session above.')));
            return Column(children: snap.data!.docs.map((doc) { final d=doc.data(); return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
              Text(d['title'] ?? 'Class', style: const TextStyle(fontWeight:FontWeight.bold)), Text('${d['courseTitle'] ?? ''} • ${d['sessionDate'] ?? ''}'),
              const SizedBox(height:8), TextField(controller: studentUid, decoration: const InputDecoration(labelText:'Student UID (Firebase UID)')), 
              DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText:'Attendance status'), items:['Present','Absent','Late'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>status=v ?? 'Present'),),
              const SizedBox(height:8), FilledButton(onPressed:busy?null:()=>_markAttendance(doc.id,d), child:Text(busy?'Saving…':'Save Attendance')),
            ]))); }).toList());
          }),
          const Divider(height:28), const Text('Attendance Records',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
          StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: db.collection('attendanceRecords').snapshots(), builder:(context,snap){ if(snap.hasError)return Text('Records error: ${snap.error}'); if(!snap.hasData)return const Center(child:CircularProgressIndicator()); if(snap.data!.docs.isEmpty)return const Text('No records yet.'); final docs=snap.data!.docs.toList()..sort((a,b)=>(b.data()['sessionDate']??'').toString().compareTo((a.data()['sessionDate']??'').toString())); return Column(children:docs.map((doc)=>_recordCard(doc.data())).toList());}),
        ] else ...[
          StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: db.collection('attendanceRecords').where('uid',isEqualTo:widget.account.uid).snapshots(), builder:(context,snap){ if(snap.hasError)return Text('Attendance load error: ${snap.error}'); if(!snap.hasData)return const Center(child:CircularProgressIndicator()); final docs=snap.data!.docs; final present=docs.where((d)=>d.data()['status']=='Present').length; final total=docs.length; final percent=total==0?0:(present*100/total).round(); return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Attendance Summary',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Text('Present: $present / $total'),Text('Attendance: $percent%'),LinearProgressIndicator(value:total==0?0:present/total)]))), if(docs.isEmpty) const Padding(padding:EdgeInsets.all(20),child:Text('No attendance records yet.')) else ...docs.map((doc)=>_recordCard(doc.data()))]);}),
        ]
      ]),
  );
  @override void dispose(){studentUid.dispose();studentId.dispose();super.dispose();}
}

class StudentProgressPage extends StatelessWidget {
  final StudentAccount account;
  const StudentProgressPage({super.key, required this.account});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Course Progress')),
    body: !firebaseConfigured ? const Center(child: Text('Connect Firebase to see your enrollment progress.')) :
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('courseEnrollments').where('uid', isEqualTo: account.uid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Could not load progress: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No course enrollment found yet. Contact the centre admin to enroll you.')));
          return ListView(padding: const EdgeInsets.all(16), children: snap.data!.docs.map((doc) {
            final d=doc.data(); final progress=((d['progressPercent'] ?? 0) as num).clamp(0,100).toDouble();
            return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['courseTitle'] ?? 'Course', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8), LinearProgressIndicator(value: progress/100),
              const SizedBox(height: 6), Text('${progress.toStringAsFixed(0)}% complete • ${d['status'] ?? 'Enrolled'}'),
              const SizedBox(height: 8), Wrap(spacing: 12, runSpacing: 4, children: [
                Text('Lessons: ${d['completedLessons'] ?? 0}/${d['totalLessons'] ?? 0}'),
                Text('Classes attended: ${d['attendanceCount'] ?? 0}'),
                Text('Exam average: ${d['examAverage'] ?? 0}%'),
              ]),
              if ((d['adminNote'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Admin note: ${d['adminNote']}')),
            ])));
          }).toList();
        },
      ),
  );
}

class AdminEnrollmentPage extends StatefulWidget {
  const AdminEnrollmentPage({super.key});
  @override State<AdminEnrollmentPage> createState() => _AdminEnrollmentPageState();
}
class _AdminEnrollmentPageState extends State<AdminEnrollmentPage> {
  final uidCtrl=TextEditingController();
  final noteCtrl=TextEditingController();
  String? courseId;
  bool busy=false;
  final db=FirebaseFirestore.instance;
  Future<void> enroll(Map<String,dynamic> course) async {
    final uid=uidCtrl.text.trim(); if(uid.isEmpty || courseId==null) return;
    setState(()=>busy=true);
    try {
      final student=await db.collection('students').doc(uid).get();
      if(!student.exists) throw Exception('Student UID not found. Paste the Firebase student UID, not the student ID.');
      final id='${uid}_$courseId';
      await db.collection('courseEnrollments').doc(id).set({
        'uid':uid,'studentName':student.data()?['fullName'] ?? 'Student','studentId':student.data()?['studentId'] ?? '',
        'courseId':courseId,'courseTitle':course['title'] ?? 'Course','status':'Enrolled','progressPercent':0,
        'completedLessons':0,'totalLessons':0,'attendanceCount':0,'examAverage':0,'adminNote':noteCtrl.text.trim(),
        'enrolledAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp(),
      },SetOptions(merge:true));
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student enrolled / record updated.')));
    }catch(e){if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ',''))));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> editProgress(QueryDocumentSnapshot<Map<String,dynamic>> doc) async {
    final d=doc.data(); final progress=TextEditingController(text:'${d['progressPercent'] ?? 0}');
    final lessons=TextEditingController(text:'${d['completedLessons'] ?? 0}');
    final total=TextEditingController(text:'${d['totalLessons'] ?? 0}');
    final attendance=TextEditingController(text:'${d['attendanceCount'] ?? 0}');
    final average=TextEditingController(text:'${d['examAverage'] ?? 0}');
    final note=TextEditingController(text:d['adminNote'] ?? '');
    String status=d['status'] ?? 'Enrolled';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:Text('Update ${d['courseTitle']}'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      for(final pair in [('Progress %',progress),('Lessons complete',lessons),('Total lessons',total),('Attendance count',attendance),('Exam average %',average)]) TextField(controller:pair.$2,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:pair.$1)),
      TextField(controller:note,decoration:const InputDecoration(labelText:'Admin note')),
      DropdownButtonFormField<String>(value:status,items:['Enrolled','In Progress','Completed','Paused'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setD(()=>status=v??status),decoration:const InputDecoration(labelText:'Status')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))])));
    if(ok==true){
      int n(String t)=>int.tryParse(t.trim())??0;
      await doc.reference.update({'progressPercent':n(progress.text).clamp(0,100),'completedLessons':n(lessons.text),'totalLessons':n(total.text),'attendanceCount':n(attendance.text),'examAverage':n(average.text).clamp(0,100),'adminNote':note.text.trim(),'status':status,'updatedAt':FieldValue.serverTimestamp()});
    }
  }
  @override void dispose(){uidCtrl.dispose();noteCtrl.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Enrollment & Progress')),body:!firebaseConfigured?const Center(child:Text('Firebase must be configured to manage enrollments.')):ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Enroll a student',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    TextField(controller:uidCtrl,decoration:const InputDecoration(labelText:'Student Firebase UID',hintText:'Find UID from Student Management')),
    TextField(controller:noteCtrl,decoration:const InputDecoration(labelText:'Optional admin note')),
    const SizedBox(height:8),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:db.collection('courses').where('active',isEqualTo:true).snapshots(),builder:(context,snap){
      if(snap.hasError)return Text('Courses error: ${snap.error}');if(!snap.hasData)return const LinearProgressIndicator();
      final docs=snap.data!.docs;if(docs.isEmpty)return const Text('Add active courses first.');courseId??=docs.first.id;
      return DropdownButtonFormField<String>(value:courseId,items:docs.map((d)=>DropdownMenuItem(value:d.id,child:Text(d.data()['title']??'Course'))).toList(),onChanged:(v)=>setState(()=>courseId=v),decoration:const InputDecoration(labelText:'Select course'));
    }),
    const SizedBox(height:10),FilledButton.icon(onPressed:busy?null:()=>FirebaseFirestore.instance.collection('courses').doc(courseId).get().then((d){if(d.exists)enroll(d.data()!);}),icon:const Icon(Icons.person_add),label:Text(busy?'Saving...':'Enroll student')),
    const Divider(height:32),const Text('Current enrollment records',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:db.collection('courseEnrollments').snapshots(),builder:(context,snap){if(snap.hasError)return Text('Enrollment list error: ${snap.error}');if(!snap.hasData)return const Center(child:CircularProgressIndicator());if(snap.data!.docs.isEmpty)return const Text('No enrollment records yet.');return Column(children:snap.data!.docs.map((doc){final d=doc.data();final p=((d['progressPercent']??0) as num).clamp(0,100);return Card(child:ListTile(isThreeLine:true,title:Text('${d['studentName']??'Student'} • ${d['courseTitle']??'Course'}'),subtitle:Text('${d['studentId']??d['uid']}\n${d['status']??'Enrolled'} — $p%'),trailing:IconButton(icon:const Icon(Icons.edit),tooltip:'Edit progress',onPressed:()=>editProgress(doc))));}).toList());}),
  ]);
}

class RecordedVideosPage extends StatefulWidget {
  final bool isAdmin;
  final String? courseTitle;
  const RecordedVideosPage({super.key, required this.isAdmin, this.courseTitle});
  @override State<RecordedVideosPage> createState() => _RecordedVideosPageState();
}
class _RecordedVideosPageState extends State<RecordedVideosPage> {
  final db = FirebaseFirestore.instance;
  Future<void> _openVideo(Map<String, dynamic> d) async {
    final uri = Uri.tryParse(d['videoUrl'] ?? '');
    if (uri != null && uri.hasScheme && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video link is invalid or could not be opened.')));
    }
  }
  Widget _lessonCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'offline';
    final progressRef = db.collection('videoProgress').doc('${uid}_${doc.id}');
    return Card(child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firebaseConfigured ? progressRef.snapshots() : null,
      builder: (context, progress) {
        final completed = progress.data?.data()?['completed'] == true;
        return ListTile(isThreeLine: true, leading: CircleAvatar(child: Icon(completed ? Icons.check : Icons.play_arrow)),
          title: Text(d['title'] ?? 'Lesson'),
          subtitle: Text('${d['courseTitle'] ?? 'All courses'}${(d['description'] ?? '').toString().isNotEmpty ? '\n${d['description']}' : ''}'),
          trailing: widget.isAdmin ? PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _showVideoForm(doc); if (v == 'delete') _deleteVideo(doc); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]) : IconButton(tooltip: completed ? 'Mark incomplete' : 'Mark completed', icon: Icon(completed ? Icons.check_circle : Icons.check_circle_outline), onPressed: firebaseConfigured ? () async { await progressRef.set({'uid': uid, 'videoId': doc.id, 'completed': !completed, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); } : null),
          onTap: () => _openVideo(d));
      }));
  }
  Future<void> _showVideoForm([DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    if (!widget.isAdmin) return;
    final d = doc?.data() ?? {};
    final title = TextEditingController(text: d['title'] ?? '');
    final course = TextEditingController(text: d['courseTitle'] ?? widget.courseTitle ?? '');
    final description = TextEditingController(text: d['description'] ?? '');
    final url = TextEditingController(text: d['videoUrl'] ?? '');
    final order = TextEditingController(text: d['lessonOrder']?.toString() ?? '1');
    final form = GlobalKey<FormState>();
    final save = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(doc == null ? 'Add recorded lesson' : 'Edit lesson'), content: SizedBox(width: 440, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Lesson title'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter lesson title' : null),
      TextFormField(controller: course, decoration: const InputDecoration(labelText: 'Course name (e.g. DCA)'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter course name' : null),
      TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
      TextFormField(controller: url, decoration: const InputDecoration(labelText: 'Video URL (YouTube or direct link)'), validator: (v) { final u = Uri.tryParse((v ?? '').trim()); return (u == null || !u.hasScheme || !(u.scheme == 'https' || u.scheme == 'http')) ? 'Enter a valid https/http URL' : null; }),
      TextFormField(controller: order, decoration: const InputDecoration(labelText: 'Lesson order'), keyboardType: TextInputType.number, validator: (v) => int.tryParse(v ?? '') == null ? 'Enter a number' : null),
      const SizedBox(height: 6), const Text('This release accepts a video link. Direct file upload requires Firebase Storage configuration.', style: TextStyle(fontSize: 12)),
    ])))), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Save'))]));
    if (save == true) {
      final payload = {'title': title.text.trim(), 'courseTitle': course.text.trim(), 'description': description.text.trim(), 'videoUrl': url.text.trim(), 'lessonOrder': int.parse(order.text), 'active': true, 'updatedAt': FieldValue.serverTimestamp()};
      if (doc == null) payload['createdAt'] = FieldValue.serverTimestamp();
      if (doc == null) await db.collection('recordedVideos').add(payload); else await doc.reference.update(payload);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recorded lesson saved.')));
    }
    title.dispose(); course.dispose(); description.dispose(); url.dispose(); order.dispose();
  }
  Future<void> _deleteVideo(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete lesson?'), content: Text(doc.data()?['title'] ?? ''), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (yes == true) await doc.reference.delete();
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.isAdmin ? 'Recorded Video Management' : 'Video Library')), floatingActionButton: widget.isAdmin ? FloatingActionButton.extended(onPressed: () => _showVideoForm(), icon: const Icon(Icons.add), label: const Text('Add lesson')) : null, body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: db.collection('recordedVideos').where('active', isEqualTo: true).snapshots(), builder: (context, snap) {
    if (snap.hasError) return Center(child: Text('Videos load error: ${snap.error}'));
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final docs = snap.data!.docs.where((doc) => widget.courseTitle == null || (doc.data()['courseTitle'] ?? '').toString().toLowerCase() == widget.courseTitle!.toLowerCase()).toList()..sort((a,b) => ((a.data()['lessonOrder'] as num?)?.toInt() ?? 0).compareTo((b.data()['lessonOrder'] as num?)?.toInt() ?? 0));
    if (docs.isEmpty) return const Center(child: Text('No recorded lessons available yet. Admin can add video links.'));
    return ListView(padding: const EdgeInsets.all(12), children: docs.map(_lessonCard).toList());
  }));
}

class AdminRecordedVideosPage extends StatelessWidget {
  const AdminRecordedVideosPage({super.key});
  @override Widget build(BuildContext context) => RecordedVideosPage(isAdmin: true);
}

class LiveClassesPage extends StatefulWidget {
  final bool isAdmin;
  const LiveClassesPage({super.key, required this.isAdmin});
  @override State<LiveClassesPage> createState() => _LiveClassesPageState();
}
class _LiveClassesPageState extends State<LiveClassesPage> {
  final db = FirebaseFirestore.instance;
  Future<void> _edit([DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    if (!widget.isAdmin) return;
    final d = doc?.data() ?? <String, dynamic>{};
    final title = TextEditingController(text: d['title'] ?? '');
    final course = TextEditingController(text: d['courseTitle'] ?? '');
    final dateTime = TextEditingController(text: d['startsAt'] is Timestamp ? (d['startsAt'] as Timestamp).toDate().toIso8601String().substring(0,16).replaceFirst('T',' ') : '');
    final link = TextEditingController(text: d['meetingUrl'] ?? '');
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(doc == null ? 'Schedule live class' : 'Edit live class'), content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Class title'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter title' : null),
      TextFormField(controller: course, decoration: const InputDecoration(labelText: 'Course (optional)')),
      TextFormField(controller: dateTime, decoration: const InputDecoration(labelText: 'Date/time (YYYY-MM-DD HH:MM)'), validator: (v) { try { DateTime.parse((v ?? '').trim().replaceFirst(' ', 'T')); return null; } catch (_) { return 'Use format YYYY-MM-DD HH:MM'; }}),
      TextFormField(controller: link, decoration: const InputDecoration(labelText: 'Meeting URL'), validator: (v) { final uri = Uri.tryParse((v ?? '').trim()); return (uri == null || !uri.hasScheme || !(uri.scheme == 'https' || uri.scheme == 'http')) ? 'Enter a valid http/https link' : null; }),
    ])))), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Save'))]));
    if (ok == true) {
      final parsed = DateTime.parse(dateTime.text.trim().replaceFirst(' ', 'T'));
      final payload = {'title': title.text.trim(), 'courseTitle': course.text.trim(), 'startsAt': Timestamp.fromDate(parsed), 'meetingUrl': link.text.trim(), 'active': true, 'updatedAt': FieldValue.serverTimestamp()};
      if (doc == null) payload['createdAt'] = FieldValue.serverTimestamp();
      if (doc == null) await db.collection('liveClasses').add(payload); else await doc.reference.update(payload);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Live class saved.')));
    }
    title.dispose(); course.dispose(); dateTime.dispose(); link.dispose();
  }
  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete class?'), content: Text(doc.data()?['title'] ?? ''), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (confirm == true) await doc.reference.delete();
  }
  Widget _classCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final start = (d['startsAt'] as Timestamp?)?.toDate();
    final dateText = start == null ? 'Date not set' : '${start.toLocal()}'.substring(0,16);
    return Card(child: ListTile(isThreeLine: true, leading: const Icon(Icons.video_call), title: Text(d['title'] ?? 'Live class'), subtitle: Text('${d['courseTitle'] ?? 'All courses'}\n$dateText'), trailing: widget.isAdmin ? PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _edit(doc); if (v == 'delete') _delete(doc); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]) : null, onTap: widget.isAdmin ? null : () async { final uri = Uri.tryParse(d['meetingUrl'] ?? ''); if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting link could not be opened.'))); }));
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.isAdmin ? 'Live Class Management' : 'Upcoming Live Classes')), floatingActionButton: widget.isAdmin ? FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Schedule class')) : null, body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: db.collection('liveClasses').where('active', isEqualTo: true).snapshots(), builder: (context, snap) { if (snap.hasError) return Center(child: Text('Load error: ${snap.error}')); if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final docs = snap.data!.docs.toList()..sort((a,b) => ((a.data()['startsAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo((b.data()['startsAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)); if (docs.isEmpty) return const Center(child: Text('No live classes scheduled yet.')); return ListView(padding: const EdgeInsets.all(12), children: docs.map(_classCard).toList()); }));
}

class NotesPage extends StatefulWidget {
  final bool isAdmin;
  final String? courseTitle;
  const NotesPage({super.key, required this.isAdmin, this.courseTitle});
  @override State<NotesPage> createState() => _NotesPageState();
}
class _NotesPageState extends State<NotesPage> {
  final db = FirebaseFirestore.instance;
  Future<void> _edit([DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    if (!widget.isAdmin) return;
    final d = doc?.data() ?? <String, dynamic>{};
    final title = TextEditingController(text: d['title'] ?? '');
    final course = TextEditingController(text: d['courseTitle'] ?? widget.courseTitle ?? '');
    final chapter = TextEditingController(text: d['chapter'] ?? '');
    final description = TextEditingController(text: d['description'] ?? '');
    final url = TextEditingController(text: d['pdfUrl'] ?? '');
    final form = GlobalKey<FormState>();
    final save = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(doc == null ? 'Add PDF note' : 'Edit PDF note'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Note title'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null),
        TextFormField(controller: course, decoration: const InputDecoration(labelText: 'Course name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter course name' : null),
        TextFormField(controller: chapter, decoration: const InputDecoration(labelText: 'Chapter / unit (optional)')),
        TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
        TextFormField(controller: url, decoration: const InputDecoration(labelText: 'PDF URL (https link)'), validator: (v) { final u = Uri.tryParse((v ?? '').trim()); return (u == null || u.scheme != 'https' || u.host.isEmpty) ? 'Enter a valid https PDF link' : null; }),
        const SizedBox(height: 8), const Text('Upload is not enabled yet. Add a shareable PDF link (Firebase Storage upload is a later step).', style: TextStyle(fontSize: 12)),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Save'))]));
    if (save == true) {
      final payload = {'title': title.text.trim(), 'courseTitle': course.text.trim(), 'chapter': chapter.text.trim(), 'description': description.text.trim(), 'pdfUrl': url.text.trim(), 'active': true, 'updatedAt': FieldValue.serverTimestamp()};
      if (doc == null) payload['createdAt'] = FieldValue.serverTimestamp();
      if (doc == null) await db.collection('notes').add(payload); else await doc.reference.update(payload);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Study note saved.')));
    }
    title.dispose(); course.dispose(); chapter.dispose(); description.dispose(); url.dispose();
  }
  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete note?'), content: Text(doc.data()?['title'] ?? ''), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (yes == true) await doc.reference.delete();
  }
  Widget _noteCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Card(child: ListTile(isThreeLine: true, leading: const Icon(Icons.picture_as_pdf), title: Text(d['title'] ?? 'PDF Note'), subtitle: Text('${d['courseTitle'] ?? 'Course'}${(d['chapter'] ?? '').toString().isNotEmpty ? ' • ${d['chapter']}' : ''}${(d['description'] ?? '').toString().isNotEmpty ? '\n${d['description']}' : ''}'), trailing: widget.isAdmin ? PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _edit(doc); if (v == 'delete') _delete(doc); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]) : const Icon(Icons.open_in_new), onTap: widget.isAdmin ? null : () async { final uri = Uri.tryParse(d['pdfUrl'] ?? ''); if (uri != null && await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); } else if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF link could not be opened.'))); } }));
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.isAdmin ? 'Notes / PDF Management' : 'Study Notes')), floatingActionButton: widget.isAdmin ? FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add note')) : null, body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: firebaseConfigured ? db.collection('notes').where('active', isEqualTo: true).snapshots() : null, builder: (context, snap) { if (!firebaseConfigured) return const Center(child: Text('Connect Firebase to load study notes.')); if (snap.hasError) return Center(child: Text('Notes loading error: ${snap.error}')); if (!snap.hasData) return const Center(child: CircularProgressIndicator()); var docs = snap.data!.docs.toList(); if (widget.courseTitle != null) docs = docs.where((d) => (d.data()['courseTitle'] ?? '').toString().toLowerCase() == widget.courseTitle!.toLowerCase()).toList(); docs.sort((a,b) => (a.data()['title'] ?? '').toString().toLowerCase().compareTo((b.data()['title'] ?? '').toString().toLowerCase()); if (docs.isEmpty) return const Center(child: Text('No study notes available yet.')); return ListView(padding: const EdgeInsets.all(12), children: docs.map(_noteCard).toList()); }));
}

class CourseDetailPage extends StatelessWidget {
  final Course course;
  const CourseDetailPage({super.key, required this.course});

  List<String> get modules {
    if (course.syllabus.isNotEmpty) return course.syllabus;
    switch (course.title) {
      case 'CCA': return ['Computer fundamentals', 'Windows & file management', 'Typing practice', 'MS Word', 'MS Excel', 'MS PowerPoint', 'Internet & email'];
      case 'DCA': return ['Computer fundamentals', 'MS Word', 'MS Excel', 'MS PowerPoint', 'Internet tools', 'Practical projects'];
      case 'ADCA': return ['Office applications', 'Advanced Excel', 'Database basics', 'Web fundamentals', 'Programming basics', 'Project work'];
      case 'Tally with GST': return ['Accounting fundamentals', 'Company setup', 'Ledgers & vouchers', 'Inventory', 'GST entries', 'Reports & practice'];
      case 'Python': return ['Getting started', 'Variables & data types', 'Conditions & loops', 'Functions', 'Collections', 'Mini projects'];
      case 'AI & Generative AI': return ['AI fundamentals', 'Prompt writing', 'Generative AI tools', 'Responsible AI', 'Productivity use cases', 'Project practice'];
      case 'HTML & CSS': return ['HTML structure', 'Text, links & images', 'Forms', 'CSS selectors', 'Layout & responsive basics', 'Website project'];
      default: return ['Programming fundamentals', 'Variables & operators', 'Conditions', 'Loops', 'Functions', 'Practice programs'];
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(course.title)),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(course.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), Text(course.subtitle),
        const SizedBox(height: 12), Wrap(spacing: 8, children: [Chip(label: Text(course.level)), Chip(label: Text(course.duration))]),
      ]))),
      const SizedBox(height: 12),
      const Text('Course outline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...modules.asMap().entries.map((e) => Card(child: ListTile(leading: CircleAvatar(child: Text('${e.key + 1}')), title: Text(e.value), subtitle: const Text('Learning module')))),
      const SizedBox(height: 12),
      Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('Notes & PDFs'), subtitle: const Text('Study materials for this course'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotesPage(isAdmin: false, courseTitle: course.title))))),
      Card(child: ListTile(leading: const Icon(Icons.video_library), title: const Text('Recorded lessons'), subtitle: const Text('Open video lessons for this course'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordedVideosPage(isAdmin: false, courseTitle: course.title))))),
      Card(child: ListTile(leading: const Icon(Icons.quiz), title: const Text('Practice MCQ'), subtitle: const Text('Available exams for this course'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamsPage(isAdmin: false, courseTitle: course.title))))),
    ]),
  );

}


class AdminCoursesPage extends StatefulWidget {
  const AdminCoursesPage({super.key});
  @override State<AdminCoursesPage> createState() => _AdminCoursesPageState();
}

class _AdminCoursesPageState extends State<AdminCoursesPage> {
  final db = FirebaseFirestore.instance;
  Future<void> _edit([DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final title = TextEditingController(text: data['title'] ?? '');
    final subtitle = TextEditingController(text: data['subtitle'] ?? '');
    final level = TextEditingController(text: data['level'] ?? '');
    final duration = TextEditingController(text: data['duration'] ?? '');
    final fee = TextEditingController(text: data['fee']?.toString() ?? '');
    final syllabus = TextEditingController(text: (data['syllabus'] as List?)?.join('\n') ?? '');
    bool active = data['active'] != false;
    final form = GlobalKey<FormState>();
    final save = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text(doc == null ? 'Add course' : 'Edit course'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Course name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        TextFormField(controller: subtitle, decoration: const InputDecoration(labelText: 'Short description')),
        TextFormField(controller: level, decoration: const InputDecoration(labelText: 'Level')),
        TextFormField(controller: duration, decoration: const InputDecoration(labelText: 'Duration')),
        TextFormField(controller: fee, decoration: const InputDecoration(labelText: 'Course fee (₹)'), keyboardType: TextInputType.number),
        TextFormField(controller: syllabus, decoration: const InputDecoration(labelText: 'Syllabus (one item per line)'), minLines: 2, maxLines: 5),
        SwitchListTile(value: active, title: const Text('Course active'), onChanged: (v) => setDialog(() => active = v)),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Save'))],
    )));
    if (save == true) {
      final Map<String, dynamic> payload = {'title': title.text.trim(), 'subtitle': subtitle.text.trim(), 'level': level.text.trim(), 'duration': duration.text.trim(), 'fee': fee.text.trim(), 'syllabus': syllabus.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(), 'active': active, 'updatedAt': FieldValue.serverTimestamp()};
      if (doc == null) payload['createdAt'] = FieldValue.serverTimestamp();
      if (doc == null) await db.collection('courses').add(payload); else await doc.reference.update(payload);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course saved.')));
    }
    title.dispose(); subtitle.dispose(); level.dispose(); duration.dispose(); fee.dispose(); syllabus.dispose();
  }
  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete course?'), content: Text('Delete ${doc.data()?['title'] ?? 'this course'}?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (ok == true) await doc.reference.delete();
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Course Management')), floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add course')), body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: db.collection('courses').snapshots(), builder: (context, snap) {
    if (snap.hasError) return Center(child: Text('Could not load courses: ${snap.error}'));
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    if (snap.data!.docs.isEmpty) return const Center(child: Text('No courses yet. Tap Add course to create one.'));
    return ListView(padding: const EdgeInsets.all(12), children: snap.data!.docs.map((doc) { final d = doc.data(); return Card(child: ListTile(title: Text(d['title'] ?? 'Unnamed'), subtitle: Text('${d['duration'] ?? ''} • Fee: ${d['fee'] ?? 'Not set'} • ${d['active'] == false ? 'Inactive' : 'Active'}'), trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _edit(doc); if (v == 'delete') _delete(doc); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))])); }).toList());
  }));
}

class AdminStudentsPage extends StatelessWidget {
  const AdminStudentsPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Student Management')), body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('students').snapshots(), builder: (context, snap) {
    if (snap.hasError) return Center(child: Text('Could not load students: ${snap.error}'));
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final docs = snap.data!.docs;
    if (docs.isEmpty) return const Center(child: Text('No student registrations found.'));
    return ListView.builder(itemCount: docs.length, itemBuilder: (context, i) { final d = docs[i].data(); return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(d['fullName'] ?? 'Student'), subtitle: Text('${d['studentId'] ?? ''}\nUID: ${docs[i].id}\n${d['mobile'] ?? ''} • ${d['status'] ?? ''}'), isThreeLine: true, trailing: IconButton(tooltip: 'Copy Firebase UID', icon: const Icon(Icons.copy), onPressed: () async { await Clipboard.setData(ClipboardData(text: docs[i].id)); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firebase UID copied'))); }))); });
  }));
}

// v1.0 MCQ module: student-visible questions are stored separately from answer keys.
class ExamsPage extends StatefulWidget {
  final bool isAdmin;
  final String? courseTitle;
  const ExamsPage({super.key, required this.isAdmin, this.courseTitle});
  @override State<ExamsPage> createState() => _ExamsPageState();
}
class _ExamsPageState extends State<ExamsPage> {
  final db = FirebaseFirestore.instance;
  Future<void> _createExam() async {
    if (!widget.isAdmin) return;
    final title = TextEditingController();
    final course = TextEditingController(text: widget.courseTitle ?? '');
    final minutes = TextEditingController(text: '20');
    final questions = <Map<String, dynamic>>[];
    final keys = <int>[];
    final form = GlobalKey<FormState>();
    bool adding = false;
    final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: const Text('Create MCQ Exam'), content: SizedBox(width: 460, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Exam title'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        TextFormField(controller: course, decoration: const InputDecoration(labelText: 'Course name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        TextFormField(controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (minutes)'), validator: (v) => (int.tryParse(v ?? '') == null || int.parse(v!) < 1) ? 'Enter positive minutes' : null),
        const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: Text('Questions: ${questions.length}', style: const TextStyle(fontWeight: FontWeight.bold))),
        ...questions.asMap().entries.map((e) => ListTile(dense: true, leading: Text('${e.key+1}'), title: Text(e.value['question']), subtitle: Text('Correct option: ${keys[e.key]+1}'), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => refresh(() { questions.removeAt(e.key); keys.removeAt(e.key); })))),
        OutlinedButton.icon(onPressed: adding ? null : () async { adding = true; final q = await _questionDialog(); adding = false; if (q != null) refresh(() { questions.add(q['questionData']); keys.add(q['correctIndex']); }); }, icon: const Icon(Icons.add), label: const Text('Add question')),
      ])))), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate() && questions.isNotEmpty) Navigator.pop(ctx, true); }, child: const Text('Save exam'))])));
    if (saved == true) {
      final ref = await db.collection('exams').add({'title': title.text.trim(), 'courseTitle': course.text.trim(), 'durationMinutes': int.parse(minutes.text), 'questionCount': questions.length, 'questions': questions, 'active': true, 'createdAt': FieldValue.serverTimestamp()});
      await db.collection('examAnswerKeys').doc(ref.id).set({'correctIndexes': keys, 'createdAt': FieldValue.serverTimestamp()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exam created. Answer key is admin-only.')));
    }
    title.dispose(); course.dispose(); minutes.dispose();
  }
  Future<Map<String, dynamic>?> _questionDialog() async {
    final question = TextEditingController();
    final options = List.generate(4, (_) => TextEditingController());
    int correct = 0; final form = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: const Text('Add MCQ'), content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: question, maxLines: 3, decoration: const InputDecoration(labelText: 'Question'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        ...options.asMap().entries.map((e) => TextFormField(controller: e.value, decoration: InputDecoration(labelText: 'Option ${e.key+1}'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Fill all options' : null)),
        const SizedBox(height: 8), const Text('Choose the correct option:'),
        ...List.generate(4, (i) => RadioListTile<int>(dense: true, value: i, groupValue: correct, title: Text('Option ${i+1}'), onChanged: (v) => refresh(() => correct = v ?? 0))),
      ])))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, {'questionData': {'question': question.text.trim(), 'options': options.map((o) => o.text.trim()).toList()}, 'correctIndex': correct}); }, child: const Text('Add'))])));
    question.dispose(); for (final o in options) { o.dispose(); }
    return result;
  }
  Future<void> _deleteExam(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete exam?'), content: Text(doc.data()?['title'] ?? ''), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (ok == true) { await doc.reference.delete(); await db.collection('examAnswerKeys').doc(doc.id).delete(); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.isAdmin ? 'Exam Management' : 'MCQ Exams')), floatingActionButton: widget.isAdmin ? FloatingActionButton.extended(onPressed: _createExam, icon: const Icon(Icons.add), label: const Text('Create exam')) : null,
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: db.collection('exams').where('active', isEqualTo: true).snapshots(), builder: (context, snap) {
      if (snap.hasError) return Center(child: Text('Exam loading error: ${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snap.data!.docs.where((d) => widget.courseTitle == null || (d.data()['courseTitle'] ?? '').toString().toLowerCase() == widget.courseTitle!.toLowerCase()).toList();
      if (docs.isEmpty) return const Center(child: Text('No exams available yet.'));
      return ListView(padding: const EdgeInsets.all(12), children: docs.map((doc) { final d = doc.data(); return Card(child: ListTile(leading: const Icon(Icons.quiz), title: Text(d['title'] ?? 'MCQ Exam'), subtitle: Text('${d['courseTitle'] ?? 'General'} • ${d['questionCount'] ?? 0} questions • ${d['durationMinutes'] ?? 20} minutes'), trailing: widget.isAdmin ? PopupMenuButton<String>(onSelected: (v) { if (v == 'delete') _deleteExam(doc); if (v == 'results') Navigator.push(context, MaterialPageRoute(builder: (_) => ExamResultsPage(examId: doc.id))); }, itemBuilder: (_) => const [PopupMenuItem(value: 'results', child: Text('View results')), PopupMenuItem(value: 'delete', child: Text('Delete exam'))]) : const Icon(Icons.chevron_right), onTap: widget.isAdmin ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamTakingPage(examId: doc.id, examData: d)))); }).toList());)
    }));
}

class ExamTakingPage extends StatefulWidget {
  final String examId; final Map<String, dynamic> examData;
  const ExamTakingPage({super.key, required this.examId, required this.examData});
  @override State<ExamTakingPage> createState() => _ExamTakingPageState();
}
class _ExamTakingPageState extends State<ExamTakingPage> {
  late List<Map<String, dynamic>> questions; late List<int?> answers; Timer? timer; int remaining = 0; bool submitting = false;
  @override void initState() { super.initState(); questions = (widget.examData['questions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(); answers = List.filled(questions.length, null); remaining = ((widget.examData['durationMinutes'] as num?)?.toInt() ?? 20) * 60; timer = Timer.periodic(const Duration(seconds: 1), (t) { if (!mounted) return; if (remaining <= 1) { t.cancel(); _submit(); } else setState(() => remaining--); }); }
  String get timeText => '${(remaining ~/ 60).toString().padLeft(2,'0')}:${(remaining % 60).toString().padLeft(2,'0')}';
  Future<void> _submit() async { if (submitting) return; submitting = true; timer?.cancel(); try { final callable = FirebaseFunctions.instance.httpsCallable('submitMcqExam'); final response = await callable.call({'examId': widget.examId, 'answers': answers.map((a) => a ?? -1).toList()}); final result = Map<String, dynamic>.from(response.data as Map); if (!mounted) return; await showDialog<void>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(title: const Text('Exam submitted'), content: Text('Score: ${result['score']} / ${result['total']}\nPercentage: ${result['percentage']}%'), actions: [FilledButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('Done'))]); } on FirebaseFunctionsException catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: ${e.message ?? e.code}. Deploy exam grading function first.'))); submitting = false; } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission error: $e'))); submitting = false; } }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.examData['title'] ?? 'Exam'), actions: [Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(timeText, style: const TextStyle(fontWeight: FontWeight.bold))))]), body: ListView(padding: const EdgeInsets.all(12), children: [Text('Answered: ${answers.where((a) => a != null).length}/${questions.length}', style: const TextStyle(fontWeight: FontWeight.bold)), ...questions.asMap().entries.map((e) { final q = e.value; final opts = (q['options'] as List? ?? []).map((x) => x.toString()).toList(); return Card(margin: const EdgeInsets.symmetric(vertical: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Q${e.key+1}. ${q['question']}', style: const TextStyle(fontWeight: FontWeight.bold)), ...opts.asMap().entries.map((o) => RadioListTile<int>(contentPadding: EdgeInsets.zero, value: o.key, groupValue: answers[e.key], title: Text(o.value), onChanged: submitting ? null : (v) => setState(() => answers[e.key] = v))]))); }), FilledButton.icon(onPressed: submitting ? null : _submit, icon: const Icon(Icons.send), label: const Text('Submit Exam'))]));
}

class ExamResultsPage extends StatelessWidget {
  final String examId; const ExamResultsPage({super.key, required this.examId});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Exam Results')), body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('examResults').where('examId', isEqualTo: examId).snapshots(), builder: (context, snap) { if (snap.hasError) return Center(child: Text('Results error: ${snap.error}')); if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final docs = snap.data!.docs; if (docs.isEmpty) return const Center(child: Text('No submissions yet.')); return ListView(children: docs.map((d) { final x = d.data(); return ListTile(leading: const Icon(Icons.assessment), title: Text(x['studentName'] ?? x['uid'] ?? 'Student'), subtitle: Text('${x['score']}/${x['total']} • ${x['percentage']}%'), trailing: Text(x['submittedAt'] is Timestamp ? (x['submittedAt'] as Timestamp).toDate().toLocal().toString().substring(0,16) : ''); }).toList()); }));
}

// Certificate module v1.2: Admin-issued certificate records and student certificate wallet.
class CertificatesPage extends StatefulWidget {
  final bool isAdmin;
  final StudentAccount account;
  const CertificatesPage({super.key, required this.isAdmin, required this.account});
  @override State<CertificatesPage> createState() => _CertificatesPageState();
}
class _CertificatesPageState extends State<CertificatesPage> {
  final _studentId = TextEditingController();
  final _studentName = TextEditingController();
  final _course = TextEditingController();
  bool _busy = false;
  String _certificateNumber() {
    final now = DateTime.now();
    final suffix = now.microsecondsSinceEpoch.toString().substring(7);
    return 'BYCSM-${now.year}-$suffix';
  }
  Future<void> _issue() async {
    if (_studentId.text.trim().isEmpty || _studentName.text.trim().isEmpty || _course.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final number = _certificateNumber();
      await FirebaseFirestore.instance.collection('certificates').add({
        'uid': _studentId.text.trim(), 'studentName': _studentName.text.trim(),
        'courseTitle': _course.text.trim(), 'certificateNumber': number,
        'issuedAt': FieldValue.serverTimestamp(), 'status': 'issued',
        'issuedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Certificate issued: $number'))); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Issue failed: $e'))); }
    if (mounted) setState(() => _busy = false);
  }
  Future<void> _printCertificate(Map<String, dynamic> data) async {
    final doc = pw.Document();
    final issued = data['issuedAt'] is Timestamp ? (data['issuedAt'] as Timestamp).toDate() : DateTime.now();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4.landscape, build: (context) => pw.Center(child: pw.Container(padding: const pw.EdgeInsets.all(36), decoration: pw.BoxDecoration(border: pw.Border.all(width: 4, color: PdfColors.blue900)), child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
      pw.Text('BHARATIYA YUVA COMPUTER SAKSHARATA MISSION', style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
      pw.SizedBox(height: 18), pw.Text('CERTIFICATE OF COMPLETION', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 22), pw.Text('This certificate is proudly presented to', style: const pw.TextStyle(fontSize: 16)),
      pw.SizedBox(height: 12), pw.Text(data['studentName'] ?? 'Student', style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12), pw.Text('for successfully completing the course', style: const pw.TextStyle(fontSize: 16)),
      pw.SizedBox(height: 10), pw.Text(data['courseTitle'] ?? 'Course', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
      pw.SizedBox(height: 28), pw.Text('Certificate ID: ${data['certificateNumber'] ?? ''}  •  Date: ${issued.day}/${issued.month}/${issued.year}', style: const pw.TextStyle(fontSize: 12)),
      pw.SizedBox(height: 22), pw.Text('Bharatiya Yuva Computer Saksharata Mission', style: const pw.TextStyle(fontSize: 13)),
    ])))));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
  Future<void> _showIssueForm() async {
    _studentId.clear(); _studentName.clear(); _course.clear();
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Issue Certificate'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _studentId, decoration: const InputDecoration(labelText: 'Student UID (Firebase UID)')),
        TextField(controller: _studentName, decoration: const InputDecoration(labelText: 'Student full name')),
        TextField(controller: _course, decoration: const InputDecoration(labelText: 'Course name')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _issue, child: Text(_busy ? 'Issuing…' : 'Issue'))],
    ));
  }
  @override void dispose() { _studentId.dispose(); _studentName.dispose(); _course.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance.collection('certificates');
    final stream = widget.isAdmin ? query.orderBy('issuedAt', descending: true).snapshots() : query.where('uid', isEqualTo: widget.account.uid).snapshots();
    return Scaffold(appBar: AppBar(title: const Text('Certificates')), floatingActionButton: widget.isAdmin ? FloatingActionButton.extended(onPressed: _showIssueForm, icon: const Icon(Icons.add), label: const Text('Issue Certificate')) : null,
      body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: stream, builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Could not load certificates: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty) return const Center(child: Text('No certificates issued yet.'));
        return ListView.builder(padding: const EdgeInsets.all(12), itemCount: snap.data!.docs.length, itemBuilder: (context, i) {
          final d = snap.data!.docs[i].data();
          final date = d['issuedAt'] is Timestamp ? (d['issuedAt'] as Timestamp).toDate() : null;
          return Card(child: ListTile(leading: const Icon(Icons.workspace_premium, color: Colors.amber), title: Text(d['courseTitle'] ?? 'Course Certificate'), subtitle: Text('${d['studentName'] ?? 'Student'}\nCertificate ID: ${d['certificateNumber'] ?? 'Pending'}\nIssued: ${date == null ? '—' : '${date.day}/${date.month}/${date.year}'}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.print_outlined), tooltip: 'Print / Save PDF', onPressed: () => _printCertificate(d)),));
        });
      }));
  }
}


// v1.9: App settings and help hub. Support links use device handlers; no external
// deployment or support account is assumed to be configured.
class SettingsHelpPage extends StatelessWidget {
  const SettingsHelpPage({super.key});
  static const centreName = 'Bharatiya Yuva Computer Saksharata Mission';
  static const centreAddress = 'Bhatbandh More, near Mishra Lodge (Aadhar Center), Purulia';
  static const centrePhone = '9475955105';
  static const appVersion = '1.9.0';

  Future<void> _open(BuildContext context, String value) async {
    final uri = Uri.parse(value);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this link on your device.')));
    }
  }

  void _faq(BuildContext context) => showDialog<void>(context: context, builder: (_) => AlertDialog(
    title: const Text('Frequently Asked Questions'),
    content: const SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('How do I log in?\nUse your Student ID and password provided during registration.', style: TextStyle(fontWeight: FontWeight.w500)),
      SizedBox(height: 12),
      Text('Where can I find classes?\nOpen Learning Center, then Live Classes or Recorded Videos.'),
      SizedBox(height: 12),
      Text('Where are notes and exams?\nUse Notes / PDFs and MCQ Exams in the Learning Center.'),
      SizedBox(height: 12),
      Text('I forgot my password. What should I do?\nContact the centre/admin for identity verification and reset help.'),
      SizedBox(height: 12),
      Text('How do I get a certificate?\nCertificates appear in your app after the centre/admin issues one.'),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings & Help')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        Image.asset('assets/bycsm_logo.jpg', height: 90, fit: BoxFit.contain),
        const SizedBox(height: 10),
        const Text('BYCSM Computer Learning', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const Text(centreName, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const Text('Version 1.9.0', style: TextStyle(color: Colors.grey)),
      ]))),
      const SizedBox(height: 8),
      const ListTile(title: Text('About BYCSM'), leading: Icon(Icons.school_outlined), subtitle: Text('Computer education and digital learning centre')),
      ListTile(leading: const Icon(Icons.location_on_outlined), title: const Text('Centre Address'), subtitle: const Text(centreAddress), onTap: () => _open(context, 'https://maps.google.com/?q=${Uri.encodeComponent(centreAddress)}')),
      ListTile(leading: const Icon(Icons.phone_outlined), title: const Text('Call Centre'), subtitle: const Text(centrePhone), onTap: () => _open(context, 'tel:$centrePhone')),
      ListTile(leading: const Icon(Icons.chat_outlined), title: const Text('WhatsApp Support'), subtitle: const Text('Message the centre'), onTap: () => _open(context, 'https://wa.me/91$centrePhone')),
      const Divider(),
      ListTile(leading: const Icon(Icons.help_outline), title: const Text('Help & FAQ'), subtitle: const Text('Common student questions'), onTap: () => _faq(context)),
      ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy & Security'), subtitle: const Text('Account security information'), onTap: () => showDialog<void>(context: context, builder: (_) => const AlertDialog(title: Text('Privacy & Security'), content: Text('Use a unique password and do not share it. Student account data is intended to be stored in Firebase once the project is configured. This starter app has not yet been deployed or independently security-tested. Contact the centre if you need help with your account.'), actions: []))),
      ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Change Password'), subtitle: const Text('Update your login password'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()))),
      const SizedBox(height: 12),
      const Center(child: Text('© BYCSM • Learn. Practice. Grow.', style: TextStyle(color: Colors.grey))),
    ]),
  );
}
