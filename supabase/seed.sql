-- Lango — starter content (small, high-quality dataset).
-- Run after 0001_initial_schema.sql.

insert into public.languages (code, name) values
  ('ko', 'Korean'),
  ('ja', 'Japanese')
on conflict (code) do nothing;

-- ── Korean vocabulary ────────────────────────────────────────────────────────
insert into public.vocabulary
  (language, word, romanization, translation, part_of_speech, difficulty, example_native, example_translation) values
  ('ko', '먹다', 'meokda', 'to eat', 'verb', 1, '밥을 먹다', 'to eat a meal'),
  ('ko', '가다', 'gada', 'to go', 'verb', 1, '학교에 가다', 'to go to school'),
  ('ko', '오다', 'oda', 'to come', 'verb', 1, '친구가 오다', 'a friend comes'),
  ('ko', '보다', 'boda', 'to see / to watch', 'verb', 1, '책을 보다', 'to look at a book'),
  ('ko', '하다', 'hada', 'to do', 'verb', 1, '공부를 하다', 'to do studying'),
  ('ko', '있다', 'itda', 'to exist / to have', 'verb', 1, '시간이 있다', 'to have time'),
  ('ko', '없다', 'eopda', 'to not exist / to not have', 'verb', 1, '시간이 없다', 'to not have time'),
  ('ko', '좋다', 'jota', 'to be good', 'adjective', 1, '날씨가 좋다', 'the weather is good'),
  ('ko', '크다', 'keuda', 'to be big', 'adjective', 1, '집이 크다', 'the house is big'),
  ('ko', '작다', 'jakda', 'to be small', 'adjective', 1, '집이 작다', 'the house is small'),
  ('ko', '물', 'mul', 'water', 'noun', 1, '물을 마셔요', 'I drink water'),
  ('ko', '밥', 'bap', 'rice / meal', 'noun', 1, '밥을 먹어요', 'I eat a meal'),
  ('ko', '집', 'jip', 'house / home', 'noun', 1, '집에 가요', 'I go home'),
  ('ko', '학교', 'hakgyo', 'school', 'noun', 1, '학교에 가요', 'I go to school'),
  ('ko', '친구', 'chingu', 'friend', 'noun', 1, '친구를 만나요', 'I meet a friend'),
  ('ko', '책', 'chaek', 'book', 'noun', 1, '책을 읽어요', 'I read a book'),
  ('ko', '사람', 'saram', 'person', 'noun', 1, '좋은 사람', 'a good person'),
  ('ko', '시간', 'sigan', 'time', 'noun', 1, '시간이 없어요', 'I have no time'),
  ('ko', '오늘', 'oneul', 'today', 'noun', 1, '오늘 뭐 해요?', 'What are you doing today?'),
  ('ko', '내일', 'naeil', 'tomorrow', 'noun', 1, '내일 만나요', 'See you tomorrow'),
  ('ko', '어제', 'eoje', 'yesterday', 'noun', 1, '어제 학교에 갔어요', 'I went to school yesterday'),
  ('ko', '안녕하세요', 'annyeonghaseyo', 'hello', 'expression', 1, null, null),
  ('ko', '감사합니다', 'gamsahamnida', 'thank you', 'expression', 1, null, null),
  ('ko', '네', 'ne', 'yes', 'expression', 1, null, null),
  ('ko', '아니요', 'aniyo', 'no', 'expression', 1, null, null),
  ('ko', '이름', 'ireum', 'name', 'noun', 1, '이름이 뭐예요?', 'What is your name?'),
  ('ko', '사랑', 'sarang', 'love', 'noun', 2, '사랑해요', 'I love you'),
  ('ko', '한국어', 'hangugeo', 'Korean language', 'noun', 1, '한국어를 공부해요', 'I study Korean'),
  ('ko', '일본어', 'ilboneo', 'Japanese language', 'noun', 1, '일본어를 공부해요', 'I study Japanese'),
  ('ko', '공부하다', 'gongbuhada', 'to study', 'verb', 1, '한국어를 공부하다', 'to study Korean')
on conflict (language, word, translation) do nothing;

