import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_task_page.dart';

class Task {
  String? id;
  String title;
  DateTime deadline;
  int orderId;

  Task({
    this.id,
    required this.title,
    required this.deadline,
    this.orderId = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'deadline': Timestamp.fromDate(deadline),
      'orderId': orderId,
    };
  }

  factory Task.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      deadline: (data['deadline'] as Timestamp).toDate(),
      orderId: data['orderId'] ?? 0,
    );
  }
}

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final CollectionReference _tasksCollection = FirebaseFirestore.instance.collection('tasks');
  List<Task> tasks = [];
  StreamSubscription? _subscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subscription = _tasksCollection
        .orderBy('orderId')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        tasks = snapshot.docs.map((doc) => Task.fromSnapshot(doc)).toList();
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _addTaskToFirebase(Task task) async {
    task.orderId = tasks.length;
    await _tasksCollection.add(task.toMap());
  }

  Future<void> _deleteTaskFromFirebase(String id) async {
    await _tasksCollection.doc(id).delete();
  }

  Future<void> _updateTaskOrder() async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task.orderId != i) {
        task.orderId = i;
        final docRef = _tasksCollection.doc(task.id);
        batch.update(docRef, {'orderId': i});
      }
    }
    await batch.commit();
  }

  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Delete Task", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to delete this task?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("No", style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Yes", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.png'),
        ),
        title: const Text("Tasks list"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : tasks.isEmpty
              ? const Center(child: Text("No tasks yet."))
              : ReorderableListView(
                  padding: const EdgeInsets.all(16),
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      borderRadius: BorderRadius.circular(12),
                      elevation: 6.0,
                      color: Colors.transparent,
                      child: child,
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final Task item = tasks.removeAt(oldIndex);
                      tasks.insert(newIndex, item);
                    });
                    _updateTaskOrder();
                  },
                  children: [
                    for (int index = 0; index < tasks.length; index++)
                      Dismissible(
                        key: Key(tasks[index].id!),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await _showDeleteConfirmationDialog();
                        },
                        onDismissed: (direction) {
                          _deleteTaskFromFirebase(tasks[index].id!);
                        },
                        child: Container(
                          key: ValueKey(tasks[index].id),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              tasks[index].title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                "Deadline: ${_formatDate(tasks[index].deadline)}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            trailing: const Icon(Icons.drag_handle, color: Colors.black26),
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTaskPage()),
          );

          if (result != null && result is Task) {
             final newTask = Task(
               title: result.title, 
               deadline: result.deadline,
             );
             _addTaskToFirebase(newTask);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}