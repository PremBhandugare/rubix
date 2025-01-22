import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyRequestsScreen extends StatelessWidget {
  final String currentUserId;

  const MyRequestsScreen({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('myRequests')
            .doc(currentUserId)
            .collection('requests')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data!.docs;
          
          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index].data() as Map<String, dynamic>;
              return RequestCard(request: request);
            },
          );
        },
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;

  const RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (request['status']) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

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
                    request['foodName'],
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(request['status'].toUpperCase()),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: statusColor),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Category: ${request['foodCategory']}'),
            Text('Quantity: ${request['quantity']}'),
            Text('Requested on: ${DateFormat('MMM dd, yyyy').format(
              request['timestamp'].toDate()
            )}'),
            Text('Expires on: ${DateFormat('MMM dd, yyyy').format(
              request['expirationDate'].toDate()
            )}'),
            
            if (request['status'] == 'approved')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'Donor Contact: ${request['donorContact']}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}