-- ── Japanese vocabulary ──────────────────────────────────────────────────────
insert into public.vocabulary
  (language, word, romanization, translation, part_of_speech, difficulty, example_native, example_translation) values
  ('ja', '食べる', 'taberu', 'to eat', 'verb', 1, 'ご飯を食べる', 'to eat a meal'),
  ('ja', '行く', 'iku', 'to go', 'verb', 1, '学校に行く', 'to go to school'),
  ('ja', '来る', 'kuru', 'to come', 'verb', 1, '友達が来る', 'a friend comes'),
  ('ja', '見る', 'miru', 'to see / to watch', 'verb', 1, '映画を見る', 'to watch a movie'),
  ('ja', 'する', 'suru', 'to do', 'verb', 1, '勉強をする', 'to do studying'),
  ('ja', 'ある', 'aru', 'to exist (things)', 'verb', 1, '時間がある', 'to have time'),
  ('ja', 'いる', 'iru', 'to exist (people/animals)', 'verb', 1, '猫がいる', 'there is a cat'),
  ('ja', 'いい', 'ii', 'good', 'adjective', 1, '天気がいい', 'the weather is good'),
  ('ja', '大きい', 'ookii', 'big', 'adjective', 1, '家が大きい', 'the house is big'),
  ('ja', '小さい', 'chiisai', 'small', 'adjective', 1, '家が小さい', 'the house is small'),
  ('ja', '水', 'mizu', 'water', 'noun', 1, '水を飲みます', 'I drink water'),
  ('ja', 'ご飯', 'gohan', 'rice / meal', 'noun', 1, 'ご飯を食べます', 'I eat a meal'),
  ('ja', '家', 'ie', 'house / home', 'noun', 1, '家に帰ります', 'I go home'),
  ('ja', '学校', 'gakkou', 'school', 'noun', 1, '学校に行きます', 'I go to school'),
  ('ja', '友達', 'tomodachi', 'friend', 'noun', 1, '友達に会います', 'I meet a friend'),
  ('ja', '本', 'hon', 'book', 'noun', 1, '本を読みます', 'I read a book'),
  ('ja', '人', 'hito', 'person', 'noun', 1, 'いい人', 'a good person'),
  ('ja', '時間', 'jikan', 'time', 'noun', 1, '時間がありません', 'I have no time'),
  ('ja', '今日', 'kyou', 'today', 'noun', 1, '今日は何をしますか', 'What are you doing today?'),
  ('ja', '明日', 'ashita', 'tomorrow', 'noun', 1, 'また明日', 'See you tomorrow'),
  ('ja', '昨日', 'kinou', 'yesterday', 'noun', 1, '昨日学校に行きました', 'I went to school yesterday'),
  ('ja', 'こんにちは', 'konnichiwa', 'hello', 'expression', 1, null, null),
  ('ja', 'ありがとう', 'arigatou', 'thank you', 'expression', 1, null, null),
  ('ja', 'はい', 'hai', 'yes', 'expression', 1, null, null),
  ('ja', 'いいえ', 'iie', 'no', 'expression', 1, null, null),
  ('ja', '名前', 'namae', 'name', 'noun', 1, 'お名前は何ですか', 'What is your name?'),
  ('ja', '愛', 'ai', 'love', 'noun', 2, '愛しています', 'I love you'),
  ('ja', '韓国語', 'kankokugo', 'Korean language', 'noun', 1, '韓国語を勉強します', 'I study Korean'),
  ('ja', '日本語', 'nihongo', 'Japanese language', 'noun', 1, '日本語を勉強します', 'I study Japanese'),
  ('ja', '勉強する', 'benkyou suru', 'to study', 'verb', 1, '日本語を勉強する', 'to study Japanese')
on conflict (language, word, translation) do nothing;

