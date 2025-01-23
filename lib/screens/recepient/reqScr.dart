import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(width: 30,),
                  Image.asset(
                    'assets/globe.png',
                    height: 30,
                    width: 30,
                  ),
                  const SizedBox(width: 10,),
                  Text(
                    'Ahar Setu',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                
              
              _buildHeroSection(),
              SizedBox(height: 10),
                _buildHorizontalList(context, donations, 'Fresh'),
                _buildHorizontalList(context, donations, 'Canned'),
                _buildHorizontalList(context, donations, 'Cooked'),
                _buildHorizontalList(context, donations, 'Packaged'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalList(BuildContext context, List<QueryDocumentSnapshot> donations, String category) {
    final filteredDonations = donations.where((donation) {
      final data = donation.data() as Map<String, dynamic>;
      return category == 'All Donations' || data['foodCategory'] == category;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            category,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filteredDonations.length,
            itemBuilder: (context, index) {
              final donation = filteredDonations[index];
              final data = donation.data() as Map<String, dynamic>;
              
              return GestureDetector(
                onTap: () => _showDonationDetails(context, donation),
                child: Container(
                  width: 150,
                  margin: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: data['imageUrl'] != null
                            ? Image.network(
                                data['imageUrl'],
                                width: 150,
                                height: 120,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 150,
                                height: 120,
                                color: Colors.grey[300],
                                child: Icon(Icons.no_food, color: Colors.grey[600]),
                              ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        data['foodName'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Expires: ${DateFormat('MMM dd').format(data['expirationDate'].toDate())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDonationDetails(BuildContext context, QueryDocumentSnapshot donation) {
    final data = donation.data() as Map<String, dynamic>;
    final requests = List<Map<String, dynamic>>.from(
      donation['recipients']?['requests'] ?? []
    );
    final hasRequested = requests.any(
      (r) => r['recipientId'] == currentUserId,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
  borderRadius: BorderRadius.circular(10),
  child: SizedBox(
    width: double.infinity,
    height: 250,
    child: data['imageUrl'] != null && data['imageUrl'].isNotEmpty
      ? Image.network(
          data['imageUrl'],
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[300],
            child: Icon(Icons.no_food, size: 100, color: Colors.grey[600]),
          ),
        )
      : Container(
          color: Colors.grey[300],
          child: Icon(Icons.no_food, size: 100, color: Colors.grey[600]),
        ),
  ),
),
                SizedBox(height: 16),
                Text(
                  data['foodName'],
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 8),
                _buildDetailRow(Icons.category, 'Category', data['foodCategory']),
                _buildDetailRow(Icons.shopping_basket, 'Quantity', data['quantity'].toString()),
                _buildDetailRow(
                  Icons.calendar_today, 
                  'Expiration Date', 
                  DateFormat('MMM dd, yyyy').format(data['expirationDate'].toDate())
                ),
                SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: hasRequested ? null : () => _showInterest(context, donation),
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
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _showInterest(BuildContext context, QueryDocumentSnapshot donation) async {
    try {
      final donationRef = FirebaseFirestore.instance
          .collection('donations')
          .doc(donation.id);

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

      await FirebaseFirestore.instance
          .collection('myRequests')
          .doc(currentUserId)
          .collection('requests')
          .add({
        'donationId': donation.id,
        'foodName': donation['foodName'],
        'quantity': donation['quantity'],
        'foodCategory': donation['foodCategory'],
        'donorId': donation['userId'],
        'status': 'pending',
        'timestamp': Timestamp.now(),
        'expirationDate': donation['expirationDate'],
      });

      Navigator.of(context).pop(); // Close the dialog
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
}
Widget _buildHeroSection() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/D2.jpg',
                fit: BoxFit.cover,
              ),
              Positioned(
                bottom: 5,
                left: 5,
                right: 5,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Save Food, Save Lives',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }