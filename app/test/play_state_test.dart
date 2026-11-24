import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wordcross/features/play/attempt.dart';
import 'package:wordcross/features/play/play_state.dart';
import 'package:wordcross/features/play/puzzle.dart';

import 'fixtures/test_puzzles.dart';

/// 3×3, 가운데만 검은 칸.
///   1 . 2
///   . # .
///   3 . .
/// 가로: 1(0,0) 3(2,0) / 세로: 1(0,0) 2(0,2)
PuzzleData tinyPuzzle() => PuzzleData(
      id: 'test-001',
      level: 'beginner',
      rows: 3,
      cols: 3,
      blocks: {(1, 1)},
      clues: const [
        Clue(id: 4, no: 2, dir: Direction.down, row: 0, col: 2, length: 3, definitionEn: 'down two'),
        Clue(id: 1, no: 1, dir: Direction.across, row: 0, col: 0, length: 3, meaningKo: '가로 일', definitionEn: 'across one', exampleBlank: 'An _____.'),
        Clue(id: 3, no: 1, dir: Direction.down, row: 0, col: 0, length: 3),
        Clue(id: 2, no: 3, dir: Direction.across, row: 2, col: 0, length: 3, meaningKo: '가로 삼'),
      ],
    );

void main() {
  group('PuzzleData', () {
    test('단어를 가로 번호순, 세로 번호순으로 정렬하고 칸 번호를 매긴다', () {
      final p = tinyPuzzle();
      expect(p.clues.map((c) => '${c.no}${c.dir.name}'), ['1across', '3across', '1down', '2down']);
      expect(p.numberAt(0, 0), 1);
      expect(p.numberAt(0, 2), 2);
      expect(p.numberAt(2, 0), 3);
      expect(p.numberAt(0, 1), isNull);
      expect(p.clueAt(0, 1, Direction.across)!.no, 1);
      expect(p.clueAt(0, 1, Direction.down), isNull);
    });

    test('검은 칸에 걸친 단어는 거른다', () {
      expect(
        () => PuzzleData(
          id: 'bad',
          level: 'beginner',
          rows: 3,
          cols: 3,
          blocks: {(1, 1)},
          clues: const [Clue(id: 1, no: 1, dir: Direction.across, row: 1, col: 0, length: 3)],
        ),
        throwsFormatException,
      );
    });

    test('get_puzzle() 모양의 샘플 퍼즐을 읽는다', () {
      final p = PuzzleData.fromJson(jsonDecode(testPuzzles['beg-001']!) as Map<String, dynamic>);
      expect(p.rows, 11);
      expect(p.cols, 11);
      expect(p.clues, hasLength(24));
      expect(p.title, '초급 #001');
      expect(p.isBlock(0, 6), isTrue);
      expect(p.clues.first.meaningKo, isNotNull);
    });
  });

  group('칸 선택', () {
    test('첫 가로 단어의 첫 칸에서 시작한다', () {
      final s = PlayState.start(tinyPuzzle());
      expect((s.row, s.col, s.dir), (0, 0, Direction.across));
      expect(s.currentClue!.no, 1);
      expect(s.inCurrentWord(0, 2), isTrue);
      expect(s.inCurrentWord(2, 0), isFalse);
    });

    test('같은 칸을 다시 누르면 가로·세로가 바뀐다', () {
      final s = PlayState.start(tinyPuzzle()).tapCell(0, 0);
      expect(s.dir, Direction.down);
      expect(s.inCurrentWord(2, 0), isTrue);
      expect(s.tapCell(0, 0).dir, Direction.across);
    });

    test('한 방향 단어에만 속한 칸을 누르면 그 방향으로 바뀐다', () {
      final s = PlayState.start(tinyPuzzle()).tapCell(1, 0);
      expect((s.row, s.col, s.dir), (1, 0, Direction.down));
      // 세로 단어뿐인 칸은 다시 눌러도 방향이 그대로다.
      expect(s.tapCell(1, 0).dir, Direction.down);
    });

    test('검은 칸과 격자 밖은 눌러도 바뀌지 않는다', () {
      final s = PlayState.start(tinyPuzzle());
      expect(identical(s.tapCell(1, 1), s), isTrue);
      expect(identical(s.tapCell(5, 0), s), isTrue);
    });
  });

  group('글자 입력', () {
    test('넣으면 대문자로 저장하고 다음 칸으로, 단어 끝에서는 멈춘다', () {
      var s = PlayState.start(tinyPuzzle());
      s = s.typeLetter('c').typeLetter('a');
      expect(s.letterAt(0, 0), 'C');
      expect(s.letterAt(0, 1), 'A');
      expect((s.row, s.col), (0, 2));
      s = s.typeLetter('t').typeLetter('s');
      expect(s.letterAt(0, 2), 'S');
      expect((s.row, s.col), (0, 2));
    });

    test('영문자가 아니면 무시한다', () {
      final s = PlayState.start(tinyPuzzle());
      expect(identical(s.typeLetter('1'), s), isTrue);
      expect(identical(s.typeLetter('가'), s), isTrue);
      expect(identical(s.typeLetter('ab'), s), isTrue);
    });

    test('지우기: 글자가 있으면 그 칸을, 비었으면 앞 칸으로 가서 지운다', () {
      var s = PlayState.start(tinyPuzzle()).typeLetter('C').typeLetter('A');
      expect((s.row, s.col), (0, 2));
      s = s.backspace();
      expect((s.row, s.col), (0, 1));
      expect(s.letterAt(0, 1), isNull);
      expect(s.letterAt(0, 0), 'C');
      s = s.backspace().backspace();
      expect((s.row, s.col), (0, 0));
      expect(s.letters, isEmpty);
    });

    test('교차하는 칸의 글자는 두 단어가 함께 쓴다', () {
      final s = PlayState.start(tinyPuzzle()).typeLetter('C').typeLetter('A').typeLetter('T');
      expect(s.isWordFilled(s.puzzle.clues[0]), isTrue);
      expect(s.guessFor(s.puzzle.clues[0]), 'CAT');
      expect(s.guessFor(s.puzzle.clues[1]), isNull);
      expect(s.doneWordCount, 0); // 채우기만 해서는 맞힌 단어가 아니다
      final down = s.tapCell(0, 2);
      expect(down.dir, Direction.down);
      expect(down.letterAt(0, 2), 'T');
    });
  });

  group('단어 이동', () {
    test('다음 단어: 가로 다음 세로, 끝에서 처음으로', () {
      var s = PlayState.start(tinyPuzzle());
      final order = <String>[];
      for (var i = 0; i < 5; i++) {
        order.add('${s.currentClue!.no}${s.dir.label}');
        s = s.nextClue();
      }
      expect(order, ['1가로', '3가로', '1세로', '2세로', '1가로']);
      expect(PlayState.start(tinyPuzzle()).previousClue().currentClue!.no, 2);
    });

    test('단어로 옮기면 첫 빈칸에 선다', () {
      final s = PlayState.start(tinyPuzzle()).typeLetter('C').nextClue().nextClue();
      // 1세로의 첫 칸(0,0)은 이미 C가 있다.
      expect((s.row, s.col, s.dir), (1, 0, Direction.down));
    });

    test('화살표: 다른 축이면 방향부터 바꾸고, 같은 축이면 검은 칸을 건너뛴다', () {
      var s = PlayState.start(tinyPuzzle()).moveCursor(1, 0);
      expect((s.row, s.col, s.dir), (0, 0, Direction.down));
      s = s.moveCursor(1, 0);
      expect((s.row, s.col), (1, 0));
      s = s.moveCursor(0, 1);
      expect((s.row, s.col, s.dir), (1, 2, Direction.down));
    });
  });

  group('맞힌 단어 잠금', () {
    // 1가로 CAT을 맞힌 상태. (0,0) (0,1) (0,2)가 잠긴다.
    PlayState solved() => PlayState.start(tinyPuzzle()).applyProgress(const [
          WordProgress(clueId: 1, solved: true, tries: 2, triesLeft: 3, score: 90, answer: 'cat'),
        ]);

    test('정답 글자를 채우고 칸을 잠그며 맞힌 수를 센다', () {
      final s = solved();
      expect([s.letterAt(0, 0), s.letterAt(0, 1), s.letterAt(0, 2)], ['C', 'A', 'T']);
      expect(s.isLocked(0, 2), isTrue);
      expect(s.isLocked(2, 0), isFalse);
      expect((s.doneWordCount, s.remainingWordCount), (1, 3));
      expect(s.progressOf(s.puzzle.clues[0]).score, 90);
    });

    test('입력해 둔 틀린 글자도 정답으로 바뀐다', () {
      final s = PlayState.start(tinyPuzzle()).typeLetter('X').applyProgress(const [
        WordProgress(clueId: 1, solved: true, answer: 'CAT'),
      ]);
      expect(s.letterAt(0, 0), 'C');
    });

    test('잠긴 칸은 다른 글자로 바뀌지 않고, 그 글자는 다음 칸에 들어간다', () {
      final s = solved().tapCell(0, 0); // 1세로, 첫 칸 C가 잠김
      expect(s.dir, Direction.down);
      final typed = s.typeLetter('O');
      expect((typed.letterAt(0, 0), typed.letterAt(1, 0)), ('C', 'O'));
      expect((typed.row, typed.col), (2, 0));
    });

    test('잠긴 글자를 그대로 치면 지나간다', () {
      final s = solved().tapCell(0, 0).typeLetter('C').typeLetter('O').typeLetter('W');
      expect([s.letterAt(0, 0), s.letterAt(1, 0), s.letterAt(2, 0)], ['C', 'O', 'W']);
    });

    test('다 잠긴 단어에서는 입력도 지우기도 되지 않는다', () {
      final s = solved();
      expect(identical(s.typeLetter('Z'), s), isTrue);
      expect(identical(s.backspace(), s), isTrue);
    });

    test('지우기는 잠긴 칸을 건너뛴다', () {
      var s = solved().tapCell(0, 0).typeLetter('O'); // (1,0)=O, 지금 칸 (2,0)
      s = s.backspace();
      expect((s.row, s.letterAt(1, 0)), (1, null));
      expect(identical(s.backspace(), s), isTrue); // 앞은 잠긴 C뿐
    });

    test('단어로 옮기면 빈칸, 없으면 잠기지 않은 칸에 선다', () {
      final s = solved().nextClue().nextClue(); // 1세로
      expect((s.row, s.col), (1, 0));
    });

    test('정답이 없거나 길이가 다른 응답은 글자를 바꾸지 않는다', () {
      final s = PlayState.start(tinyPuzzle()).applyProgress(const [
        WordProgress(clueId: 1, solved: true, answer: 'LONGER'),
        WordProgress(clueId: 2, solved: true),
      ]);
      expect(s.letters, isEmpty);
      expect(s.locked, isEmpty);
    });
  });

  group('힌트', () {
    test('있는 힌트만 차례로 바꾸고, 하나뿐이면 바꿀 수 없다', () {
      var s = PlayState.start(tinyPuzzle());
      expect(s.shownHintKind, HintKind.meaningKo);
      expect(s.nextHintKind, HintKind.definitionEn);
      s = s.cycleHint();
      expect(s.shownHintKind, HintKind.definitionEn);
      s = s.cycleHint().cycleHint();
      expect(s.shownHintKind, HintKind.meaningKo);

      final only = s.nextClue(); // 3가로: 한국어 뜻만 있음
      expect(only.shownHintKind, HintKind.meaningKo);
      expect(only.nextHintKind, isNull);
    });

    test('고른 힌트 종류가 없는 단어는 있는 것을 보여 주고, 힌트가 없으면 null', () {
      final s = PlayState.start(tinyPuzzle()).cycleHint(); // 영어 정의
      expect(s.nextClue().shownHintKind, HintKind.meaningKo); // 3가로에는 영어 정의가 없음
      expect(s.nextClue().nextClue().shownHintKind, isNull); // 1세로에는 힌트가 없음
      expect(s.previousClue().shownHintKind, HintKind.definitionEn); // 2세로
    });
  });
}