-- ── Grammar points + examples ────────────────────────────────────────────────
with g as (
  insert into public.grammar_points (language, name, meaning, explanation, difficulty) values
    ('ko', '-아/어 주세요', 'Please do...', 'Attach -아/어 주세요 to a verb stem to politely ask someone to do something for you. Verbs whose last vowel is ㅏ/ㅗ take -아 주세요; the rest take -어 주세요.', 1),
    ('ko', '은/는', 'Topic particle', 'Marks the topic of the sentence — what the sentence is about. Use 은 after a consonant and 는 after a vowel. Often contrasts with something else.', 1),
    ('ko', '이/가', 'Subject particle', 'Marks the grammatical subject. Use 이 after a consonant and 가 after a vowel. Emphasizes who or what is doing the action, or introduces new information.', 1),
    ('ko', '-고 싶다', 'Want to...', 'Attach -고 싶다 to a verb stem to express what the speaker wants to do. In polite speech, use -고 싶어요.', 1),
    ('ko', '-았/었어요', 'Past tense (polite)', 'Attach -았어요 (after ㅏ/ㅗ vowels) or -었어요 (after other vowels) to the verb stem to make the polite past tense.', 1),
    ('ja', '〜てください', 'Please...', 'Attach ください to the verb''s て-form to politely ask someone to do something.', 1),
    ('ja', 'は', 'Topic particle', 'Marks the topic of the sentence — what the sentence is about. Written は but pronounced "wa" as a particle.', 1),
    ('ja', 'が', 'Subject particle', 'Marks the grammatical subject. Emphasizes who or what does the action, or introduces new information.', 1),
    ('ja', '〜たい', 'Want to...', 'Attach たい to the verb''s ます-stem to express what the speaker wants to do. Conjugates like an い-adjective.', 1),
    ('ja', '〜ました', 'Past tense (polite)', 'Replace ます with ました to make the polite past tense of a verb.', 1)
  -- Without this the whole seed file fails on a re-run, and everything after
  -- this statement never gets applied. A re-run returns no rows here, so the
  -- example insert below correctly becomes a no-op rather than duplicating.
  on conflict (language, name) do nothing
  returning id, language, name
)
insert into public.grammar_examples (grammar_point_id, native, translation, sort_order)
select g.id, e.native, e.translation, e.sort_order
from g
join (values
  ('ko', '-아/어 주세요', '도와 주세요.', 'Please help me.', 0),
  ('ko', '-아/어 주세요', '기다려 주세요.', 'Please wait.', 1),
  ('ko', '은/는', '저는 학생이에요.', 'I am a student.', 0),
  ('ko', '은/는', '오늘은 날씨가 좋아요.', 'As for today, the weather is good.', 1),
  ('ko', '이/가', '비가 와요.', 'It is raining.', 0),
  ('ko', '이/가', '친구가 왔어요.', 'A friend came.', 1),
  ('ko', '-고 싶다', '먹고 싶어요.', 'I want to eat.', 0),
  ('ko', '-고 싶다', '한국에 가고 싶어요.', 'I want to go to Korea.', 1),
  ('ko', '-았/었어요', '학교에 갔어요.', 'I went to school.', 0),
  ('ko', '-았/었어요', '밥을 먹었어요.', 'I ate a meal.', 1),
  ('ja', '〜てください', '待ってください。', 'Please wait.', 0),
  ('ja', '〜てください', '助けてください。', 'Please help me.', 1),
  ('ja', 'は', '私は学生です。', 'I am a student.', 0),
  ('ja', 'は', '今日は天気がいいです。', 'As for today, the weather is good.', 1),
  ('ja', 'が', '雨が降っています。', 'It is raining.', 0),
  ('ja', 'が', '友達が来ました。', 'A friend came.', 1),
  ('ja', '〜たい', '食べたいです。', 'I want to eat.', 0),
  ('ja', '〜たい', '日本に行きたいです。', 'I want to go to Japan.', 1),
  ('ja', '〜ました', '学校に行きました。', 'I went to school.', 0),
  ('ja', '〜ました', 'ご飯を食べました。', 'I ate a meal.', 1)
) as e(language, name, native, translation, sort_order)
  on e.language = g.language and e.name = g.name;

-- ── Hangul ───────────────────────────────────────────────────────────────────
insert into public.characters
  (language, script, character, romanization, pronunciation_hint, example_word, example_translation, sort_order) values
  ('ko', 'hangul_consonant', 'ㄱ', 'g/k', 'like g in "go"', '가방', 'bag', 1),
  ('ko', 'hangul_consonant', 'ㄴ', 'n', 'like n in "no"', '나무', 'tree', 2),
  ('ko', 'hangul_consonant', 'ㄷ', 'd/t', 'like d in "dog"', '다리', 'leg / bridge', 3),
  ('ko', 'hangul_consonant', 'ㄹ', 'r/l', 'between r and l', '라면', 'ramen', 4),
  ('ko', 'hangul_consonant', 'ㅁ', 'm', 'like m in "mom"', '물', 'water', 5),
  ('ko', 'hangul_consonant', 'ㅂ', 'b/p', 'like b in "boy"', '밥', 'rice / meal', 6),
  ('ko', 'hangul_consonant', 'ㅅ', 's', 'like s in "sun"', '사람', 'person', 7),
  ('ko', 'hangul_consonant', 'ㅇ', 'ng / silent', 'silent at the start, "ng" at the end of a syllable', '아기', 'baby', 8),
  ('ko', 'hangul_consonant', 'ㅈ', 'j', 'like j in "jam"', '자다', 'to sleep', 9),
  ('ko', 'hangul_consonant', 'ㅊ', 'ch', 'like ch in "chair"', '차', 'tea / car', 10),
  ('ko', 'hangul_consonant', 'ㅋ', 'k', 'aspirated k', '코', 'nose', 11),
  ('ko', 'hangul_consonant', 'ㅌ', 't', 'aspirated t', '토끼', 'rabbit', 12),
  ('ko', 'hangul_consonant', 'ㅍ', 'p', 'aspirated p', '팔', 'arm', 13),
  ('ko', 'hangul_consonant', 'ㅎ', 'h', 'like h in "hat"', '하늘', 'sky', 14),
  ('ko', 'hangul_vowel', 'ㅏ', 'a', 'like a in "father"', '아기', 'baby', 15),
  ('ko', 'hangul_vowel', 'ㅑ', 'ya', 'like ya in "yard"', '야구', 'baseball', 16),
  ('ko', 'hangul_vowel', 'ㅓ', 'eo', 'like u in "up"', '어머니', 'mother', 17),
  ('ko', 'hangul_vowel', 'ㅕ', 'yeo', 'like yu in "yummy"', '여자', 'woman', 18),
  ('ko', 'hangul_vowel', 'ㅗ', 'o', 'like o in "go"', '오이', 'cucumber', 19),
  ('ko', 'hangul_vowel', 'ㅛ', 'yo', 'like yo in "yoga"', '요리', 'cooking', 20),
  ('ko', 'hangul_vowel', 'ㅜ', 'u', 'like oo in "moon"', '우유', 'milk', 21),
  ('ko', 'hangul_vowel', 'ㅠ', 'yu', 'like you', '유리', 'glass', 22),
  ('ko', 'hangul_vowel', 'ㅡ', 'eu', 'like u with lips spread flat', '그림', 'picture', 23),
  ('ko', 'hangul_vowel', 'ㅣ', 'i', 'like ee in "see"', '이름', 'name', 24)
