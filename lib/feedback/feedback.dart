import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:moneymanager/themeColor.dart';

class FeedbackForm extends StatefulWidget {
  const FeedbackForm({super.key});

  @override
  _FeedbackFormState createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  final _formKey = GlobalKey<FormState>();
  String? _feedbackType;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  double _rating = 0; // 0 means no rating selected initially

  final List<String> _feedbackTypes = ['Bug Report', 'Feature Request', 'General Feedback', 'Compliment'];
  final List<IconData> _feedbackTypeIcons = [Icons.bug_report_outlined, Icons.lightbulb_outline, Icons.comment_outlined, Icons.thumb_up_alt_outlined];

  @override
  void dispose() {
    _subjectController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    if (_formKey.currentState!.validate()) {
      if (_rating == 0 && _feedbackType != 'Compliment') { // Make rating optional for compliments
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please provide a rating to submit your feedback.'),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20), // Adjust margin if needed
          ),
        );
        return;
      }
      // Form is valid, process the feedback
      String feedbackData = "Feedback Type: ${_feedbackType ?? 'Not selected'}\n"
          "Subject: ${_subjectController.text.isNotEmpty ? _subjectController.text : 'N/A'}\n"
          "Details: ${_detailsController.text}\n"
          "Rating: $_rating stars";

      print("--- Feedback Submitted ---");
      print(feedbackData);
      print("--------------------------");

      // Here you would typically send the data to your backend (e.g., Firestore)
      // For example:
      FirebaseFirestore.instance.collection('feedback').add({
        'type': _feedbackType,
        'subject': _subjectController.text,
        'details': _detailsController.text,
        'rating': _rating,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid, // If applicable
      });

      Navigator.pop(context); // Close the modal sheet

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Thank you for your feedback!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
           margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // This padding adjusts for the keyboard when it appears.
    // It's applied to the main container of the modal.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor, // Or your preferred dark theme background
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView( // Changed to ListView for better scrollability with keyboard
            shrinkWrap: true,
            children: <Widget>[
              // Drag Handle
              Center(
                child: Container(
                  width: 45,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 15.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                'Share Your Feedback',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.apptheme_Black, // Use your theme color
                ),
              ),
              const SizedBox(height: 20),

              // Feedback Type Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Feedback Type',
                  prefixIcon: Icon(
                    _feedbackType == null
                        ? Icons.category_outlined
                        : _feedbackTypeIcons[_feedbackTypes.indexOf(_feedbackType!)],
                    color: theme.apptheme_Black,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.apptheme_Black, width: 2),
                     borderRadius: BorderRadius.circular(12)
                  ),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                ),
                value: _feedbackType,
                hint: const Text('Select type'),
                items: _feedbackTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        Icon(_feedbackTypeIcons[_feedbackTypes.indexOf(value)], color: Colors.grey[700], size: 20),
                        const SizedBox(width: 10),
                        Text(value),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _feedbackType = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a feedback type' : null,
              ),
              const SizedBox(height: 18),

              // Subject TextField (Optional)
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject (Optional)',
                  prefixIcon: Icon(Icons.short_text_rounded, color: theme.apptheme_Black),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                   focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.apptheme_Black, width: 2),
                     borderRadius: BorderRadius.circular(12)
                  ),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),

              // Details TextField
              TextFormField(
                controller: _detailsController,
                decoration: InputDecoration(
                  labelText: 'Details',
                  hintText: 'Please provide as much detail as possible...',
                  prefixIcon: Icon(Icons.notes_rounded, color: theme.apptheme_Black),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                   focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.apptheme_Black, width: 2),
                     borderRadius: BorderRadius.circular(12)
                  ),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                ),
                maxLines: 4,
                minLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter some details for your feedback.';
                  }
                  if (value.trim().length < 10) {
                    return 'Please provide at least 10 characters.';
                  }
                  return null;
                },
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 20),

              // Rating Stars
              Text(
                'Rate Your Experience (Optional for Compliments)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: index < _rating ? Colors.amber[600] : Colors.grey[400],
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1.0;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 25),

              // Submit Button
              ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 20),
                label: const Text('Submit Feedback', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.apptheme_Black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
                onPressed: _submitFeedback,
              ),
              const SizedBox(height: 10), // Extra space at the bottom
            ],
          ),
        ),
      ),
    );
  }
}
