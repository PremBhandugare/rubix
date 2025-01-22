import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MyDonationsScreen extends StatelessWidget {
  final String currentUserId;

  const MyDonationsScreen({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Donations')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('userId', isEqualTo: currentUserId)
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
               final donation = donations[index].data() as Map<String, dynamic>;
              return MyDonationCard(
                donationId: donations[index].id,
                donation: donation,
              );
            },
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
    required this.donationId,
    required this.donation,
  });

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
        SnackBar(content: Text('Request approved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve request: $e')),
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
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
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
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(donation['status'].toUpperCase()),
                  backgroundColor: isAvailable 
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                ),
              ],
            ),
            
            if (donation['imageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  donation['imageUrl'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            
            SizedBox(height: 8),
            Text('Category: ${donation['foodCategory']}'),
            Text('Quantity: ${donation['quantity']}'),
            Text('Expires: ${DateFormat('MMM dd, yyyy').format(
              donation['expirationDate'].toDate()
            )}'),
            
            Divider(height: 24),
            
            if (requests.isNotEmpty) ...[
              Text(
                'Recipient Requests (${requests.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              
              if (approvedRecipient != null)
                ListTile(
                  tileColor: Colors.green.withOpacity(0.1),
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text(approvedRecipient['recipientName']),
                  subtitle: Text(approvedRecipient['recipientEmail']),
                )
              else
                ...requests.map((request) => ListTile(
                  title: Text(request['recipientName']),
                  subtitle: Text(request['recipientEmail']),
                  trailing: isAvailable
                      ? ElevatedButton(
                          onPressed: () => handleApproval(context, request),
                          child: Text('Approve'),
                        )
                      : null,
                )).toList(),
            ] else
              Text('No requests yet'),
          ],
        ),
      ),
    );
  }
}