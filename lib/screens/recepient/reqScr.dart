import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rubix/screens/recepient/myreqScr.dart';

// Screen to show all available donations to recipients
class AvailableDonationsScreen extends StatelessWidget {
  final String currentUserId;
  final String currentUserEmail;
  final String currentUserName;

  const AvailableDonationsScreen({
    required this.currentUserId,
    required this.currentUserEmail,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Donations'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MyRequestsScreen(currentUserId: currentUserId),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('status', isEqualTo: 'available')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final donations = snapshot.data!.docs;
          
          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: donations.length,
            itemBuilder: (context, index) {
              final donation = donations[index];
              final data = donation.data() as Map<String, dynamic>;
              // Check if user has already requested this donation
              // Check if user has already requested this donation
              final requests = List<Map<String, dynamic>>.from(
  donation['recipients']?['requests'] ?? []
);
final hasRequested = requests.any(
  (r) => r['recipientId'] == currentUserId,
);

              return DonationCard(
                donationId: donation.id,
                donation: data,
                currentUserId: currentUserId,
                currentUserEmail: currentUserEmail,
                currentUserName: currentUserName,
                hasRequested: hasRequested,
              );
            },
          );
        },
      ),
    );
  }
}

class DonationCard extends StatelessWidget {
  final String donationId;
  final Map<String, dynamic> donation;
  final String currentUserId;
  final String currentUserEmail;
  final String currentUserName;
  final bool hasRequested;

  const DonationCard({
    required this.donationId,
    required this.donation,
    required this.currentUserId,
    required this.currentUserEmail,
    required this.currentUserName,
    required this.hasRequested,
  });

  Future<void> showInterest(BuildContext context) async {
    try {
      // First, update the donations collection
      final donationRef = FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId);

      final recipientRequest = {
        'recipientId': currentUserId,
        'recipientEmail': currentUserEmail,
        'recipientName': currentUserName,
        'timestamp': Timestamp.now(),
        'status': 'pending'
      };

      await donationRef.update({
        'recipients.requests': FieldValue.arrayUnion([recipientRequest])
      });

      // Then, create a request document in myRequests collection
      await FirebaseFirestore.instance
          .collection('myRequests')
          .doc(currentUserId)
          .collection('requests')
          .add({
        'donationId': donationId,
        'foodName': donation['foodName'],
        'quantity': donation['quantity'],
        'foodCategory': donation['foodCategory'],
        'donorId': donation['userId'],
        'status': 'pending',
        'timestamp': Timestamp.now(),
        'expirationDate': donation['expirationDate'],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              donation['foodName'],
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            
            if (donation['imageUrl'] != null)
              Image.network(
                donation['imageUrl'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            
            SizedBox(height: 8),
            Text('Category: ${donation['foodCategory']}'),
            Text('Quantity: ${donation['quantity']}'),
            Text('Expires: ${DateFormat('MMM dd, yyyy').format(
              donation['expirationDate'].toDate()
            )}'),
            
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: hasRequested ? null : () => showInterest(context),
                child: Text(hasRequested ? 'Request Sent' : 'Show Interest'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasRequested ? Colors.grey : Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}