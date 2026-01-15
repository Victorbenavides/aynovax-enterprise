import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/src/ui/widgets/typing_indicator.dart';

// --- IMPORTS ---
import 'package:frontend/src/services/api_service.dart';
// Import the new ChatBubble widget we created
import 'package:frontend/src/ui/widgets/chat_bubble.dart'; 

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  // --- STATE VARIABLES ---
  List<Map<String, dynamic>> _documents = [];
  Map<String, dynamic>? _selectedDoc;
  final List<Map<String, String>> _messages = [];
  
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isLoadingDocs = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  // --- LOGIC METHODS ---

  /// Selects a document and retrieves its specific chat history from the backend.
  void _selectDocument(Map<String, dynamic> doc) async {
    setState(() {
      _selectedDoc = doc;
      _isLoadingDocs = true; 
    });

    try {
      // Fetch history from API
      final history = await ApiService.getChatHistory(doc['id']);

      if (mounted) {
        setState(() {
          _messages.clear(); 
          
          if (history.isEmpty) {
            // Default welcome message for new documents
            _messages.add({"role": "ai", "text": "Context loaded: ${doc['filename']}."});
          } else {
            // Restore previous conversation
            _messages.addAll(history);
          }
          _isLoadingDocs = false;
        });
        
        // Scroll to bottom after frame render
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      print("Error retrieving history: $e");
      setState(() => _isLoadingDocs = false);
    }
  }

  /// Loads the list of available PDF documents from the database.
  Future<void> _loadDocuments() async {
    final docs = await ApiService.getDocuments();
    setState(() {
      _documents = docs;
    });
      
    // Auto-select the first document if none is selected
    if (_selectedDoc == null && _documents.isNotEmpty) {
      _selectDocument(_documents.first);
    } else {
      setState(() => _isLoadingDocs = false);
    }
  }

  /// Handles PDF file picking and uploading.
  Future<void> _uploadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'], withData: true,
    );

    if (result != null) {
      _showSnack("Processing document...", isError: false);
      try {
        final res = await ApiService.uploadDocument(result.files.first);
        await _loadDocuments(); 
        
        // Switch context to the new file immediately
        final newDoc = _documents.firstWhere((d) => d['id'] == res['db_id']);
        _selectDocument(newDoc);
        
        _showSnack("Document ready!", isError: false);
      } catch (e) {
        _showSnack("Upload failed: $e", isError: true);
      }
    }
  }

  /// Deletes the currently selected document and clears the view.
  Future<void> _deleteCurrentDoc() async {
    if (_selectedDoc == null) return;
    
    await ApiService.deleteDocument(_selectedDoc!['id']);
    _showSnack("Document deleted.", isError: false);
    
    setState(() {
      _selectedDoc = null;
      _messages.clear();
    });
    
    await _loadDocuments();
  }

  /// Clears chat memory but keeps the document.
  Future<void> _resetChatHistory() async {
    if (_selectedDoc == null) return;
    await ApiService.clearChatHistory(_selectedDoc!['id']);
    setState(() {
      _messages.clear();
      _messages.add({"role": "ai", "text": "Memory reset."});
    });
  }

  /// Sends the user query to the AI and handles streaming response.
  void _sendMessage() async {
    if (_textController.text.trim().isEmpty || _selectedDoc == null) return;

    final query = _textController.text;
    _textController.clear();

    setState(() {
      _messages.add({"role": "user", "text": query});
      _messages.add({"role": "ai", "text": ""}); // Placeholder for stream
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      await for (final chunk in ApiService.sendChatQueryStream(query, _selectedDoc!['id'])) {
        setState(() {
          _messages.last['text'] = (_messages.last['text'] ?? "") + chunk;
        });
        _scrollToBottom();
      }
    } catch (e) {
      _messages.last['text'] = "Connection error: $e";
    } finally {
      setState(() => _isTyping = false);
    }
  }

  // --- UI HELPERS ---

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60, 
        duration: const Duration(milliseconds: 200), 
        curve: Curves.easeOut
      );
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF8AB4F8),
      behavior: SnackBarBehavior.floating, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(20),
      duration: const Duration(seconds: 2),
    ));
  }

  // --- VISUAL BUILD ---

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    final bg = const Color(0xFF131314);
    final surface = const Color(0xFF1E1F20);
    final primary = const Color(0xFF8AB4F8);

    return Scaffold(
      backgroundColor: bg,
      
      // 1. APP BAR
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: Text(_selectedDoc?['filename'] ?? "AynovaX", style: GoogleFonts.inter(fontSize: 16)),
        actions: _selectedDoc != null ? [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined), 
            tooltip: "Reset Chat",
            onPressed: _resetChatHistory
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
            tooltip: "Delete File",
            onPressed: _deleteCurrentDoc
          ),
        ] : [],
      ),
      
      // 2. SIDEBAR (Drawer)
      drawer: Drawer(
        backgroundColor: surface,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF28292A)),
              accountName: const Text("Active User"),
              accountEmail: const Text("Enterprise Access"),
              currentAccountPicture: CircleAvatar(backgroundColor: primary, child: const Icon(Icons.person, color: Colors.black)),
            ),
            ListTile(
              leading: Icon(Icons.add, color: primary),
              title: Text("Upload New PDF", style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(context); _uploadPdf(); },
            ),
            const Divider(color: Colors.grey),
            Expanded(
              child: _isLoadingDocs 
                ? const Center(child: CircularProgressIndicator()) 
                : ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (ctx, i) {
                      final doc = _documents[i];
                      final isSelected = doc['id'] == _selectedDoc?['id'];
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: primary.withOpacity(0.1),
                        leading: const Icon(Icons.article_outlined, color: Colors.white70),
                        title: Text(doc['filename'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSelected ? primary : Colors.white70)),
                        
                        onTap: () {
                          Navigator.pop(context); 
                          _selectDocument(doc);   
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      
      // 3. MAIN BODY
      body: _selectedDoc == null 
        ? Center(child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Icon(Icons.auto_awesome_motion, size: 60, color: Colors.grey[800]),
              const SizedBox(height: 15),
              const Text("Select a document from the menu", style: TextStyle(color: Colors.grey))
            ]
          ))
        : Column(
            children: [
              Expanded(
                child: SelectionArea( 
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      
                      // --- REFACTORED: USING CHAT BUBBLE WIDGET ---
                      return ChatBubble(
                        role: msg['role'] ?? 'user',
                        text: msg['text'] ?? '',
                      );
                      // --------------------------------------------
                    },
                  ),
                ),
              ),
              
               if (_isTyping) 
                const Align(
                  alignment: Alignment.centerLeft,
                  child: TypingIndicator()
                ),
              
              // Input Area
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.withOpacity(0.3))
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Ask something...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: primary),
                      onPressed: _sendMessage,
                    )
                  ],
                ),
              )
            ],
          ),
    );
  }
}