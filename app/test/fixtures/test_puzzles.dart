// 테스트 전용 퍼즐. 테스트가 특정 힌트·칸 위치를 확인하므로 data/ 가 바뀌어도 그대로 둔다.
// (2주차 당시 data/puzzles/beg-001.json 으로 만든 get_puzzle() 모양 JSON)

/// 퍼즐 id → get_puzzle() 응답 JSON.
const testPuzzles = <String, String>{
  'beg-001': _beg001,
};

const _beg001 = r'''
{
 "id": "beg-001",
 "level": "beginner",
 "rows": 11,
 "cols": 11,
 "template": "uk-11-03",
 "blocks": [
  [
   0,
   6
  ],
  [
   1,
   1
  ],
  [
   1,
   3
  ],
  [
   1,
   5
  ],
  [
   1,
   7
  ],
  [
   1,
   9
  ],
  [
   2,
   3
  ],
  [
   3,
   1
  ],
  [
   3,
   3
  ],
  [
   3,
   5
  ],
  [
   3,
   7
  ],
  [
   3,
   9
  ],
  [
   3,
   10
  ],
  [
   4,
   3
  ],
  [
   5,
   1
  ],
  [
   5,
   2
  ],
  [
   5,
   3
  ],
  [
   5,
   4
  ],
  [
   5,
   5
  ],
  [
   5,
   6
  ],
  [
   5,
   7
  ],
  [
   5,
   8
  ],
  [
   5,
   9
  ],
  [
   6,
   7
  ],
  [
   7,
   0
  ],
  [
   7,
   1
  ],
  [
   7,
   3
  ],
  [
   7,
   5
  ],
  [
   7,
   7
  ],
  [
   7,
   9
  ],
  [
   8,
   7
  ],
  [
   9,
   1
  ],
  [
   9,
   3
  ],
  [
   9,
   5
  ],
  [
   9,
   7
  ],
  [
   9,
   9
  ],
  [
   10,
   4
  ]
 ],
 "clues": [
  {
   "id": 1,
   "no": 1,
   "dir": "across",
   "row": 0,
   "col": 0,
   "length": 6,
   "meaning_ko": "나뭇가지, 가지",
   "definition_en": "The woody part of a tree arising from the trunk and usually dividing",
   "example_blank": "We decided to _____ out into selling some foodstuffs."
  },
  {
   "id": 2,
   "no": 4,
   "dir": "across",
   "row": 0,
   "col": 7,
   "length": 4,
   "meaning_ko": "쇼핑 센터",
   "definition_en": "very large building containing lots of stores and restaurants",
   "example_blank": "Is there a bus that goes to the _____?"
  },
  {
   "id": 3,
   "no": 8,
   "dir": "across",
   "row": 2,
   "col": 0,
   "length": 3,
   "meaning_ko": "체육관, 헬스장",
   "definition_en": "building with equipment you can use to exercise your body",
   "example_blank": "The students have an excellent _____ at their disposal."
  },
  {
   "id": 4,
   "no": 9,
   "dir": "across",
   "row": 2,
   "col": 4,
   "length": 7,
   "meaning_ko": "상상하다",
   "definition_en": "To form a mental image of something; to envision or create something in one's mind",
   "example_blank": "What do you _____ when you see that picture?"
  },
  {
   "id": 5,
   "no": 10,
   "dir": "across",
   "row": 4,
   "col": 0,
   "length": 3,
   "meaning_ko": "미술, 아트",
   "definition_en": "The conscious production or arrangement of sounds, colours, forms, movements, or other elements in a manner that affects the senses and emotions, usually specifically the production of the beautiful in a graphic or plastic medium",
   "example_blank": "It is important to be accomplished in some _____."
  },
  {
   "id": 6,
   "no": 11,
   "dir": "across",
   "row": 4,
   "col": 4,
   "length": 7,
   "meaning_ko": null,
   "definition_en": "the state of being healthy",
   "example_blank": "Tom's _____ has improved markedly under his new coach."
  },
  {
   "id": 7,
   "no": 13,
   "dir": "across",
   "row": 6,
   "col": 0,
   "length": 7,
   "meaning_ko": null,
   "definition_en": "to surround fully",
   "example_blank": "In accordance with your request, I _____ a picture of myself."
  },
  {
   "id": 8,
   "no": 17,
   "dir": "across",
   "row": 6,
   "col": 8,
   "length": 3,
   "meaning_ko": "그녀, 그",
   "definition_en": "The female (typically) person or animal previously mentioned or implied",
   "example_blank": "Whatever I do, _____ says I can do better."
  },
  {
   "id": 9,
   "no": 18,
   "dir": "across",
   "row": 8,
   "col": 0,
   "length": 7,
   "meaning_ko": "현재(現在)의, 출석하다",
   "definition_en": "Relating to now, for the time being; current",
   "example_blank": "I didn't expect such a nice _____ from you."
  },
  {
   "id": 10,
   "no": 19,
   "dir": "across",
   "row": 8,
   "col": 8,
   "length": 3,
   "meaning_ko": "행위, 행동",
   "definition_en": "Something done, a deed",
   "example_blank": "It is imperative for you to _____ at once."
  },
  {
   "id": 11,
   "no": 20,
   "dir": "across",
   "row": 10,
   "col": 0,
   "length": 4,
   "meaning_ko": "잡다, 쥐다",
   "definition_en": "To get into one's hands, possession, or control, with or without force",
   "example_blank": "It would _____ forever for me to explain everything."
  },
  {
   "id": 12,
   "no": 21,
   "dir": "across",
   "row": 10,
   "col": 5,
   "length": 6,
   "meaning_ko": "중개인, 브로커",
   "definition_en": "someone who buys and sells thing for a percentage of sales",
   "example_blank": "Tom is on the phone with his _____."
  },
  {
   "id": 13,
   "no": 1,
   "dir": "down",
   "row": 0,
   "col": 0,
   "length": 7,
   "meaning_ko": null,
   "definition_en": "travel bags",
   "example_blank": "To prevent hijacks, all carry-on _____ is carefully inspected."
  },
  {
   "id": 14,
   "no": 2,
   "dir": "down",
   "row": 0,
   "col": 2,
   "length": 5,
   "meaning_ko": "승인하다, 인정하다",
   "definition_en": "To allow to enter; to grant entrance (to), whether into a place, into the mind, or into consideration",
   "example_blank": "You must _____ that you are in the wrong."
  },
  {
   "id": 15,
   "no": 3,
   "dir": "down",
   "row": 0,
   "col": 4,
   "length": 5,
   "meaning_ko": "장",
   "definition_en": "The leader or head of a tribe, organisation, business unit, or other group",
   "example_blank": "The section _____ made me work like a slave."
  },
  {
   "id": 16,
   "no": 5,
   "dir": "down",
   "row": 0,
   "col": 8,
   "length": 5,
   "meaning_ko": null,
   "definition_en": "similar, almost the same",
   "example_blank": "Paul has three sons. They look very much _____."
  },
  {
   "id": 17,
   "no": 6,
   "dir": "down",
   "row": 0,
   "col": 10,
   "length": 3,
   "meaning_ko": "놓이다, 거짓말하다",
   "definition_en": "To rest in a horizontal position on a surface",
   "example_blank": "Tom said he was ill, which was a _____."
  },
  {
   "id": 18,
   "no": 7,
   "dir": "down",
   "row": 1,
   "col": 6,
   "length": 4,
   "meaning_ko": null,
   "definition_en": "take short sharp breaths through your mouth, noisily",
   "example_blank": "Tom's gone down two _____ sizes since he went vegan."
  },
  {
   "id": 19,
   "no": 12,
   "dir": "down",
   "row": 4,
   "col": 10,
   "length": 7,
   "meaning_ko": "스웨터, 쎄타",
   "definition_en": "a warm item of clothing worn over the arms and upper body, made of wool,",
   "example_blank": "I think I had better have my _____ mended."
  },
  {
   "id": 20,
   "no": 14,
   "dir": "down",
   "row": 6,
   "col": 2,
   "length": 5,
   "meaning_ko": "사무원, 서기",
   "definition_en": "someone who works at a counter",
   "example_blank": "I couldn't find a _____ to wait on me."
  },
  {
   "id": 21,
   "no": 15,
   "dir": "down",
   "row": 6,
   "col": 4,
   "length": 4,
   "meaning_ko": "오븐",
   "definition_en": "kitchen appliance used for baking or roasting",
   "example_blank": "The _____ in my house didn't run well today."
  },
  {
   "id": 22,
   "no": 16,
   "dir": "down",
   "row": 6,
   "col": 6,
   "length": 5,
   "meaning_ko": "들어가다, 들어오다",
   "definition_en": "To go or come into an enclosed or partially enclosed space",
   "example_blank": "Take off your hat when you _____ a classroom."
  },
  {
   "id": 23,
   "no": 17,
   "dir": "down",
   "row": 6,
   "col": 8,
   "length": 5,
   "meaning_ko": "무더기, 스택",
   "definition_en": "a pile of things placed one on top of the other",
   "example_blank": "Only one _____ had a real bill on top."
  },
  {
   "id": 24,
   "no": 18,
   "dir": "down",
   "row": 8,
   "col": 0,
   "length": 3,
   "meaning_ko": "애완동물, 반려동물",
   "definition_en": "an animal you keep in the house to play with",
   "example_blank": "How often is it necessary to feed your _____?"
  }
 ]
}
''';
