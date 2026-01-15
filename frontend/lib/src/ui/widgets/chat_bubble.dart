// File: lib/src/ui/widgets/chat_bubble.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard functionality
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatBubble extends StatelessWidget {
  final String role; // 'user' or 'ai'
  final String text;

  const ChatBubble({
    super.key, 
    required this.role, 
    required this.text
  });

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    final primaryColor = const Color(0xFF8AB4F8); // Google Blue
    final userBg = const Color(0xFF28292A);       // Soft Dark Grey
    
    // Alignment: User to the right, AI to the left
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        // Constrain width so it doesn't take up the full screen
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        margin: const EdgeInsets.only(bottom: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            // 1. AI AVATAR (Only if not user)
            if (!isUser) 
              Container(
                margin: const EdgeInsets.only(right: 12, top: 2),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.transparent,
                  child: Icon(Icons.auto_awesome, color: primaryColor, size: 18),
                ),
              ),

            // 2. TEXT BOX (Flexible for long text)
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? userBg : Colors.transparent,
                  // Modern rounded borders
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                    bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                  ),
                  border: isUser ? null : Border.all(color: Colors.white12), // Subtle border for AI
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Small "AynovaX" label above AI text
                    if (!isUser)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text("AynovaX", 
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor
                          )
                        ),
                      ),

                    // MESSAGE CONTENT (Markdown)
                    MarkdownBody(
                      data: text,
                      selectable: true, 
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.inter(color: Colors.white, fontSize: 15, height: 1.5),
                        strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        code: GoogleFonts.firaCode(
                          backgroundColor: const Color(0xFF131314), 
                          fontSize: 13,
                          color: const Color(0xFFFFCC00) // Yellow for code
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFF131314),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24)
                        ),
                      ),
                    ),
                    
                    // 3. ACTION BAR (Copy Button)
                    if (!isUser && text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white10),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Text copied to clipboard"),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            )
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 14, color: Colors.grey[400]),
                              const SizedBox(width: 6),
                              Text("Copy", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}