/// 퍼즐 데이터. Supabase `get_puzzle()` RPC가 돌려주는 JSON과 같은 모양이다.
/// 정답 철자는 들어 있지 않다 (정답 확인은 3주차 RPC가 한다).
library;

enum Direction {
  across('가로'),
  down('세로');

  const Direction(this.label);

  final String label;

  Direction get other => this == across ? down : across;

  static Direction parse(Object? v) => switch (v) {
        'across' => across,
        'down' => down,
        _ => throw FormatException('알 수 없는 방향: $v'),
      };
}

/// 힌트 종류. 한국어·영어 힌트는 마음껏 바꿔 볼 수 있다 (기획서 8장).
enum HintKind {
  meaningKo('한국어 뜻', '뜻'),
  definitionEn('영어 정의', '영어'),
  example('예문 빈칸', '예문');

  const HintKind(this.label, this.shortLabel);

  final String label;

  /// 전환 버튼에 쓰는 짧은 이름.
  final String shortLabel;
}

class Clue {
  const Clue({
    required this.id,
    required this.no,
    required this.dir,
    required this.row,
    required this.col,
    required this.length,
    this.meaningKo,
    this.definitionEn,
    this.exampleBlank,
  });

  factory Clue.fromJson(Map<String, dynamic> j) => Clue(
        id: (j['id'] as num).toInt(),
        no: (j['no'] as num).toInt(),
        dir: Direction.parse(j['dir']),
        row: (j['row'] as num).toInt(),
        col: (j['col'] as num).toInt(),
        length: (j['length'] as num).toInt(),
        meaningKo: _text(j['meaning_ko']),
        definitionEn: _text(j['definition_en']),
        exampleBlank: _text(j['example_blank']),
      );

  /// puzzle_words.id. 3주차 정답 확인 RPC에 넘긴다.
  final int id;
  final int no;
  final Direction dir;
  final int row;
  final int col;
  final int length;
  final String? meaningKo;
  final String? definitionEn;
  final String? exampleBlank;

  /// 단어가 차지하는 칸 (행, 열) 차례대로.
  List<(int, int)> get cells => [
        for (var i = 0; i < length; i++) dir == Direction.across ? (row, col + i) : (row + i, col),
      ];

  String? hint(HintKind kind) => switch (kind) {
        HintKind.meaningKo => meaningKo,
        HintKind.definitionEn => definitionEn,
        HintKind.example => exampleBlank,
      };

  /// 이 단어에 있는 힌트 종류.
  List<HintKind> get hintKinds => [for (final k in HintKind.values) if (hint(k) != null) k];

  static String? _text(Object? v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}

class PuzzleData {
  PuzzleData({
    required this.id,
    required this.level,
    required this.rows,
    required this.cols,
    required Set<(int, int)> blocks,
    required List<Clue> clues,
  })  : blocks = Set.unmodifiable(blocks),
        clues = List<Clue>.unmodifiable(<Clue>[...clues]..sort(_clueOrder)) {
    for (final c in this.clues) {
      for (final cell in c.cells) {
        final (r, col) = cell;
        if (r < 0 || r >= rows || col < 0 || col >= cols || this.blocks.contains(cell)) {
          throw FormatException('${c.no}${c.dir.label} 단어가 격자 밖이나 검은 칸에 걸려 있어요.');
        }
        (c.dir == Direction.across ? _across : _down)[cell] = c;
      }
      _numbers[(c.row, c.col)] = c.no;
    }
  }

  factory PuzzleData.fromJson(Map<String, dynamic> j) => PuzzleData(
        id: j['id'] as String,
        level: j['level'] as String,
        rows: (j['rows'] as num).toInt(),
        cols: (j['cols'] as num).toInt(),
        blocks: {
          for (final b in (j['blocks'] as List? ?? const []).cast<List>()) ((b[0] as num).toInt(), (b[1] as num).toInt()),
        },
        clues: [for (final c in (j['clues'] as List? ?? const []).cast<Map>()) Clue.fromJson(c.cast<String, dynamic>())],
      );

  final String id;

  /// beginner / intermediate / advanced
  final String level;
  final int rows;
  final int cols;
  final Set<(int, int)> blocks;

  /// 가로 단어를 번호순으로, 그다음 세로 단어를 번호순으로.
  final List<Clue> clues;

  final _across = <(int, int), Clue>{};
  final _down = <(int, int), Clue>{};
  final _numbers = <(int, int), int>{};

  static int _clueOrder(Clue a, Clue b) => a.dir != b.dir ? a.dir.index - b.dir.index : a.no - b.no;

  bool isBlock(int row, int col) => blocks.contains((row, col));

  /// 칸 왼쪽 위에 적는 번호. 없으면 null.
  int? numberAt(int row, int col) => _numbers[(row, col)];

  /// 이 칸을 지나는 [dir] 방향 단어.
  Clue? clueAt(int row, int col, Direction dir) => (dir == Direction.across ? _across : _down)[(row, col)];

  String get levelLabel => switch (level) {
        'beginner' => '초급',
        'intermediate' => '중급',
        'advanced' => '고급',
        _ => level,
      };

  /// 화면 제목. 예: beg-001 → 초급 #001
  String get title {
    final dash = id.lastIndexOf('-');
    return dash < 0 ? '$levelLabel $id' : '$levelLabel #${id.substring(dash + 1)}';
  }
}