on conflict (language, script, character) do nothing;

-- ── Hiragana ─────────────────────────────────────────────────────────────────
insert into public.characters (language, script, character, romanization, sort_order) values
  ('ja','hiragana','あ','a',1),('ja','hiragana','い','i',2),('ja','hiragana','う','u',3),('ja','hiragana','え','e',4),('ja','hiragana','お','o',5),
  ('ja','hiragana','か','ka',6),('ja','hiragana','き','ki',7),('ja','hiragana','く','ku',8),('ja','hiragana','け','ke',9),('ja','hiragana','こ','ko',10),
  ('ja','hiragana','さ','sa',11),('ja','hiragana','し','shi',12),('ja','hiragana','す','su',13),('ja','hiragana','せ','se',14),('ja','hiragana','そ','so',15),
  ('ja','hiragana','た','ta',16),('ja','hiragana','ち','chi',17),('ja','hiragana','つ','tsu',18),('ja','hiragana','て','te',19),('ja','hiragana','と','to',20),
  ('ja','hiragana','な','na',21),('ja','hiragana','に','ni',22),('ja','hiragana','ぬ','nu',23),('ja','hiragana','ね','ne',24),('ja','hiragana','の','no',25),
  ('ja','hiragana','は','ha',26),('ja','hiragana','ひ','hi',27),('ja','hiragana','ふ','fu',28),('ja','hiragana','へ','he',29),('ja','hiragana','ほ','ho',30),
  ('ja','hiragana','ま','ma',31),('ja','hiragana','み','mi',32),('ja','hiragana','む','mu',33),('ja','hiragana','め','me',34),('ja','hiragana','も','mo',35),
  ('ja','hiragana','や','ya',36),('ja','hiragana','ゆ','yu',37),('ja','hiragana','よ','yo',38),
  ('ja','hiragana','ら','ra',39),('ja','hiragana','り','ri',40),('ja','hiragana','る','ru',41),('ja','hiragana','れ','re',42),('ja','hiragana','ろ','ro',43),
  ('ja','hiragana','わ','wa',44),('ja','hiragana','を','wo',45),('ja','hiragana','ん','n',46)
on conflict (language, script, character) do nothing;

