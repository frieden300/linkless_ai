import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/folder.dart';
import '../data/repositories/folder_repository.dart';
import '../data/repositories/chat_repository.dart';
import 'chat_provider.dart';
import 'providers.dart';
import 'package:uuid/uuid.dart';

class FolderState {
  final List<Folder> folders;
  final bool isLoading;

  FolderState({required this.folders, this.isLoading = false});

  FolderState copyWith({List<Folder>? folders, bool? isLoading}) {
    return FolderState(
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FolderNotifier extends StateNotifier<FolderState> {
  final FolderRepository _repository;
  final ChatRepository _chatRepository;
  final Ref _ref;

  FolderNotifier(this._repository, this._chatRepository, this._ref)
    : super(FolderState(folders: [])) {
    loadFolders();
  }

  Future<void> loadFolders() async {
    state = state.copyWith(isLoading: true);
    final folders = await _repository.getAllFolders();
    state = state.copyWith(folders: folders, isLoading: false);
  }

  Future<void> createFolder(String name) async {
    final folder = Folder(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
    );
    await _repository.insertFolder(folder);
    await loadFolders();
  }

  Future<void> renameFolder(String id, String newName) async {
    final folder = state.folders.firstWhere((f) => f.id == id);
    final updatedFolder = Folder(
      id: folder.id,
      name: newName,
      createdAt: folder.createdAt,
    );
    await _repository.updateFolder(updatedFolder);
    await loadFolders();
  }

  Future<void> deleteFolder(String id) async {
    // Delete all chats in this folder first
    await _chatRepository.deleteConversationsInFolder(id);

    // Delete the folder itself
    await _repository.deleteFolder(id);

    // Refresh both folders and chat list
    await loadFolders();
    _ref.read(chatProvider.notifier).loadConversations();
  }
}

final folderProvider = StateNotifierProvider<FolderNotifier, FolderState>((
  ref,
) {
  return FolderNotifier(
    ref.watch(folderRepositoryProvider),
    ref.watch(chatRepositoryProvider),
    ref,
  );
});
