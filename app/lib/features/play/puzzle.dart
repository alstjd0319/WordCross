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

  String get levelLabel => PuzzleLevel.labelOf(level);

  /// 화면 제목. 예: beg-001 → 초급 #001
  String get title => puzzleTitle(id, level);
}

/// 난이도. DB `public.level` enum과 같은 이름.
enum PuzzleLevel {
  beginner('초급', 20),
  intermediate('중급', 26),
  advanced('고급', 38);

  const PuzzleLevel(this.label, this._secondsPerWord);

  final String label;

  /// 단어 하나에 드는 예상 시간(초). Figma v3 2-2 예시(초급 18단어 약 6분, 중급 28단어 약 12~13분,
  /// 고급 32단어 약 20분)에 맞춘 값이다. 풀이 기록이 쌓이면 실제 평균으로 바꾼다.
  final int _secondsPerWord;

  /// 단어 수로 어림한 풀이 시간(분). 최소 1분.
  int estimatedMinutes(int wordCount) => ((wordCount * _secondsPerWord) / 60).round().clamp(1, 999);

  static PuzzleLevel? parse(String value) {
    for (final l in values) {
      if (l.name == value) return l;
    }
    return null;
  }

  static String labelOf(String value) => parse(value)?.label ?? value;
}

/// 화면 제목. 예: beg-001 → 초급 #001
String puzzleTitle(String id, String level) {
  final label = PuzzleLevel.labelOf(level);
  final dash = id.lastIndexOf('-');
  return dash < 0 ? '$label $id' : '$label #${id.substring(dash + 1)}';
}

/// 퍼즐 목록에 쓰는 요약 정보. `puzzles` 테이블의 공개 열(정답 없음)과 같다.
class PuzzleSummary {
  const PuzzleSummary({
    required this.id,
    required this.level,
    required this.rows,
    required this.cols,
    required this.wordCount,
  });

  factory PuzzleSummary.fromJson(Map<String, dynamic> j) => PuzzleSummary(
        id: j['id'] as String,
        level: j['level'] as String,
        rows: (j['rows'] as num).toInt(),
        cols: (j['cols'] as num).toInt(),
        wordCount: (j['word_count'] as num? ?? 0).toInt(),
      );

  factory PuzzleSummary.of(PuzzleData p) =>
      PuzzleSummary(id: p.id, level: p.level, rows: p.rows, cols: p.cols, wordCount: p.clues.length);

  final String id;

  /// beginner / intermediate / advanced
  final String level;
  final int rows;
  final int cols;
  final int wordCount;

  PuzzleLevel? get puzzleLevel => PuzzleLevel.parse(level);
  String get title => puzzleTitle(id, level);

  /// 예: 13×13
  String get sizeLabel => '$rows×$cols';

  int? get estimatedMinutes => puzzleLevel?.estimatedMinutes(wordCount);

  /// 목록 정렬: 초급 → 중급 → 고급, 같은 난이도는 id 순.
  static int compare(PuzzleSummary a, PuzzleSummary b) {
    final la = a.puzzleLevel?.index ?? 99, lb = b.puzzleLevel?.index ?? 99;
    return la != lb ? la - lb : a.id.compareTo(b.id);
  }
}