-- ── Katakana ─────────────────────────────────────────────────────────────────
insert into public.characters (language, script, character, romanization, sort_order) values
  ('ja','katakana','ア','a',101),('ja','katakana','イ','i',102),('ja','katakana','ウ','u',103),('ja','katakana','エ','e',104),('ja','katakana','オ','o',105),
  ('ja','katakana','カ','ka',106),('ja','katakana','キ','ki',107),('ja','katakana','ク','ku',108),('ja','katakana','ケ','ke',109),('ja','katakana','コ','ko',110),
  ('ja','katakana','サ','sa',111),('ja','katakana','シ','shi',112),('ja','katakana','ス','su',113),('ja','katakana','セ','se',114),('ja','katakana','ソ','so',115),
  ('ja','katakana','タ','ta',116),('ja','katakana','チ','chi',117),('ja','katakana','ツ','tsu',118),('ja','katakana','テ','te',119),('ja','katakana','ト','to',120),
  ('ja','katakana','ナ','na',121),('ja','katakana','ニ','ni',122),('ja','katakana','ヌ','nu',123),('ja','katakana','ネ','ne',124),('ja','katakana','ノ','no',125),
  ('ja','katakana','ハ','ha',126),('ja','katakana','ヒ','hi',127),('ja','katakana','フ','fu',128),('ja','katakana','ヘ','he',129),('ja','katakana','ホ','ho',130),
  ('ja','katakana','マ','ma',131),('ja','katakana','ミ','mi',132),('ja','katakana','ム','mu',133),('ja','katakana','メ','me',134),('ja','katakana','モ','mo',135),
  ('ja','katakana','ヤ','ya',136),('ja','katakana','ユ','yu',137),('ja','katakana','ヨ','yo',138),
  ('ja','katakana','ラ','ra',139),('ja','katakana','リ','ri',140),('ja','katakana','ル','ru',141),('ja','katakana','レ','re',142),('ja','katakana','ロ','ro',143),
  ('ja','katakana','ワ','wa',144),('ja','katakana','ヲ','wo',145),('ja','katakana','ン','n',146)
on conflict (language, script, character) do nothing;

