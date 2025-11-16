import 'package:flutter/material.dart';
import 'add_task_page.dart';

class TaskListPage extends StatefulWidget{
  const TaskListPage({super.key});

  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  // lista de task-uri
  List<String> tasks = [];

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tasks list"),
      ),

      // ListView pentru a afisa lista
      body: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(tasks[index]),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTask = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTaskPage()),
          );

          // dacă pagina AddTaskPage trimite un task înapoi, il adaugam
          if (newTask != null && newTask is String) {
            setState(() {
              tasks.add(newTask);
            });
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}