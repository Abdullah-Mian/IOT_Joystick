// import 'package:flutter/material.dart';
// import '../services/auth_service.dart';

// class LoginScreen extends StatelessWidget {
//   final AuthService _authService = AuthService();

//   LoginScreen({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Login'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Center(
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const SizedBox(height: 5.0),
//                 const TextField(
//                   keyboardType: TextInputType.emailAddress,
//                   decoration: InputDecoration(
//                     border: OutlineInputBorder(),
//                     labelText: 'Email',
//                   ),
//                 ),
//                 const SizedBox(height: 16.0),
//                 const TextField(
//                   decoration: InputDecoration(
//                     border: OutlineInputBorder(),
//                     labelText: 'Password',
//                   ),
//                   obscureText: true,
//                 ),
//                 const SizedBox(height: 32.0),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     ElevatedButton(
//                       onPressed: () {
//                         // Add your sign in logic here
//                       },
//                       child: const Text('Sign In'),
//                     ),
//                     const SizedBox(width: 16.0),
//                     ElevatedButton(
//                       onPressed: () {
//                         // Add your create account logic here
//                       },
//                       child: const Text('Create Account'),
//                     ),
//                     const SizedBox(width: 16.0),
//                     ElevatedButton.icon(
//                       onPressed: () async {
//                         final userCredential =
//                             await _authService.signInWithGoogle();
//                         if (userCredential != null) {
//                           Navigator.pop(context);
//                         }
//                       },
//                       icon: const Icon(Icons.login),
//                       label: const Text('Sign in with Google'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
