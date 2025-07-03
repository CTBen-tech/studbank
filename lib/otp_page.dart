import 'package:flutter/material.dart';

class OtpPage extends StatelessWidget {
  const OtpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter OTP')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter the 5-digit OTP sent to your phone',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Container(
                  width: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Handle OTP verification
              },
              child: const Text('Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
