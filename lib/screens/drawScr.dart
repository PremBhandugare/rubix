import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rubix/screens/donor/myDonScr.dart';
import 'package:rubix/screens/donor/reDonScr.dart';
import 'package:rubix/screens/recepient/myreqScr.dart';
import 'package:rubix/screens/recepient/reqScr.dart';

String? userId;
String? emailId;
String? usernamee;

class DrawerScreen extends StatefulWidget {
  @override
  _DrawerScreenState createState() => _DrawerScreenState();
}

class _DrawerScreenState extends State<DrawerScreen> {
  String fullName = 'Loading...';
  String email = '';
  String role = '';
  String emailID = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
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
            fullName = data['fullName'] ?? 'No Name';
            email = data['email'] ?? 'No Email';
            usernamee = data['fullName'] ?? 'No Name';
            emailId = data['email'] ?? 'No Email';
            role = 'donor';
            emailID = user.uid;
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
              fullName = data['fullName'] ?? 'No Name';
              email = data['email'] ?? 'No Email';
              usernamee = data['fullName'] ?? 'No Name';
              emailId = data['email'] ?? 'No Email';
              role = 'recepient';
            });
          } else {
            setState(() {
              fullName = 'No User Data';
              role = 'unknown';
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        fullName = 'Error loading data';
        role = 'unknown';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildUserHeader(),
          _buildCommonMenuItems(),
          if (role == 'recepient')
            _buildUserMenuItems()
          else if (role == 'donor')
            _buildInstituteMenuItems(),
          _buildSettingsAndLogout(),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return UserAccountsDrawerHeader(
      accountName: Text(
        fullName,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      accountEmail: Text(
        email,
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        child: Text(
          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 40.0,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        
      ),
    );
  }

  Widget _buildCommonMenuItems() {
    return ListTile(
      leading: Icon(Icons.home),
      title: Text('Home'),
      onTap: () {
        
        Navigator.pop(context);
      },
    );
  }

  Widget _buildUserMenuItems() {
    return Column(
      children: [
        ListTile(
      leading: Icon(Icons.add_shopping_cart),
      title: Text('My Requets'),
      onTap: () { 
          Navigator.of(context)
          .push(MaterialPageRoute(
            builder:(ctx)=>MyRequestsScreen(currentUserId: userId!)));   
      },
    ),
  ListTile(
      leading: Icon(Icons.add_shopping_cart),
      title: Text('Req'),
      onTap: () { 
          Navigator.of(context)
          .push(MaterialPageRoute(
            builder:
            (ctx)=>AvailableDonationsScreen(
              currentUserId: userId!, 
              currentUserEmail: emailId!, 
              currentUserName: usernamee!
              )));   
      },
    )
      ],
    );
  }

  Widget _buildInstituteMenuItems() {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.add_business),
          title: Text('Raise a Request'),
          onTap: () {
            
           Navigator.of(context)
           .push(MaterialPageRoute(
            builder:(ctx)=>DonationRequestScreen()));
            
           
          },
        ),
        ListTile(
      leading: Icon(Icons.add_shopping_cart),
      title: Text('My Contributions'),
      onTap: () {
        
          Navigator.of(context)
          .push(MaterialPageRoute(
            builder:(ctx)=>MyDonationsScreen(currentUserId: userId!,)));
        
        
      },
    )
        
      ],
    );
  }

  Widget _buildSettingsAndLogout() {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.settings),
          title: Text('Settings'),
          onTap: () {
           
            Navigator.pop(context);
           
          },
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.logout, color: Colors.red),
          title: Text('Logout', style: TextStyle(color: Colors.red)),
          onTap: () => _showLogoutDialog(),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pop();
                
              },
            ),
          ],
        );
      },
    );
  }
}