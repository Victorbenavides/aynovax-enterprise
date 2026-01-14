import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
// Asegúrate de que esta ruta coincida con la tuya:
import 'package:frontend/src/services/api_service.dart';

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  // Estado
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

  // --- LÓGICA PRINCIPAL (CORREGIDA) ---

  // 1. ESTA ES LA FUNCIÓN MÁGICA QUE TE FALTABA
  // Se encarga de cambiar el documento Y recuperar su chat de la base de datos.
  void _selectDocument(Map<String, dynamic> doc) async {
    setState(() {
      _selectedDoc = doc;
      _isLoadingDocs = true; 
    });

    try {
      // <--- AQUÍ PEDIMOS LA MEMORIA AL BACKEND
      final history = await ApiService.getChatHistory(doc['id']);

      if (mounted) {
        setState(() {
          _messages.clear(); // Limpiamos la pantalla visualmente...
          
          if (history.isEmpty) {
            // Si es nuevo, saludamos
            _messages.add({"role": "ai", "text": "Context loaded: ${doc['filename']}."});
          } else {
            // <--- ¡SI HAY HISTORIA, LA PONEMOS!
            _messages.addAll(history);
          }
          _isLoadingDocs = false;
        });
        
        // Esperamos un microsegundo para que la lista se renderice y bajamos el scroll
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      print("Error recuperando historial: $e");
      setState(() => _isLoadingDocs = false);
    }
  }

  Future<void> _loadDocuments() async {
    final docs = await ApiService.getDocuments();
    setState(() {
      _documents = docs;
    });
      
    // Si hay documentos y no hemos seleccionado uno, cargamos el primero CON SU HISTORIA
    if (_selectedDoc == null && _documents.isNotEmpty) {
      _selectDocument(_documents.first);
    } else {
      setState(() => _isLoadingDocs = false);
    }
  }

  Future<void> _uploadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'], withData: true,
    );

    if (result != null) {
      _showSnack("Procesando documento...", isError: false);
      try {
        final res = await ApiService.uploadDocument(result.files.first);
        await _loadDocuments(); 
        
        // Al subir, cambiamos a ese documento inmediatamente
        final newDoc = _documents.firstWhere((d) => d['id'] == res['db_id']);
        _selectDocument(newDoc);
        
        _showSnack("¡Documento listo!", isError: false);
      } catch (e) {
        _showSnack("Error al subir: $e", isError: true);
      }
    }
  }

  Future<void> _deleteCurrentDoc() async {
    if (_selectedDoc == null) return;
    
    await ApiService.deleteDocument(_selectedDoc!['id']);
    _showSnack("Documento eliminado.", isError: false);
    
    setState(() {
      _selectedDoc = null;
      _messages.clear();
    });
    
    await _loadDocuments();
  }

  Future<void> _resetChatHistory() async {
    if (_selectedDoc == null) return;
    await ApiService.clearChatHistory(_selectedDoc!['id']);
    setState(() {
      _messages.clear();
      _messages.add({"role": "ai", "text": "Memoria reiniciada."});
    });
  }

  void _sendMessage() async {
    if (_textController.text.trim().isEmpty || _selectedDoc == null) return;

    final query = _textController.text;
    _textController.clear();

    setState(() {
      _messages.add({"role": "user", "text": query});
      _messages.add({"role": "ai", "text": ""}); 
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
      _messages.last['text'] = "Error de conexión: $e";
    } finally {
      setState(() => _isTyping = false);
    }
  }

  // --- UI HELPERS ---

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60, // +60 para asegurar que se vea lo último
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
            tooltip: "Reiniciar Chat",
            onPressed: _resetChatHistory
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
            tooltip: "Borrar Archivo",
            onPressed: _deleteCurrentDoc
          ),
        ] : [],
      ),
      // 2. SIDEBAR (Drawer) - AQUÍ ESTABA EL ERROR
      drawer: Drawer(
        backgroundColor: surface,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF28292A)),
              accountName: const Text("Usuario Activo"),
              accountEmail: const Text("Enterprise Access"),
              currentAccountPicture: CircleAvatar(backgroundColor: primary, child: const Icon(Icons.person, color: Colors.black)),
            ),
            ListTile(
              leading: Icon(Icons.add, color: primary),
              title: Text("Subir Nuevo PDF", style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
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
                        
                        // <--- ESTA ES LA PARTE IMPORTANTE QUE CORREGIMOS
                        onTap: () {
                          Navigator.pop(context); // Cierra menú
                          _selectDocument(doc);   // <--- LLAMA A LA FUNCIÓN QUE TRAE EL HISTORIAL
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      // 3. CUERPO DEL CHAT
      body: _selectedDoc == null 
        ? Center(child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Icon(Icons.auto_awesome_motion, size: 60, color: Colors.grey[800]),
              const SizedBox(height: 15),
              const Text("Selecciona un documento del menú", style: TextStyle(color: Colors.grey))
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
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF28292A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser) ...[
                                Row(children: [
                                  Icon(Icons.auto_awesome, size: 14, color: primary),
                                  const SizedBox(width: 8),
                                  Text("AynovaX", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))
                                ]),
                                const SizedBox(height: 8),
                              ],
                              MarkdownBody(
                                data: msg['text'] ?? "",
                                selectable: true, 
                                styleSheet: MarkdownStyleSheet(
                                  p: GoogleFonts.inter(color: Colors.white, fontSize: 15, height: 1.5),
                                  strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  code: const TextStyle(backgroundColor: Color(0xFF131314), fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_isTyping) const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
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
                          hintText: "Pregunta algo...",
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