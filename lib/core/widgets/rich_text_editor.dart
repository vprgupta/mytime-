import 'package:flutter/material.dart';

class RichTextEditor extends StatefulWidget {
  final String? initialText;
  final Function(String)? onChanged;
  final String? hintText;

  const RichTextEditor({
    super.key,
    this.initialText,
    this.onChanged,
    this.hintText,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late TextEditingController _controller;
  bool _isBold = false;
  bool _isItalic = false;
  double _fontSize = 16.0;
  Color _textColor = Colors.black;
  bool _isBulletList = false;
  bool _isNumberedList = false;
  int _listCounter = 1;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _controller.addListener(() {
      widget.onChanged?.call(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleBold() {
    setState(() {
      _isBold = !_isBold;
    });
  }

  void _toggleItalic() {
    setState(() {
      _isItalic = !_isItalic;
    });
  }

  void _changeFontSize(double size) {
    setState(() {
      _fontSize = size;
    });
  }

  void _changeTextColor(Color color) {
    setState(() {
      _textColor = color;
    });
  }

  void _toggleBulletList() {
    setState(() {
      _isBulletList = !_isBulletList;
      if (_isBulletList) {
        _isNumberedList = false;
        _insertBulletPoint();
      }
    });
  }

  void _toggleNumberedList() {
    setState(() {
      _isNumberedList = !_isNumberedList;
      if (_isNumberedList) {
        _isBulletList = false;
        _listCounter = 1;
        _insertNumberedPoint();
      }
    });
  }

  void _insertBulletPoint() {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, '• ');
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: selection.start + 2);
  }

  void _insertNumberedPoint() {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, '$_listCounter. ');
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: selection.start + '$_listCounter. '.length);
    _listCounter++;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Bold
              _ToolbarButton(
                icon: Icons.format_bold,
                isActive: _isBold,
                onPressed: _toggleBold,
                tooltip: 'Bold',
              ),
              
              // Italic
              _ToolbarButton(
                icon: Icons.format_italic,
                isActive: _isItalic,
                onPressed: _toggleItalic,
                tooltip: 'Italic',
              ),
              
              // Font Size
              PopupMenuButton<double>(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 12.0, child: Text('Small (12)')),
                  const PopupMenuItem(value: 16.0, child: Text('Normal (16)')),
                  const PopupMenuItem(value: 20.0, child: Text('Large (20)')),
                ],
                onSelected: _changeFontSize,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_fontSize.toInt()}'),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
              
              // Text Color
              PopupMenuButton<Color>(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: Colors.black, child: _ColorOption(Colors.black, 'Black')),
                  const PopupMenuItem(value: Colors.red, child: _ColorOption(Colors.red, 'Red')),
                  const PopupMenuItem(value: Colors.blue, child: _ColorOption(Colors.blue, 'Blue')),
                  const PopupMenuItem(value: Colors.green, child: _ColorOption(Colors.green, 'Green')),
                  const PopupMenuItem(value: Colors.orange, child: _ColorOption(Colors.orange, 'Orange')),
                  const PopupMenuItem(value: Colors.purple, child: _ColorOption(Colors.purple, 'Purple')),
                ],
                onSelected: _changeTextColor,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _textColor,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
              
              // Bullet List
              _ToolbarButton(
                icon: Icons.format_list_bulleted,
                isActive: _isBulletList,
                onPressed: _toggleBulletList,
                tooltip: 'Bullet List',
              ),
              
              // Numbered List
              _ToolbarButton(
                icon: Icons.format_list_numbered,
                isActive: _isNumberedList,
                onPressed: _toggleNumberedList,
                tooltip: 'Numbered List',
              ),
            ],
          ),
        ),
        
        // Text Field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              style: TextStyle(
                fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                fontSize: _fontSize,
                color: _textColor,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'Start writing...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (text) {
                // Handle list continuation
                if (text.endsWith('\n')) {
                  if (_isBulletList) {
                    Future.delayed(Duration.zero, () => _insertBulletPoint());
                  } else if (_isNumberedList) {
                    Future.delayed(Duration.zero, () => _insertNumberedPoint());
                  }
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final String tooltip;

  const _ToolbarButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? Colors.blue.shade300 : Colors.grey.shade400,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final String name;

  const _ColorOption(this.color, this.name);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
        const SizedBox(width: 8),
        Text(name),
      ],
    );
  }
}