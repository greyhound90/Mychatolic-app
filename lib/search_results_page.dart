import 'package:flutter/material.dart';
import 'other_user_profile_page.dart';

class SearchResultsPage extends StatelessWidget {
  final Map<String, dynamic> filters;

  const SearchResultsPage({super.key, required this.filters});

  @override
  Widget build(BuildContext context) {
    // Dummy Data for Search Results
    final List<Map<String, dynamic>> dummyUsers = [
      {
        "name": "Andreas",
        "age": 25,
        "parish": "Paroki St. Yoseph",
        "avatar": null, // Use default icon
        "isFriend": false,
      },
      {
        "name": "Maria",
        "age": 22,
        "parish": "Katedral Jakarta",
        "avatar": null,
        "isFriend": false,
      },
      {
        "name": "Yohanes",
        "age": 28,
        "parish": "Paroki Blok B",
        "avatar": null,
        "isFriend": true,
      },
      {
        "name": "Theresia",
        "age": 30,
        "parish": "Paroki Kelapa Gading",
        "avatar": null,
        "isFriend": false,
      },
      {
        "name": "Fransiskus",
        "age": 24,
        "parish": "Paroki St. Andreas",
        "avatar": null,
        "isFriend": false,
      },
       {
        "name": "Bernadette",
        "age": 21,
        "parish": "Paroki Alam Sutera",
        "avatar": null,
        "isFriend": false,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF2C225B), // Deep Royal Purple
      appBar: AppBar(
        title: const Text("Hasil Pencarian", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
        backgroundColor: const Color(0xFF2C225B),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: dummyUsers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = dummyUsers[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfilePage(userData: user)));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF3D3270), // Soft Purple Card
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset:const Offset(0, 2))]
              ),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFFF9F1C),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF2C225B),
                      child: Text(
                        user['name'][0],
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${user['name']} - ${user['age']} th", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user['parish'],
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
  
                  // Action Button
                  if (user['isFriend'])
                     const Icon(Icons.check_circle, color: Color(0xFFA3B18A), size: 28) // Already Friend
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F1C).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () {
                          // TODO: Implement Add Friend Logic
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Permintan pertemanan dikirim ke ${user['name']}")));
                        }, 
                        icon: const Icon(Icons.person_add_rounded, color: Color(0xFFFF9F1C)),
                        tooltip: "Tambah Teman",
                      ),
                    )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
