
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
    'CCA',
    'DCA',
    'ADCA',
    'Tally with GST',
    'Python',
    'Artificial Intelligence',
    'C & C++',
    'Java',
    'HTML & CSS',
    'Hardware & Networking',
  ];

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
          const Center(
            child: Text('Online MCQ Exams',
                style: TextStyle(fontSize: 22)),
          ),
          const Center(
            child: Text('Notes & PDF',
                style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.school),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz),
            label: 'Exam',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book),
            label: 'Notes',
          ),
        ],
      ),
    );
  }

  Widget dashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          color: Colors.blue,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to BYCSM!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Learn Computer Skills for Your Future',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Student Dashboard',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        dashboardCard(Icons.person, 'Student Login'),
        dashboardCard(Icons.video_library, 'Live & Recorded Classes'),
        dashboardCard(Icons.quiz, 'Online MCQ Exam'),
        dashboardCard(Icons.picture_as_pdf, 'Study Notes & PDF'),
        dashboardCard(Icons.workspace_premium, 'Certificates'),
        dashboardCard(Icons.admin_panel_settings, 'Admin Panel'),
      ],
    );
  }

  Widget dashboardCard(IconData icon, String title) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title - Coming Soon')),
          );
        },
      ),
    );
  }

  Widget coursePage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Available Courses',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...courses.map(
          (course) => Card(
            child: ListTile(
              leading: const Icon(Icons.computer, color: Colors.blue),
              title: Text(course),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$course selected')),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
