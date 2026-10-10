import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../models.dart';

/// Pick a picture from the gallery and keep it in the app. When [studentId] is set
/// (or chosen in the dialog) the routine also shows up inside that student's profile.
Future<void> addRoutineFromGallery(BuildContext context, WidgetRef ref, {String studentId = ''}) async {
  final x = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 1800, maxHeight: 1800, imageQuality: 80);
  if (x == null || !context.mounted) return;
  final bytes = await x.readAsBytes();
  if (!context.mounted) return;
  final repo = ref.read(repoProvider);
  final title = TextEditingController();
  var student = studentId;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('Routine'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: title, autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Class routine, Exam routine'),
        ),
        const SizedBox(height: 12),
        if (studentId.isEmpty)
          DropdownButtonFormField<String>(
            initialValue: student,
            decoration: const InputDecoration(
                labelText: 'For student (optional)',
                helperText: 'It will also appear in that student\'s profile'),
            items: [
              const DropdownMenuItem(value: '', child: Text('— everyone / general —')),
              ...repo.studentList.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
            ],
            onChanged: (v) => setS(() => student = v ?? ''),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    )),
  );
  final name = title.text.trim();
  title.dispose();
  if (ok != true) return;
  await repo.saveRoutine(Routine(
      id: newId(), title: name.isEmpty ? 'Routine' : name, image: base64Encode(bytes),
      createdAt: DateTime.now(), studentId: student));
}

/// Full-screen, zoomable view of a routine picture.
class RoutineViewer extends StatelessWidget {
  const RoutineViewer({super.key, required this.routine});
  final Routine routine;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(routine.title),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 1, maxScale: 6,
            child: Image.memory(base64Decode(routine.image)),
          ),
        ),
      );
}

/// Routine pictures (class routine, exam routine, timetable…) picked from the
/// gallery and kept inside the app.
class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  Future<String?> _askTitle(BuildContext context, String label, String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Routines')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.routinesL, repo.studentsL]),
          builder: (context, _) {
            final items = repo.routineList;
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.photo_library_outlined,
                message: 'No routine pictures yet.\nPick one from your gallery.',
                cta: 'Add from gallery',
                onCta: () => addRoutineFromGallery(context, ref),
              );
            }
            return GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: items.map((r) {
                final who = r.studentId.isEmpty ? null : repo.student(r.studentId)?.name;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => RoutineViewer(routine: r))),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: Image.memory(base64Decode(r.image), fit: BoxFit.cover,
                          gaplessPlayback: true)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (who != null)
                              Text(who, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
                          ])),
                          PopupMenuButton<String>(
                            iconSize: 20,
                            onSelected: (v) async {
                              if (v == 'rename') {
                                final t = await _askTitle(context, 'Rename', r.title);
                                if (t != null && t.isNotEmpty) {
                                  await repo.saveRoutine(Routine(id: r.id, title: t, image: r.image,
                                      createdAt: r.createdAt, studentId: r.studentId));
                                }
                              } else if (v == 'student') {
                                if (!context.mounted) return;
                                final id = await _pickStudent(context, repo, r.studentId);
                                if (id != null) {
                                  await repo.saveRoutine(Routine(id: r.id, title: r.title, image: r.image,
                                      createdAt: r.createdAt, studentId: id));
                                }
                              } else {
                                await repo.deleteRoutine(r.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'rename', child: Text('Rename')),
                              PopupMenuItem(value: 'student', child: Text('Link to student')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ]),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addRoutine',
        onPressed: () => addRoutineFromGallery(context, ref),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add'),
      ),
    );
  }

  Future<String?> _pickStudent(BuildContext context, Repo repo, String current) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Everyone / general'),
            trailing: current.isEmpty ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final s in repo.studentList)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(s.name),
              trailing: s.id == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, s.id),
            ),
        ]),
      )),
    );
  }
}
