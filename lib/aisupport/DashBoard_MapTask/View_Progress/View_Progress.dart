import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/ViewModel_DashBoard.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:provider/provider.dart';

class CompletedTasksScreen extends StatefulWidget {
  const CompletedTasksScreen({super.key});

  @override
  State<CompletedTasksScreen> createState() => _CompletedTasksScreenState();
}

class _CompletedTasksScreenState extends State<CompletedTasksScreen> {
  late Future<List<TaskHiveModel>> _completedTasksFuture;

  @override
  void initState() {
    super.initState();
    // ViewModelから完了済みタスクを取得する
    _completedTasksFuture = context.read<AIFinanceViewModel>().fetchAllCompletedTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 30, 30, 30),
      appBar: AppBar(
        title: const Text('Completed Tasks'),
        backgroundColor: Colors.black.withOpacity(0.6),
      ),
      body: FutureBuilder<List<TaskHiveModel>>(
        future: _completedTasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No completed tasks yet.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            );
          }

          final completedTasks = snapshot.data!;
          return ListView.builder(
            itemCount: completedTasks.length,
            itemBuilder: (context, index) {
              final task = completedTasks[index];
              String formattedDate = task.dueDate != null
                  ? DateFormat('MMMM d, yyyy').format(task.dueDate!)
                  : 'No date';
              return Card(
                color: const Color(0xFF2A2A2A),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.greenAccent),
                  title: Text(task.title, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Completed on: $formattedDate',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}