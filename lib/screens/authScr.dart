import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rubix/widgets/ctextf.dart';


final FirebaseAuth firebase = FirebaseAuth.instance;

class LoginScr extends StatefulWidget {
  const LoginScr({super.key});
  @override
  State<LoginScr> createState() => _LoginScrState();
}

class _LoginScrState extends State<LoginScr> {
  final recepCtlr = TextEditingController();
  final passCtlr = TextEditingController();
  final contCtlr = TextEditingController();
  final nameCtlr = TextEditingController();
  final donorNameCtlr = TextEditingController();
  final donorAddressCtlr = TextEditingController();
  
  bool islogin = false;
  bool isDonor = false;
  final formkey = GlobalKey<FormState>();
  
  String recepName = '';
  String passname = '';
  String contact = '';
  String name = '';
  String donorName = '';
  String donorAddress = '';
  bool isauthen = false;

  void submit() async {
    bool isvalid = formkey.currentState!.validate();
    if (!isvalid) {
      return;
    }
    if (!islogin && !isDonor && nameCtlr.text.isEmpty) {
      return;
    }
    if (!islogin && isDonor && donorNameCtlr.text.isEmpty) {
      return;
    }

    formkey.currentState!.save();
    
    if (islogin) {
      try {
        setState(() {
          isauthen = true;
        });
        final userCredentials = await firebase.signInWithEmailAndPassword(
          email: recepName,
          password: passname,
        );
        
        
        final userDoc = await FirebaseFirestore.instance
            .collection(isDonor ? 'donors' : 'recepients')
            .doc(userCredentials.user!.uid)
            .get();
            
        if (!userDoc.exists) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No ${isDonor ? 'donor' : 'recepient'} account found with this email.',
          );
        }
        
      } on FirebaseAuthException catch (e) {
        setState(() {
          isauthen = false;
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication failed.')),
        );
      }
    } else {
      try {
        setState(() {
          isauthen = true;
        });
        final userCredentials = await firebase.createUserWithEmailAndPassword(
          email: recepName,
          password: passname,
        );
        
        if (isDonor) {
         
          await FirebaseFirestore.instance
              .collection('donors')
              .doc(userCredentials.user!.uid)
              .set({
            'email': recepName,
            'fullName': donorName,
            'type': 'donor',
            'points': 0,
          });
        } else {
          // Store user data
          await FirebaseFirestore.instance
              .collection('recepients')
              .doc(userCredentials.user!.uid)
              .set({
            'email': recepName,
            'fullName': name,
            'type': 'recepient',
          });
        }
        
        setState(() {
          isauthen = false;
        });
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication failed.')),
        );
        setState(() {
          isauthen = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 25,),
              // Image.asset('assets/images/Logo.png',height: 80,),
              // const SizedBox(height: 10,),
              Text('FOOD Seva',style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),),
              Card(
              color: Theme.of(context).colorScheme.onError,
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
                child: Column(
                  children: [
                    Text(
                      islogin ? 'Login' : 'Register',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    
                    ToggleButtons(
                      isSelected: [!isDonor, isDonor],
                      onPressed: (index) {
                        setState(() {
                          isDonor = index == 1;
                        });
                      },
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Recepient'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Donor'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: formkey,
                      child: Column(
                        children: [
                          if (!islogin && !isDonor)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: TextFormField(
                                controller: nameCtlr,
                                decoration: customInputDecoration(hintText: 'Full name'),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Name should not be empty';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  name = value!;
                                },
                              ),
                            ),
                          if (!islogin && isDonor) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: TextFormField(
                                controller: donorNameCtlr,
                                decoration: customInputDecoration(hintText: 'Donor Name'),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Donor name should not be empty';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  donorName = value!;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                           
                          ],
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TextFormField(
                              controller: recepCtlr,
                              decoration: customInputDecoration(
                                hintText: 'Email',
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty ||
                                    !value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                recepName = value!;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TextFormField(
                              controller: passCtlr,
                              obscureText: true,
                              decoration: customInputDecoration(hintText: 'Password'),
                              validator: (value) {
                                if (value == null || value.trim().length < 8) {
                                  return 'Password must be 8 characters long';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                passname = value!;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          if (isauthen) const CircularProgressIndicator(),
                          if (!isauthen)
                            ElevatedButton(
                              onPressed: submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                              ),
                              child: Text(
                                islogin ? 'Sign in' : 'Sign up',
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          const SizedBox(height: 5),
                          if (!isauthen)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  islogin = !islogin;
                                });
                              },
                              child: Text(
                                islogin ? 'Create an account' : 'Already have an account',
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
            
          ),
        ),
      ),
    );
  }
}