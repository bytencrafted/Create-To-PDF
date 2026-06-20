/// Ein Eintrag in der Importliste (Bild oder PDF).
///
/// Wichtig: [id] ist eine stabile, einmalige ID, die bei der Erstellung
/// vergeben wird. Sie wird für Widget-Keys in ReorderableListView/Dismissible
/// benutzt – NICHT der Listenindex. Index-basierte Keys brechen beim
/// Umsortieren und Wischen ("Dismissed widget still in tree").

enum ItemType { image, pdf }

class InputEntry {
  static int _seq = 0;

  final int id;
  final ItemType type;
  final String path;
  final String name;

  InputEntry(this.type, this.path, this.name) : id = _seq++;

  bool get isImage => type == ItemType.image;
  bool get isPdf => type == ItemType.pdf;
}