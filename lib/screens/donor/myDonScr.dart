import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyDonationsScreen extends StatelessWidget {
  final String currentUserId;

  const MyDonationsScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Donations'),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('userId', isEqualTo: currentUserId)
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
                  Icon(Icons.volunteer_activism, size: 100, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No donations yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to donation creation screen
                    },
                    child: Text('Make a Donation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
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
                final donation = donations[index].data() as Map<String, dynamic>;
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: MyDonationCard(
                        donationId: donations[index].id,
                        donation: donation,
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

class MyDonationCard extends StatelessWidget {
  final String donationId;
  final Map<String, dynamic> donation;

  const MyDonationCard({
    Key? key,
    required this.donationId,
    required this.donation,
  }) : super(key: key);

  Future<void> handleApproval(BuildContext context, Map<String, dynamic> recipient) async {
    try {
      // Update donation status
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .update({
        'status': 'claimed',
        'recipients.accepted': recipient,
        'recipients.requests': FieldValue.arrayUnion([
          {...recipient, 'status': 'approved'}
        ])
      });

      // Update recipient's request status
      await FirebaseFirestore.instance
          .collection('myRequests')
          .doc(recipient['recipientId'])
          .collection('requests')
          .where('donationId', isEqualTo: donationId)
          .get()
          .then((querySnapshot) {
            querySnapshot.docs.first.reference.update({
              'status': 'approved',
              'donorContact': donation['contactDetails']
            });
          });

      // Update other recipients' request status as rejected
      final requests = List<Map<String, dynamic>>.from(
        donation['recipients']?['requests'] ?? []
      );

      for (var request in requests) {
        if (request['recipientId'] != recipient['recipientId']) {
          await FirebaseFirestore.instance
              .collection('myRequests')
              .doc(request['recipientId'])
              .collection('requests')
              .where('donationId', isEqualTo: donationId)
              .get()
              .then((querySnapshot) {
                querySnapshot.docs.first.reference.update({
                  'status': 'rejected'
                });
              });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = List<Map<String, dynamic>>.from(
      donation['recipients']?['requests'] ?? []
    );
    final isAvailable = donation['status'] == 'available';
    final approvedRecipient = donation['recipients']?['accepted'];

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: donation['imageUrl'] != null
                ?Image.network(
                    donation['imageUrl'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: Icon(Icons.image, size: 100, color: Colors.grey[400]),
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        donation['foodName'],
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusChip(donation['status']),
                  ],
                ),
                SizedBox(height: 8),
                _buildInfoRow(Icons.category, 'Category: ${donation['foodCategory']}'),
                _buildInfoRow(Icons.shopping_basket, 'Quantity: ${donation['quantity']}'),
                _buildInfoRow(
                  Icons.calendar_today,
                  'Expires: ${DateFormat('MMM dd, yyyy').format(donation['expirationDate'].toDate())}',
                ),
                
                SizedBox(height: 16),
                
                if (requests.isNotEmpty) ...[
                  Text(
                    'Recipient Requests (${requests.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  if (approvedRecipient != null)
                    _buildApprovedRecipientTile(approvedRecipient)
                  else
                    ...requests.map((request) => _buildRecipientTile(context, request, isAvailable)).toList(),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No requests yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
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

  Widget _buildStatusChip(String status) {
    Color chipColor;
    IconData chipIcon;

    switch (status.toLowerCase()) {
      case 'available':
        chipColor = Colors.green;
        chipIcon = Icons.check_circle;
        break;
      case 'claimed':
        chipColor = Colors.orange;
        chipIcon = Icons.access_time;
        break;
      default:
        chipColor = Colors.grey;
        chipIcon = Icons.info;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: chipColor,
      avatar: Icon(chipIcon, color: Colors.white, size: 18),
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

  Widget _buildApprovedRecipientTile(Map<String, dynamic> recipient) {
    return Card(
      color: Colors.green[50],
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.check, color: Colors.white),
        ),
        title: Text(
          recipient['recipientName'],
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(recipient['recipientEmail']),
        trailing: Icon(Icons.verified_user, color: Colors.green),
      ),
    );
  }

  Widget _buildRecipientTile(BuildContext context, Map<String, dynamic> request, bool isAvailable) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            request['recipientName'][0].toUpperCase(),
            style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(request['recipientName']),
        subtitle: Text(request['recipientEmail']),
        trailing: isAvailable
            ? ElevatedButton(
                onPressed: () => handleApproval(context, request),
                child: Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