-- ── Kanji (US-061) ───────────────────────────────────────────────────────────
-- JLPT N5 set. `stroke_count` is deliberately left null: the app does not show
-- stroke order or counts it has not verified against a reference source.
insert into public.characters
  (language, script, character, romanization, meanings, readings, level_label, sort_order) values
  ('ja','kanji','日','nichi / hi',        '{sun,day}',              '{"on":["ニチ","ジツ"],"kun":["ひ","-び","-か"]}', 'JLPT N5', 200),
  ('ja','kanji','月','getsu / tsuki',     '{moon,month}',           '{"on":["ゲツ","ガツ"],"kun":["つき"]}',          'JLPT N5', 201),
  ('ja','kanji','火','ka / hi',           '{fire}',                 '{"on":["カ"],"kun":["ひ"]}',                     'JLPT N5', 202),
  ('ja','kanji','水','sui / mizu',        '{water}',                '{"on":["スイ"],"kun":["みず"]}',                 'JLPT N5', 203),
  ('ja','kanji','木','moku / ki',         '{tree,wood}',            '{"on":["モク","ボク"],"kun":["き"]}',            'JLPT N5', 204),
  ('ja','kanji','金','kin / kane',        '{gold,money,metal}',     '{"on":["キン","コン"],"kun":["かね"]}',          'JLPT N5', 205),
  ('ja','kanji','土','do / tsuchi',       '{earth,soil}',           '{"on":["ド","ト"],"kun":["つち"]}',              'JLPT N5', 206),
  ('ja','kanji','人','jin / hito',        '{person}',               '{"on":["ジン","ニン"],"kun":["ひと"]}',          'JLPT N5', 207),
  ('ja','kanji','口','kou / kuchi',       '{mouth,opening}',        '{"on":["コウ","ク"],"kun":["くち"]}',            'JLPT N5', 208),
  ('ja','kanji','目','moku / me',         '{eye}',                  '{"on":["モク","ボク"],"kun":["め"]}',            'JLPT N5', 209),
  ('ja','kanji','耳','ji / mimi',         '{ear}',                  '{"on":["ジ"],"kun":["みみ"]}',                   'JLPT N5', 210),
  ('ja','kanji','手','shu / te',          '{hand}',                 '{"on":["シュ"],"kun":["て"]}',                   'JLPT N5', 211),
  ('ja','kanji','足','soku / ashi',       '{foot,leg,"to suffice"}','{"on":["ソク"],"kun":["あし","た-りる"]}',       'JLPT N5', 212),
  ('ja','kanji','山','san / yama',        '{mountain}',             '{"on":["サン"],"kun":["やま"]}',                 'JLPT N5', 213),
  ('ja','kanji','川','sen / kawa',        '{river}',                '{"on":["セン"],"kun":["かわ"]}',                 'JLPT N5', 214),
  ('ja','kanji','田','den / ta',          '{"rice field"}',         '{"on":["デン"],"kun":["た"]}',                   'JLPT N5', 215),
  ('ja','kanji','天','ten / ama',         '{heaven,sky}',           '{"on":["テン"],"kun":["あま"]}',                 'JLPT N5', 216),
  ('ja','kanji','雨','u / ame',           '{rain}',                 '{"on":["ウ"],"kun":["あめ"]}',                   'JLPT N5', 217),
  ('ja','kanji','大','dai / ookii',       '{big,large}',            '{"on":["ダイ","タイ"],"kun":["おお-きい"]}',     'JLPT N5', 218),
  ('ja','kanji','小','shou / chiisai',    '{small,little}',         '{"on":["ショウ"],"kun":["ちい-さい","こ-"]}',    'JLPT N5', 219),
  ('ja','kanji','中','chuu / naka',       '{middle,inside}',        '{"on":["チュウ"],"kun":["なか"]}',               'JLPT N5', 220),
  ('ja','kanji','上','jou / ue',          '{above,up,"to rise"}',   '{"on":["ジョウ"],"kun":["うえ","あ-がる","のぼ-る"]}', 'JLPT N5', 221),
  ('ja','kanji','下','ka / shita',        '{below,down,"to lower"}','{"on":["カ","ゲ"],"kun":["した","さ-がる","くだ-さい"]}', 'JLPT N5', 222),
  ('ja','kanji','左','sa / hidari',       '{left}',                 '{"on":["サ"],"kun":["ひだり"]}',                 'JLPT N5', 223),
  ('ja','kanji','右','u / migi',          '{right}',                '{"on":["ウ","ユウ"],"kun":["みぎ"]}',            'JLPT N5', 224),
  ('ja','kanji','本','hon / moto',        '{book,origin,"counter for long objects"}', '{"on":["ホン"],"kun":["もと"]}', 'JLPT N5', 225),
  ('ja','kanji','年','nen / toshi',       '{year}',                 '{"on":["ネン"],"kun":["とし"]}',                 'JLPT N5', 226),
  ('ja','kanji','時','ji / toki',         '{time,hour}',            '{"on":["ジ"],"kun":["とき"]}',                   'JLPT N5', 227),
  ('ja','kanji','分','bun / wakeru',      '{minute,part,"to divide","to understand"}', '{"on":["ブン","フン","ブ"],"kun":["わ-ける","わ-かる"]}', 'JLPT N5', 228),
  ('ja','kanji','今','kon / ima',         '{now}',                  '{"on":["コン","キン"],"kun":["いま"]}',          'JLPT N5', 229),
  ('ja','kanji','何','ka / nani',         '{what}',                 '{"on":["カ"],"kun":["なに","なん"]}',            'JLPT N5', 230),
  ('ja','kanji','私','shi / watashi',     '{I,private}',            '{"on":["シ"],"kun":["わたし","わたくし"]}',      'JLPT N5', 231),
  ('ja','kanji','学','gaku / manabu',     '{study,learning}',       '{"on":["ガク"],"kun":["まな-ぶ"]}',              'JLPT N5', 232),
  ('ja','kanji','校','kou',               '{school}',               '{"on":["コウ"],"kun":[]}',                       'JLPT N5', 233),
  ('ja','kanji','先','sen / saki',        '{previous,ahead,tip}',   '{"on":["セン"],"kun":["さき"]}',                 'JLPT N5', 234),
  ('ja','kanji','生','sei / ikiru',       '{life,birth,raw}',       '{"on":["セイ","ショウ"],"kun":["い-きる","う-まれる","なま"]}', 'JLPT N5', 235),
  ('ja','kanji','国','koku / kuni',       '{country}',              '{"on":["コク"],"kun":["くに"]}',                 'JLPT N5', 236),
  ('ja','kanji','語','go / kataru',       '{language,"to tell"}',   '{"on":["ゴ"],"kun":["かた-る"]}',                'JLPT N5', 237),
  ('ja','kanji','車','sha / kuruma',      '{car,vehicle,wheel}',    '{"on":["シャ"],"kun":["くるま"]}',               'JLPT N5', 238),
  ('ja','kanji','見','ken / miru',        '{"to see","to look"}',   '{"on":["ケン"],"kun":["み-る"]}',                'JLPT N5', 239),
  ('ja','kanji','行','kou / iku',         '{"to go","to carry out"}','{"on":["コウ","ギョウ"],"kun":["い-く","おこな-う"]}', 'JLPT N5', 240),
  ('ja','kanji','食','shoku / taberu',    '{"to eat",food}',        '{"on":["ショク"],"kun":["た-べる","く-う"]}',    'JLPT N5', 241),
  ('ja','kanji','飲','in / nomu',         '{"to drink"}',           '{"on":["イン"],"kun":["の-む"]}',                'JLPT N5', 242),
  ('ja','kanji','高','kou / takai',       '{tall,high,expensive}',  '{"on":["コウ"],"kun":["たか-い"]}',              'JLPT N5', 243),
  ('ja','kanji','安','an / yasui',        '{cheap,peaceful}',       '{"on":["アン"],"kun":["やす-い"]}',              'JLPT N5', 244),
  ('ja','kanji','新','shin / atarashii',  '{new}',                  '{"on":["シン"],"kun":["あたら-しい"]}',          'JLPT N5', 245),
  ('ja','kanji','古','ko / furui',        '{old}',                  '{"on":["コ"],"kun":["ふる-い"]}',                'JLPT N5', 246),
  ('ja','kanji','話','wa / hanasu',       '{"to speak",story}',     '{"on":["ワ"],"kun":["はな-す","はなし"]}',       'JLPT N5', 247),
  ('ja','kanji','読','doku / yomu',       '{"to read"}',            '{"on":["ドク"],"kun":["よ-む"]}',                'JLPT N5', 248),
  ('ja','kanji','書','sho / kaku',        '{"to write"}',           '{"on":["ショ"],"kun":["か-く"]}',                'JLPT N5', 249)
