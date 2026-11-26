
import 'package:flutter/material.dart';

void main() {
  runApp(const BYCSMApp());
}

class BYCSMApp extends StatelessWidget {
  const BYCSMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BYCSM Computer Learning',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  final courses = [
    'CCA', 'DCA', 'ADCA', 'Tally with GST',
    'Python', 'Artificial Intelligence',
    'C & C++', 'Java', 'HTML & CSS',
    'Hardware & Networking',
  ];

  void openPage(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeaturePage(title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BYCSM Learning App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          dashboard(),
          coursePage(),
          const FeaturePage(title: 'Online MCQ Exam'),
          const FeaturePage(title: 'Study Notes & PDF'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Exam'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Notes'),
        ],
      ),
    );
  }

  Widget dashboard() {
    final items = [
      [Icons.person, 'Student Login'],
      [Icons.app_registration, 'Student Registration'],
      [Icons.video_library, 'Live & Recorded Classes'],
      [Icons.quiz, 'Online MCQ Exam'],
      [Icons.picture_as_pdf, 'Study Notes & PDF'],
      [Icons.workspace_premium, 'Certificates'],
      [Icons.admin_panel_settings, 'Admin Panel'],
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          color: Colors.blue,
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome to BYCSM!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Learn Computer Skills for Your Future',
                    style: TextStyle(color: Colors.white)),
                SizedBox(height: 8),
                Text('Bharatiya Yuva Computer Saksharata Mission',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Student Dashboard',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...items.map((item) => Card(
          child: ListTile(
            leading: Icon(item[0] as IconData, color: Colors.blue),
            title: Text(item[1] as String),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => openPage(item[1] as String),
          ),
        )),
      ],
    );
  }

  Widget coursePage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Available Courses',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...courses.map((course) => Card(
          child: ListTile(
            leading: const Icon(Icons.computer, color: Colors.blue),
            title: Text(course),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => openPage(course),
          ),
        )),
      ],
    );
  }
}

class FeaturePage extends StatelessWidget {
  final String title;

  const FeaturePage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school, size: 65, color: Colors.blue),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'BYCSM Computer Learning',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                'This section is ready for the next development step.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
