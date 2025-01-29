import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
String? userId;
String? emailId;
String? usernamee;
const Distance distance = Distance();
class DonationsMapScreen extends StatefulWidget {
   final LatLng? currentLocation;
  final bool isLoadingLocation;

  const DonationsMapScreen({
    super.key, 
    this.currentLocation,
    this.isLoadingLocation = false,
  });

  @override
  _DonationsMapScreenState createState() => _DonationsMapScreenState();
}

class _DonationsMapScreenState extends State<DonationsMapScreen> {
  final MapController _mapController = MapController();
  int _selectedDonationIndex = -1;
  List<LatLng> _routePoints = [];
  double _selectedDonationDistance = 0.0;
  double _showdist = 0.0 ;
  List<QueryDocumentSnapshot> _donations = [];
   bool _isLoadingRoute = false;

   @override
  void initState() {
    super.initState();
    _fetchUserData();
    if (widget.currentLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(widget.currentLocation!, 12);
      });
    }
  }

  @override
  void didUpdateWidget(DonationsMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update map center when location changes
    if (widget.currentLocation != null && 
        widget.currentLocation != oldWidget.currentLocation) {
      _mapController.move(widget.currentLocation!, 13);
    }
  }
  
  Future<List<LatLng>> fetchRoute(LatLng start, LatLng end) async {
    try {
      final response = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          return coordinates
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();
        }
      }
      throw Exception('Failed to fetch route');
    } catch (e) {
      print('Error fetching route: $e');
      // Fallback to straight line if route fetching fails
      return [start, end];
    }
  }

  Future<void> _showRouteToDonation(LatLng donationLocation) async {
    if (widget.currentLocation != null) {
      setState(() {
        _isLoadingRoute = true;
      });

      try {
        final routePoints = await fetchRoute(widget.currentLocation!, donationLocation);
        
        setState(() {
          _routePoints = routePoints;
          // Calculate distance in kilometers
        _showdist = distance.as(
          LengthUnit.Kilometer,
          widget.currentLocation!,
          donationLocation,
        );
          // Calculate actual route distance
          _selectedDonationDistance = 0;
          for (int i = 0; i < routePoints.length - 1; i++) {
            _selectedDonationDistance += distance.as(
              LengthUnit.Kilometer,
              routePoints[i],
              routePoints[i + 1],
            );
          }
        });
        
        // Adjust map bounds to show entire route
        final bounds = LatLngBounds.fromPoints(_routePoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50.0),
          ),
        );
      } finally {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        userId = user.uid;
        
        final instituteDoc = await FirebaseFirestore.instance
            .collection('donors')
            .doc(user.uid)
            .get();

        if (instituteDoc.exists) {
          final data = instituteDoc.data() as Map<String, dynamic>;
          setState(() {
            
            usernamee = data['fullName'] ?? 'No Name';
            emailId = data['email'] ?? 'No Email';
            
          });
        } else {
          
          final userDoc = await FirebaseFirestore.instance
              .collection('recepients')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            setState(() {
              userId = user.uid;
              usernamee = data['fullName'] ?? 'No Name';
              emailId = data['email'] ?? 'No Email';
            });
          } else {
          }
        }
      }
    } catch (e) {
      
    }
  }

 

 @override
Widget build(BuildContext context) {
  return Scaffold(
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('status', isEqualTo: 'available')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No available donations'));
        }

         // Filter out expired donations
        final now = DateTime.now();
        final donations = snapshot.data!.docs.where((donation) {
          final data = donation.data() as Map<String, dynamic>;
          final expirationDate = (data['expirationDate'] as Timestamp).toDate();
          return expirationDate.isAfter(now);
        }).toList();

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.currentLocation ?? const LatLng(19.1136, 72.8697),
                initialZoom: 12.0,
                onTap: (_, __) {
                    setState(() {
                      _selectedDonationIndex = -1;
                      _routePoints = []; // Clear route when tapping map
                    });
                  },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=oyLqwKTDuilIERXSgG5B',
                ),
                PolylineLayer(
                    polylines: [
                      if (_routePoints.isNotEmpty)
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 4,
                          color: Colors.blue,
                        ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // Current location marker
                      if (widget.currentLocation != null)
                        Marker(
                          point: widget.currentLocation!,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blue, width: 2),
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 25,
                            ),
                          ),
                        ),
                    
                    
                    ...List.generate(donations.length, (index) {
                    final donation = donations[index].data() as Map<String, dynamic>;
                    return Marker(
                      point: LatLng(donation['latitude'], donation['longitude']),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                              setState(() => _selectedDonationIndex = index);
                              _showRouteToDonation(LatLng(donation['latitude'],donation['longitude']));
                            },
                        child: Icon(
                          Icons.dining,
                          color: _selectedDonationIndex == index ? Colors.red : Colors.green,
                          size: 35,
                        ),
                      ),
                    );
                  }),
                  ]
                ),
                
              ],
            ),
            if (_isLoadingRoute)
                const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Calculating route...'),
                        ],
                      ),
                    ),
                  ),
                ),
          if (_selectedDonationIndex != -1)
  Positioned(
    left: 16,
    right: 16,
    bottom: 16,
    child: InkWell(
      onTap: () {
        _showDonationDetails(context, donations[_selectedDonationIndex]);
      },
      child: Card(
  elevation: 8,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  color: Colors.white,
  child: Padding(
    padding: const EdgeInsets.all(10), // Reduced padding
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.fastfood, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (donations[_selectedDonationIndex].data() as Map<String, dynamic>)['foodName'],
                style: const TextStyle(
                  fontSize: 18, // Smaller font
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1, // Reduced max lines
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const Divider(),
        if (widget.currentLocation != null && _showdist > 0)
          Row(
            children: [
              Icon(Icons.directions, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                '${_showdist.toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Text(
                'More Info',
                style: const TextStyle(fontSize: 14, color: Colors.blue),
              ),
      ],
    ),
  ),
),
    ),
  ),
  
        ],
        
        
      );
}
),
floatingActionButton: widget.currentLocation != null ? FloatingActionButton(
        onPressed: () => _mapController.move(widget.currentLocation!, 13),
        child: const Icon(Icons.my_location),
      ) : null,
);

  }
}
void _showDonationDetails(BuildContext context, QueryDocumentSnapshot donation) {
    final data = donation.data() as Map<String, dynamic>;
    final requests = List<Map<String, dynamic>>.from(
      donation['recipients']?['requests'] ?? []
    );
    final hasRequested = requests.any(
      (r) => r['recipientId'] == userId,
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
                      style: TextStyle(fontSize: 16,color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasRequested ? Colors.grey : Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
        'recipientId': userId,
        'recipientEmail': emailId,
        'recipientName': usernamee,
        'timestamp': Timestamp.now(),
        'status': 'pending'
      };

      await donationRef.update({
        'recipients.requests': FieldValue.arrayUnion([recipientRequest])
      });

      await FirebaseFirestore.instance
          .collection('myRequests')
          .doc(userId)
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