on conflict (language, script, character) do nothing;

-- Example vocabulary per kanji, drawn from the vocabulary table so each example
-- keeps its own audio, reading and SRS state.
insert into public.character_vocabulary (character_id, vocabulary_id, sort_order)
select c.id, v.id, p.ord
from (values
  ('日','日本語',0), ('水','水',0),   ('人','人',0),   ('大','大きい',0),
  ('小','小さい',0), ('本','本',0),   ('時','時間',0), ('今','今日',0),
  ('学','学校',0),   ('校','学校',0), ('語','日本語',0), ('語','韓国語',1),
  ('家','家',0),     ('食','食べる',0), ('見','見る',0), ('行','行く',0)
) as p(ch, word, ord)
join public.characters c
  on c.language = 'ja' and c.script = 'kanji' and c.character = p.ch
join public.vocabulary v
  on v.language = 'ja' and v.word = p.word
on conflict (character_id, vocabulary_id) do nothing;

-- ── Korean ↔ Japanese comparison (US-120, US-121) ────────────────────────────
-- `equivalence` is stated per concept and never inflated: 'close' means the two
-- structures really do the same job, 'partial' means they overlap but diverge,
-- 'false_friend' means they look related and are not.
with c as (
  insert into public.concepts
    (kind, english, key_difference, similarity, equivalence, sort_order) values
    ('expression', 'I am going to school.',
     'Both mark the destination with a particle after the noun, and both put the verb last. The particles differ: Korean 에, Japanese に.',
     'Word order is identical, so a sentence can usually be mapped word for word.',
     'close', 0),
    ('expression', 'I am a student.',
     'Korean 이에요/예요 attaches directly to the noun and alternates on the final consonant; Japanese です is a separate word and never changes shape here.',
     'Both mark the subject as a topic and place the copula at the end.',
     'close', 1),
    ('expression', 'I want to eat.',
     'Korean -고 싶다 is an auxiliary verb. Japanese 〜たい behaves like an い-adjective, so it conjugates (たかった, たくない) where the Korean form does not.',
     'Both attach to the verb stem and express the speaker''s own desire.',
     'partial', 2),
    ('expression', 'I have no time.',
     'Korean has a dedicated verb for non-existence, 없다. Japanese has no such verb and negates ある instead (ありません).',
     'Both mark what is missing with the subject particle rather than an object particle.',
     'partial', 3),
    ('grammar', 'Topic particle',
     'Korean alternates 은 after a consonant and 는 after a vowel. Japanese は never changes form, but is read "wa" when used as a particle.',
     'Both mark what the sentence is about, and both carry an implied contrast with something else.',
     'close', 10),
    ('grammar', 'Subject particle',
     'Korean alternates 이 after a consonant and 가 after a vowel. Japanese が has one form.',
     'Both mark the grammatical subject and both introduce new information rather than a known topic.',
     'close', 11),
    ('grammar', 'Polite past tense',
     'Korean -았/었- is a tense marker inside the verb, so the plain past -았/었다 exists on its own. Japanese ました is the past form of the polite ending ます; the plain past is a different form, 〜た.',
     'Both are formed by changing the verb ending, not by adding a helper verb.',
     'partial', 12),
    ('grammar', 'Location particle',
     'Korean splits location in two: 에 for where something is or is headed, 에서 for where an action happens. Japanese also splits it, but along a different line: に for existence and destination, で for the place of an action. Mapping 에 to に everywhere produces wrong sentences.',
     'Both languages mark location with a particle after the noun rather than a preposition before it.',
     'partial', 13),
    ('vocabulary', 'Study / ingenuity (工夫)',
     'The same two characters. Korean 공부 (工夫) means studying. Japanese 工夫 (くふう) means devising a clever solution. They are not translations of each other.',
     'Both are Sino-Xenic readings of the same written form, which is why they look related.',
     'false_friend', 20),
    ('vocabulary', 'Partner / mistress (愛人)',
     'The same two characters. Korean 애인 (愛人) is a neutral word for a romantic partner. Japanese 愛人 (あいじん) means a lover in an affair and is not neutral. Using the Korean sense in Japanese causes real offence.',
     'Both come from the same written form and both refer to a romantic relationship.',
     'false_friend', 21)
  on conflict (kind, english) do nothing
  returning id, kind, english
)
insert into public.concept_entries
  (concept_id, language, structure, example_native, example_translation, literal_gloss, note)
