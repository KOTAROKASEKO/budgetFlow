class Task {
  final String taskId;
  final String taskName;
  final DateTime dueDate;
  final String status;
  // Add other properties as needed from your JSON structure

  Task({
    required this.taskId,
    required this.taskName,
    required this.dueDate,
    this.status = 'pending',
  });
  //store local sql
  
}