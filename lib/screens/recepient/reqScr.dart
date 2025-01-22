import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rubix/screens/recepient/myreqScr.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class AvailableDonationsScreen extends StatelessWidget {
  final String currentUserId;
  final String currentUserEmail;
  final String currentUserName;

  const AvailableDonationsScreen({
    Key? key,
    required this.currentUserId,
    required this.currentUserEmail,
    required this.currentUserName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Donations'),
        backgroundColor: Colors.green,
        elevation: 0,
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
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            );
          }

          final donations = snapshot.data!.docs;

          if (donations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.no_food, size: 100, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No available donations',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return AnimationLimiter(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: donations.length,
              itemBuilder: (context, index) {
                final donation = donations[index];
                final data = donation.data() as Map<String, dynamic>;
                final requests = List<Map<String, dynamic>>.from(
                  donation['recipients']?['requests'] ?? []
                );
                final hasRequested = requests.any(
                  (r) => r['recipientId'] == currentUserId,
                );

                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: DonationCard(
                        donationId: donation.id,
                        donation: data,
                        currentUserId: currentUserId,
                        currentUserEmail: currentUserEmail,
                        currentUserName: currentUserName,
                        hasRequested: hasRequested,
                      ),
                    ),
                  ),
                );
              },
            ),
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
    Key? key,
    required this.donationId,
    required this.donation,
    required this.currentUserId,
    required this.currentUserEmail,
    required this.currentUserName,
    required this.hasRequested,
  }) : super(key: key);

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
        SnackBar(
          content: Text('Request sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: donation['imageUrl'] != null
                ? Image.network(
                    donation['imageUrl'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: Icon(Icons.no_food, size: 100, color: Colors.grey[400]),
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donation['foodName'],
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                _buildInfoRow(Icons.category, 'Category: ${donation['foodCategory']}'),
                _buildInfoRow(Icons.shopping_basket, 'Quantity: ${donation['quantity']}'),
                _buildInfoRow(
                  Icons.calendar_today,
                  'Expires: ${DateFormat('MMM dd, yyyy').format(donation['expirationDate'].toDate())}',
                ),
                SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: hasRequested ? null : () => showInterest(context),
                    child: Text(
                      hasRequested ? 'Request Sent' : 'Show Interest',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasRequested ? Colors.grey : Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}

