//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// // Model class for transactions to ensure type safety
// class TransactionModel {
//   final double amount;
//   final String category;
//   final String type;
//   final DateTime date;
//   final String? description;

//   TransactionModel({
//     required this.amount,
//     required this.category,
//     required this.type,
//     required this.date,
//     this.description,
//   });

//   factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return TransactionModel(
//       amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
//       category: data['category'] as String? ?? 'Unknown',
//       type: data['type'] as String? ?? 'expense',
//       date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
//       description: data['description'] as String?,
//     );
//   }
// }

// class DashboardPage extends StatelessWidget {
//   const DashboardPage({super.key}); // Fixed: Use super.key

//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;

//     // Redirect to login if user is not authenticated
//     if (user == null) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         Navigator.pushReplacementNamed(context, '/login');
//       });
//       return const Scaffold(
//         body: Center(child: Text('Redirecting to login...')),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(title: const Text('Safe Budget Dashboard')),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .collection('transactions')
//             .orderBy('timestamp', descending: true)
//             .limit(5)
//             .snapshots(),
//         builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
//           if (snapshot.hasError) {
//             return const Center(
//               child: Text('Error loading transactions. Please try again.'),
//             );
//           }

//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(child: Text('No transactions found.'));
//           }

//           final transactions = snapshot.data!.docs
//               .map((doc) => TransactionModel.fromFirestore(doc))
//               .toList();

//           // Calculate total balance dynamically
//           double totalBalance = 0.0;
//           for (var transaction in transactions) {
//             if (transaction.type == 'income') {
//               totalBalance += transaction.amount;
//             } else if (transaction.type == 'expense') {
//               totalBalance -= transaction.amount;
//             }
//           }

//           return Column(
//             children: [
//               Card(
//                 margin: const EdgeInsets.all(16.0),
//                 child: ListTile(
//                   title: const Text(
//                     'Total Balance',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   subtitle: Text(
//                     '\$${totalBalance.toStringAsFixed(2)}',
//                     style: TextStyle(
//                       color: totalBalance >= 0 ? Colors.green : Colors.red,
//                     ),
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: transactions.length,
//                   itemBuilder: (context, index) {
//                     final transaction = transactions[index];
//                     return ListTile(
//                       title: Text(transaction.category),
//                       subtitle: Text(
//                         '${transaction.type.capitalize()} - \$${transaction.amount.toStringAsFixed(2)}',
//                       ),
//                       trailing: Text(
//                         _formatDate(transaction.date),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: ElevatedButton(
//                   onPressed: () =>
//                       Navigator.pushNamed(context, '/add-transaction'),
//                   child: const Text('Add Transaction'),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   // Helper function to format date
//   String _formatDate(DateTime date) {
//     return '${date.day}/${date.month}/${date.year}';
//   }
// }

// // Extension to capitalize strings
// extension StringExtension on String {
//   String capitalize() {
//     return "${this[0].toUpperCase()}${substring(1)}";
//   }
// }


class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Guest';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Budget Dashboard'),
      ),
      body: Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 32),
      Text(
        '${_getGreeting()}, $displayName!',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      // Blue banner container
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Balance',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              "10,000",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),

    );
  }
}
