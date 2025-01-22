import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';

class MyRequestsScreen extends StatelessWidget {
  final String currentUserId;

  const MyRequestsScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Requests'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('myRequests')
            .doc(currentUserId)
            .collection('requests')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 100, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No requests yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data!.docs;
          
          return AnimationLimiter(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index].data() as Map<String, dynamic>;
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: RequestCard(request: request),
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

class RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;

  const RequestCard({Key? key, required this.request}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    switch (request['status']) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
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
                          request['foodName'],
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          request['status'].toUpperCase(),
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: statusColor,
                        avatar: Icon(statusIcon, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildInfoRow(Icons.category, 'Category: ${request['foodCategory']}'),
                  _buildInfoRow(Icons.shopping_basket, 'Quantity: ${request['quantity']}'),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Requested on: ${DateFormat('MMM dd, yyyy').format(request['timestamp'].toDate())}',
                  ),
                  _buildInfoRow(
                    Icons.event,
                    'Expires on: ${DateFormat('MMM dd, yyyy').format(request['expirationDate'].toDate())}',
                  ),
                  
                  if (request['status'] == 'approved') ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.contact_phone, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Donor Contact: ${request['donorContact']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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