select c.id, e.language, e.structure, e.example_native, e.example_translation,
       e.literal_gloss, e.note
from c
join (values
  ('expression','I am going to school.','ko','[place] + 에 + 가다','학교에 가요.','I go to school.','school-TO go','에 marks the destination.'),
  ('expression','I am going to school.','ja','[place] + に + 行く','学校に行きます。','I go to school.','school-TO go','に marks the destination.'),
  ('expression','I am a student.','ko','[noun] + 이에요/예요','저는 학생이에요.','I am a student.','I-TOPIC student-BE','학생 ends in a consonant, so 이에요.'),
  ('expression','I am a student.','ja','[noun] + です','私は学生です。','I am a student.','I-TOPIC student BE','です is invariant here.'),
  ('expression','I want to eat.','ko','[verb stem] + 고 싶다','먹고 싶어요.','I want to eat.','eat-want','Negated as 먹고 싶지 않아요.'),
  ('expression','I want to eat.','ja','[ます-stem] + たい','食べたいです。','I want to eat.','eat-want','Negated as 食べたくないです — たい inflects.'),
  ('expression','I have no time.','ko','[noun] + 이/가 + 없다','시간이 없어요.','I have no time.','time-SUBJ not-exist','없다 is its own verb, the opposite of 있다.'),
  ('expression','I have no time.','ja','[noun] + が + ありません','時間がありません。','I have no time.','time-SUBJ exist-NOT','Negation of ある; there is no separate verb.'),
  ('grammar','Topic particle','ko','은 (after consonant) / 는 (after vowel)','저는 학생이에요.','I am a student.',null,'저 ends in a vowel, so 는.'),
  ('grammar','Topic particle','ja','は (always written は, read "wa")','私は学生です。','I am a student.',null,'Spelling never changes.'),
  ('grammar','Subject particle','ko','이 (after consonant) / 가 (after vowel)','비가 와요.','It is raining.',null,'비 ends in a vowel, so 가.'),
  ('grammar','Subject particle','ja','が','雨が降っています。','It is raining.',null,'One form in all positions.'),
  ('grammar','Polite past tense','ko','[verb stem] + 았/었 + 어요','학교에 갔어요.','I went to school.',null,'가 + 았 contracts to 갔.'),
  ('grammar','Polite past tense','ja','[ます-stem] + ました','学校に行きました。','I went to school.',null,'行きます becomes 行きました.'),
  ('grammar','Location particle','ko','에 (existence / destination) vs 에서 (action)','집에서 공부해요.','I study at home.','home-AT study','에 would mean "to home", not "at home".'),
  ('grammar','Location particle','ja','に (existence / destination) vs で (action)','家で勉強します。','I study at home.','home-AT study','に would mean "to home", not "at home".'),
  ('vocabulary','Study / ingenuity (工夫)','ko','공부 (工夫)','한국어를 공부해요.','I study Korean.',null,'Everyday word for studying.'),
  ('vocabulary','Study / ingenuity (工夫)','ja','工夫 (くふう)','工夫が必要です。','Some ingenuity is needed.',null,'Never means studying — that is 勉強.'),
  ('vocabulary','Partner / mistress (愛人)','ko','애인 (愛人)','애인이 있어요.','I have a partner.',null,'Neutral, used freely.'),
  ('vocabulary','Partner / mistress (愛人)','ja','愛人 (あいじん)','彼には愛人がいる。','He has a mistress.',null,'Strongly negative. For a partner say 恋人.')
) as e(kind, english, language, structure, example_native, example_translation, literal_gloss, note)
  on e.kind = c.kind and e.english = c.english
on conflict (concept_id, language) do nothing;
