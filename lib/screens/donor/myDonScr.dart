import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class MyDonationsScreen extends StatefulWidget {
  final String currentUserId;

  const MyDonationsScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _MyDonationsScreenState createState() => _MyDonationsScreenState();
}

class _MyDonationsScreenState extends State<MyDonationsScreen> {
 String _selectedFilter = 'ongoing';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar( // Optional: Customize AppBar background color
  flexibleSpace: Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Ensures minimal space usage
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () => setState(() => _selectedFilter = 'ongoing'),
            child: Text(
              'Ongoing',
              style: TextStyle(
                color: _selectedFilter == 'ongoing' ? Colors.white : Colors.white54,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: _selectedFilter == 'ongoing' 
                  ? Colors.green[700] 
                  : Colors.green.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          SizedBox(width: 16),
          TextButton(
            onPressed: () => setState(() => _selectedFilter = 'completed'),
            child: Text(
              'Completed',
              style: TextStyle(
                color: _selectedFilter == 'completed' ? Colors.white : Colors.white54,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: _selectedFilter == 'completed' 
                  ? Colors.green[700] 
                  : Colors.green.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),

      body: StreamBuilder<QuerySnapshot>(
        stream: _selectedFilter == 'ongoing'
            ? FirebaseFirestore.instance
                .collection('donations')
                .where('userId', isEqualTo: widget.currentUserId)
                .where('status', isEqualTo: 'available')
                .snapshots()
            : FirebaseFirestore.instance
                .collection('donations')
                .where('userId', isEqualTo: widget.currentUserId)
                .where('status', isEqualTo: 'claimed')
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
                  Icon(
                    _selectedFilter == 'ongoing' 
                      ? Icons.hourglass_empty 
                      : Icons.check_circle_outline, 
                    size: 100, 
                    color: Colors.grey
                  ),
                  SizedBox(height: 16),
                  Text(
                    _selectedFilter == 'ongoing' 
                      ? 'No ongoing donations' 
                      : 'No completed donations',
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
                final donation = donations[index].data() as Map<String, dynamic>;
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: _ImprovedDonationCard(
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

class _ImprovedDonationCard extends StatelessWidget {
  final String donationId;
  final Map<String, dynamic> donation;

  const _ImprovedDonationCard({
    Key? key,
    required this.donationId,
    required this.donation,
  }) : super(key: key);

  Future<void> handleApproval(BuildContext context, Map<String, dynamic> recipient) async {
    try {

      int pointsToAllocate = donation['quantity'] > 50 ? 20 : 10;

      // Update donor's points
      await FirebaseFirestore.instance
          .collection('donors')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'points': FieldValue.increment(pointsToAllocate)
      });
      // After updating points
      _showPointsAchievementDialog(context, pointsToAllocate);
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
          content: Text('Request approved! You earned $pointsToAllocate points.'),
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
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small image on the left
          ClipRRect(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            child: donation['imageUrl'] != null
                ? Image.network(
                    donation['imageUrl'],
                    width: 120,
                    height: 160,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 120,
                    height: 160,
                    color: Colors.grey[300],
                    child: Icon(Icons.image, size: 60, color: Colors.grey[400]),
                  ),
          ),
          
          // Expanded details
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          donation['foodName'],
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusChip(donation['status']),
                    ],
                  ),
                  SizedBox(height: 8),
                  _buildInfoRow(Icons.category, donation['foodCategory']),
                  _buildInfoRow(Icons.shopping_basket, donation['quantity']),
                  _buildInfoRow(
                    Icons.calendar_today,
                    DateFormat('MMM dd, yyyy').format(donation['expirationDate'].toDate()),
                  ),
                  SizedBox(height: 10,),
                ],
              ),
            ),
          ),
        ],
      ),
        SizedBox(height: 5,),
        if (donation['status'] == 'claimed') ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approved Recipient',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 8),
                _buildApprovedRecipientTile(donation['recipients']['accepted']),
              ],
            ),
          ),
        ],
        if (donation['status'] == 'available') ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 8),
                ...List<Map<String, dynamic>>.from(donation['recipients']['requests']).map((request) {
                  final isAvailable = request['status'] == 'pending';
                  return _buildRecipientTile(context, request, isAvailable);
                }).toList(),
              ],
            ),
          ),
        ],
        ],
      )
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

  Widget _buildInfoRow(IconData icon, dynamic text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text.toString(),
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
            style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(request['recipientName']),
        subtitle: Text(request['recipientEmail']),
        trailing: isAvailable
            ? ElevatedButton(
                onPressed: () => handleApproval(context, request),
                child: Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
void _showPointsAchievementDialog(BuildContext context, int points) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade300, Colors.green.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.stars_rounded,
                color: Colors.yellow,
                size: 80,
              ),
              SizedBox(height: 20),
              Text(
                'Achievement Unlocked!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  children: [
                    TextSpan(text: 'You earned '),
                    TextSpan(
                      text: '$points Points',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow,
                      ),
                    ),
                    TextSpan(text: ' for your donation!'),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Awesome!',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
